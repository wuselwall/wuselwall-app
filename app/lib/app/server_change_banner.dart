import 'package:flutter/material.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_address.dart';

/// The strip above every screen while the server's discovery document names another
/// address or key than the ones the app runs on ([ServerChange]). The app stays on the
/// stored server until the person reconnects here.
///
/// A new address is confirmed here first, with the address shown: reconnecting signs
/// this device out, so nothing of the old session goes to the new address, and the
/// person signs in again there. The device's offline data stays; it belongs to one
/// household and is dropped by itself when another household signs in. A new key on
/// the same address reconnects at once and keeps the session.
class ServerChangeBanner extends StatefulWidget {
  const ServerChangeBanner({
    required this.change,
    required this.onReconnect,
    super.key,
  });

  final ServerChange change;
  final Future<void> Function() onReconnect;

  @override
  State<ServerChangeBanner> createState() => _ServerChangeBannerState();
}

class _ServerChangeBannerState extends State<ServerChangeBanner> {
  bool _confirming = false;
  bool _busy = false;

  Future<void> _reconnect() async {
    if (widget.change.addressChanged && !_confirming) {
      setState(() => _confirming = true);
      return;
    }
    setState(() => _busy = true);
    await widget.onReconnect();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final host = displayServerAddress(widget.change.server.supabaseUrl);
    final text = !widget.change.addressChanged
        ? l10n.serverKeyChangedBody
        : _confirming
        ? l10n.serverMovedConfirm(host)
        : l10n.serverMovedBody(host);
    final style = TextStyle(color: scheme.onErrorContainer);
    return Material(
      key: const ValueKey('server-change-banner'),
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space4,
            vertical: Tokens.space2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space2),
                child: Icon(Icons.dns_outlined, color: scheme.onErrorContainer),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: Tokens.space2),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(text, style: style),
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        if (_confirming)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _confirming = false),
                            child: Text(l10n.cancel, style: style),
                          ),
                        TextButton(
                          key: const ValueKey('server-change-reconnect'),
                          onPressed: _busy ? null : _reconnect,
                          child: Text(l10n.serverMovedAction, style: style),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
