import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// Reads `api.household_export` (GDPR Art. 20): every row the household owns as one JSON
/// document. The server refuses anyone but a guardian on a personal device.
class HouseholdExportRepository {
  const HouseholdExportRepository(this._api);

  final ApiClient _api;

  /// The export as pretty-printed JSON, ready to save. [actor] is the acting profile.
  Future<Result<String>> export({required String? actor}) => _api.rpc(
    'household_export',
    params: {'p_actor': actor},
    parse: (json) => const JsonEncoder.withIndent('  ').convert(json),
  );
}

final householdExportRepositoryProvider = Provider<HouseholdExportRepository>(
  (ref) => HouseholdExportRepository(ref.watch(apiClientProvider)),
);
