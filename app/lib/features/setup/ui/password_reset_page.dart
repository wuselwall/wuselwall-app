import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/email_code.dart';
import 'package:wuselwall/features/identity/ui/pairing_code_input_formatter.dart';
import 'package:wuselwall/features/identity/ui/password_field.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';

/// "Passwort vergessen?" on a server without mail (specs/20, Q48): the address, the
/// one-time code a guardian made on their phone (or the operator with `wuselwall password`)
/// and a new password. Signs in with it; the router takes over from there.
class PasswordResetPage extends ConsumerStatefulWidget {
  const PasswordResetPage({this.initialEmail, super.key});

  final String? initialEmail;

  @override
  ConsumerState<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends ConsumerState<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _tooShort = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    if (_password.text.length < passwordMinLength) {
      setState(() => _tooShort = true);
      return;
    }
    setState(() {
      _busy = true;
      _tooShort = false;
    });
    final result = await ref
        .read(identityRepositoryProvider)
        .redeemPasswordReset(
          email: _email.text.trim(),
          code: _code.text,
          password: _password.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Err(:final failure)) context.showFailure(failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final online = ref.watch(connectivityProvider).value ?? true;
    final busy = _busy || !online;

    return AuthFormScaffold(
      onBack: () => Navigator.of(context).maybePop(),
      title: l10n.passwordResetTitle,
      children: [
        Text(l10n.passwordResetIntro),
        const SizedBox(height: Tokens.space6),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                autofocus: _email.text.isEmpty,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.fieldEmail),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? l10n.emailRequired : null,
              ),
              const SizedBox(height: Tokens.space4),
              TextFormField(
                key: const ValueKey('password-reset-code'),
                controller: _code,
                autofocus: _email.text.isNotEmpty,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [PairingCodeInputFormatter()],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.passwordResetCodeLabel,
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? l10n.errCodeInvalid
                    : null,
              ),
              const SizedBox(height: Tokens.space4),
              PasswordField(
                controller: _password,
                onSubmitted: (_) => busy ? null : _save(),
              ),
            ],
          ),
        ),
        if (_tooShort) ...[
          const SizedBox(height: Tokens.space3),
          Text(
            l10n.errPasswordTooShort,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: Tokens.space6),
        FilledButton(
          onPressed: busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.passwordResetSave),
        ),
      ],
    );
  }
}
