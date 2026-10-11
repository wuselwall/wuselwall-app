import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/setup/ui/sign_in_page.dart';

/// Step two of a guardian sign-in: the 6-digit code from the authenticator app.
/// Until it passes, the session carries no household claims (see the access-token hook).
class MfaChallengePage extends ConsumerStatefulWidget {
  const MfaChallengePage({super.key});

  @override
  ConsumerState<MfaChallengePage> createState() => _MfaChallengePageState();
}

class _MfaChallengePageState extends ConsumerState<MfaChallengePage> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .totpChallenge(_code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.failureOrNull.let(context.showFailure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mfaTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space6),
              children: [
                Text(l10n.mfaBody),
                const SizedBox(height: Tokens.space4),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: 6,
                  style: Theme.of(context).textTheme.headlineSmall,
                  decoration: InputDecoration(labelText: l10n.mfaCodeLabel),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Tokens.space4),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(l10n.mfaVerify),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(identityRepositoryProvider).signOut(),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
