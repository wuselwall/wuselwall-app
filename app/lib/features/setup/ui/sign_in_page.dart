import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/server/setup_store.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';
import 'package:wuselwall/features/setup/ui/password_sign_in_page.dart';

/// E1 (specs/20, "With email"): the address, then a code by e-mail (E2). A password is
/// one step behind "Ich habe ein Passwort". The same answer for every address. On a
/// server without mail, [PasswordSignInPage] instead (Q48).
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({this.initialEmail, super.key});

  /// Prefilled when E2 sends the person back to change the address.
  final String? initialEmail;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _emailKey = GlobalKey<FormFieldState<String>>();
  final _passwordKey = GlobalKey<FormFieldState<String>>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _password = TextEditingController();
  _SignInAction? _busyAction;
  bool get _busy => _busyAction != null;
  bool _showPassword = false;
  bool _wrongCredentials = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Mails the code and goes to E2. Also the way out of a wrong password.
  Future<void> _cancelSetup() async {
    final session = ref.read(serverSessionProvider);
    await ref.read(setupStoreProvider).clear();
    session.setupPending.value = false;
    if (mounted) context.go(Routes.setup);
  }

  Future<void> _sendCode() async {
    if (_busy || !(_emailKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    setState(() => _busyAction = _SignInAction.emailCode);
    final result = await ref
        .read(identityRepositoryProvider)
        .sendEmailCode(
          email,
          locale: Localizations.localeOf(context).languageCode,
        );
    if (!mounted) return;
    setState(() => _busyAction = null);
    switch (result) {
      case Ok():
        unawaited(context.push(emailCodeLocation(email)));
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _signInWithPassword() async {
    if (_busy ||
        !(_emailKey.currentState?.validate() ?? false) ||
        !(_passwordKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _busyAction = _SignInAction.password;
      _wrongCredentials = false;
    });
    final result = await ref
        .read(identityRepositoryProvider)
        .signIn(_email.text.trim(), _password.text);
    if (!mounted) return;
    setState(() => _busyAction = null);
    switch (result) {
      // Success: the router moves on once the session state is read.
      case Ok():
        break;
      case Err(failure: AuthFailure(code: 'invalid_credentials')):
        // Never says which of the two was wrong.
        setState(() => _wrongCredentials = true);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _passkey() async {
    if (_busy) return;
    setState(() => _busyAction = _SignInAction.passkey);
    final result = await ref
        .read(identityRepositoryProvider)
        .signInWithPasskey();
    if (!mounted) return;
    setState(() => _busyAction = null);
    result.failureOrNull.let(context.showFailure);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(emailCodeSignInProvider)) {
      return PasswordSignInPage(
        initialEmail: widget.initialEmail,
        onBack: () => unawaited(_cancelSetup()),
      );
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ww = context.ww;
    final online = ref.watch(connectivityProvider).value ?? true;
    final busy = _busy || !online;

    return AuthFormScaffold(
      onBack: () => unawaited(_cancelSetup()),
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
        Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: _emailKey,
                controller: _email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.fieldEmail),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return l10n.emailRequired;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return l10n.emailInvalid;
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (busy) return;
                  if (_showPassword) {
                    FocusScope.of(context).nextFocus();
                  } else {
                    _sendCode();
                  }
                },
              ),
              if (_showPassword) ...[
                const SizedBox(height: Tokens.space6),
                TextFormField(
                  key: _passwordKey,
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.fieldPasswordSimple,
                  ),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? l10n.passwordRequired : null,
                  onFieldSubmitted: (_) => busy ? null : _signInWithPassword(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Tokens.space6),
        FilledButton(
          onPressed: busy ? null : _sendCode,
          child: _busyAction == _SignInAction.emailCode
              ? _BusyButtonLabel(label: l10n.emailSendingCode)
              : Text(l10n.emailContinue),
        ),
        if (!_showPassword)
          TextButton(
            onPressed: busy ? null : () => setState(() => _showPassword = true),
            child: Text(l10n.emailHavePassword),
          )
        else ...[
          const SizedBox(height: Tokens.space4),
          if (_wrongCredentials) ...[
            const SizedBox(height: Tokens.space3),
            Text(
              l10n.emailWrongCredentials,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: Tokens.space3),
          OutlinedButton(
            onPressed: busy ? null : _signInWithPassword,
            child: _busyAction == _SignInAction.password
                ? _BusyButtonLabel(label: l10n.signInProgress)
                : Text(l10n.signInAction),
          ),
          TextButton(
            onPressed: busy ? null : _sendCode,
            child: _busyAction == _SignInAction.emailCode
                ? _BusyButtonLabel(label: l10n.emailSendingCode)
                : Text(l10n.emailUseCodeInstead),
          ),
        ],
        // Passkeys need a JavaScript SDK on the web that is not self-hosted yet
        // (web/index.html); the native apps offer them only in a build that names its
        // own server, whose domain is in its associated domains (ADR-018).
        if (!kIsWeb && ref.watch(appConfigProvider).passkeys) ...[
          const SizedBox(height: Tokens.space3),
          OutlinedButton.icon(
            onPressed: busy ? null : _passkey,
            icon: const Icon(Icons.fingerprint),
            label: _busyAction == _SignInAction.passkey
                ? _BusyButtonLabel(label: l10n.signInProgress)
                : Text(l10n.signInPasskey),
          ),
        ],
      ],
    );
  }
}

class _BusyButtonLabel extends StatelessWidget {
  const _BusyButtonLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 4,
    children: [
      const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      Text(label),
    ],
  );
}

enum _SignInAction { emailCode, password, passkey }

/// Where E1 sends the person: E2 with the address it mailed.
String emailCodeLocation(String email) =>
    '${Routes.emailCode}?email=${Uri.encodeQueryComponent(email)}';

extension NullableLet<T extends Object> on T? {
  void let(void Function(T value) action) {
    final v = this;
    if (v != null) action(v);
  }
}
