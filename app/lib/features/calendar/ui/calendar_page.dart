import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/swipe_stepper.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/ui/calendar_board.dart';
import 'package:wuselwall/features/calendar/ui/calendar_month.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// The calendar tab's body: the grid for the chosen mode. The home page owns the app
/// bar (its toolbar is [CalendarToolbar]), so this has no Scaffold of its own.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  bool? _lastCompact;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    if (_lastCompact != compact) {
      _lastCompact = compact;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(calendarViewProvider.notifier)
            .setResponsiveMode(compact ? CalendarMode.day : CalendarMode.week);
      });
    }

    final view = ref.watch(calendarViewProvider);
    final nav = ref.read(calendarViewProvider.notifier);
    // A swipe is the toolbar's previous and next (specs/09 "Gestures").
    return SwipeStepper(
      onPrevious: nav.previous,
      onNext: nav.next,
      child: view.mode == CalendarMode.month
          ? CalendarMonthView(view: view)
          : _grid(view),
    );
  }

  Widget _grid(CalendarView view) {
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

/// One row of calendar controls. Narrow screens use a menu for the view selector.
class CalendarToolbar extends ConsumerWidget {
  const CalendarToolbar({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final view = ref.watch(calendarViewProvider);
    final nav = ref.read(calendarViewProvider.notifier);
    final label = switch (view.mode) {
      CalendarMode.day => context.fullDate(view.from),
      CalendarMode.month => context.monthYear(view.month),
      _ => l10n.calendarRange(
        context.dayMonth(view.from),
        context.dayMonth(view.to),
      ),
    };
    final modes = <CalendarMode, String>{
      CalendarMode.day: l10n.calendarDay,
      CalendarMode.threeDays: l10n.calendarThreeDays,
      CalendarMode.week: l10n.calendarWeek,
      CalendarMode.month: l10n.calendarMonth,
    };
    final previous = IconButton(
      tooltip: l10n.calendarPrevious,
      icon: const Icon(Icons.chevron_left),
      onPressed: nav.previous,
    );
    final next = IconButton(
      tooltip: l10n.calendarNext,
      icon: const Icon(Icons.chevron_right),
      onPressed: nav.next,
    );
    // The narrow bar abbreviates the month ("Okt. 2026"); the tooltip has it whole.
    Widget range(TextAlign align, {bool short = false}) => Tooltip(
      message: label,
      child: Text(
        short && view.mode == CalendarMode.month
            ? context.monthYearShort(view.month)
            : label,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
    Widget narrow() => Row(
      children: [
        previous,
        Expanded(child: range(TextAlign.center, short: true)),
        next,
        IconButton(
          tooltip: l10n.calendarToday,
          icon: const Icon(Icons.today_outlined),
          onPressed: nav.today,
        ),
        PopupMenuButton<CalendarMode>(
          tooltip: l10n.calendarChooseView,
          initialValue: view.mode,
          icon: Icon(switch (view.mode) {
            CalendarMode.day => Icons.view_day_outlined,
            CalendarMode.threeDays => Icons.view_column_outlined,
            CalendarMode.week => Icons.view_week_outlined,
            CalendarMode.month => Icons.calendar_view_month_outlined,
          }),
          onSelected: nav.setMode,
          itemBuilder: (_) => [
            for (final mode in modes.entries)
              CheckedPopupMenuItem(
                value: mode.key,
                checked: view.mode == mode.key,
                child: Text(mode.value),
              ),
          ],
        ),
      ],
    );
    // Wide: the navigation stays together after the title, the view on the right.
    // "Heute" is a word where there is room for it, else the icon of the narrow bar.
    Widget wide({required bool todayWord}) => Row(
      children: [
        if (todayWord)
          TextButton(onPressed: nav.today, child: Text(l10n.calendarToday))
        else
          IconButton(
            tooltip: l10n.calendarToday,
            icon: const Icon(Icons.today_outlined),
            onPressed: nav.today,
          ),
        previous,
        next,
        const SizedBox(width: 8),
        Expanded(child: range(TextAlign.start)),
        const SizedBox(width: 12),
        SegmentedButton<CalendarMode>(
          showSelectedIcon: false,
          segments: [
            for (final mode in modes.entries)
              ButtonSegment(value: mode.key, label: Text(mode.value)),
          ],
          selected: {view.mode},
          onSelectionChanged: (modes) => nav.setMode(modes.first),
        ),
      ],
    );
    if (!compact) {
      // The French and Spanish labels are longer: the four view buttons take up to
      // 520 px, so a bar with less room than that and the navigation takes the narrow
      // one, and only a wide one has room for the word beside them.
      return LayoutBuilder(
        builder: (context, box) {
          final room = box.maxWidth / MediaQuery.textScalerOf(context).scale(1);
          if (room < 760) return narrow();
          return wide(todayWord: room >= 900);
        },
      );
    }
    return narrow();
  }
}
