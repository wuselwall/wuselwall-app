import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';

/// Starting a family (H1) and adding its first people (H2). Holds no rules: the `api`
/// functions do. Refusals a person can correct come back as failures with a code:
/// `founder_code_required`, `founder_code_invalid` (validation) and `rate_limited`.
class HouseholdOnboardingRepository {
  const HouseholdOnboardingRepository(this._api, this._auth);

  final ApiClient _api;
  final GoTrueClient _auth;

  Future<Result<Account>> account() => _api.rpc(
    'my_account',
    parse: (json) => Account.fromJson(json! as Map<String, dynamic>),
  );

  /// Creates the household, this session as the founder's personal device, and refreshes
  /// the session so its token carries the device claims.
  Future<Result<void>> create({
    required String householdName,
    required String displayName,
    required String colorHex,
    required String timezone,
    required String locale,
    required String? founderCode,
    required bool seedExamples,
    required String deviceLabel,
  }) async {
    final created = await _api.rpc<void>(
      'household_create',
      params: {
        'p_name': householdName.trim(),
        'p_display_name': displayName.trim(),
        'p_color': colorHex,
        'p_timezone': timezone,
        'p_locale': locale,
        'p_founder_code': founderCode?.trim(),
        'p_seed_examples': seedExamples,
        'p_device_label': deviceLabel.trim(),
      },
      parse: (json) {
        final map = json! as Map<String, dynamic>;
        if (map['ok'] != true) {
          throw switch (map['reason']) {
            'rate_limited' => const PermissionFailure(code: 'rate_limited'),
            'founder_code_invalid' => const ValidationFailure(
              code: 'founder_code_invalid',
            ),
            _ => const ValidationFailure(code: 'founder_code_required'),
          };
        }
      },
    );
    if (created is Err<void>) return created;
    final refreshed = await Result.guard(_auth.refreshSession);
    return refreshed.map((_) {});
  }

  /// H2's rows, as the guardian's household members.
  Future<Result<void>> addMembers(List<NewMember> members) => _api.rpc(
    'household_add_members',
    params: {
      'p_actor': null,
      'p_members': [for (final m in members) m.toJson()],
    },
    parse: (_) {},
  );

  /// The examples' chores that need children; idempotent, so it only adds what is missing.
  Future<Result<void>> completeExamples() =>
      _api.rpc('tasks_seed_starter', params: {'p_actor': null}, parse: (_) {});
}

final householdOnboardingRepositoryProvider =
    Provider<HouseholdOnboardingRepository>(
      (ref) => HouseholdOnboardingRepository(
        ref.watch(apiClientProvider),
        ref.watch(supabaseClientProvider).auth,
      ),
    );
