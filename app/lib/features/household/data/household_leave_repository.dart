import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// Leaving a family, deleting it, and what a deleted family offers (specs/20 J6). Holds no
/// rules: the `api` functions do. Leaving and restoring end with a session refresh, so the
/// token carries (or drops) the household claims at once.
class HouseholdLeaveRepository {
  const HouseholdLeaveRepository(this._api, this._auth);

  final ApiClient _api;
  final GoTrueClient _auth;

  /// Leaves the family on this phone; the account stays and can start or join another.
  Future<Result<void>> leaveFamily({required String profileId}) async {
    final left = await _api.rpc<void>(
      'account_leave',
      params: {'p_actor': profileId},
      parse: (_) {},
    );
    if (left is Err<void>) return left;
    return _refresh();
  }

  /// Deletes the family at once and for good: every device signs out, and all its data is
  /// removed. The caller signs out locally afterwards.
  Future<Result<void>> deleteFamily({
    required String profileId,
    required String confirmName,
  }) => _api.rpc(
    'household_delete',
    params: {'p_actor': profileId, 'p_confirm_name': confirmName},
    parse: (_) {},
  );

  /// Brings back a family deleted before deletion was immediate (it kept 14 days), with this
  /// phone as its personal device.
  Future<Result<void>> restoreFamily() async {
    final restored = await _api.rpc<void>('household_restore', parse: (_) {});
    if (restored is Err<void>) return restored;
    return _refresh();
  }

  /// Unlinks this account from its deleted family, to start a new one.
  Future<Result<void>> startAfresh() async {
    final left = await _api.rpc<void>('account_leave_deleted', parse: (_) {});
    if (left is Err<void>) return left;
    return _refresh();
  }

  Future<Result<void>> _refresh() async {
    final refreshed = await Result.guard(_auth.refreshSession);
    return refreshed.map((_) {});
  }
}

final householdLeaveRepositoryProvider = Provider<HouseholdLeaveRepository>(
  (ref) => HouseholdLeaveRepository(
    ref.watch(apiClientProvider),
    ref.watch(supabaseClientProvider).auth,
  ),
);
