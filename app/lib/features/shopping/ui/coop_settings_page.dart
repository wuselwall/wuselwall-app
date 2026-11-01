import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/shopping/application/coop_handoff_providers.dart';
import 'package:wuselwall/features/shopping/data/coop_protocol.dart';
import 'package:wuselwall/features/shopping/ui/coop_sheet.dart';

/// Einstellungen → Geräte → Coop-Einkaufsliste (specs/30, "The guardian's path"): what
/// the connector does, that it is not Coop's, what leaves the device, and the one
/// button to sign in or to disconnect.
class CoopSettingsPage extends ConsumerWidget {
  const CoopSettingsPage({super.key});

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final outcome = await ref.read(coopSheetLauncherProvider)(context);
    if (outcome == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(coopOutcomeMessage(l10n, outcome))),
      );
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    await ref.read(coopHandoffProvider.notifier).disconnect();
    if (context.mounted) context.showMessage(l10n.coopSignedOut);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final link = ref.watch(coopHandoffProvider).value;
    final pushed = link?.lastPushCount;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.coopTitle)),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          Text(l10n.coopIntro(coopListName)),
          const SizedBox(height: Tokens.space4),
          Text(l10n.coopPrivacy),
          const SizedBox(height: Tokens.space4),
          Text(
            l10n.coopUnofficial,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Tokens.space6),
          if (link == null)
            FilledButton.icon(
              key: const ValueKey('coop-sign-in'),
              onPressed: () => _signIn(context, ref),
              icon: const Icon(Icons.login),
              label: Text(l10n.coopSignIn),
            )
          else ...[
            ListTile(
              key: const ValueKey('coop-connected'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(l10n.coopConnected),
              subtitle: Text(
                [
                  l10n.coopConnectedDetail(coopListName),
                  if (pushed != null) l10n.coopLastPush(pushed),
                ].join('\n'),
              ),
            ),
            const SizedBox(height: Tokens.space2),
            OutlinedButton.icon(
              key: const ValueKey('coop-disconnect'),
              onPressed: () => _disconnect(context, ref),
              icon: const Icon(Icons.link_off),
              label: Text(l10n.coopSignOut),
            ),
          ],
        ],
      ),
    );
  }
}
