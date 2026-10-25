import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

/// Every setting of the household with its effective value; refetched when another
/// device changes one (the `settings` topic).
final householdSettingsProvider =
    FutureProvider.autoDispose<List<SettingEntry>>((ref) async {
      ref.watch(deviceKeyProvider);
      final householdId = ref.watch(deviceProvider).value?.householdId;
      if (householdId != null) {
        refreshOnInvalidation(ref, householdId: householdId, topic: 'settings');
      }
      return (await ref.watch(householdSettingsRepositoryProvider).all())
          .unwrap();
    });

/// The effective entry for [key] as seen by [profileId] on [deviceId]: that person's or
/// device's override if one exists, otherwise the household-level row. Null if the key
/// is not in [entries].
SettingEntry? resolveSetting(
  Iterable<SettingEntry> entries,
  String key, {
  String? profileId,
  String? deviceId,
}) {
  SettingEntry? householdRow;
  for (final e in entries) {
    if (e.key != key) continue;
    if (e.profileId == profileId && e.deviceId == deviceId) return e;
    if (e.profileId == null && e.deviceId == null) householdRow = e;
  }
  return householdRow;
}

/// The country the family lives in: the country of `household.region` (`CH` of
/// `CH-ZH`), or null before a family is joined, while the settings load, or without a
/// region. German follows it (specs/09 "Regional German").
final householdCountryProvider = Provider<String?>((ref) {
  if (ref.watch(deviceProvider).value?.householdId == null) return null;
  final settings = ref.watch(householdSettingsProvider).value;
  if (settings == null) return null;
  final region = resolveSetting(settings, 'household.region')?.value;
  if (region is! String || region.isEmpty) return null;
  return region.split('-').first.toUpperCase();
});
