import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/school/domain/proposal_models.dart';

/// The proposals an assistant handed the family (specs/24 "Proposals"): read through
/// `api.proposals`, decided through `api.proposal_resolve`. The app never creates one;
/// that is the assistant's one write (`api.mcp_propose`), or a scan's.
class ProposalsRepository {
  const ProposalsRepository(this._api);

  final ApiClient _api;

  /// The open proposals, newest first. Rows of a kind this app does not know are left out.
  Future<Result<List<ProposalRecord>>> open() => _api
      .select(
        'proposals',
        parse: ProposalRecord.fromJson,
        build: (q) =>
            q.eq('status', 'open').order('created_at', ascending: false),
      )
      .then((r) => r.map((rows) => rows.nonNulls.toList(growable: false)));

  /// Records the guardian's verdict: [applied] after the content was written through the
  /// school functions, else rejected.
  Future<Result<void>> resolve({
    required String? actor,
    required String id,
    required bool applied,
  }) => _api.rpc(
    'proposal_resolve',
    params: {
      'p_actor': actor,
      'p_id': id,
      'p_status': applied ? 'applied' : 'rejected',
    },
    parse: (_) {},
  );
}

final proposalsRepositoryProvider = Provider<ProposalsRepository>(
  (ref) => ProposalsRepository(ref.watch(apiClientProvider)),
);
