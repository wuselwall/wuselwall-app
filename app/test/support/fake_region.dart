import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/region/data/region_repository.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';

/// Regions of Switzerland (Zürich with a district and two municipalities, Bern without
/// any) and Bavaria, as the cache returns them.
List<Region> referenceRegions() => [for (final r in _rows) Region.fromJson(r)];

/// Two school holidays of the autumn. The second overlaps a holiday the household entered.
List<HolidayCandidate> referenceCandidates({bool herbstImported = false}) => [
  HolidayCandidate.fromJson({
    'feed_id': 'feed-herbst',
    'kind': 'holiday',
    'names': {'de': 'Herbstferien', 'en': 'Autumn holidays'},
    'starts_on': '2026-10-19',
    'ends_on': '2026-10-31',
    'already_imported': herbstImported,
    'overlaps_existing': false,
  }),
  HolidayCandidate.fromJson({
    'feed_id': 'feed-weihnacht',
    'kind': 'holiday',
    'names': {'de': 'Weihnachtsferien', 'en': 'Christmas holidays'},
    'starts_on': '2026-12-21',
    'ends_on': '2027-01-08',
    'already_imported': false,
    'overlaps_existing': true,
  }),
  HolidayCandidate.fromJson({
    'feed_id': 'feed-feiertag',
    'kind': 'public_holiday',
    'names': {'de': 'Allerheiligen', 'en': 'All Saints'},
    'starts_on': '2026-11-01',
    'ends_on': '2026-11-01',
  }),
];

/// Records what the picker, the school form and the import sheet asked for. The cache is
/// [regions] and [status]; a refresh fills the status (or fails with [refreshFailure]).
class FakeRegionRepository implements RegionRepository {
  FakeRegionRepository({
    List<Region>? regions,
    this.status,
    List<HolidayCandidate>? candidates,
    this.refreshFailure,
  }) : cachedRegions = regions ?? referenceRegions(),
       candidates = candidates ?? referenceCandidates();

  final List<Region> cachedRegions;
  FeedStatus? status;
  final List<HolidayCandidate> candidates;
  final Failure? refreshFailure;

  final refreshes = <String>[];
  final previews =
      <({String schoolId, String region, DateTime from, DateTime to})>[];
  final imports =
      <({String schoolId, List<String> feedIds, String language})>[];

  @override
  Future<Result<List<Region>>> regions(String country) async => Ok([
    for (final r in cachedRegions)
      if (r.country == country) r,
  ]);

  @override
  Future<Result<FeedStatus?>> feedStatus(String country) async =>
      Ok(status?.country == country ? status : null);

  @override
  Future<Result<FeedStatus>> refresh(String country) async {
    refreshes.add(country);
    final failure = refreshFailure;
    if (failure != null) return Err(failure);
    status = FeedStatus(country: country, fetchedAt: DateTime.now());
    return Ok(status!);
  }

  @override
  Future<Result<List<HolidayCandidate>>> importPreview({
    required String? actor,
    required String schoolId,
    required String region,
    required DateTime from,
    required DateTime to,
  }) async {
    previews.add((schoolId: schoolId, region: region, from: from, to: to));
    return Ok(candidates);
  }

  @override
  Future<Result<int>> importHolidays({
    required String? actor,
    required String schoolId,
    required List<String> feedIds,
    required String language,
  }) async {
    imports.add((schoolId: schoolId, feedIds: feedIds, language: language));
    return Ok(feedIds.length);
  }
}

const _rows = <Map<String, dynamic>>[
  {
    'code': 'CH-BE',
    'country': 'CH',
    'parent_code': null,
    'level': 1,
    'category': 'Kanton',
    'short_name': 'BE',
    'names': {'de': 'Bern', 'en': 'Bern'},
  },
  {
    'code': 'CH-ZH',
    'country': 'CH',
    'parent_code': null,
    'level': 1,
    'category': 'Kanton',
    'short_name': 'ZH',
    'names': {'de': 'Zürich', 'en': 'Zurich'},
  },
  {
    'code': 'CH-ZH-UE',
    'country': 'CH',
    'parent_code': 'CH-ZH',
    'level': 2,
    'category': 'Bezirk',
    'short_name': 'Uster',
    'names': {'de': 'Uster', 'en': 'Uster'},
  },
  {
    'code': 'CH-ZH-UE-0003',
    'country': 'CH',
    'parent_code': 'CH-ZH-UE',
    'level': 3,
    'category': 'Gemeinde',
    'short_name': 'Uster',
    'names': {'de': 'Uster', 'en': 'Uster'},
  },
  {
    'code': 'CH-ZH-UE-0004',
    'country': 'CH',
    'parent_code': 'CH-ZH-UE',
    'level': 3,
    'category': 'Gemeinde',
    'short_name': 'Wetzikon',
    'names': {'de': 'Wetzikon', 'en': 'Wetzikon'},
  },
  {
    'code': 'DE-BY',
    'country': 'DE',
    'parent_code': null,
    'level': 1,
    'category': 'Bundesland',
    'short_name': 'BY',
    'names': {'de': 'Bayern', 'en': 'Bavaria'},
  },
];
