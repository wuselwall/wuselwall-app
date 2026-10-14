// Regions and holiday candidates as the `api.regions`, `api.holiday_feed_status` and
// `api.holiday_import_preview` reads return them (the regions migration). Codes are
// OpenHolidays subdivision codes: `CH` (country), `CH-ZH` (canton), `CH-ZH-ZH` (district),
// `CH-ZH-ZH-ZH` (municipality), `DE-BY` (Bundesland), `AT-9`.

/// The countries the region picker offers, in display order. Anything else is "another
/// country": no region, and holidays are entered by hand.
const regionCountries = ['DE', 'AT', 'CH', 'LI'];

/// How old a country's cache may be before the import sheet refreshes it (specs/21).
const regionCacheMaxAge = Duration(days: 7);

/// Pulls the text in [names] for [language]: that language, else German, else any name the
/// source has. Empty when there is none.
String localizedName(Map<String, String> names, String language) {
  for (final key in [language, 'de']) {
    final name = names[key]?.trim();
    if (name != null && name.isNotEmpty) return name;
  }
  for (final name in names.values) {
    if (name.trim().isNotEmpty) return name.trim();
  }
  return '';
}

Map<String, String> _names(Object? json) {
  if (json is! Map) return const {};
  return {
    for (final e in json.entries)
      if (e.value is String) e.key as String: e.value as String,
  };
}

/// One subdivision of a country. [parentCode] is null on level 1.
class Region {
  const Region({
    required this.code,
    required this.country,
    required this.level,
    required this.category,
    required this.shortName,
    required this.names,
    this.parentCode,
  });

  factory Region.fromJson(Map<String, dynamic> json) => Region(
    code: json['code'] as String,
    country: json['country'] as String,
    parentCode: json['parent_code'] as String?,
    level: (json['level'] as num).toInt(),
    category: json['category'] as String? ?? '',
    shortName: json['short_name'] as String? ?? '',
    names: _names(json['names']),
  );

  final String code;
  final String country;
  final String? parentCode;

  /// 1 for a canton or Bundesland, up to 4 for a municipality.
  final int level;

  /// The source's label for the level: Kanton, Bezirk, Gemeinde, Bundesland.
  final String category;
  final String shortName;

  /// Language code to name.
  final Map<String, String> names;

  /// The name in [language] (`de` first when it is missing).
  String displayName(String language) {
    final name = localizedName(names, language);
    return name.isNotEmpty ? name : shortName;
  }

  /// True when [code] lies below this region (a district or municipality of this canton).
  bool contains(String otherCode) => otherCode.startsWith('$code-');
}

/// When a country's cache was last filled, and what it covers.
class FeedStatus {
  const FeedStatus({
    required this.country,
    this.fetchedAt,
    this.validFrom,
    this.validTo,
    this.lastError,
  });

  factory FeedStatus.fromJson(Map<String, dynamic> json) => FeedStatus(
    country: json['country'] as String,
    fetchedAt: _date(json['fetched_at']),
    validFrom: _date(json['valid_from']),
    validTo: _date(json['valid_to']),
    lastError: json['last_error'] as String?,
  );

  final String country;
  final DateTime? fetchedAt;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String? lastError;

  /// Missing, or older than [regionCacheMaxAge] at [now].
  bool isStale(DateTime now) =>
      fetchedAt == null || now.difference(fetchedAt!) > regionCacheMaxAge;
}

DateTime? _date(Object? wire) =>
    wire == null ? null : DateTime.parse(wire as String);

/// One feed row the import would bring: a public holiday (`public_holiday`, applied
/// automatically, never imported by the app) or a school holiday (`holiday`).
class HolidayCandidate {
  const HolidayCandidate({
    required this.feedId,
    required this.kind,
    required this.names,
    required this.startsOn,
    required this.endsOn,
    this.alreadyImported = false,
    this.overlapsExisting = false,
  });

  factory HolidayCandidate.fromJson(Map<String, dynamic> json) =>
      HolidayCandidate(
        feedId: json['feed_id'] as String,
        kind: json['kind'] as String,
        names: _names(json['names']),
        startsOn: DateTime.parse(json['starts_on'] as String),
        endsOn: DateTime.parse(json['ends_on'] as String),
        alreadyImported: json['already_imported'] as bool? ?? false,
        overlapsExisting: json['overlaps_existing'] as bool? ?? false,
      );

  final String feedId;
  final String kind;
  final Map<String, String> names;
  final DateTime startsOn;

  /// Inclusive.
  final DateTime endsOn;
  final bool alreadyImported;

  /// A manual entry of the household covers some of these dates.
  final bool overlapsExisting;

  bool get isSchoolHoliday => kind == 'holiday';

  String displayName(String language) => localizedName(names, language);
}

/// The region the user chose. [code] is null for "no region" (another country, or a
/// region taken off again). Dismissing the picker gives no [RegionPick] at all.
class RegionPick {
  const RegionPick(this.code);

  final String? code;
}

/// The regions of a country by code, for the lookups the labels and the picker make.
class RegionIndex {
  RegionIndex(Iterable<Region> regions)
    : _byCode = {for (final r in regions) r.code: r};

  final Map<String, Region> _byCode;

  Region? operator [](String code) => _byCode[code];

  /// The level-1 region above [code] (CH-ZH for CH-ZH-ZH-ZH); null when it is not cached.
  Region? top(String code) => _byCode[code.split('-').take(2).join('-')];

  /// The region one level up from [region]; null on level 1 or when it is not cached.
  Region? parentOf(Region region) =>
      region.parentCode == null ? null : _byCode[region.parentCode];

  /// The regions below the level-1 region [top], level 2 and deeper.
  Iterable<Region> below(String top) =>
      _byCode.values.where((r) => r.level > 1 && r.code.startsWith('$top-'));
}
