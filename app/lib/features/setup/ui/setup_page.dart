import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

/// What every un-enrolled device shows: three ways in.
class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupTitle)),
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
                Text(l10n.setupBody),
                const SizedBox(height: Tokens.space6),
                FilledButton.icon(
                  onPressed: () => context.go(Routes.enrol),
                  icon: const Icon(Icons.pin_outlined),
                  label: Text(l10n.setupEnrolAction),
                ),
                const SizedBox(height: Tokens.space3),
                OutlinedButton.icon(
                  onPressed: () => context.go(Routes.signIn),
                  icon: const Icon(Icons.login),
                  label: Text(l10n.setupSignInAction),
                ),
                const SizedBox(height: Tokens.space3),
                TextButton(
                  onPressed: () => context.go(Routes.wizard),
                  child: Text(l10n.setupHouseholdAction),
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
