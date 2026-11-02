import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/account/application/account_admin_providers.dart';
import 'package:wuselwall/features/household/application/household_leave_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/email_code.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// The sensitive account actions (deleting the account, changing the password, resetting
/// another adult's password or second factor; specs/20 J6, security review 2026-11-01 F3,
/// F10, F23) need a sign-in of the last five minutes, and the second factor where the
/// account has one. The server says so with `reauth_required` or `mfa_required`; this file
/// renews the sign-in in place and the caller retries once.

/// Whether [f] is the server asking for a fresh sign-in or the second factor.
bool isStepUpFailure(Failure f) =>
    f is PermissionFailure &&
    (f.code == 'reauth_required' || f.code == 'mfa_required');

/// Renews the sign-in: the e-mail code, or on a server without mail the password. The two
/// texts explain why, for this action. True when the session is fresh afterwards. An account
/// with an authenticator starts a new session at aal1: the router then shows the
/// second-factor step, so the action is to be repeated after it, and the person is told so.
Future<bool> renewSignIn(
  BuildContext context,
  WidgetRef ref, {
  required String Function(String email) emailBody,
  required String Function(String email) passwordBody,
}) async {
  final l10n = context.l10n;
  final admin = ref.read(accountAdminRepositoryProvider);
  final email = ref.read(myAccountProvider).value?.email;
  if (email == null) {
    context.showMessage(l10n.accountDeleteReauthSignInAgain);
    return false;
  }
  // Without mail there is no code: the password renews the sign-in (Q48).
  final emailCode = ref.read(emailCodeSignInProvider);
  final renewed = await showDialog<bool>(
    context: context,
    builder: (_) => emailCode
        ? EmailReauthDialog(email: email, body: emailBody(email))
        : PasswordReauthDialog(email: email, body: passwordBody(email)),
  );
  if (renewed != true || !context.mounted) return false;
  if (ref.read(identityRepositoryProvider).mfaState() ==
      MfaState.challengeRequired) {
    context.showMessage(l10n.accountMfaRequired);
    return false;
  }
  return admin.hasRecentSignIn();
}

/// The e-mail code that renews a sign-in (E2's check, in a dialog). True once the code signed
/// the account in again.
class EmailReauthDialog extends ConsumerStatefulWidget {
  const EmailReauthDialog({required this.email, required this.body, super.key});

  final String email;
  final String body;

  @override
  ConsumerState<EmailReauthDialog> createState() => _EmailReauthDialogState();
}

class _EmailReauthDialogState extends ConsumerState<EmailReauthDialog> {
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
          Text(widget.body),
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

/// The password that renews a sign-in on a server without mail (Q48). True once it signed the
/// account in again.
class PasswordReauthDialog extends ConsumerStatefulWidget {
  const PasswordReauthDialog({
    required this.email,
    required this.body,
    super.key,
  });

  final String email;
  final String body;

  @override
  ConsumerState<PasswordReauthDialog> createState() =>
      _PasswordReauthDialogState();
}

class _PasswordReauthDialogState extends ConsumerState<PasswordReauthDialog> {
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_password.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(identityRepositoryProvider)
        .signIn(widget.email, _password.text);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(failure: AuthFailure(code: 'invalid_credentials')):
        setState(() {
          _busy = false;
          _error = context.l10n.emailWrongCredentials;
          _password.clear();
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
          Text(widget.body),
          const SizedBox(height: Tokens.space4),
          TextField(
            key: const ValueKey('reauth-password'),
            controller: _password,
            autofocus: true,
            enabled: !_busy,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: l10n.fieldPasswordSimple,
              errorText: _error,
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _verify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy || _password.text.isEmpty ? null : _verify,
          child: Text(l10n.accountDeleteReauthConfirm),
        ),
      ],
    );
  }
}
