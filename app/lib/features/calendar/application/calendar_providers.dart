import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/usual_week.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

/// How many days the calendar shows at once. The week starts on Monday (specs/05).
enum CalendarMode {
  day(1),
  threeDays(3),
  week(7),

  /// The read-only month overview: six weeks from the Monday on or before the first
  /// of the month, so every month fits the same grid.
  month(42);

  const CalendarMode(this.days);

  /// Days on screen; for the shorter modes also the step of previous/next (the month
  /// steps by a month).
  final int days;
}

/// What the calendar shows: a mode and the date it is anchored on (local midnight).
class CalendarView {
  const CalendarView({required this.mode, required this.anchor});

  final CalendarMode mode;
  final DateTime anchor;

  /// The first and last column (inclusive local dates).
  DateTime get from => switch (mode) {
    CalendarMode.week => _mondayOf(anchor),
    CalendarMode.month => _mondayOf(month),
    _ => anchor,
  };

  /// The month in view (its first day), for the month mode's title and grid.
  DateTime get month => DateTime(anchor.year, anchor.month);

  DateTime get to => _addCalendarDays(from, mode.days - 1);

  /// The day columns, from [from] on.
  List<DateTime> get days => [
    for (var i = 0; i < mode.days; i++) _addCalendarDays(from, i),
  ];

  /// The day a new event starts on (local midnight): [today] while it is in view,
  /// otherwise the first day shown.
  /// In the month mode: today while it is in that month, otherwise its first day.
  DateTime newEventDay(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    if (mode == CalendarMode.month) {
      return day.year == anchor.year && day.month == anchor.month ? day : month;
    }
    return days.contains(day) ? day : from;
  }

  /// Moves by calendar days, preserving the local midnight across DST changes; the
  /// month mode moves to the first of the previous or next month.
  CalendarView shifted(int direction) => CalendarView(
    mode: mode,
    anchor: mode == CalendarMode.month
        ? DateTime(anchor.year, anchor.month + direction)
        : _addCalendarDays(anchor, direction * mode.days),
  );
}

DateTime _addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

DateTime _mondayOf(DateTime date) =>
    _addCalendarDays(date, DateTime.monday - date.weekday);

/// The calendar's mode and anchor. Previous and next move by the mode's span; in week
/// mode they move by a week, always keeping the Monday of the week in view, and in the
/// month mode by a month.
class CalendarViewNotifier extends Notifier<CalendarView> {
  bool _modeWasSelected = false;

  @override
  CalendarView build() {
    final now = DateTime.now();
    return CalendarView(
      // CalendarPage chooses the responsive default once it knows the viewport.
      mode: CalendarMode.day,
      anchor: DateTime(now.year, now.month, now.day),
    );
  }

  /// Applies a phone/tablet default while the person has not chosen a view.
  /// Explicit selections survive tab changes and viewport rotations.
  void setResponsiveMode(CalendarMode mode) {
    if (_modeWasSelected || state.mode == mode) return;
    state = CalendarView(mode: mode, anchor: state.anchor);
  }

  void setMode(CalendarMode mode) {
    _modeWasSelected = true;
    state = CalendarView(mode: mode, anchor: state.anchor);
  }

  /// Opens [day] in the day view: a tap on a day of the month, where editing happens.
  void openDay(DateTime day) {
    _modeWasSelected = true;
    state = CalendarView(
      mode: CalendarMode.day,
      anchor: DateTime(day.year, day.month, day.day),
    );
  }

  void previous() => _shift(-1);

  void next() => _shift(1);

  void today() {
    final now = DateTime.now();
    state = CalendarView(
      mode: state.mode,
      anchor: DateTime(now.year, now.month, now.day),
    );
  }

  void _shift(int direction) => state = state.shifted(direction);
}

/// Not auto-disposed: the mode and the week in view survive a trip to the shopping tab.
final calendarViewProvider =
    NotifierProvider<CalendarViewNotifier, CalendarView>(
      CalendarViewNotifier.new,
    );

/// Occurrences from [from] to [to] (inclusive local dates). Refetched when another
/// device changes the calendar (the `calendar` topic).
final occurrencesProvider = FutureProvider.autoDispose
    .family<OccurrenceWindow, ({DateTime from, DateTime to})>((
      ref,
      window,
    ) async {
      ref.watch(deviceKeyProvider);
      final householdId = ref.watch(
        deviceProvider.select((d) => d.value?.householdId),
      );
      if (householdId != null) {
        refreshOnInvalidation(
          ref,
          householdId: householdId,
          topic: 'calendar',
          also: {'board', 'settings', 'school'},
        );
      }
      return (await ref
              .watch(calendarRepositoryProvider)
              .occurrences(window.from, window.to))
          .unwrap();
    });

/// The month view's occurrences from [from] to [to] with the window's public holidays
/// (`holidays` of the `occurrences` function). Refetched like [occurrencesProvider].
final monthOccurrencesProvider = FutureProvider.autoDispose
    .family<OccurrenceWindow, ({DateTime from, DateTime to})>((
      ref,
      window,
    ) async {
      ref.watch(deviceKeyProvider);
      final householdId = ref.watch(
        deviceProvider.select((d) => d.value?.householdId),
      );
      if (householdId != null) {
        refreshOnInvalidation(
          ref,
          householdId: householdId,
          topic: 'calendar',
          also: {'board', 'settings', 'school'},
        );
      }
      return (await ref
              .watch(calendarRepositoryProvider)
              .occurrences(window.from, window.to, holidays: true))
          .unwrap();
    });

/// One event for the editor, loaded when an existing appointment is opened.
final calendarEventProvider = FutureProvider.autoDispose
    .family<CalendarEvent, String>((ref, id) async {
      ref.watch(deviceKeyProvider);
      return (await ref.watch(calendarRepositoryProvider).event(id)).unwrap();
    });

/// Every member's usual week (`api.usual_weeks`), for the settings page, which
/// refreshes it after a save.
final usualWeeksProvider = FutureProvider.autoDispose<List<UsualWeek>>((
  ref,
) async {
  ref.watch(deviceKeyProvider);
  final household = ref.watch(
    deviceProvider.select((d) => d.value?.householdId),
  );
  if (household != null) {
    refreshOnInvalidation(ref, householdId: household, topic: 'calendar');
  }
  return (await ref.watch(calendarRepositoryProvider).usualWeeks()).unwrap();
});
