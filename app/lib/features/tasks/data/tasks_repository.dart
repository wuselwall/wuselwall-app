import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';

/// Reads the `api` views and writes through the `api` functions of the tasks module
/// (specs/06). Every write names the acting profile, which the server checks against
/// the device. The UI never sees a table.
class TasksRepository {
  const TasksRepository(this._api);

  final ApiClient _api;

  /// Active task definitions, by title.
  Future<Result<List<TaskDefinition>>> definitions() => _api.select(
    'task_definitions',
    parse: TaskDefinition.fromJson,
    build: (q) => q.eq('is_active', true).order('title'),
  );

  /// The instances that matter on [day]: due that day, or still open in their window.
  /// Skipped and expired ones are left out; done ones stay, so the board can strike them.
  Future<Result<List<TaskInstance>>> instancesOn(DateTime day) {
    final d = taskIsoDate(day);
    return _api.select(
      'task_instances',
      parse: TaskInstance.fromJson,
      build: (q) => q
          .inFilter('status', ['open', 'done', 'verified'])
          .or(
            'due_on.eq.$d,and(status.eq.open,opens_on.lte.$d,closes_on.gte.$d)',
          )
          .order('due_on')
          .order('title'),
    );
  }

  /// Ticked chores that wait for a guardian (`requires_verification`).
  Future<Result<List<TaskInstance>>> pendingVerifications() => _api.select(
    'task_instances',
    parse: TaskInstance.fromJson,
    build: (q) => q
        .eq('status', 'done')
        .eq('requires_verification', true)
        .order('completed_at'),
  );

  Future<Result<List<PointBalance>>> balances() =>
      _api.select('point_balances', parse: PointBalance.fromJson);

  /// The newest ledger rows of the household, up to [limit].
  Future<Result<List<PointTransaction>>> ledger({int limit = 300}) =>
      _api.select(
        'point_transactions',
        parse: PointTransaction.fromJson,
        build: (q) => q.order('occurred_at', ascending: false).limit(limit),
      );

  Future<Result<List<Reward>>> rewards() => _api.select(
    'rewards',
    parse: Reward.fromJson,
    build: (q) => q.eq('is_active', true).order('cost_points'),
  );

  Future<Result<List<RewardRedemption>>> redemptions({int limit = 200}) =>
      _api.select(
        'reward_redemptions',
        parse: RewardRedemption.fromJson,
        build: (q) => q.order('requested_at', ascending: false).limit(limit),
      );

  Future<Result<List<Streak>>> streaks() =>
      _api.select('streaks', parse: Streak.fromJson);

  /// Creates or changes a definition. A recurring one then gets its next instances
  /// from the `tasks-materialise` function (specs/06, the materialiser).
  Future<Result<String>> saveDefinition({
    required String? actor,
    required TaskDraft draft,
  }) async {
    final saved = await _api.rpc(
      'task_definition_save',
      params: {'p_actor': actor, 'p_def': draft.toJson()},
      parse: (json) => (json! as Map<String, dynamic>)['id'] as String,
    );
    if (saved case Err()) return saved;
    if (draft.rrule != null) {
      final materialised = await _api.function(
        'tasks-materialise',
        body: const {},
        parse: (_) {},
      );
      if (materialised case Err(:final failure)) return Err(failure);
    }
    return saved;
  }

  Future<Result<void>> archiveDefinition({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'task_definition_archive',
    params: {'p_actor': actor, 'p_id': id},
    parse: (_) {},
  );

  /// A one-off task, not tied to a definition.
  Future<Result<String>> createAdhoc({
    required String? actor,
    required Map<String, dynamic> task,
  }) => _api.rpc(
    'task_create_adhoc',
    params: {'p_actor': actor, 'p_task': task},
    parse: (json) => (json! as Map<String, dynamic>)['id'] as String,
  );

  /// The acting profile ticks [instanceId]. The server credits points (or waits for
  /// a guardian) and advances the streak.
  Future<Result<TaskCompletion>> complete({
    required String? actor,
    required String instanceId,
  }) => _api.rpc(
    'task_complete',
    params: {'p_actor': actor, 'p_instance_id': instanceId},
    parse: (json) => TaskCompletion.fromJson(json! as Map<String, dynamic>),
  );

  /// Takes back a tick made today by the same person (specs/06).
  Future<Result<TaskCompletion>> undo({
    required String? actor,
    required String instanceId,
  }) => _api.rpc(
    'task_undo',
    params: {'p_actor': actor, 'p_instance_id': instanceId},
    parse: (json) => TaskCompletion.fromJson(json! as Map<String, dynamic>),
  );

  /// A guardian's verdict on a verification-required tick.
  Future<Result<void>> verify({
    required String? actor,
    required String instanceId,
    required bool approve,
  }) => _api.rpc(
    'task_verify',
    params: {
      'p_actor': actor,
      'p_instance_id': instanceId,
      'p_approve': approve,
    },
    parse: (_) {},
  );

  Future<Result<void>> skip({
    required String? actor,
    required String instanceId,
  }) => _api.rpc(
    'task_skip',
    params: {'p_actor': actor, 'p_instance_id': instanceId},
    parse: (_) {},
  );

  /// A guardian's correction. [note] is required: corrections are never invisible.
  Future<Result<void>> adjustPoints({
    required String? actor,
    required String profileId,
    required int amount,
    required String note,
  }) => _api.rpc(
    'points_adjust',
    params: {
      'p_actor': actor,
      'p_profile_id': profileId,
      'p_amount': amount,
      'p_note': note,
    },
    parse: (_) {},
  );

  Future<Result<String>> saveReward({
    required String? actor,
    required RewardDraft draft,
  }) => _api.rpc(
    'reward_save',
    params: {'p_actor': actor, 'p_reward': draft.toJson()},
    parse: (json) => (json! as Map<String, dynamic>)['id'] as String,
  );

  /// Asks for a reward. Approved at once when the reward needs no approval and the
  /// balance covers it; otherwise it waits for a guardian.
  Future<Result<RedemptionStatus>> requestReward({
    required String? actor,
    required String rewardId,
  }) => _api.rpc(
    'reward_request',
    params: {'p_actor': actor, 'p_reward_id': rewardId},
    parse: (json) => RedemptionStatus.parse(
      (json! as Map<String, dynamic>)['status'] as String?,
    ),
  );

  Future<Result<void>> decideReward({
    required String? actor,
    required String redemptionId,
    required bool approve,
    String? note,
  }) => _api.rpc(
    'reward_decide',
    params: {
      'p_actor': actor,
      'p_redemption_id': redemptionId,
      'p_approve': approve,
      'p_note': note,
    },
    parse: (_) {},
  );

  Future<Result<void>> fulfilReward({
    required String? actor,
    required String redemptionId,
  }) => _api.rpc(
    'reward_fulfil',
    params: {'p_actor': actor, 'p_redemption_id': redemptionId},
    parse: (_) {},
  );

  /// Adds the starter chores, rewards and badges (specs/21). Idempotent on the server.
  Future<Result<void>> seedStarter({required String? actor}) =>
      _api.rpc('tasks_seed_starter', params: {'p_actor': actor}, parse: (_) {});
}

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(ref.watch(apiClientProvider)),
);
