import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/domain/trip_plan.dart';

/// What the trip card on Today (adult register) shows (specs/30 "During the trip").
/// Pure.

/// How many days before a fixed trip the card appears.
const tripTodayLeadDays = 30;

/// Where the card's trip is.
enum TripTodayPhase {
  /// From [tripTodayLeadDays] days before the first day: days left, to-dos, packing.
  before,

  /// From the first to the last day: "Tag 3 von 10", today's entries, tonight's stay.
  running,
}

class TripToday {
  const TripToday({
    required this.trip,
    required this.phase,
    required this.daysLeft,
    required this.dayNumber,
    required this.dayCount,
    required this.dueTodos,
    required this.packed,
    required this.packTotal,
    required this.todayItems,
    required this.stayTonight,
    required this.tomorrowFirst,
  });

  /// The card for the running or next fixed trip of [trips], or null when there is
  /// none to show: no fixed trip with dates that is running or begins within
  /// [tripTodayLeadDays] days. A running trip wins; of several upcoming ones the nearest.
  static TripToday? of({
    required List<Trip> trips,
    required List<TripEntry> entries,
    required List<TripCheck> checks,
    required DateTime today,
  }) {
    final day = dayOf(today);
    Trip? pick;
    for (final t in trips) {
      if (t.stage != TripStage.fixed || !t.hasDates || t.isPast(day)) continue;
      if (!t.isRunning(day) && t.daysUntil(day)! > tripTodayLeadDays) continue;
      if (pick == null) {
        pick = t;
        continue;
      }
      final better =
          t.isRunning(day) && !pick.isRunning(day) ||
          t.isRunning(day) == pick.isRunning(day) &&
              t.daysUntil(day)! < pick.daysUntil(day)!;
      if (better) pick = t;
    }
    if (pick == null) return null;
    final trip = pick;

    final mine = [
      for (final c in checks)
        if (c.tripId == trip.id) c,
    ]..sort((a, b) => a.position.compareTo(b.position));
    final dueTodos = [
      for (final c in mine)
        if (c.kind == CheckKind.todo && !c.done)
          if (c.dueOn(trip) case final due? when daysBetween(due, day) >= 0) c,
    ];
    final pack = [
      for (final c in mine)
        if (c.kind == CheckKind.pack) c,
    ];

    final plan = TripPlan.of(trip, entries);
    final today0 = plan.day(day);
    final tomorrow = plan.day(addDays(day, 1));
    final running = trip.isRunning(day);

    return TripToday(
      trip: trip,
      phase: running ? TripTodayPhase.running : TripTodayPhase.before,
      daysLeft: running ? 0 : trip.daysUntil(day)!,
      dayNumber: trip.dayNumber(day),
      dayCount: trip.days,
      dueTodos: dueTodos,
      packed: pack.where((c) => c.done).length,
      packTotal: pack.length,
      todayItems: today0?.items ?? const [],
      stayTonight: today0?.stay,
      tomorrowFirst: tomorrow?.items.firstOrNull,
    );
  }

  final Trip trip;
  final TripTodayPhase phase;

  /// Days until the first day; 0 while running.
  final int daysLeft;

  /// "Tag 3": 1 on the first day; null before the trip.
  final int? dayNumber;

  /// "von 10".
  final int dayCount;

  /// Open to-dos that are due today or earlier ([TripCheck.dueOn]); to-dos without a
  /// due day are not listed.
  final List<TripCheck> dueTodos;

  /// Packing progress: ticked and all items of every person and the family.
  final int packed;
  final int packTotal;

  /// Today's plan items in time order (running trips; empty before).
  final List<PlanItem> todayItems;

  /// Where the family sleeps tonight (address and phone are on the entry).
  final TripEntry? stayTonight;

  /// The first item of tomorrow, while tomorrow is still a day of the trip.
  final PlanItem? tomorrowFirst;

  bool get running => phase == TripTodayPhase.running;
}

/// The quiet line on Today for trips that are being planned (specs/30 "In the calendar and
/// on the wall"): the nearest of them and how many more there are. Shown only while there is
/// no [TripToday] card; ideas never make one (the wish list is permanent).
class TripPlanningLine {
  const TripPlanningLine({required this.trip, required this.more});

  /// The line for [upcoming], the planned and fixed trips with dates that are not over,
  /// soonest first; null when there are none.
  static TripPlanningLine? of(List<Trip> upcoming) {
    final first = upcoming.firstOrNull;
    if (first == null) return null;
    return TripPlanningLine(trip: first, more: upcoming.length - 1);
  }

  final Trip trip;

  /// How many other trips are being planned.
  final int more;
}
