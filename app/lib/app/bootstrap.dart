import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/notifications/notification_scheduler.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/core/notifications/plugin_notification_scheduler.dart';
import 'package:wuselwall/core/server/first_party.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/server_compat.dart';
import 'package:wuselwall/core/server/server_discovery.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/core/server/server_link.dart';
import 'package:wuselwall/core/server/server_store.dart';
import 'package:wuselwall/core/server/setup_link.dart';
import 'package:wuselwall/core/server/setup_store.dart';
import 'package:wuselwall/core/supabase/secure_session_storage.dart';
import 'package:wuselwall/core/supabase/supabase_bootstrap.dart';
import 'package:wuselwall/demo/demo_overrides.dart';
import 'package:wuselwall/features/identity/domain/enrol_code.dart';
import 'package:wuselwall/features/setup/ui/server_choice_page.dart';

/// Decides which server the app talks to, before anything else starts (ADR-018,
/// decision 3), and starts the app on it.
///
/// - A build that names its server (`SUPABASE_URL`, development) starts on it at once.
/// - A store build starts on the server it chose before; it checks that server's
///   discovery document again in the background and stops at a server it no longer
///   fits (decision 5).
/// - A store build updated from one that had a first-party server compiled in finds a
///   session but no server, and keeps that server ([legacyServer]).
/// - An invitation or pairing link names its server ([links]); with no server chosen the app
///   uses that one and skips the question.
/// - The web app refreshes its own origin before using a cached server/key; it uses
///   the cache only when discovery is unreachable, so an offline start still works.
/// - Otherwise it asks ([ServerChoicePage]), or shows the demo household.
class Bootstrap extends StatefulWidget {
  Bootstrap({
    required this.build,
    ServerStore? store,
    ServerDiscovery? discovery,
    Future<String> Function()? appVersion,
    Future<void> Function(AppConfig)? connect,
    Future<void> Function()? disconnect,
    Future<bool> Function()? hasSession,
    Future<void> Function()? signOutLocally,
    this.webOrigin,
    this.initialSetup,
    SetupStore? setupStore,
    this.links,
    @visibleForTesting this.app = const WuselWallApp(),
    super.key,
  }) : setupStore = setupStore ?? SetupStore(),
       store = store ?? ServerStore(),
       discovery = discovery ?? ServerDiscovery(),
       appVersion = appVersion ?? _packageVersion,
       connect = connect ?? initSupabase,
       disconnect = disconnect ?? _disposeSupabase,
       hasSession = hasSession ?? SecureSessionStorage().hasAccessToken,
       signOutLocally = signOutLocally ?? _signOutLocally;

  /// The build's configuration (`AppConfig.fromEnvironment`).
  final AppConfig build;
  final ServerStore store;
  final SetupStore setupStore;
  final SetupLink? initialSetup;
  final ServerDiscovery discovery;
  final Future<String> Function() appVersion;
  final Future<void> Function(AppConfig) connect;
  final Future<void> Function() disconnect;
  final Future<bool> Function() hasSession;

  /// Ends this device's session on its server, here only: the device record is the
  /// running app's business (Settings → Change server signs out first).
  final Future<void> Function() signOutLocally;

  /// The web app's own origin; null on the native apps.
  final Uri? webOrigin;

  /// The links the app is opened with, as text (`app_links`; null where there are none).
  /// A link names a server: with none chosen the app connects to it, with the same one it
  /// continues, with another it asks (specs/20, "Choosing the server").
  final Stream<String>? links;

  /// What runs once a server is chosen (tests replace it: no Supabase there).
  final Widget app;

  static Future<String> _packageVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  static Future<void> _disposeSupabase() => Supabase.instance.dispose();

  static Future<void> _signOutLocally() async {
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (e, st) {
      logError(
        'Local sign-out before leaving the server',
        error: e,
        stackTrace: st,
      );
    }
    await SecureSessionStorage().removePersistedSession();
  }

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

sealed class _Phase {
  const _Phase();
}

final class _Starting extends _Phase {
  const _Starting();
}

final class _Choosing extends _Phase {
  const _Choosing({this.prefill, this.problem});
  final String? prefill;
  final ServerProblem? problem;
}

final class _Running extends _Phase {
  const _Running(this.config, this.session, this.generation);
  final AppConfig config;
  final ServerSession session;
  final int generation;
}

final class _Demo extends _Phase {
  const _Demo();
}

final class _Incompatible extends _Phase {
  const _Incompatible(this.problem);
  final ServerProblem problem;
}

class _BootstrapState extends State<Bootstrap> {
  _Phase _phase = const _Starting();
  bool _connected = false;
  int _generation = 0;
  String? _pendingEnrolCode;

  /// The server the app runs on, null while none is chosen.
  Uri? _server;
  ServerSession? _session;
  OpenedLink? _pendingLink;
  StreamSubscription<String>? _linkSubscription;
  bool _started = false;
  OpenedLink? _earlyLink;
  SetupLink? _earlySetup;
  final _firstLink = Completer<void>();

  @override
  void initState() {
    super.initState();
    _linkSubscription = widget.links?.listen(
      (raw) => unawaited(_onLink(raw)),
      onError: (Object e, StackTrace st) =>
          logError('Reading a link', error: e, stackTrace: st),
    );
    unawaited(_startAndOpenLink());
  }

  @override
  void dispose() {
    unawaited(_linkSubscription?.cancel());
    super.dispose();
  }

  Future<void> _startAndOpenLink() async {
    await _start();
    _started = true;
    final early = _earlyLink;
    _earlyLink = null;
    if (early != null) await _handleLink(early);
    final setup = _earlySetup;
    _earlySetup = null;
    if (setup != null) await _handleSetup(setup);
  }

  Future<void> _onLink(String raw) async {
    final setup = parseSetupLink(raw);
    if (setup != null) {
      if (!_firstLink.isCompleted) _firstLink.complete();
      if (!_started) {
        _earlySetup = setup;
        return;
      }
      await _handleSetup(setup);
      return;
    }
    final link = parseAppLink(raw);
    if (link == null) return;
    if (!_firstLink.isCompleted) _firstLink.complete();
    if (!_started) {
      _earlyLink = link;
      return;
    }
    await _handleLink(link);
  }

  Future<void> _handleSetup(SetupLink link) async {
    // Never silently switch an existing installation to an untrusted link's server.
    if (_server != null && _server != link.server) return;
    if (_server == null) {
      await _connect(link.server, setup: link);
    } else {
      await widget.setupStore.save(link);
      _session?.setupPending.value = true;
    }
  }

  /// A link while the app is up: connect, continue, or hand the decision to the app.
  Future<void> _handleLink(OpenedLink link) async {
    if (!mounted || _phase is _Incompatible) return;
    final verdict = decideLink(
      linkServer: link.server,
      current: _server,
      signedIn: _server != null && await widget.hasSession(),
    );
    switch (verdict) {
      case LinkVerdict.needsServer:
        _show(const _Choosing(problem: ServerProblem.linkWithoutServer));
      case LinkVerdict.connect:
        await _connectForLink(link);
      case LinkVerdict.proceed:
      case LinkVerdict.offerSwitch:
      case LinkVerdict.otherServer:
        _session?.inbox.value = LinkEvent(link, verdict, current: _server);
    }
  }

  /// Leaves the current server for the one [link] names. Nobody is signed in on it.
  Future<void> _switchToLinkServer(OpenedLink link) => _connectForLink(link);

  Future<void> _connectForLink(OpenedLink link) async {
    final server = link.server!;
    _show(const _Starting());
    _pendingLink = link;
    final problem = await _connect(server);
    if (problem != null) {
      _pendingLink = null;
      _show(_Choosing(prefill: displayServerAddress(server), problem: problem));
    }
  }

  Future<void> _start() async {
    final build = widget.build;
    final stored = build.hasFixedServer ? null : await widget.store.read();
    final setup = widget.initialSetup;
    final web = widget.webOrigin;
    if (!build.hasFixedServer && web != null) {
      // The installation, not a previous browser choice, defines this web app's
      // backend. Refresh before constructing clients: a background recheck leaves
      // the running app using a retired address/key until another reload.
      final discovered = await widget.discovery.discover(web);
      switch (discovered) {
        case Ok(value: final server):
          final problem = await _fit(server);
          if (problem != null) {
            _show(_Incompatible(problem));
            return;
          }
          if (stored != null && stored.supabaseUrl != server.supabaseUrl) {
            // Never restore another backend's session into this client. Keep
            // offline data untouched; the member signs in on this server again.
            await SecureSessionStorage().removePersistedSession();
            await widget.setupStore.clear();
          }
          if (setup != null && setup.server == server.supabaseUrl) {
            await widget.setupStore.save(setup);
          }
          await widget.store.write(server);
          await _run(AppConfig.forServer(build, server));
          return;
        case Err(failure: NetworkFailure()) when stored != null:
          break; // Offline: the last working configuration remains usable.
        case Err(:final failure):
          _show(
            _Choosing(
              prefill: displayServerAddress(web),
              problem: failure is NetworkFailure
                  ? ServerProblem.unreachable
                  : ServerProblem.notWuselwall,
            ),
          );
          return;
      }
    }
    if (setup != null) {
      if (build.hasFixedServer) {
        if (Uri.parse(build.supabaseUrl) == setup.server) {
          await widget.setupStore.save(setup);
        }
      } else if (stored == null || stored.supabaseUrl == setup.server) {
        if (await _connect(setup.server, setup: setup) == null) return;
      }
    }
    if (build.hasFixedServer) {
      await _run(build);
      return;
    }
    if (stored != null) {
      await _run(AppConfig.forServer(build, stored));
      unawaited(_recheck(stored));
      return;
    }
    final legacy = legacyServer;
    if (legacy != null && await widget.hasSession()) {
      final problem = await _connect(legacy);
      if (problem == null) return;
      // Offline at the first start after the update: the address is known, ask again.
      _show(_Choosing(prefill: displayServerAddress(legacy), problem: problem));
      return;
    }

    // A link that opened the app names its server: wait a moment for it rather than ask.
    if (widget.links != null) {
      await _firstLink.future.timeout(
        const Duration(milliseconds: 400),
        onTimeout: () {},
      );
      if (_earlyLink != null || _earlySetup != null) return;
    }
    _show(const _Choosing());
  }

  /// Discovers [address], checks it against this app, keeps it and starts the app on it.
  /// Returns why it could not, or null.
  Future<ServerProblem?> _connect(Uri address, {SetupLink? setup}) async {
    final result = await widget.discovery.discover(address);
    switch (result) {
      case Err(:final failure):
        return failure is NetworkFailure
            ? ServerProblem.unreachable
            : ServerProblem.notWuselwall;
      case Ok(value: final server):
        final problem = await _fit(server);
        if (problem != null) return problem;
        // Discovery must not substitute a different origin for a capability.
        if (setup != null && setup.server != server.supabaseUrl) {
          return ServerProblem.invalid;
        }
        if (setup != null) await widget.setupStore.save(setup);
        await widget.store.write(server);
        await _run(AppConfig.forServer(widget.build, server));
        return null;
    }
  }

  Future<ServerProblem?> _fit(ServerInfo server) async =>
      switch (compatibility(server, await widget.appVersion())) {
        Compatibility.ok => null,
        Compatibility.serverTooOld => ServerProblem.serverTooOld,
        Compatibility.appTooOld => ServerProblem.appTooOld,
      };

  /// The stored server again, as it describes itself today. Offline: nothing changes.
  /// A changed document is kept for the next start; a server this app no longer fits
  /// stops the app now.
  Future<void> _recheck(ServerInfo stored) async {
    final result = await widget.discovery.discover(stored.supabaseUrl);
    if (result case Ok(value: final server)) {
      final problem = await _fit(server);
      if (problem != null) {
        _show(_Incompatible(problem));
        return;
      }
      await widget.store.write(server);
    }
  }

  Future<ServerProblem?> _choose(String raw) async {
    // An invitation or pairing link (or `CODE@host`) names its server and carries on.
    final link = parseAppLink(raw);
    final typed = link == null ? parseInvitation(raw) : null;
    final named =
        link ??
        (typed == null
            ? null
            : OpenedLink(
                LinkKind.invitation,
                typed.secret,
                server: typed.server,
              ));
    if (named != null) {
      if (named.server == null) return ServerProblem.linkWithoutServer;
      _pendingLink = named;
      final problem = await _connect(named.server!);
      if (problem != null) _pendingLink = null;
      return problem;
    }
    final setup = parseSetupLink(raw);
    if (setup != null) return _connect(setup.server, setup: setup);
    final address = parseServerAddress(raw, allowHttp: kDebugMode);
    if (address == null) return ServerProblem.invalid;
    // A device code's QR carries its server: one scan for both (ADR-018).
    _pendingEnrolCode = raw.trim().startsWith('wuselwall://enrol')
        ? parseEnrolmentCode(raw)
        : null;
    return _connect(address);
  }

  Future<void> _run(AppConfig config) async {
    if (_connected) {
      await widget.disconnect();
      _connected = false;
    }
    await widget.connect(config);
    _connected = true;
    _server = Uri.tryParse(config.supabaseUrl);
    final pending = _pendingLink;
    final session = ServerSession(
      hasSetup:
          _server != null && await widget.setupStore.read(_server!) != null,
      leave: config.hasFixedServer ? null : _leave,
      pendingEnrolCode: _pendingEnrolCode,
      openLink: _handleLink,
      switchToLinkServer: config.hasFixedServer ? null : _switchToLinkServer,
      initialLink: pending == null
          ? null
          : LinkEvent(pending, LinkVerdict.proceed, current: _server),
    );
    _pendingLink = null;
    _pendingEnrolCode = null;
    _session = session;
    _show(_Running(config, session, ++_generation));
  }

  /// Signs this device out of its server and forgets the server: the next start asks
  /// again. The running app has emptied its own stores before calling this.
  Future<void> _leave() async {
    if (_connected) await widget.signOutLocally();
    await widget.setupStore.clear();
    await widget.store.clear();
    _server = null;
    _session = null;
    _show(const _Choosing());
    // The old app is gone from the tree after this frame; then its client can go.
    await WidgetsBinding.instance.endOfFrame;
    if (_connected) {
      await widget.disconnect();
      _connected = false;
    }
  }

  void _show(_Phase phase) {
    if (mounted) setState(() => _phase = phase);
  }

  @override
  Widget build(BuildContext context) => switch (_phase) {
    _Starting() => const BootstrapShell(
      child: Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
    _Choosing(:final prefill, :final problem) => BootstrapShell(
      child: ServerChoicePage(
        key: ValueKey(_phase),
        prefill: prefill,
        problem: problem,
        onAddress: _choose,
        onDemo: () => _show(const _Demo()),
      ),
    ),
    _Incompatible(:final problem) => BootstrapShell(
      child: ServerIncompatiblePage(
        problem: problem,
        onChooseOther: () => unawaited(_leave()),
      ),
    ),
    _Demo() => ProviderScope(
      key: const ValueKey('demo'),
      overrides: [
        ...demoOverrides(),
        appBannerProvider.overrideWithValue(
          (context) => DemoBanner(onExit: () => _show(const _Choosing())),
        ),
      ],
      child: const WuselWallApp(),
    ),
    _Running(:final config, :final session, :final generation) => ProviderScope(
      key: ValueKey('server-$generation'),
      overrides: [
        appConfigProvider.overrideWithValue(config),
        serverSessionProvider.overrideWithValue(session),
        setupStoreProvider.overrideWithValue(widget.setupStore),
        // Local reminders exist on Android and iOS only (specs/09, Q47).
        notificationSchedulerProvider.overrideWithValue(
          !kIsWeb &&
                  (defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS)
              ? PluginNotificationScheduler()
              : const NoopNotificationScheduler(),
        ),
      ],
      child: widget.app,
    ),
  };
}

/// The screens before the app (the server choice, a mismatch): the app's theme and
/// languages, nothing else. Also the docs' screenshot of the server choice.
class BootstrapShell extends StatelessWidget {
  const BootstrapShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => context.l10n.appTitle,
    supportedLocales: supportedLocales,
    localizationsDelegates: localizationsDelegates,
    theme: AppTheme.build(UiRegister.adult, Shade.light),
    darkTheme: AppTheme.build(UiRegister.adult, Shade.dark),
    home: child,
  );
}
