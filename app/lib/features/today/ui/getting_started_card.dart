import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';
import 'package:wuselwall/features/reminders/ui/reminder_start_row.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';

/// At most this many open items are listed; the progress counts all of them.
const _maxOpenItems = 4;

/// The setup card at the top of Today (specs/20 "The getting-started card"). Hidden when
/// nothing is open: everything done, everything dismissed, or nothing to show.
class GettingStartedCard extends ConsumerWidget {
  const GettingStartedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(gettingStartedProvider).value ?? const <GettingStartedItem>[];
    // Client-side item: the phone's reminders (specs/20, "Erinnerungen einschalten").
    final reminderOpen = ref.watch(reminderCardProvider).value ?? false;
    if (items.every((i) => i.done) && !reminderOpen) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final total = items.length + (reminderOpen ? 1 : 0);
    final doneCount = items.where((i) => i.done).length;
    final rows = <Widget>[];
    var openShown = 0;
    for (final entry in items) {
      if (!entry.done) {
        if (openShown == _maxOpenItems) continue;
        openShown++;
      }
      rows.add(_ItemRow(entry: entry));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space4),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: Tokens.space2),
                Expanded(
                  child: Text(
                    l10n.todayStartTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  l10n.todayStartProgress(doneCount, total),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: Tokens.space2),
            LinearProgressIndicator(value: doneCount / total),
            ...rows,
            if (reminderOpen) const ReminderStartRow(),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.entry});

  final GettingStartedItem entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ww = context.ww;
    final theme = Theme.of(context);
    final item = entry.item;
    final done = entry.done;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: Tokens.space1,
      leading: Icon(
        item.icon,
        color: done ? ww.success : theme.colorScheme.onSurface,
      ),
      title: Text(
        startItemLabel(l10n, item),
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
          color: done ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      trailing: done
          ? Icon(Icons.check_circle, color: ww.success)
          : TextButton(
              onPressed: () => unawaited(_dismiss(context, ref, item)),
              child: Text(l10n.todayStartNotNeeded),
            ),
      onTap: done ? null : () => unawaited(_open(context, ref, item)),
    );
  }
}

/// Where an item leads: the settings for the household's people and devices, the feed
/// and school screens for their own.
Future<void> _open(BuildContext context, WidgetRef ref, StartItem item) async {
  final container = ProviderScope.containerOf(context);
  final route = switch (item) {
    StartItem.subscribeFeed => Routes.feedTokens,
    StartItem.school => Routes.schoolSetup,
    StartItem.connectTablet =>
      '${Routes.devicePair}?kind=${PairingKind.kidTablet.wire}',
    StartItem.wallDisplay =>
      '${Routes.devicePair}?kind=${PairingKind.wallDisplay.wire}',
    _ => Routes.settings,
  };
  await context.push<void>(route);
  container.invalidate(gettingStartedProvider);
}

Future<void> _dismiss(
  BuildContext context,
  WidgetRef ref,
  StartItem item,
) async {
  final container = ProviderScope.containerOf(context);
  final repository = ref.read(gettingStartedRepositoryProvider);
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  final actor = container.read(actingProfileProvider);
  if (actor == null) return;
  final result = await repository.dismiss(actor: actor, item: item);
  container.invalidate(gettingStartedProvider);
  if (!context.mounted) return;
  if (result case Err(:final failure)) context.showFailure(failure);
}

/// The card's label for [item].
String startItemLabel(AppLocalizations l10n, StartItem item) => switch (item) {
  StartItem.invitePartner => l10n.todayStartInvitePartner,
  StartItem.connectTablet => l10n.todayStartConnectTablet,
  StartItem.wallDisplay => l10n.todayStartWallDisplay,
  StartItem.setPin => l10n.todayStartSetPin,
  StartItem.subscribeFeed => l10n.todayStartSubscribeFeed,
  StartItem.school => l10n.todayStartSchool,
};
