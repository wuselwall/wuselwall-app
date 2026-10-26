import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/email_code.dart';
import 'package:wuselwall/features/identity/ui/password_field.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';

/// E1 on a server without mail (specs/20 "Choosing the server", Q48): the address and a
/// password, nothing by mail. Opens on a new account, because founders and invited people
/// are who arrive here fresh; "Anmelden" is one tap away. There is no E2 or E3: the server
/// autoconfirms the address, and the password is the way to sign in. A forgotten password
/// is reset with a guardian's code ([Routes.passwordReset]).
class PasswordSignInPage extends ConsumerStatefulWidget {
  const PasswordSignInPage({
    required this.onBack,
    this.initialEmail,
    super.key,
  });

  final String? initialEmail;
  final VoidCallback onBack;

  @override
  ConsumerState<PasswordSignInPage> createState() => _PasswordSignInPageState();
}

enum _Mode { signUp, signIn }

class _PasswordSignInPageState extends ConsumerState<PasswordSignInPage> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _password = TextEditingController();
  _Mode _mode = _Mode.signUp;
  bool _busy = false;
  bool _wrongCredentials = false;
  bool _accountExists = false;
  bool _tooShort = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchTo(_Mode mode) => setState(() {
    _mode = mode;
    _wrongCredentials = false;
    _accountExists = false;
    _tooShort = false;
  });

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (_mode == _Mode.signUp && password.length < passwordMinLength) {
      setState(() => _tooShort = true);
      return;
    }
    setState(() {
      _busy = true;
      _wrongCredentials = false;
      _tooShort = false;
    });
    final repo = ref.read(identityRepositoryProvider);
    final result = _mode == _Mode.signUp
        ? await repo.signUpWithPassword(
            email,
            password,
            locale: Localizations.localeOf(context).languageCode,
          )
        : await repo.signIn(email, password);
    if (!mounted) return;
    switch (result) {
      // Success: the router moves on once the session state is read.
      case Ok():
        break;
      // The address has an account: perhaps this is its password. Otherwise the person
      // signs in instead, with the address kept.
      case Err(
        failure: AuthFailure(code: 'user_already_exists' || 'email_exists'),
      ):
        final signedIn = await repo.signIn(email, password);
        if (!mounted) return;
        if (signedIn is Err<void>) {
          setState(() {
            _mode = _Mode.signIn;
            _accountExists = true;
          });
        }
      case Err(failure: AuthFailure(code: 'invalid_credentials')):
        // Never says which of the two was wrong.
        setState(() => _wrongCredentials = true);
      case Err(:final failure):
        context.showFailure(failure);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ww = context.ww;
    final online = ref.watch(connectivityProvider).value ?? true;
    final busy = _busy || !online;
    final signUp = _mode == _Mode.signUp;

    return AuthFormScaffold(
      onBack: widget.onBack,
      title: l10n.doorEmail,
      children: [
        if (!online) ...[
          Container(
            padding: const EdgeInsets.all(Tokens.space3),
            color: ww.warningContainer,
            child: Text(
              l10n.emailOffline,
              style: TextStyle(color: ww.onWarningContainer),
            ),
          ),
          const SizedBox(height: Tokens.space4),
        ],
        SegmentedButton<_Mode>(
          key: const ValueKey('password-mode'),
          segments: [
            ButtonSegment(
              value: _Mode.signUp,
              label: Text(l10n.passwordSignUpTab),
            ),
            ButtonSegment(
              value: _Mode.signIn,
              label: Text(l10n.passwordSignInTab),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: busy ? null : (s) => _switchTo(s.first),
        ),
        const SizedBox(height: Tokens.space6),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.fieldEmail),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return l10n.emailRequired;
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email)) {
                      return l10n.emailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: Tokens.space6),
                if (signUp)
                  PasswordField(
                    controller: _password,
                    onSubmitted: (_) => busy ? null : _submit(),
                  )
                else
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.fieldPasswordSimple,
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? l10n.passwordRequired : null,
                    onFieldSubmitted: (_) => busy ? null : _submit(),
                  ),
              ],
            ),
          ),
        ),
        for (final (show, text) in [
          (_tooShort, l10n.errPasswordTooShort),
          (_wrongCredentials, l10n.emailWrongCredentials),
        ])
          if (show) ...[
            const SizedBox(height: Tokens.space3),
            Text(text, style: TextStyle(color: theme.colorScheme.error)),
          ],
        if (_accountExists) ...[
          const SizedBox(height: Tokens.space3),
          Text(l10n.passwordAccountExists),
        ],
        const SizedBox(height: Tokens.space6),
        FilledButton(
          onPressed: busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(signUp ? l10n.passwordSignUpAction : l10n.signInAction),
        ),
        if (signUp) ...[
          const SizedBox(height: Tokens.space4),
          Text(l10n.passwordNoMailHint, style: theme.textTheme.bodySmall),
        ] else
          TextButton(
            onPressed: busy
                ? null
                : () => unawaited(
                    context.push(passwordResetLocation(_email.text.trim())),
                  ),
            child: Text(l10n.passwordForgot),
          ),
      ],
    );
  }
}

/// The reset page, with the address the person typed so far.
String passwordResetLocation(String email) => email.isEmpty
    ? Routes.passwordReset
    : '${Routes.passwordReset}?email=${Uri.encodeQueryComponent(email)}';
