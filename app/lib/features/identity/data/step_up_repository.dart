import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// The end of a PIN step-up (specs/08 "Guardian PIN step-up"). The server keeps the
/// window on the device row; this call closes it early, so that on a shared tablet or
/// the wall the next person who taps a guardian's avatar is asked for the PIN again.
class StepUpRepository {
  const StepUpRepository(this._api);

  final ApiClient _api;

  /// Clears the window of this device, whoever opened it. No acting profile: the wall
  /// calls it when it reverts to nobody.
  Future<Result<void>> stepDown() =>
      _api.rpc('guardian_step_down', parse: (_) {});
}

final stepUpRepositoryProvider = Provider<StepUpRepository>(
  (ref) => StepUpRepository(ref.watch(apiClientProvider)),
);
