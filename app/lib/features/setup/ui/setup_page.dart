import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/data/sign_in_methods_repository.dart';
import 'package:wuselwall/features/identity/domain/sign_in_method.dart';
import 'package:wuselwall/features/setup/ui/provider_buttons.dart';

/// What every un-enrolled device shows (specs/20, "The front door"): the sign-in
/// group (Apple and Google where this build offers them, then email), then below
/// "or" the device code and a new household.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  StreamSubscription<Object>? _redirectErrors;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // A redirect sign-in (the web, Apple on Android) reports back here, not from
    // the call that opened the browser.
    _redirectErrors = ref
        .read(signInMethodsRepositoryProvider)
        .authErrors()
        .listen((failure) {
          if (mounted) context.showFailure(failure);
        });
  }

  @override
  void dispose() {
    unawaited(_redirectErrors?.cancel());
    super.dispose();
  }

  Future<void> _signIn(SignInProvider provider) async {
    setState(() => _busy = true);
    final result = await ref
        .read(signInMethodsRepositoryProvider)
        .signIn(provider);
    if (!mounted) return;
    setState(() => _busy = false);
    final failure = result.failureOrNull;
    if (failure != null) context.showFailure(failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final providers = ref.read(signInMethodsRepositoryProvider).available();
    final online = ref.watch(connectivityProvider).value ?? true;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space6),
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: Tokens.space4),
                Text(l10n.setupHeadline, style: theme.textTheme.headlineSmall),
                const SizedBox(height: Tokens.space2),
                Text(l10n.doorTagline),
                const SizedBox(height: Tokens.space6),
                for (final p in providers) ...[
                  ProviderButton(
                    provider: p,
                    onPressed: _busy || !online ? null : () => _signIn(p),
                  ),
                  const SizedBox(height: Tokens.space3),
                ],
                // Email + password until the email code (E1–E3) replaces it.
                OutlinedButton.icon(
                  onPressed: _busy || !online
                      ? null
                      : () => context.go(Routes.signIn),
                  icon: const Icon(Icons.mail_outline),
                  label: Text(l10n.doorEmail),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Tokens.space4),
                  child: Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Tokens.space3,
                        ),
                        child: Text(l10n.doorOr),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                ),
                // Pairing (J3): the new device shows a code, a guardian's phone approves it.
                TextButton.icon(
                  onPressed: _busy || !online
                      ? null
                      : () => context.go(Routes.pair),
                  icon: const Icon(Icons.tablet_android),
                  label: Text(l10n.pairFrontDoorAction),
                ),
                if (kDebugMode)
                  TextButton(
                    onPressed: () => context.go(Routes.system),
                    child: Text(l10n.systemTitle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
