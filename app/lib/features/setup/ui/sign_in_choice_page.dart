import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/sign_in_choice.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/email_code.dart';
import 'package:wuselwall/features/identity/ui/password_field.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';

enum _Choice { code, password }

/// E3 (specs/20, "With email"): shown once, after the first code sign-in of a new
/// account. Passkeys are not offered until they are verified.
class SignInChoicePage extends ConsumerStatefulWidget {
  const SignInChoicePage({super.key});

  @override
  ConsumerState<SignInChoicePage> createState() => _SignInChoicePageState();
}

class _SignInChoicePageState extends ConsumerState<SignInChoicePage> {
  final _password = TextEditingController();
  _Choice _choice = _Choice.code;
  bool _busy = false;
  bool _tooShort = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_choice == _Choice.password &&
        ratePassword(_password.text) == PasswordStrength.tooShort) {
      setState(() => _tooShort = true);
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(identityRepositoryProvider);
    var result = const Ok<void>(null) as Result<void>;
    if (_choice == _Choice.password) {
      result = await repo.setPassword(_password.text);
    }
    if (result is Ok<void>) {
      result = await repo.markSignInChoice(
        _choice == _Choice.password ? 'password' : 'code',
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      // Answered: the router moves on to the household steps.
      case Ok():
        ref.read(signInChoiceOwedProvider.notifier).clear();
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AuthFormScaffold(
      title: l10n.signInMethodTitle,
      showBack: false,
      children: [
        RadioGroup<_Choice>(
          groupValue: _choice,
          onChanged: (value) {
            if (value != null && !_busy) setState(() => _choice = value);
          },
          child: Column(
            children: [
              RadioListTile<_Choice>(
                value: _Choice.code,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.signInMethodCode),
              ),
              RadioListTile<_Choice>(
                value: _Choice.password,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.signInMethodPassword),
              ),
            ],
          ),
        ),
        if (_choice == _Choice.password) ...[
          const SizedBox(height: Tokens.space3),
          PasswordField(controller: _password, autofocus: true),
          if (_tooShort) ...[
            const SizedBox(height: Tokens.space2),
            Text(
              l10n.errPasswordTooShort,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
        const SizedBox(height: Tokens.space6),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.emailContinue),
        ),
      ],
    );
  }
}
