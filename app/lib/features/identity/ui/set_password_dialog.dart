import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/email_code.dart';
import 'package:wuselwall/features/identity/ui/password_field.dart';

/// Settings → Anmeldung: sets or changes the account's password (specs/20). Returns
/// true once it is saved.
Future<bool> showSetPasswordDialog(BuildContext context) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => const _SetPasswordDialog(),
  );
  return saved ?? false;
}

class _SetPasswordDialog extends ConsumerStatefulWidget {
  const _SetPasswordDialog();

  @override
  ConsumerState<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends ConsumerState<_SetPasswordDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _tooShort = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (ratePassword(_password.text) == PasswordStrength.tooShort) {
      setState(() => _tooShort = true);
      return;
    }
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .setPassword(_password.text);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.pop(context, true);
      case Err(:final failure):
        setState(() => _busy = false);
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasPassword = ref.read(identityRepositoryProvider).hasPassword();
    return AlertDialog(
      title: Text(
        hasPassword ? l10n.passwordChangeAction : l10n.passwordSetAction,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.passwordDialogBody),
          const SizedBox(height: Tokens.space4),
          PasswordField(controller: _password, autofocus: true),
          if (_tooShort) ...[
            const SizedBox(height: Tokens.space2),
            Text(
              l10n.errPasswordTooShort,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
      ],
    );
  }
}
