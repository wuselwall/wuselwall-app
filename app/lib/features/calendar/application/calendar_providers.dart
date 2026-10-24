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
  week(7);

  const CalendarMode(this.days);

  /// Columns on screen, and the step of previous/next.
  final int days;
}

/// What the calendar shows: a mode and the date it is anchored on (local midnight).
class CalendarView {
  const CalendarView({required this.mode, required this.anchor});

  final CalendarMode mode;
  final DateTime anchor;

  /// The first and last column (inclusive local dates).
  DateTime get from => switch (mode) {
    CalendarMode.week => _addCalendarDays(
      anchor,
      DateTime.monday - anchor.weekday,
    ),
    _ => anchor,
  };

  DateTime get to => _addCalendarDays(from, mode.days - 1);

  /// The day columns, from [from] on.
  List<DateTime> get days => [
    for (var i = 0; i < mode.days; i++) _addCalendarDays(from, i),
  ];

  /// The day a new event starts on (local midnight): [today] while it is in view,
  /// otherwise the first day shown.
  DateTime newEventDay(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return days.contains(day) ? day : from;
  }

  /// Moves by calendar days, preserving the local midnight across DST changes.
  CalendarView shifted(int direction) => CalendarView(
    mode: mode,
    anchor: _addCalendarDays(anchor, direction * mode.days),
  );
}

DateTime _addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// The calendar's mode and anchor. Previous and next move by the mode's span; in week
/// mode they move by a week, always keeping the Monday of the week in view.
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
      final householdId = ref.watch(deviceProvider).value?.householdId;
      if (householdId != null) {
        refreshOnInvalidation(ref, householdId: householdId, topic: 'calendar');
      }
      return (await ref
              .watch(calendarRepositoryProvider)
              .occurrences(window.from, window.to))
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
  return (await ref.watch(calendarRepositoryProvider).usualWeeks()).unwrap();
});
