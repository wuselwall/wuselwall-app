import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';

/// The region data the apps read: the public cache of regions and holidays. The apps never
/// call OpenHolidays themselves; [refresh] asks the `holidays-sync` Edge Function to fill
/// the server's cache for a country (NFR-9). Imports are household writes, so they name the
/// acting profile, as every write does.
abstract class RegionRepository {
  /// Every region of [country], level 1 first.
  Future<Result<List<Region>>> regions(String country);

  /// The cache state of [country]; null when it was never fetched.
  Future<Result<FeedStatus?>> feedStatus(String country);

  /// Fills or refreshes the server's cache for [country].
  Future<Result<FeedStatus>> refresh(String country);

  /// The feed rows that cover [region] between [from] and [to] (inclusive), for [schoolId].
  Future<Result<List<HolidayCandidate>>> importPreview({
    required String? actor,
    required String schoolId,
    required String region,
    required DateTime from,
    required DateTime to,
  });

  /// Imports the rows [feedIds] into [schoolId] in [language]. Returns how many were added.
  Future<Result<int>> importHolidays({
    required String? actor,
    required String schoolId,
    required List<String> feedIds,
    required String language,
  });
}

/// The Supabase implementation: `api.regions` and `api.holiday_feed_status` for reads,
/// `holidays-sync` for the cache, and `api.holiday_import_preview` and `api.holiday_import`.
class SupabaseRegionRepository implements RegionRepository {
  const SupabaseRegionRepository(this._api);

  final ApiClient _api;

  /// Read in pages: PostgREST returns at most `max_rows` rows per request (1000 by
  /// default) and Switzerland alone has about 2000 regions. The server may cap a page below
  /// what was asked, so only an empty page ends the read. Ordered by the primary key last,
  /// so the pages do not overlap.
  @override
  Future<Result<List<Region>>> regions(String country) async {
    final all = <Region>[];
    while (true) {
      final page = await _api.select(
        'regions',
        parse: Region.fromJson,
        build: (q) => q
            .eq('country', country)
            .order('level')
            .order('short_name')
            .order('code')
            .range(all.length, all.length + regionPageSize - 1),
      );
      switch (page) {
        case Ok(:final value):
          if (value.isEmpty) return Ok(all);
          all.addAll(value);
        case Err(:final failure):
          return Err(failure);
      }
    }
  }

  @override
  Future<Result<FeedStatus?>> feedStatus(String country) => _api
      .select(
        'holiday_feed_status',
        parse: FeedStatus.fromJson,
        build: (q) => q.eq('country', country).limit(1),
      )
      .then((r) => r.map((rows) => rows.firstOrNull));

  @override
  Future<Result<FeedStatus>> refresh(String country) => _api.function(
    'holidays-sync',
    body: {'country': country},
    parse: (json) => FeedStatus.fromJson({
      'country': country,
      ...(json! as Map<String, dynamic>),
    }),
  );

  @override
  Future<Result<List<HolidayCandidate>>> importPreview({
    required String? actor,
    required String schoolId,
    required String region,
    required DateTime from,
    required DateTime to,
  }) => _api.rpc(
    'holiday_import_preview',
    params: {
      'p_actor': actor,
      'p_school_id': schoolId,
      'p_region': region,
      'p_from': _ymd(from),
      'p_to': _ymd(to),
    },
    parse: (json) => [
      for (final row in (json as List? ?? const []))
        HolidayCandidate.fromJson(row as Map<String, dynamic>),
    ],
  );

  @override
  Future<Result<int>> importHolidays({
    required String? actor,
    required String schoolId,
    required List<String> feedIds,
    required String language,
  }) => _api.rpc(
    'holiday_import',
    params: {
      'p_actor': actor,
      'p_school_id': schoolId,
      'p_feed_ids': feedIds,
      'p_lang': language,
    },
    parse: (json) => (json as num).toInt(),
  );
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The rows [SupabaseRegionRepository.regions] asks for per request: PostgREST's default
/// `max_rows`.
const regionPageSize = 1000;

final regionRepositoryProvider = Provider<RegionRepository>(
  (ref) => SupabaseRegionRepository(ref.watch(apiClientProvider)),
);
