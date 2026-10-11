import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';

/// Guardian sign-in (email + password). Success makes this a personal device; the
/// router moves on once the device record is read.
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.failureOrNull.let(context.showFailure);
  }

  Future<void> _passkey() async {
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .signInWithPasskey();
    if (!mounted) return;
    setState(() => _busy = false);
    result.failureOrNull.let(context.showFailure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthFormScaffold(
      title: l10n.signInTitle,
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(labelText: l10n.fieldEmail),
        ),
        const SizedBox(height: Tokens.space4),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(labelText: l10n.fieldPasswordSimple),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Tokens.space6),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.signInAction),
        ),
        const SizedBox(height: Tokens.space3),
        OutlinedButton.icon(
          onPressed: _busy ? null : _passkey,
          icon: const Icon(Icons.fingerprint),
          label: Text(l10n.signInPasskey),
        ),
      ],
    );
  }
}

extension NullableLet<T extends Object> on T? {
  void let(void Function(T value) action) {
    final v = this;
    if (v != null) action(v);
  }
}
