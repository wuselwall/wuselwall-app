import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/ui/calendar_board.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// The calendar tab's body: the grid for the chosen mode. The home page owns the app
/// bar (its toolbar is [CalendarToolbar]), so this has no Scaffold of its own.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(calendarViewProvider);
    final window = (from: view.from, to: view.to);
    final occurrences = ref.watch(occurrencesProvider(window));
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    // Minute resolution: the now line moves, the grid does not rebuild every second.
    final now = ref.watch(nowProvider.select(_toMinute));
    return AsyncValueView(
      value: occurrences,
      onRetry: () => ref.invalidate(occurrencesProvider(window)),
      data: (data) =>
          CalendarBoard(view: view, window: data, members: members, now: now),
    );
  }
}

DateTime _toMinute(DateTime t) =>
    DateTime(t.year, t.month, t.day, t.hour, t.minute);

/// The calendar's controls in the app bar's bottom: previous, the range in view, next,
/// today, and the mode (Tag / 3 Tage / Woche).
class CalendarToolbar extends ConsumerWidget implements PreferredSizeWidget {
  const CalendarToolbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(104);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(calendarViewProvider);
    final nav = ref.read(calendarViewProvider.notifier);
    final label = view.mode == CalendarMode.day
        ? context.fullDate(view.from)
        : l10n.calendarRange(
            context.dayMonth(view.from),
            context.dayMonth(view.to),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l10n.calendarPrevious,
              icon: const Icon(Icons.chevron_left),
              onPressed: nav.previous,
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: l10n.calendarNext,
              icon: const Icon(Icons.chevron_right),
              onPressed: nav.next,
            ),
            TextButton(onPressed: nav.today, child: Text(l10n.calendarToday)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SegmentedButton<CalendarMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: CalendarMode.day,
                label: Text(l10n.calendarDay),
              ),
              ButtonSegment(
                value: CalendarMode.threeDays,
                label: Text(l10n.calendarThreeDays),
              ),
              ButtonSegment(
                value: CalendarMode.week,
                label: Text(l10n.calendarWeek),
              ),
            ],
            selected: {view.mode},
            onSelectionChanged: (modes) => nav.setMode(modes.first),
          ),
        ),
      ],
    );
  }
}
