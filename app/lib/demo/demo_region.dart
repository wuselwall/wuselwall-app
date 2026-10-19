import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/region/data/region_repository.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';

/// Regions and holidays for the demo build (`lib/main_demo.dart`): a few Swiss and German
/// subdivisions and two school holidays of the autumn. Importing a holiday marks it as
/// imported, so the sheet shows the state after an import. Nothing leaves the page.
class DemoRegionRepository implements RegionRepository {
  DemoRegionRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _imported = <String>{};

  static final _regions = [for (final r in _regionRows) Region.fromJson(r)];

  @override
  Future<Result<List<Region>>> regions(String country) async => Ok([
    for (final r in _regions)
      if (r.country == country) r,
  ]);

  @override
  Future<Result<FeedStatus?>> feedStatus(String country) async {
    final now = _clock();
    return Ok(
      FeedStatus(
        country: country,
        fetchedAt: now,
        validFrom: DateTime(now.year, 1, 1),
        validTo: DateTime(now.year + 2, 12, 31),
      ),
    );
  }

  @override
  Future<Result<FeedStatus>> refresh(String country) async {
    final now = _clock();
    return Ok(FeedStatus(country: country, fetchedAt: now));
  }

  @override
  Future<Result<List<HolidayCandidate>>> importPreview({
    required String? actor,
    required String schoolId,
    required String region,
    required DateTime from,
    required DateTime to,
  }) async {
    if (region.split('-').first != 'CH' && region.split('-').first != 'DE') {
      return const Ok([]);
    }
    return Ok([
      for (final row in _holidayRows)
        HolidayCandidate.fromJson({
          ...row,
          'already_imported': _imported.contains(row['feed_id']),
        }),
    ]);
  }

  @override
  Future<Result<int>> importHolidays({
    required String? actor,
    required String schoolId,
    required List<String> feedIds,
    required String language,
  }) async {
    final fresh = feedIds.where(_imported.add).length;
    return Ok(fresh);
  }
}

const _regionRows = <Map<String, dynamic>>[
  {
    'code': 'CH-BE',
    'country': 'CH',
    'parent_code': null,
    'level': 1,
    'category': 'Kanton',
    'short_name': 'BE',
    'names': {'de': 'Bern', 'en': 'Bern', 'fr': 'Berne', 'es': 'Berna'},
  },
  {
    'code': 'CH-ZH',
    'country': 'CH',
    'parent_code': null,
    'level': 1,
    'category': 'Kanton',
    'short_name': 'ZH',
    'names': {'de': 'Zürich', 'en': 'Zurich', 'fr': 'Zurich', 'es': 'Zúrich'},
  },
  {
    'code': 'CH-ZH-UE',
    'country': 'CH',
    'parent_code': 'CH-ZH',
    'level': 2,
    'category': 'Bezirk',
    'short_name': 'Uster',
    'names': {'de': 'Uster', 'en': 'Uster', 'fr': 'Uster', 'es': 'Uster'},
  },
  {
    'code': 'CH-ZH-UE-0003',
    'country': 'CH',
    'parent_code': 'CH-ZH-UE',
    'level': 3,
    'category': 'Gemeinde',
    'short_name': 'Uster',
    'names': {'de': 'Uster', 'en': 'Uster', 'fr': 'Uster', 'es': 'Uster'},
  },
  {
    'code': 'CH-ZH-UE-0004',
    'country': 'CH',
    'parent_code': 'CH-ZH-UE',
    'level': 3,
    'category': 'Gemeinde',
    'short_name': 'Wetzikon',
    'names': {
      'de': 'Wetzikon',
      'en': 'Wetzikon',
      'fr': 'Wetzikon',
      'es': 'Wetzikon',
    },
  },
  {
    'code': 'CH-ZH-ZH',
    'country': 'CH',
    'parent_code': 'CH-ZH',
    'level': 2,
    'category': 'Bezirk',
    'short_name': 'Zürich',
    'names': {'de': 'Zürich', 'en': 'Zurich', 'fr': 'Zurich', 'es': 'Zúrich'},
  },
  {
    'code': 'CH-ZH-ZH-0261',
    'country': 'CH',
    'parent_code': 'CH-ZH-ZH',
    'level': 3,
    'category': 'Gemeinde',
    'short_name': 'Zürich',
    'names': {'de': 'Zürich', 'en': 'Zurich', 'fr': 'Zurich', 'es': 'Zúrich'},
  },
  {
    'code': 'DE-BE',
    'country': 'DE',
    'parent_code': null,
    'level': 1,
    'category': 'Bundesland',
    'short_name': 'BE',
    'names': {'de': 'Berlin', 'en': 'Berlin', 'fr': 'Berlin', 'es': 'Berlín'},
  },
  {
    'code': 'DE-BY',
    'country': 'DE',
    'parent_code': null,
    'level': 1,
    'category': 'Bundesland',
    'short_name': 'BY',
    'names': {
      'de': 'Bayern',
      'en': 'Bavaria',
      'fr': 'Bavière',
      'es': 'Baviera',
    },
  },
  {
    'code': 'AT-9',
    'country': 'AT',
    'parent_code': null,
    'level': 1,
    'category': 'Bundesland',
    'short_name': 'W',
    'names': {'de': 'Wien', 'en': 'Vienna', 'fr': 'Vienne', 'es': 'Viena'},
  },
];

const _holidayRows = <Map<String, dynamic>>[
  {
    'feed_id': 'demo-herbstferien-2026',
    'kind': 'holiday',
    'names': {
      'de': 'Herbstferien',
      'en': 'Autumn holidays',
      'fr': 'Vacances d’automne',
      'es': 'Vacaciones de otoño',
    },
    'starts_on': '2026-10-19',
    'ends_on': '2026-10-31',
    'already_imported': false,
    'overlaps_existing': false,
  },
  {
    'feed_id': 'demo-weihnachtsferien-2026',
    'kind': 'holiday',
    'names': {
      'de': 'Weihnachtsferien',
      'en': 'Christmas holidays',
      'fr': 'Vacances de Noël',
      'es': 'Vacaciones de Navidad',
    },
    'starts_on': '2026-12-21',
    'ends_on': '2027-01-08',
    'already_imported': false,
    'overlaps_existing': true,
  },
];
