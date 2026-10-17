import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/account/application/account_admin_providers.dart';
import 'package:wuselwall/features/household/application/household_leave_providers.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/email_code.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// "Konto löschen" in Einstellungen → Konto (specs/20 J6). The account and its devices go;
/// the profile stays in the family. Disabled, with the reason, for the last
/// guardian with an account. A stale sign-in is renewed first (the server asks for a sign-in
/// of at most five minutes), then the deletion is retried once.
class DeleteAccountTile extends ConsumerStatefulWidget {
  const DeleteAccountTile({super.key});

  @override
  ConsumerState<DeleteAccountTile> createState() => _DeleteAccountTileState();
}

class _DeleteAccountTileState extends ConsumerState<DeleteAccountTile> {
  var _busy = false;

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountDeleteDialogTitle),
        content: Text(l10n.accountDeleteDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('delete-account-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.accountDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(accountAdminRepositoryProvider);
    var result = await repo.deleteAccount();
    if (result case Err(:final failure) when _needsSignIn(failure)) {
      final renewed = await _renewSignIn();
      if (!mounted) return;
      if (!renewed) {
        setState(() => _busy = false);
        return;
      }
      result = await repo.deleteAccount();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    // On success the repository has signed this phone out: the router shows the front door.
    if (result case Err(:final failure)) context.showFailure(failure);
  }

  static bool _needsSignIn(Failure f) =>
      f is PermissionFailure && f.code == 'reauth_required';

  /// Asks for a sign-in that is at most five minutes old: a code to the account's address.
  /// True when one happened.
  Future<bool> _renewSignIn() async {
    final l10n = context.l10n;
    final repo = ref.read(accountAdminRepositoryProvider);
    final email = ref.read(myAccountProvider).value?.email;
    if (email != null) {
      final renewed = await showDialog<bool>(
        context: context,
        builder: (_) => _EmailReauthDialog(email: email),
      );
      return renewed == true && repo.hasRecentSignIn();
    }
    context.showMessage(l10n.accountDeleteReauthSignInAgain);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Adults on their own phone only: a child's phone has no account of its own to delete.
    final device = ref.watch(deviceProvider).value;
    if (device == null ||
        device.deviceClass != DeviceClass.personal ||
        device.register != UiRegister.adult) {
      return const SizedBox.shrink();
    }
    final account = ref.watch(myAccountProvider).value;
    if (account == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final blocked = account.leaveBlocked != null;
    return ListTile(
      key: const ValueKey('delete-account'),
      leading: Icon(
        Icons.person_remove_outlined,
        color: theme.colorScheme.error,
      ),
      title: Text(
        l10n.accountDeleteTile,
        style: TextStyle(color: theme.colorScheme.error),
      ),
      subtitle: Text(
        blocked ? l10n.accountDeleteBlocked : l10n.accountDeleteExplain,
      ),
      enabled: !blocked && !_busy,
      onTap: blocked || _busy ? null : _delete,
    );
  }
}

/// The e-mail code that renews a sign-in (E2's check, in a dialog). True once the code signed
/// the account in again.
class _EmailReauthDialog extends ConsumerStatefulWidget {
  const _EmailReauthDialog({required this.email});

  final String email;

  @override
  ConsumerState<_EmailReauthDialog> createState() => _EmailReauthDialogState();
}

class _EmailReauthDialogState extends ConsumerState<_EmailReauthDialog> {
  final _code = TextEditingController();
  var _sent = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .sendEmailCode(
          widget.email,
          locale: Localizations.localeOf(context).languageCode,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = result is Ok;
    });
    if (result case Err(:final failure)) context.showFailure(failure);
  }

  Future<void> _verify() async {
    final digits = _code.text.trim();
    if (digits.length != emailCodeLength || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(identityRepositoryProvider)
        .verifyEmailCode(widget.email, digits);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(failure: AuthFailure()):
        setState(() {
          _busy = false;
          _error = context.l10n.emailCodeWrong;
          _code.clear();
        });
      case Err(:final failure):
        setState(() => _busy = false);
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.accountDeleteReauthTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.accountDeleteReauthBody(widget.email)),
          if (_sent) ...[
            const SizedBox(height: Tokens.space4),
            TextField(
              key: const ValueKey('reauth-code'),
              controller: _code,
              autofocus: true,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              maxLength: emailCodeLength,
              decoration: InputDecoration(
                labelText: l10n.accountDeleteReauthCodeLabel,
                errorText: _error,
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _verify(),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : _sent
              ? (_code.text.trim().length == emailCodeLength ? _verify : null)
              : _send,
          child: Text(
            _sent
                ? l10n.accountDeleteReauthConfirm
                : l10n.accountDeleteReauthSend,
          ),
        ),
      ],
    );
  }
}
