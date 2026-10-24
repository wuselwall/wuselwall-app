import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';

/// What a countdown is called on screen.
String countdownTitle(AppLocalizations l10n, Countdown c) => switch (c.kind) {
  CountdownKind.birthday => l10n.countdownBirthdayOf(c.title),
  CountdownKind.homecoming => l10n.countdownHomecoming(c.title),
  CountdownKind.ferien || CountdownKind.event => c.title,
};

/// How long until it happens. Children and the wall count nights up to a week
/// ("noch 3× schlafen"), then days; grown-ups read "in 3 Tagen" (specs/27).
String countdownWhen(
  AppLocalizations l10n,
  Countdown c,
  DateTime today, {
  bool sleeps = true,
}) {
  final days = c.daysFrom(today);
  if (days <= 0) return l10n.countdownToday;
  if (days == 1) return l10n.countdownTomorrow;
  if (!sleeps) return l10n.countdownInDays(days);
  return days <= 7 ? l10n.countdownSleeps(days) : l10n.countdownDaysLeft(days);
}

Widget _icon(Countdown c, double size) => EmojiPicture(
  eventIconAsset(c.iconKey) ?? eventIconAsset('star')!,
  size: size,
);

/// "Worauf ich mich freue": the child's own countdowns and the whole family's, as
/// big cards (specs/27 "Vorfreude").
class KidCountdowns extends ConsumerWidget {
  const KidCountdowns({required this.actor, super.key});

  final String actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(ritualTodayProvider);
    final list = [
      for (final c in ref.watch(countdownsProvider))
        if (c.isFor(actor)) c,
    ].take(3).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KidSectionTitle(l10n.kidLookingForward),
        for (final c in list)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space2),
            child: KidCard(
              child: Row(
                children: [
                  _icon(c, 44),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Text(
                      countdownTitle(l10n, c),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    countdownWhen(l10n, c, today),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The wall's Vorfreude: the nearest two, small, in the footer. Nothing when there is
/// nothing to look forward to.
class BoardCountdowns extends ConsumerWidget {
  const BoardCountdowns({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(ritualTodayProvider);
    final all = ref.watch(countdownsProvider);
    if (all.isEmpty) return const SizedBox.shrink();
    final ink = Theme.of(context).colorScheme.onSurface;
    // Two when there is room for both at full length, else the nearest one.
    return LayoutBuilder(
      builder: (context, constraints) => _strip(
        l10n,
        today,
        all.take(constraints.maxWidth >= 860 ? 2 : 1).toList(),
        ink,
      ),
    );
  }

  Widget _strip(
    AppLocalizations l10n,
    DateTime today,
    List<Countdown> list,
    Color ink,
  ) {
    return Semantics(
      label: l10n.todayLookingForward,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, c) in list.indexed) ...[
            if (i > 0) const SizedBox(width: 20),
            _icon(c, 30),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${countdownTitle(l10n, c)} · ${countdownWhen(l10n, c, today)}',
                style: boardUi(24, weight: FontWeight.w600, color: ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line on Today: the nearest countdown within the horizon.
class TodayCountdown extends ConsumerWidget {
  const TodayCountdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(ritualTodayProvider);
    final c = ref.watch(countdownsProvider).firstOrNull;
    if (c == null) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: _icon(c, 32),
        title: Text(countdownTitle(l10n, c)),
        subtitle: Text(l10n.todayLookingForward),
        trailing: Text(
          countdownWhen(l10n, c, today, sleeps: false),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}
