import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// Trying out a combination of options (specs/30 "Comparing and combining"): the ticked
/// entries of one trip, their total, their dates and what does not fit. Pure: nothing is
/// saved, the server only stores sets and applies the choice.

/// A run of nights, [from] the night of that day to the morning after [to]'s night:
/// the night of day `d` is the one from `d` to `d + 1`. Both ends included.
class NightRange {
  const NightRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  int get nights => daysBetween(from, to) + 1;

  @override
  bool operator ==(Object other) =>
      other is NightRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'NightRange($from..$to)';
}

/// Why a rental does not fit the ticked transport.
enum RentalMismatch {
  /// A rental is ticked and no transport is.
  noTransport,

  /// The rental starts before the arrival (the end date of the first transport, or its
  /// start date when it has no end).
  startsBeforeArrival,

  /// The rental ends after the departure (the start date of the last transport); only
  /// checked with two or more dated transports.
  endsAfterDeparture,
}

/// What does not fit in a combination: exactly the four cases of specs/30.
sealed class CombinationWarning {
  const CombinationWarning();
}

/// A night between the first and the last day that no ticked stay covers.
class UncoveredNights extends CombinationWarning {
  const UncoveredNights(this.ranges);

  /// The nights without a stay, in date order, adjacent nights joined.
  final List<NightRange> ranges;

  int get nights => ranges.fold(0, (sum, r) => sum + r.nights);
}

/// A rental that starts before the arrival, ends after the departure, or is ticked
/// without any transport.
class RentalOutsideTransport extends CombinationWarning {
  const RentalOutsideTransport(this.rental, this.reason);

  final TripEntry rental;
  final RentalMismatch reason;
}

/// Two ticked stays that share a night. A check-out on the day of the other's check-in
/// is fine.
class OverlappingStays extends CombinationWarning {
  const OverlappingStays(this.first, this.second, this.shared);

  /// The stay that starts first.
  final TripEntry first;
  final TripEntry second;

  /// The nights both cover.
  final NightRange shared;
}

/// Ticked entries without a price: the total is "at least".
class PriceMissing extends CombinationWarning {
  const PriceMissing(this.entries);

  final List<TripEntry> entries;
}

/// The ticked set of one trip, evaluated.
class Combination {
  const Combination._({
    required this.entries,
    required this.total,
    required this.incomplete,
    required this.from,
    required this.to,
    required this.warnings,
  });

  /// Evaluates [ticked] (entries of [trip]; an entry of another trip is ignored) in the
  /// order of the trip's entries, so the result does not depend on the order of ticking.
  factory Combination.of(Trip trip, Iterable<TripEntry> ticked) {
    final entries = [
      for (final e in ticked)
        if (e.tripId == trip.id) e,
    ]..sort(_byPosition);

    var total = 0;
    final unpriced = <TripEntry>[];
    for (final e in entries) {
      if (e.priceCents != null) {
        total += e.priceCents!;
      } else if (e.kind != EntryKind.note) {
        unpriced.add(e);
      }
    }

    DateTime? from;
    DateTime? to;
    for (final e in entries) {
      final s = e.startsOn;
      final l = e.lastDay;
      if (s != null && (from == null || s.isBefore(from))) from = s;
      if (l != null && (to == null || l.isAfter(to))) to = l;
    }

    final stays = [
      for (final e in entries)
        if (e.kind == EntryKind.stay) e,
    ];
    final transports = [
      for (final e in entries)
        if (e.kind == EntryKind.transport) e,
    ];
    final rentals = [
      for (final e in entries)
        if (e.kind == EntryKind.rental) e,
    ];

    return Combination._(
      entries: entries,
      total: total,
      incomplete: unpriced.isNotEmpty,
      from: from,
      to: to,
      warnings: [
        ..._nights(from, to, stays, transports),
        ..._rentals(rentals, transports),
        ..._overlaps(stays),
        if (unpriced.isNotEmpty) PriceMissing(unpriced),
      ],
    );
  }

  /// A stored combination: its entries that still exist, from the trip's [all] entries.
  factory Combination.ofCombo(
    Trip trip,
    TripCombo combo,
    Iterable<TripEntry> all,
  ) {
    final ids = combo.entryIds.toSet();
    return Combination.of(trip, [
      for (final e in all)
        if (ids.contains(e.id)) e,
    ]);
  }

  /// The evaluated entries, in the trip's order.
  final List<TripEntry> entries;

  /// The sum of the entries that have a price, in cents.
  final int total;

  /// An entry (other than a note) has no price: show "at least" with the [total].
  final bool incomplete;

  /// The first start and the last end of the dated entries; null when none is dated.
  final DateTime? from;
  final DateTime? to;
  final List<CombinationWarning> warnings;

  bool get isEmpty => entries.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  /// Nights from [from] to [to]; 0 without both.
  int get nights => from == null || to == null ? 0 : daysBetween(from!, to!);

  /// The entries of [kind], for the card of a stored combination.
  List<TripEntry> ofKind(EntryKind kind) => [
    for (final e in entries)
      if (e.kind == kind) e,
  ];

  /// The ids of the cheapest priced entry of each of the kinds in [entries]: "the cheapest
  /// price is marked". Entries of different kinds do not compete. Entries tied at the
  /// lowest price are all marked; a kind with fewer than two priced entries has none.
  static Set<String> cheapestOf(Iterable<TripEntry> entries) {
    final byKind = <EntryKind, List<TripEntry>>{};
    for (final e in entries) {
      if (e.priceCents != null) (byKind[e.kind] ??= []).add(e);
    }
    return {
      for (final group in byKind.values)
        if (group.length >= 2) ..._lowest(group),
    };
  }
}

Iterable<String> _lowest(List<TripEntry> priced) {
  final min = priced.map((e) => e.priceCents!).reduce((a, b) => a < b ? a : b);
  return [
    for (final e in priced)
      if (e.priceCents == min) e.id,
  ];
}

int _byPosition(TripEntry a, TripEntry b) {
  final c = a.position.compareTo(b.position);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// The nights a stay covers: from its first day to the day before its last; null when
/// it lacks a date or has no night.
({DateTime from, DateTime to})? _stayNights(TripEntry stay) {
  final s = stay.startsOn;
  final e = stay.endsOn;
  if (s == null || e == null || daysBetween(s, e) < 1) return null;
  return (from: s, to: addDays(e, -1));
}

List<CombinationWarning> _nights(
  DateTime? from,
  DateTime? to,
  List<TripEntry> stays,
  List<TripEntry> transports,
) {
  if (from == null || to == null || daysBetween(from, to) < 1) return const [];
  // With neither a stay nor a dated transport the entries are loose items (an
  // activity, a rental): no accommodation is expected.
  final anyStay = stays.isNotEmpty;
  final anyTransport = transports.any((t) => t.startsOn != null);
  if (!anyStay && !anyTransport) return const [];

  final covered = <DateTime>{};
  for (final stay in stays) {
    final n = _stayNights(stay);
    if (n == null) continue;
    for (var d = n.from; !d.isAfter(n.to); d = addDays(d, 1)) {
      covered.add(d);
    }
  }
  final ranges = <NightRange>[];
  DateTime? runStart;
  DateTime? runEnd;
  final last = addDays(to, -1);
  for (var d = from; !d.isAfter(last); d = addDays(d, 1)) {
    if (covered.contains(d)) {
      if (runStart != null) ranges.add(NightRange(runStart, runEnd!));
      runStart = null;
    } else {
      runStart ??= d;
      runEnd = d;
    }
  }
  if (runStart != null) ranges.add(NightRange(runStart, runEnd!));
  return ranges.isEmpty ? const [] : [UncoveredNights(ranges)];
}

int _byStart(TripEntry a, TripEntry b) {
  final c = daysBetween(b.startsOn!, a.startsOn!);
  if (c != 0) return c;
  final at = a.startsTime;
  final bt = b.startsTime;
  if (at == null || bt == null) return 0;
  return (at.hour * 60 + at.minute) - (bt.hour * 60 + bt.minute);
}

List<CombinationWarning> _rentals(
  List<TripEntry> rentals,
  List<TripEntry> transports,
) {
  if (rentals.isEmpty) return const [];
  if (transports.isEmpty) {
    return [
      for (final r in rentals)
        RentalOutsideTransport(r, RentalMismatch.noTransport),
    ];
  }
  final dated = [
    for (final t in transports)
      if (t.startsOn != null) t,
  ]..sort(_byStart);
  if (dated.isEmpty) return const [];
  final arrival = dated.first.lastDay!;
  final departure = dated.length >= 2 ? dated.last.startsOn! : null;
  final out = <CombinationWarning>[];
  for (final r in rentals) {
    final start = r.startsOn;
    final end = r.lastDay;
    if (start != null && daysBetween(arrival, start) < 0) {
      out.add(RentalOutsideTransport(r, RentalMismatch.startsBeforeArrival));
    }
    if (departure != null && end != null && daysBetween(departure, end) > 0) {
      out.add(RentalOutsideTransport(r, RentalMismatch.endsAfterDeparture));
    }
  }
  return out;
}

List<CombinationWarning> _overlaps(List<TripEntry> stays) {
  final dated = [
    for (final s in stays)
      if (_stayNights(s) != null) s,
  ]..sort(_byStart);
  final out = <CombinationWarning>[];
  for (var i = 0; i < dated.length; i++) {
    for (var j = i + 1; j < dated.length; j++) {
      final a = _stayNights(dated[i])!;
      final b = _stayNights(dated[j])!;
      final from = daysBetween(a.from, b.from) >= 0 ? b.from : a.from;
      final to = daysBetween(a.to, b.to) >= 0 ? a.to : b.to;
      if (daysBetween(from, to) >= 0) {
        out.add(OverlappingStays(dated[i], dated[j], NightRange(from, to)));
      }
    }
  }
  return out;
}
