import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/region/data/region_repository.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';

/// The regions of [country]. A country with no cached status or no regions is filled first:
/// the server is asked to fetch it (`holidays-sync`), so the first pick works without a
/// setup step. A failure of that fetch is the provider's error.
final countryRegionsProvider = FutureProvider.autoDispose
    .family<List<Region>, String>((ref, country) async {
      final repository = ref.watch(regionRepositoryProvider);
      final status = (await repository.feedStatus(country)).unwrap();
      var regions = (await repository.regions(country)).unwrap();
      if (status == null || regions.isEmpty) {
        await repository.refresh(country).then((r) => r.unwrap());
        regions = (await repository.regions(country)).unwrap();
      }
      return regions;
    });

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
