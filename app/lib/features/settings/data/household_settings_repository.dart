import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

/// Reads `api.settings`; writes through `api.set_setting` and `api.reset_setting`.
/// [actor] is the acting profile (null on a device with nobody at it); the server checks
/// the target and the guardian rules (specs/21, "Model").
class HouseholdSettingsRepository {
  const HouseholdSettingsRepository(this._api);

  final ApiClient _api;

  Future<Result<List<SettingEntry>>> all() => _api.select(
    'settings',
    parse: SettingEntry.fromJson,
    build: (q) => q.order('key'),
  );

  /// [value] is the JSON encoding of the setting type (see the migration's header).
  Future<Result<void>> set({
    required String? actor,
    required String key,
    required Object? value,
    String? profileId,
    String? deviceId,
  }) => _api.rpc(
    'set_setting',
    params: {
      'p_actor': actor,
      'p_key': key,
      'p_value': value,
      'p_profile_id': profileId,
      'p_device_id': deviceId,
    },
    parse: (_) {},
  );

  Future<Result<void>> reset({
    required String? actor,
    required String key,
    String? profileId,
    String? deviceId,
  }) => _api.rpc(
    'reset_setting',
    params: {
      'p_actor': actor,
      'p_key': key,
      'p_profile_id': profileId,
      'p_device_id': deviceId,
    },
    parse: (_) {},
  );
}

final householdSettingsRepositoryProvider =
    Provider<HouseholdSettingsRepository>(
      (ref) => HouseholdSettingsRepository(ref.watch(apiClientProvider)),
    );
