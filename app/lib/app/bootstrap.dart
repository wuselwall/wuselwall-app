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
import 'package:wuselwall/core/server/first_party.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/server_compat.dart';
import 'package:wuselwall/core/server/server_discovery.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/core/server/server_store.dart';
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
/// - The web app first looks at its own origin: a server serves its own web app.
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
    @visibleForTesting this.app = const WuselWallApp(),
    super.key,
  }) : store = store ?? ServerStore(),
       discovery = discovery ?? ServerDiscovery(),
       appVersion = appVersion ?? _packageVersion,
       connect = connect ?? initSupabase,
       disconnect = disconnect ?? _disposeSupabase,
       hasSession = hasSession ?? SecureSessionStorage().hasAccessToken,
       signOutLocally = signOutLocally ?? _signOutLocally;

  /// The build's configuration (`AppConfig.fromEnvironment`).
  final AppConfig build;
  final ServerStore store;
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

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final build = widget.build;
    if (build.hasFixedServer) {
      await _run(build);
      return;
    }
    final stored = await widget.store.read();
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
    final web = widget.webOrigin;
    if (web != null && await _connect(web) == null) return;
    _show(const _Choosing());
  }

  /// Discovers [address], checks it against this app, keeps it and starts the app on it.
  /// Returns why it could not, or null.
  Future<ServerProblem?> _connect(Uri address) async {
    final result = await widget.discovery.discover(address);
    switch (result) {
      case Err(:final failure):
        return failure is NetworkFailure
            ? ServerProblem.unreachable
            : ServerProblem.notWuselwall;
      case Ok(value: final server):
        final problem = await _fit(server);
        if (problem != null) return problem;
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
    final session = ServerSession(
      leave: config.hasFixedServer ? null : _leave,
      pendingEnrolCode: _pendingEnrolCode,
    );
    _pendingEnrolCode = null;
    _show(_Running(config, session, ++_generation));
  }

  /// Signs this device out of its server and forgets the server: the next start asks
  /// again. The running app has emptied its own stores before calling this.
  Future<void> _leave() async {
    if (_connected) await widget.signOutLocally();
    await widget.store.clear();
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
