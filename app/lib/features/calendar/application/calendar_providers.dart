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
    CalendarMode.week => anchor.subtract(
      Duration(days: anchor.weekday - DateTime.monday),
    ),
    _ => anchor,
  };

  DateTime get to => from.add(Duration(days: mode.days - 1));

  /// The day columns, from [from] on.
  List<DateTime> get days => [
    for (var i = 0; i < mode.days; i++) from.add(Duration(days: i)),
  ];
}

/// The calendar's mode and anchor. Previous and next move by the mode's span; in week
/// mode they move by a week, always keeping the Monday of the week in view.
class CalendarViewNotifier extends Notifier<CalendarView> {
  @override
  CalendarView build() {
    final now = DateTime.now();
    return CalendarView(
      mode: CalendarMode.week,
      anchor: DateTime(now.year, now.month, now.day),
    );
  }

  void setMode(CalendarMode mode) =>
      state = CalendarView(mode: mode, anchor: state.anchor);

  void previous() => _shift(-1);

  void next() => _shift(1);

  void today() {
    final now = DateTime.now();
    state = CalendarView(
      mode: state.mode,
      anchor: DateTime(now.year, now.month, now.day),
    );
  }

  void _shift(int direction) => state = CalendarView(
    mode: state.mode,
    anchor: state.anchor.add(Duration(days: direction * state.mode.days)),
  );
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
