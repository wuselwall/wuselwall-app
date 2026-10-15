import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_link.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';
import 'package:wuselwall/features/setup/ui/qr_scan_page.dart';

/// "Ich habe einen Einladungscode" (specs/20, J2, accepting 2): the code, the link or the QR
/// code of an invitation. The banner names the household and the inviter; "Weiter" keeps the
/// invitation on this phone and goes on to sign-in, or straight to the join confirmation for an
/// account that is already signed in (H1's "Ich wurde eingeladen").
class InviteCodePage extends ConsumerStatefulWidget {
  const InviteCodePage({this.initialSecret, super.key});

  /// A secret that arrived with an opened link: checked as soon as the page is up.
  final String? initialSecret;

  @override
  ConsumerState<InviteCodePage> createState() => _InviteCodePageState();
}

class _InviteCodePageState extends ConsumerState<InviteCodePage> {
  final _code = TextEditingController();
  var _busy = false;
  String? _error;
  ({String secret, InvitationPreview preview})? _valid;

  @override
  void initState() {
    super.initState();
    final secret = widget.initialSecret;
    if (secret != null) {
      _code.text = secret;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_check(secret));
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check([String? scanned]) async {
    final l10n = context.l10n;
    final parsed = parseInvitation(scanned ?? _code.text);
    if (parsed == null) {
      setState(() {
        _error = l10n.inviteCodeInvalidFormat;
        _valid = null;
      });
      return;
    }
    // A link of another server is not followed silently: the bootstrap decides (switch,
    // or say why not).
    final server = parsed.server;
    final current = ref.read(currentServerProvider);
    if (server != null && current != null && !sameServer(server, current)) {
      await ref
          .read(serverSessionProvider)
          .openLink
          ?.call(
            OpenedLink(LinkKind.invitation, parsed.secret, server: server),
          );
      return;
    }
    final secret = parsed.secret;
    setState(() {
      _busy = true;
      _error = null;
      _valid = null;
    });
    final result = await ref.read(invitationRepositoryProvider).preview(secret);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok(value: PreviewValid(:final preview)):
        setState(() => _valid = (secret: secret, preview: preview));
      case Ok(value: PreviewRefused(:final reason)):
        setState(
          () => _error = reason == 'rate_limited'
              ? l10n.inviteRateLimited
              : l10n.inviteNoLonger,
        );
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _scan() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanPage(
          title: context.l10n.inviteScanTitle,
          parse: (raw) => parseInvitation(raw) == null ? null : raw,
        ),
      ),
    );
    if (scanned != null && mounted) {
      _code.text = scanned;
      await _check(scanned);
    }
  }

  Future<void> _continue() async {
    final valid = _valid!;
    await ref
        .read(invitationStoreProvider)
        .write(StoredInvitation.fromPreview(valid.secret, valid.preview));
    if (!mounted) return;
    if (ref.read(sessionUserIdProvider) == null) {
      context.go(Routes.signIn);
      return;
    }
    // Signed in without a household: the session is re-read first, so the join confirmation
    // is shown for the kept invitation.
    ref.invalidate(sessionStateProvider);
    await ref.read(sessionStateProvider.future);
    if (mounted) context.go(Routes.joinInvite);
  }

  // The camera scanner runs on phones; the web and desktop builds type the code instead.
  bool get _canScan =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final valid = _valid;
    return AuthFormScaffold(
      title: l10n.inviteCodeTitle,
      children: [
        Text(l10n.inviteCodeBody),
        const SizedBox(height: Tokens.space4),
        if (_canScan) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(l10n.scanQr),
          ),
          const SizedBox(height: Tokens.space4),
        ],
        TextField(
          controller: _code,
          enabled: !_busy,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          style: theme.textTheme.titleLarge,
          decoration: InputDecoration(labelText: l10n.inviteCodeLabel),
          onSubmitted: (_) => _check(),
        ),
        const SizedBox(height: Tokens.space4),
        FilledButton(
          onPressed: _busy ? null : _check,
          child: Text(l10n.inviteCheckAction),
        ),
        if (_error != null) ...[
          const SizedBox(height: Tokens.space4),
          Text(
            _error!,
            key: const ValueKey('invite-error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        if (valid != null) ...[
          const SizedBox(height: Tokens.space6),
          Card(
            key: const ValueKey('invite-banner'),
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    valid.preview.inviterFirstName == null
                        ? l10n.inviteBannerNoInviter(
                            valid.preview.householdName,
                          )
                        : l10n.inviteBanner(
                            valid.preview.inviterFirstName!,
                            valid.preview.householdName,
                          ),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Tokens.space2),
                  Text(
                    valid.preview.role == InvitationRole.guardian
                        ? l10n.inviteRoleLineGuardian
                        : l10n.inviteRoleLineMember,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Tokens.space4),
          FilledButton(onPressed: _continue, child: Text(l10n.inviteContinue)),
        ],
      ],
    );
  }
}
