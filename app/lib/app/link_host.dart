import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/server_link.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/application/pairing_providers.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/ui/already_in_family.dart';

/// Acts on the links the bootstrap hands the running app ([ServerSession.inbox]): an
/// invitation goes to the code entry with its banner, a pairing code to the guardian's
/// approval, and a link that belongs to another server is explained (and, when nobody is
/// signed in, a switch offered) instead of followed. An invitation that reaches a device
/// already in a family, by a link or kept through the sign-in, is answered with "Du bist schon
/// in Familie X" (specs/20, J2). The decisions are made in `server_link.dart` and the
/// bootstrap; this only navigates and asks.
class LinkHost extends ConsumerStatefulWidget {
  const LinkHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LinkHost> createState() => _LinkHostState();
}

class _LinkHostState extends ConsumerState<LinkHost> {
  late final ServerSession _session = ref.read(serverSessionProvider);
  late final GoRouter _router = ref.read(routerProvider);

  /// Whether this ready session was searched for a kept invitation ([_checkKept]).
  var _keptChecked = false;

  @override
  void initState() {
    super.initState();
    _session.inbox.addListener(_drain);
    _router.routerDelegate.addListener(_drain);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  @override
  void dispose() {
    _session.inbox.removeListener(_drain);
    _router.routerDelegate.removeListener(_drain);
    super.dispose();
  }

  void _drain() {
    if (!mounted) return;
    // The router decides where a device belongs only once its session is known.
    final session = ref.read(sessionStateProvider);
    if (!session.hasValue) return;
    if (session.value is! Ready) _keptChecked = false;
    // A dialog shown on the page the router is about to replace would go with it.
    if (session.value is Ready && !_routeSettled) return;
    unawaited(_checkKept());
    final event = _session.inbox.value;
    if (event == null) return;
    final context = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
      return;
    }
    _session.inbox.value = null;
    switch (event.verdict) {
      case LinkVerdict.proceed:
        _open(context, event.link);
      case LinkVerdict.offerSwitch:
        _offerSwitch(context, event);
      case LinkVerdict.otherServer:
        _explain(context, event);
      case LinkVerdict.needsServer:
      case LinkVerdict.connect:
        break;
    }
  }

  void _open(BuildContext context, OpenedLink link) {
    final router = ref.read(routerProvider);
    switch (link.kind) {
      case LinkKind.invitation:
        if (ref.read(sessionStateProvider).value is Ready) {
          // One household per account: say so, and offer the way out (specs/20, J2).
          unawaited(invitationOpenedWhileInFamily(context, ref, link.secret));
        } else {
          router.go(Routes.inviteCode, extra: link.secret);
        }
      case LinkKind.pairing:
        if (ref.read(sessionStateProvider).value is! Ready) {
          router.go(Routes.setup);
        } else if (ref.read(canApprovePairingProvider)) {
          router.push(Routes.devicePair, extra: link.secret);
        } else {
          context.showMessage(context.l10n.pairOnlyOnPersonal);
        }
    }
  }

  /// Whether an enrolled device has reached its screens: not the splash, a setup screen or
  /// the introduction, which the router replaces on its own.
  bool get _routeSettled {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    return path != Routes.splash &&
        path != Routes.firstRun &&
        !Routes.isSetup(path);
  }

  /// An invitation kept at the front door, then a sign-in to an account that already has a
  /// family: the router sends the device home, and this says why the invitation went nowhere.
  /// Looked for once each time the device becomes ready.
  Future<void> _checkKept() async {
    if (_keptChecked || ref.read(sessionStateProvider).value is! Ready) return;
    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null) {
      // The navigator is not up yet: look again after the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
      return;
    }
    _keptChecked = true;
    final kept = await ref.read(invitationStoreProvider).read();
    if (kept == null || !mounted || !context.mounted) return;
    if (ref.read(sessionStateProvider).value is! Ready) return;
    await showAlreadyInFamily(context, ref, invitation: kept, kept: true);
  }

  Future<void> _offerSwitch(BuildContext context, LinkEvent event) async {
    final l10n = context.l10n;
    final switchTo = _session.switchToLinkServer;
    if (switchTo == null) return _explain(context, event);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.linkOtherServerTitle),
        content: Text(
          l10n.linkSwitchBody(
            displayServerAddress(event.link.server!),
            event.current == null ? '' : displayServerAddress(event.current!),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('link-switch'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.linkSwitchAction),
          ),
        ],
      ),
    );
    if (yes ?? false) await switchTo(event.link);
  }

  Future<void> _explain(BuildContext context, LinkEvent event) {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.linkOtherServerTitle),
        content: Text(
          l10n.linkOtherServerBody(
            displayServerAddress(event.link.server!),
            event.current == null ? '' : displayServerAddress(event.current!),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionStateProvider, (_, _) => _drain());
    return widget.child;
  }
}
