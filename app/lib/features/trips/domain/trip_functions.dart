import 'package:flutter/foundation.dart' show listEquals;
import 'package:wuselwall/features/board/domain/week_board.dart' show parseDate;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart'
    show isoDate;

/// The request and answer shapes of the `trips` Edge Function (specs/30 "Edge
/// Functions"): the time windows and the discovery.

List<Map<String, dynamic>> _maps(Object? v) => [
  for (final row in (v as List?) ?? const <Object?>[])
    Map<String, dynamic>.from(row! as Map),
];

List<String> _strings(Object? v) =>
    ((v as List?) ?? const []).cast<String>().toList(growable: false);

// ── time windows ─────────────────────────────────────────────────────────────────────

/// What a window is made of.
enum WindowKind {
  /// Ferien of the travelling children's schools, extended over weekends and holidays.
  holidays,

  /// Weekends joined with public holidays and at most two bridge days.
  longWeekend;

  static WindowKind parse(String? v) =>
      v == 'holidays' ? holidays : longWeekend;
}

/// The arguments of the windows request. Value equality, so it is a provider key.
class TripWindowsArgs {
  const TripWindowsArgs({
    this.from,
    this.to,
    this.minDays,
    this.memberIds = const [],
    this.tripId,
  });

  /// The range to look at; the server's default is the next 18 months.
  final DateTime? from;
  final DateTime? to;

  /// The shortest window, 2 to 30: 3, 4 (the default), 7, 10 or 14 in the page.
  final int? minDays;

  /// Who travels; empty is everyone.
  final List<String> memberIds;

  /// The trip the windows are for: its own calendar entry is not a conflict.
  final String? tripId;

  /// The body of `{action: 'windows'}`.
  Map<String, dynamic> toJson() => {
    'action': 'windows',
    if (from != null) 'from': isoDate(from!),
    if (to != null) 'to': isoDate(to!),
    if (minDays != null) 'min_days': minDays,
    if (memberIds.isNotEmpty) 'member_ids': memberIds,
    'trip_id': ?tripId,
  };

  @override
  bool operator ==(Object other) =>
      other is TripWindowsArgs &&
      other.from == from &&
      other.to == to &&
      other.minDays == minDays &&
      other.tripId == tripId &&
      listEquals(other.memberIds, memberIds);

  @override
  int get hashCode =>
      Object.hash(from, to, minDays, tripId, Object.hashAll(memberIds));
}

/// An appointment or presence entry of a travelling member inside a window. It does
/// not remove the window; the family decides.
class WindowConflict {
  const WindowConflict({
    required this.date,
    required this.title,
    required this.eventId,
    required this.kind,
    this.presenceState,
    this.profileIds = const [],
  });

  factory WindowConflict.fromJson(Map<String, dynamic> json) => WindowConflict(
    date: parseDate(json['date'] as String),
    title: json['title'] as String? ?? '',
    eventId: json['event_id'] as String? ?? '',
    kind: json['kind'] as String? ?? 'appointment',
    presenceState: json['presence_state'] as String?,
    profileIds: _strings(json['profile_ids']),
  );

  final DateTime date;
  final String title;
  final String eventId;

  /// `appointment` or `presence`.
  final String kind;

  /// For a presence entry: `working`, `travel`, `away` or `childcare`.
  final String? presenceState;

  /// The travelling members it concerns.
  final List<String> profileIds;
}

/// Days of a window that only some of the travelling children have off.
class WindowPartial {
  const WindowPartial({
    required this.profileId,
    required this.from,
    required this.to,
  });

  factory WindowPartial.fromJson(Map<String, dynamic> json) => WindowPartial(
    profileId: json['profile_id'] as String,
    from: parseDate(json['from'] as String),
    to: parseDate(json['to'] as String),
  );

  final String profileId;
  final DateTime from;
  final DateTime to;
}

/// One proposed window (specs/30 "Time windows").
class TripWindow {
  const TripWindow({
    required this.from,
    required this.to,
    required this.days,
    required this.kind,
    required this.leaveDays,
    this.name,
    this.partial = const [],
    this.conflicts = const [],
  });

  factory TripWindow.fromJson(Map<String, dynamic> json) => TripWindow(
    from: parseDate(json['from'] as String),
    to: parseDate(json['to'] as String),
    days: (json['days'] as num).toInt(),
    kind: WindowKind.parse(json['kind'] as String?),
    leaveDays: (json['leave_days'] as num?)?.toInt() ?? 0,
    name: json['name'] as String?,
    partial: [
      for (final m in _maps(json['partial'])) WindowPartial.fromJson(m),
    ],
    conflicts: [
      for (final m in _maps(json['conflicts'])) WindowConflict.fromJson(m),
    ],
  );

  final DateTime from;
  final DateTime to;

  /// Length in days, both ends included.
  final int days;
  final WindowKind kind;

  /// The name of the Ferien it lies in, for [WindowKind.holidays].
  final String? name;

  /// Monday to Friday inside the window that are not public holidays: what the adults
  /// have to take off.
  final int leaveDays;

  /// Days only some of the travelling children have off, named beside the window.
  final List<WindowPartial> partial;
  final List<WindowConflict> conflicts;

  bool get hasConflicts => conflicts.isNotEmpty;
}

// ── discovery ────────────────────────────────────────────────────────────────────────

/// How far a place is from home, an estimate from the great-circle distance
/// (specs/30 "Discovery"); the wire names are the server's (`Effort` in
/// `supabase/functions/_shared/trips/discover.ts`).
enum TravelEffort {
  /// Up to 300 km.
  near,

  /// Up to 800 km: a long drive.
  car,

  /// Up to 1,500 km.
  short,

  /// Up to 4,000 km.
  medium,

  /// Beyond.
  long;

  static TravelEffort? parse(String? v) {
    for (final e in values) {
      if (e.name == v) return e;
    }
    return null;
  }

  String get wire => name;
}

/// The filters of the discovery. Value equality.
class DiscoverFilters {
  const DiscoverFilters({
    this.tempMin,
    this.tempMax,
    this.dry = false,
    this.seaMin,
    this.tags = const [],
    this.effort,
  });

  /// The day temperature wanted, at least and at most, in °C.
  final double? tempMin;
  final double? tempMax;

  /// "Little rain".
  final bool dry;

  /// The sea temperature wanted, at least.
  final double? seaMin;

  /// `sea`, `island`, `mountains`, `lake`, `city`, `countryside`, `north`, `long_haul`.
  final List<String> tags;

  /// The longest travel effort wanted; needs the home place.
  final TravelEffort? effort;

  bool get isEmpty =>
      tempMin == null &&
      tempMax == null &&
      !dry &&
      seaMin == null &&
      tags.isEmpty &&
      effort == null;

  Map<String, dynamic> toJson() => {
    if (tempMin != null) 'temp_min': tempMin,
    if (tempMax != null) 'temp_max': tempMax,
    if (dry) 'dry': true,
    if (seaMin != null) 'sea_min': seaMin,
    if (tags.isNotEmpty) 'tags': tags,
    if (effort != null) 'effort': effort!.wire,
  };

  @override
  bool operator ==(Object other) =>
      other is DiscoverFilters &&
      other.tempMin == tempMin &&
      other.tempMax == tempMax &&
      other.dry == dry &&
      other.seaMin == seaMin &&
      listEquals(other.tags, tags) &&
      other.effort == effort;

  @override
  int get hashCode =>
      Object.hash(tempMin, tempMax, dry, seaMin, Object.hashAll(tags), effort);
}

/// The arguments of the discover request. Value equality, so it is a provider key.
class TripDiscoverArgs {
  const TripDiscoverArgs({
    required this.from,
    required this.to,
    this.filters = const DiscoverFilters(),
    this.lang,
  });

  final DateTime from;
  final DateTime to;
  final DiscoverFilters filters;

  /// The language of the place names; null: the server's choice.
  final String? lang;

  @override
  bool operator ==(Object other) =>
      other is TripDiscoverArgs &&
      other.from == from &&
      other.to == to &&
      other.filters == filters &&
      other.lang == lang;

  @override
  int get hashCode => Object.hash(from, to, filters, lang);
}

/// Whether a place meets the filters.
enum DiscoverFit {
  yes,
  no,

  /// The climate is not fetched yet, or no climate service is on.
  unknown;

  static DiscoverFit parse(String? v) => switch (v) {
    'yes' => yes,
    'no' => no,
    _ => unknown,
  };
}

/// What is typical at a place in the window's months.
class DiscoverClimate {
  const DiscoverClimate({
    required this.tmax,
    required this.tmin,
    this.rainDays,
    this.sunHours,
    this.sea,
  });

  factory DiscoverClimate.fromJson(Map<String, dynamic> json) =>
      DiscoverClimate(
        tmax: (json['tmax'] as num).toDouble(),
        tmin: (json['tmin'] as num).toDouble(),
        rainDays: (json['rain_days'] as num?)?.toDouble(),
        sunHours: (json['sun_hours'] as num?)?.toDouble(),
        sea: (json['sea'] as num?)?.toDouble(),
      );

  final double tmax;
  final double tmin;
  final double? rainDays;
  final double? sunHours;

  /// The sea temperature, by the sea.
  final double? sea;
}

/// One ranked place: from the server's catalogue ([key]) or one of the family's ideas
/// ([tripId]).
class DiscoverPlace {
  const DiscoverPlace({
    required this.name,
    required this.country,
    required this.lat,
    required this.lon,
    this.key,
    this.tripId,
    this.tags = const [],
    this.km,
    this.effort,
    this.climate,
    this.fits = DiscoverFit.unknown,
  });

  factory DiscoverPlace.fromJson(Map<String, dynamic> json) => DiscoverPlace(
    key: json['key'] as String?,
    tripId: json['trip_id'] as String?,
    name: json['name'] as String? ?? '',
    country: json['country'] as String? ?? '',
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    tags: _strings(json['tags']),
    km: (json['km'] as num?)?.toDouble(),
    effort: TravelEffort.parse(json['effort'] as String?),
    climate: json['climate'] is Map
        ? DiscoverClimate.fromJson(
            Map<String, dynamic>.from(json['climate'] as Map),
          )
        : null,
    fits: DiscoverFit.parse(json['fits'] as String?),
  );

  /// The catalogue key; null for an idea of the family.
  final String? key;

  /// The family's idea this place is; null for a catalogue place.
  final String? tripId;
  final String name;
  final String country;
  final double lat;
  final double lon;
  final List<String> tags;

  /// Great-circle distance from home; null without a home place.
  final double? km;
  final TravelEffort? effort;
  final DiscoverClimate? climate;
  final DiscoverFit fits;

  bool get isIdea => tripId != null;
}

/// The discover answer: places (fits first, then nearer), how many are still being
/// fetched, and where the numbers come from.
class DiscoverResult {
  const DiscoverResult({
    this.places = const [],
    this.pending = 0,
    this.provider,
    this.attribution,
  });

  factory DiscoverResult.fromJson(Map<String, dynamic> json) => DiscoverResult(
    places: [for (final m in _maps(json['places'])) DiscoverPlace.fromJson(m)],
    pending: (json['pending'] as num?)?.toInt() ?? 0,
    provider: json['provider'] as String?,
    attribution: json['attribution'] as String?,
  );

  final List<DiscoverPlace> places;

  /// Places whose climate is not fetched yet: ask again.
  final int pending;
  final String? provider;

  /// The provider's attribution line, shown with the numbers.
  final String? attribution;
}
