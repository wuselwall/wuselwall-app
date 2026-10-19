import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/region/data/region_repository.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';

/// The regions of [country]. A country with no regions is filled first: the server is asked
/// to fetch it (`holidays-sync`), so the first pick works without a setup step, and a
/// failure of that fetch is the provider's error. Regions without a successful fetch on
/// record (an earlier write broke off) are refreshed too, but then a failure keeps what
/// there is.
///
/// Errors show at once: no automatic retries, which kept the picker loading for most of a
/// minute while the server refused again (it waits ten minutes between attempts). The
/// picker has its own retry button.
final countryRegionsProvider = FutureProvider.autoDispose
    .family<List<Region>, String>((ref, country) async {
      final repository = ref.watch(regionRepositoryProvider);
      final status = (await repository.feedStatus(country)).unwrap();
      var regions = (await repository.regions(country)).unwrap();
      if (regions.isEmpty || status?.fetchedAt == null) {
        final refreshed = await repository.refresh(country);
        if (regions.isEmpty) refreshed.unwrap();
        if (refreshed.isOk) {
          regions = (await repository.regions(country)).unwrap();
        }
      }
      return regions;
    }, retry: (_, _) => null);

/// Refreshes the cache of [country] when it is missing or older than [regionCacheMaxAge].
/// A failed refresh is an error only when nothing is cached: stale holidays still import.
Future<void> refreshCountryIfStale(
  RegionRepository repository,
  String country, {
  required DateTime now,
}) async {
  final status = (await repository.feedStatus(country)).unwrap();
  if (status != null && !status.isStale(now)) return;
  final refreshed = await repository.refresh(country);
  if (status == null) refreshed.unwrap();
}
