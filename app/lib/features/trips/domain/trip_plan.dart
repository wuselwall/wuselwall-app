import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// The plan of a trip: its days with what is chosen or booked for each, in time order
/// (specs/30 "Options and the plan"). Pure.

/// How an entry shows on one day of the plan.
///
/// By kind: a stay is `start` ("Einchecken"), `during` (the day's footer) and `end`
/// ("Auschecken"); a rental is pick-up, holding and return; a transport that spans days is
/// departure and arrival; anything on one day only is `single`.
enum PlanRole {
  /// The entry's first day (a stay's check-in, a rental's pick-up, a departure).
  start,

  /// A day between the first and the last (a stay's night, a rental's day).
  during,

  /// The entry's last day (a check-out, a return, an arrival).
  end,

  /// The entry starts and ends on this day, or has no end.
  single,
}

/// One entry on one day.
class PlanItem {
  const PlanItem(this.entry, this.role);

  final TripEntry entry;
  final PlanRole role;

  /// The wall-clock time this item happens at on its day: the entry's start time on its
  /// first day and when single, its end time on its last day; null for `during` and for
  /// an entry without a time.
  TimeOfDay? get time => switch (role) {
    PlanRole.start || PlanRole.single => entry.startsTime,
    PlanRole.end => entry.endsTime,
    PlanRole.during => null,
  };
}

/// One day of a trip with dates.
class PlanDay {
  const PlanDay({
    required this.date,
    required this.dayNumber,
    required this.items,
    required this.ongoing,
    required this.stay,
  });

  final DateTime date;

  /// 1 on the trip's first day.
  final int dayNumber;

  /// What happens on this day (roles start, end, single), without a time first, then by
  /// time, ties in the trip's order.
  final List<PlanItem> items;

  /// What continues through this day (role during): stays and rentals in between.
  final List<PlanItem> ongoing;

  /// Where the family sleeps tonight: the chosen or booked stay covering this night.
  final TripEntry? stay;
}

/// A trip's plan: [days] for a trip with dates, and the chosen entries that do not fit
/// a day.
class TripPlan {
  const TripPlan._({
    required this.trip,
    required this.days,
    required this.undated,
    required this.options,
    required this.outside,
    required this.sum,
    required this.incomplete,
  });

  /// The plan of [trip] from its [entries] (any entries of other trips are ignored).
  factory TripPlan.of(Trip trip, Iterable<TripEntry> entries) {
    final mine = [
      for (final e in entries)
        if (e.tripId == trip.id) e,
    ]..sort(_byPosition);
    final planned = [
      for (final e in mine)
        if (e.state.inPlan) e,
    ];
    final options = [
      for (final e in mine)
        if (e.state == EntryState.option) e,
    ];

    var sum = 0;
    var incomplete = false;
    for (final e in planned) {
      if (e.priceCents != null) {
        sum += e.priceCents!;
      } else if (e.kind != EntryKind.note) {
        incomplete = true;
      }
    }

    final undated = [
      for (final e in planned)
        if (e.startsOn == null) e,
    ];
    final dated = [
      for (final e in planned)
        if (e.startsOn != null) e,
    ];

    final days = <PlanDay>[];
    final outside = <TripEntry>[];
    if (trip.hasDates) {
      final first = trip.startsOn!;
      final last = trip.endsOn!;
      for (var d = first; !d.isAfter(last); d = addDays(d, 1)) {
        final items = <PlanItem>[];
        final ongoing = <PlanItem>[];
        for (final e in dated) {
          final role = _roleOn(e, d);
          if (role == null) continue;
          (role == PlanRole.during ? ongoing : items).add(PlanItem(e, role));
        }
        _sortStable(items);
        days.add(
          PlanDay(
            date: d,
            dayNumber: daysBetween(first, d) + 1,
            items: items,
            ongoing: ongoing,
            stay: _stayOn(dated, d),
          ),
        );
      }
      for (final e in dated) {
        final startsBefore = daysBetween(e.startsOn!, first) > 0;
        final endsAfter = daysBetween(last, e.lastDay!) > 0;
        final startsAfter = daysBetween(last, e.startsOn!) > 0;
        if (startsBefore || endsAfter || startsAfter) outside.add(e);
      }
    } else {
      outside.addAll(dated);
    }

    return TripPlan._(
      trip: trip,
      days: days,
      undated: undated,
      options: options,
      outside: outside,
      sum: sum,
      incomplete: incomplete,
    );
  }

  final Trip trip;

  /// The days from the trip's first to its last day; empty for a trip without dates.
  final List<PlanDay> days;

  /// Chosen or booked entries without a date, in the trip's order.
  final List<TripEntry> undated;

  /// Entries still in state option, in the trip's order.
  final List<TripEntry> options;

  /// Chosen or booked entries dated at least partly outside the trip's dates (also all
  /// dated ones when the trip has no dates). Those that touch the trip's days show there
  /// as well; this list is for flagging them.
  final List<TripEntry> outside;

  /// The sum of the prices of the chosen and booked entries, in cents.
  final int sum;

  /// A chosen or booked entry (other than a note) has no price: say "at least".
  final bool incomplete;

  /// The plan day for [date]; null outside the trip.
  PlanDay? day(DateTime date) {
    final d = dayOf(date);
    for (final day in days) {
      if (day.date == d) return day;
    }
    return null;
  }

  /// The stay of the night from [date] to the next day; null when there is none.
  TripEntry? stayTonight(DateTime date) => day(date)?.stay;

  /// What is chosen or booked, all kinds, in the plan's order of days then [undated].
  bool get isEmpty =>
      undated.isEmpty &&
      outside.isEmpty &&
      days.every((d) => d.items.isEmpty && d.ongoing.isEmpty);
}

int _byPosition(TripEntry a, TripEntry b) {
  final c = a.position.compareTo(b.position);
  return c != 0 ? c : a.id.compareTo(b.id);
}

int _minutes(TimeOfDay? t) => t == null ? -1 : t.hour * 60 + t.minute;

/// No time first, then by time; ties keep their order (`List.sort` is not stable).
void _sortStable(List<PlanItem> items) {
  final order = {for (var i = 0; i < items.length; i++) items[i]: i};
  items.sort((a, b) {
    final c = _minutes(a.time) - _minutes(b.time);
    return c != 0 ? c : order[a]! - order[b]!;
  });
}

/// How [e] shows on [date]; null when it does not touch the day.
PlanRole? _roleOn(TripEntry e, DateTime date) {
  final first = e.startsOn!;
  final last = e.lastDay!;
  final fromStart = daysBetween(first, date);
  final toEnd = daysBetween(date, last);
  if (fromStart < 0 || toEnd < 0) return null;
  if (fromStart == 0 && toEnd == 0) return PlanRole.single;
  if (fromStart == 0) return PlanRole.start;
  if (toEnd == 0) return PlanRole.end;
  return PlanRole.during;
}

/// The stay whose night [date] is: from its first day to the day before its last.
TripEntry? _stayOn(List<TripEntry> dated, DateTime date) {
  for (final e in dated) {
    if (e.kind != EntryKind.stay || e.endsOn == null) continue;
    if (daysBetween(e.startsOn!, date) >= 0 &&
        daysBetween(date, e.endsOn!) >= 1) {
      return e;
    }
  }
  return null;
}
