import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/system/domain/health_status.dart';

/// Pattern for every feature repository: translate between Dart models and `api`
/// calls, return [Result]s, hold no business rules.
class SystemRepository {
  const SystemRepository(this._api);

  final ApiClient _api;

  Future<Result<HealthStatus>> health() =>
      _api.rpc('health', parse: HealthStatus.fromJson);
}

final systemRepositoryProvider = Provider<SystemRepository>(
  (ref) => SystemRepository(ref.watch(apiClientProvider)),
);

final healthProvider = FutureProvider.autoDispose<HealthStatus>(
  (ref) async => (await ref.watch(systemRepositoryProvider).health()).unwrap(),
);
