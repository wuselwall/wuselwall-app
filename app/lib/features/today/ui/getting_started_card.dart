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
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/invitations/ui/invite_flow.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';
import 'package:wuselwall/features/reminders/ui/reminder_start_row.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';

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
    final allDone = items.every((i) => i.done) && !reminderOpen;
    // Seeing an open item and then none: the family has just finished setting up, and
    // Wusel cheers once (specs/25). A card that loads already complete stays hidden.
    if (!allDone && items.isNotEmpty) {
      ref.read(_setupProgressProvider.notifier).sawOpen();
    } else if (allDone) {
      ref.read(_setupProgressProvider.notifier).sawDone();
    }
    if (allDone) {
      return ref.watch(_setupProgressProvider) == _SetupProgress.justFinished
          ? const _SetupDone()
          : const SizedBox.shrink();
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
            Semantics(
              container: true,
              child: LinearProgressIndicator(
                value: doneCount / total,
                semanticsLabel: l10n.todayStartTitle,
              ),
            ),
            ...rows,
            if (reminderOpen) const ReminderStartRow(),
          ],
        ),
      ),
    );
  }
}

/// The least a step's title keeps beside "Brauchen wir nicht": two short words a line.
const _minTitleRoom = 140.0;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        // "Brauchen wir nicht" stays beside its step, in a smaller type, while the
        // title keeps room for its words; only then does it move under the title,
        // starting where the title starts, so it never floats between two steps
        // (round-3 review L-9).
        final labelStyle = theme.textTheme.labelMedium;
        final label = TextPainter(
          text: TextSpan(text: l10n.todayStartNotNeeded, style: labelStyle),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context),
          maxLines: 1,
        )..layout();
        final buttonWidth = label.width + 2 * Tokens.space2;
        label.dispose();
        const leadingWidth = 24.0;
        const titleInset = leadingWidth + Tokens.space2;
        // The leading icon, its gap, and room before the separate action.
        const leadingRoom = titleInset + Tokens.space4;
        final titleRoom = constraints.maxWidth - leadingRoom - buttonWidth;
        final stackAction = !done && titleRoom < _minTitleRoom;
        final dismissButton = TextButton(
          style: TextButton.styleFrom(
            textStyle: labelStyle,
            visualDensity: VisualDensity.standard,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space2),
          ),
          onPressed: () => unawaited(_dismiss(context, ref, item)),
          child: Text(l10n.todayStartNotNeeded),
        );
        final tile = ListTile(
          contentPadding: EdgeInsets.zero,
          minLeadingWidth: leadingWidth,
          horizontalTitleGap: Tokens.space2,
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
          trailing: done ? Icon(Icons.check_circle, color: ww.success) : null,
          onTap: done ? null : () => unawaited(_open(context, ref, item)),
        );
        if (done) return tile;
        if (stackAction) {
          return Column(
            children: [
              tile,
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: titleInset - Tokens.space2,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: dismissButton,
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: tile),
            dismissButton,
          ],
        );
      },
    );
  }
}

/// Where an item leads: the settings for the household's people and devices, the feed
/// and school screens for their own.
Future<void> _open(BuildContext context, WidgetRef ref, StartItem item) async {
  final container = ProviderScope.containerOf(context);
  if (item == StartItem.invitePartner) {
    await inviteAdultFlow(context, ref, offerExisting: true);
    container.invalidate(gettingStartedProvider);
    return;
  }
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

enum _SetupProgress { unknown, open, justFinished, closed }

/// What this app run has seen of the getting-started card: open items, then none.
class _SetupProgressNotifier extends Notifier<_SetupProgress> {
  @override
  _SetupProgress build() => _SetupProgress.unknown;

  void sawOpen() {
    if (state != _SetupProgress.open) {
      // Changed after this frame: the card is building right now.
      Future.microtask(() => state = _SetupProgress.open);
    }
  }

  void sawDone() {
    if (state == _SetupProgress.open) {
      Future.microtask(() => state = _SetupProgress.justFinished);
    }
  }

  void close() => state = _SetupProgress.closed;
}

final _setupProgressProvider =
    NotifierProvider<_SetupProgressNotifier, _SetupProgress>(
      _SetupProgressNotifier.new,
    );

/// Whether Today shows the getting-started cheer right now: then that Wusel is the
/// screen's one (specs/25).
final setupCheerShowingProvider = Provider<bool>(
  (ref) => ref.watch(_setupProgressProvider) == _SetupProgress.justFinished,
);

/// The last item of getting started is done: Wusel cheers, quietly or not, and the card
/// goes when it is tapped away (specs/25 "Where Wusel appears", adult).
class _SetupDone extends ConsumerWidget {
  const _SetupDone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space4),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            WuselSays(
              line: l10n.wuselSetupDone,
              pose: WuselPose.cheer,
              size: 80,
              quietAllowed: true,
            ),
            TextButton(
              onPressed: () =>
                  ref.read(_setupProgressProvider.notifier).close(),
              child: Text(l10n.todayNoticeDismiss),
            ),
          ],
        ),
      ),
    );
  }
}
