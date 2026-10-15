import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/region/application/region_providers.dart';
import 'package:wuselwall/features/region/data/region_repository.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';

/// How far ahead the import looks: the next 540 days (about 18 months).
const holidayImportWindow = Duration(days: 540);

typedef HolidayImportTarget = ({String schoolId, String region});

/// The school-holiday rows the import offers for [target], from today on. The cache of the
/// region's country is refreshed first when it is missing or stale.
final holidayCandidatesProvider = FutureProvider.autoDispose
    .family<List<HolidayCandidate>, HolidayImportTarget>((ref, target) async {
      final repository = ref.watch(regionRepositoryProvider);
      final now = DateTime.now();
      await refreshCountryIfStale(
        repository,
        target.region.split('-').first,
        now: now,
      );
      final today = DateTime(now.year, now.month, now.day);
      return (await repository.importPreview(
        actor: ref.watch(actingProfileProvider),
        schoolId: target.schoolId,
        region: target.region,
        from: today,
        to: today.add(holidayImportWindow),
      )).unwrap();
    });
