import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/server_link.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/application/pairing_providers.dart';

/// Acts on the links the bootstrap hands the running app ([ServerSession.inbox]): an
/// invitation goes to the code entry with its banner, a pairing code to the guardian's
/// approval, and a link that belongs to another server is explained (and, when nobody is
/// signed in, a switch offered) instead of followed. The decisions are made in
/// `server_link.dart` and the bootstrap; this only navigates and asks.
class LinkHost extends ConsumerStatefulWidget {
  const LinkHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LinkHost> createState() => _LinkHostState();
}

class _LinkHostState extends ConsumerState<LinkHost> {
  late final ServerSession _session = ref.read(serverSessionProvider);

  @override
  void initState() {
    super.initState();
    _session.inbox.addListener(_drain);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  @override
  void dispose() {
    _session.inbox.removeListener(_drain);
    super.dispose();
  }

  void _drain() {
    if (!mounted) return;
    final event = _session.inbox.value;
    if (event == null) return;
    // The router decides where a device belongs only once its session is known.
    if (!ref.read(sessionStateProvider).hasValue) return;
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
        // A device that already has a household is sent home by the router.
        router.go(Routes.inviteCode, extra: link.secret);
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
