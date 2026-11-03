import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_clock.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_english.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';

/// In-memory tasks for the user documentation's screenshots (`lib/main_demo.dart`).
/// The starter chores of specs/21 for the two children, a few ticks already made, the
/// ledger their balances come from, two rewards and one request waiting for their father.
/// Writes change the same state, so the screens behave as on a real device.
class DemoTasksRepository implements TasksRepository {
  DemoTasksRepository({DateTime Function()? clock})
    : _today = _startOfDay((clock ?? DemoClock.now)()) {
    _seed();
  }

  final DateTime _today;

  final _definitions = <TaskDefinition>[];
  final _instances = <TaskInstance>[];
  final _ledger = <PointTransaction>[];
  final _rewards = <Reward>[];
  final _redemptions = <RewardRedemption>[];
  final _streaks = <Streak>[];

  /// The actor of each write, for tests that want to assert who did what.
  final actors = <String?>[];

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _day(int offset) => _today.add(Duration(days: offset));

  void _seed() {
    final daughter = DemoData.daughter;
    final son = DemoData.son;

    final table = TaskDefinition(
      id: 'd-table',
      title: demoText('Tisch decken'),
      kind: TaskKind.duty,
      points: 1,
      startsOn: _day(-30),
      windowDays: 1,
      assignment: TaskAssignment.rotating,
      assigneeIds: [daughter, son],
      requiresVerification: false,
      isActive: true,
      iconKey: 'table',
      rrule: 'FREQ=DAILY',
    );
    final dishes = TaskDefinition(
      id: 'd-dishes',
      title: demoText('Spülmaschine ausräumen'),
      kind: TaskKind.duty,
      points: 1,
      startsOn: _day(-30),
      windowDays: 1,
      assignment: TaskAssignment.rotating,
      assigneeIds: [son, daughter],
      requiresVerification: false,
      isActive: true,
      iconKey: 'dishes',
      rrule: 'FREQ=DAILY',
    );
    final room = TaskDefinition(
      id: 'd-room',
      title: demoText('Zimmer aufräumen'),
      kind: TaskKind.duty,
      points: 2,
      startsOn: _day(-60),
      windowDays: 1,
      assignment: TaskAssignment.each,
      assigneeIds: [daughter, son],
      requiresVerification: true,
      isActive: true,
      iconKey: 'bed',
      rrule: 'FREQ=WEEKLY;BYDAY=SA',
    );
    final trash = TaskDefinition(
      id: 'd-trash',
      title: demoText('Müll rausbringen'),
      kind: TaskKind.bonus,
      points: 5,
      startsOn: _day(-14),
      windowDays: 3,
      assignment: TaskAssignment.open,
      assigneeIds: [],
      requiresVerification: false,
      isActive: true,
      iconKey: 'trash',
      rrule: 'FREQ=WEEKLY;BYDAY=MO',
    );
    final cooking = TaskDefinition(
      id: 'd-cooking',
      title: demoText('Beim Kochen helfen'),
      kind: TaskKind.bonus,
      points: 8,
      startsOn: _day(-14),
      windowDays: 2,
      assignment: TaskAssignment.open,
      assigneeIds: [],
      requiresVerification: false,
      isActive: true,
      iconKey: 'cooking',
      rrule: 'FREQ=WEEKLY;BYDAY=SU',
    );
    _definitions.addAll([table, dishes, room, trash, cooking]);

    TaskInstance instance(
      String id,
      TaskDefinition d, {
      String? assignee,
      InstanceStatus status = InstanceStatus.open,
      int count = 0,
      String? by,
      DateTime? at,
    }) => TaskInstance(
      id: id,
      definitionId: d.id,
      title: d.title,
      kind: d.kind,
      points: d.points,
      iconKey: d.iconKey,
      dueOn: _today,
      opensOn: _today,
      closesOn: _today.add(Duration(days: d.windowDays - 1)),
      assignedProfileId: assignee,
      status: status,
      completionCount: count,
      completedByProfileId: by,
      completedAt: at,
      requiresVerification: d.requiresVerification,
    );

    final now = DemoClock.now();
    _instances.addAll([
      instance(
        'i-table',
        table,
        assignee: daughter,
        status: InstanceStatus.done,
        count: 1,
        by: daughter,
        at: DateTime(now.year, now.month, now.day, 7, 40),
      ),
      instance('i-dishes', dishes, assignee: son),
      instance(
        'i-room-daughter',
        room,
        assignee: daughter,
        status: InstanceStatus.done,
        count: 1,
        by: daughter,
        at: DateTime(now.year, now.month, now.day, 9, 5),
      ),
      instance('i-room-son', room, assignee: son),
      instance('i-trash', trash),
      instance(
        'i-cooking',
        cooking,
        assignee: son,
        status: InstanceStatus.done,
        count: 1,
        by: son,
        at: DateTime(now.year, now.month, now.day, 8, 15),
      ),
    ]);

    _ledger.addAll([
      for (final (i, row) in [
        (daughter, 2, 'task', demoText('Tisch decken')),
        (son, 8, 'task', demoText('Beim Kochen helfen')),
        (daughter, 5, 'task', demoText('Müll rausbringen')),
        (son, 5, 'bonus', demoText('Hilfe beim Einkaufen')),
        (daughter, 2, 'task', demoText('Zimmer aufräumen')),
        (son, 2, 'task', demoText('Zimmer aufräumen')),
        (daughter, 1, 'task', demoText('Spülmaschine')),
        (son, 1, 'task', demoText('Tisch decken')),
        (daughter, 2, 'task', demoText('Tisch decken')),
      ].indexed)
        PointTransaction(
          id: 'pt-$i',
          profileId: row.$1,
          occurredAt: _today
              .subtract(Duration(days: 9 - i))
              .add(const Duration(hours: 18)),
          amount: row.$2,
          reason: LedgerReason.parse(row.$3),
          note: row.$4,
        ),
    ]);
    _ledger.add(
      PointTransaction(
        id: 'pt-adj',
        profileId: son,
        occurredAt: _today.subtract(const Duration(days: 2)),
        amount: 5,
        reason: LedgerReason.adjustment,
        note: demoText('Nachtrag vom Wochenende'),
      ),
    );

    _rewards.addAll([
      Reward(
        id: 'r-movie',
        title: demoText('Samstagsfilm aussuchen'),
        costPoints: 5,
        requiresApproval: true,
        isActive: true,
        iconKey: 'cinema',
      ),
      Reward(
        id: 'r-late',
        title: demoText('15 Minuten länger aufbleiben'),
        costPoints: 15,
        requiresApproval: true,
        isActive: true,
        iconKey: 'moon',
      ),
    ]);
    _redemptions.add(
      _requested(
        id: 'rd-1',
        rewardId: 'r-movie',
        profileId: son,
        cost: 5,
        at: now.subtract(const Duration(hours: 3)),
      ),
    );

    _streaks.addAll([
      const Streak(
        profileId: DemoData.daughter,
        definitionId: 'd-table',
        currentLength: 5,
        longestLength: 9,
      ),
      const Streak(
        profileId: DemoData.son,
        definitionId: 'd-cooking',
        currentLength: 3,
        longestLength: 3,
      ),
    ]);
  }

  int _balanceOf(String profileId) => _ledger
      .where((r) => r.profileId == profileId)
      .fold(0, (sum, r) => sum + r.amount);

  void _credit(
    String profileId,
    int amount,
    LedgerReason reason, {
    String? note,
  }) => _ledger.add(
    PointTransaction(
      id: 'pt-${_ledger.length + 1}',
      profileId: profileId,
      occurredAt: DemoClock.now(),
      amount: amount,
      reason: reason,
      note: note,
    ),
  );

  int _index(String id) => _instances.indexWhere((t) => t.id == id);

  TaskInstance _with(
    TaskInstance t, {
    InstanceStatus? status,
    int? count,
    String? assignee,
    String? by,
    DateTime? at,
  }) => TaskInstance(
    id: t.id,
    definitionId: t.definitionId,
    title: t.title,
    kind: t.kind,
    points: t.points,
    iconKey: t.iconKey,
    dueOn: t.dueOn,
    opensOn: t.opensOn,
    closesOn: t.closesOn,
    assignedProfileId: assignee ?? t.assignedProfileId,
    status: status ?? t.status,
    completionCount: count ?? t.completionCount,
    completedByProfileId: by ?? t.completedByProfileId,
    completedAt: at ?? t.completedAt,
    requiresVerification: t.requiresVerification,
  );

  @override
  Future<Result<List<TaskDefinition>>> definitions() async =>
      Ok(List.of(_definitions));

  @override
  Future<Result<List<TaskInstance>>> instancesOn(DateTime day) async =>
      Ok(List.of(_instances));

  @override
  Future<Result<List<TaskInstance>>> pendingVerifications() async => Ok([
    for (final t in _instances)
      if (t.awaitsApproval) t,
  ]);

  @override
  Future<Result<List<PointBalance>>> balances() async => Ok([
    for (final m in DemoData.members)
      PointBalance(profileId: m.id, balance: _balanceOf(m.id)),
  ]);

  @override
  Future<Result<List<PointTransaction>>> ledger({int limit = 300}) async =>
      Ok(_ledger.reversed.take(limit).toList());

  @override
  Future<Result<List<Reward>>> rewards() async => Ok(List.of(_rewards));

  @override
  Future<Result<List<RewardRedemption>>> redemptions({int limit = 200}) async =>
      Ok(_redemptions.reversed.take(limit).toList());

  @override
  Future<Result<List<Streak>>> streaks() async => Ok(List.of(_streaks));

  @override
  Future<Result<String>> saveDefinition({
    required String? actor,
    required TaskDraft draft,
  }) async {
    actors.add(actor);
    return const Ok('d-new');
  }

  @override
  Future<Result<void>> archiveDefinition({
    required String? actor,
    required String id,
  }) async {
    actors.add(actor);
    _definitions.removeWhere((d) => d.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<String>> createAdhoc({
    required String? actor,
    required Map<String, dynamic> task,
  }) async {
    actors.add(actor);
    return const Ok('i-adhoc');
  }

  @override
  Future<Result<TaskCompletion>> complete({
    required String? actor,
    required String instanceId,
  }) async {
    actors.add(actor);
    final i = _index(instanceId);
    if (i < 0) return const Err(NotFoundFailure(code: 'task_not_open'));
    final t = _instances[i];
    if (t.isTicked) {
      return Ok(TaskCompletion(status: t.status, pointsCredited: 0));
    }
    final count = t.completionCount + 1;
    const status = InstanceStatus.done;
    _instances[i] = _with(
      t,
      status: status,
      count: count,
      assignee: t.assignedProfileId ?? actor,
      by: actor,
      at: DemoClock.now(),
    );
    final credit = t.requiresVerification ? 0 : t.points;
    if (credit > 0) {
      _credit(actor!, credit, LedgerReason.task, note: t.title);
    }
    return Ok(TaskCompletion(status: status, pointsCredited: credit));
  }

  @override
  Future<Result<TaskCompletion>> undo({
    required String? actor,
    required String instanceId,
  }) async {
    actors.add(actor);
    final i = _index(instanceId);
    if (i < 0) return const Err(NotFoundFailure(code: 'task_not_open'));
    final t = _instances[i];
    _instances[i] = _with(t, status: InstanceStatus.open);
    if (!t.requiresVerification && t.points > 0) {
      _credit(actor!, -t.points, LedgerReason.task, note: t.title);
    }
    return const Ok(
      TaskCompletion(status: InstanceStatus.open, pointsCredited: 0),
    );
  }

  @override
  Future<Result<void>> verify({
    required String? actor,
    required String instanceId,
    required bool approve,
  }) async {
    actors.add(actor);
    final i = _index(instanceId);
    if (i < 0) return const Err(NotFoundFailure(code: 'task_not_open'));
    final t = _instances[i];
    if (approve) {
      _instances[i] = _with(t, status: InstanceStatus.verified);
      if (t.points > 0) {
        _credit(
          t.assignedProfileId!,
          t.points,
          LedgerReason.task,
          note: t.title,
        );
      }
    } else {
      _instances[i] = _with(t, status: InstanceStatus.open);
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> skip({
    required String? actor,
    required String instanceId,
  }) async {
    actors.add(actor);
    final i = _index(instanceId);
    if (i >= 0) {
      _instances[i] = _with(_instances[i], status: InstanceStatus.skipped);
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> adjustPoints({
    required String? actor,
    required String profileId,
    required int amount,
    required String note,
  }) async {
    actors.add(actor);
    _credit(profileId, amount, LedgerReason.adjustment, note: note);
    return const Ok(null);
  }

  @override
  Future<Result<String>> saveReward({
    required String? actor,
    required RewardDraft draft,
  }) async {
    actors.add(actor);
    return const Ok('r-new');
  }

  @override
  Future<Result<RedemptionStatus>> requestReward({
    required String? actor,
    required String rewardId,
  }) async {
    actors.add(actor);
    final reward = _rewards.firstWhere((r) => r.id == rewardId);
    _redemptions.add(
      _requested(
        id: 'rd-${_redemptions.length + 1}',
        rewardId: rewardId,
        profileId: actor!,
        cost: reward.costPoints,
        at: DemoClock.now(),
      ),
    );
    return const Ok(RedemptionStatus.requested);
  }

  @override
  Future<Result<void>> decideReward({
    required String? actor,
    required String redemptionId,
    required bool approve,
    String? note,
  }) async {
    actors.add(actor);
    final i = _redemptions.indexWhere((r) => r.id == redemptionId);
    if (i < 0) return const Err(NotFoundFailure(code: 'reward_not_found'));
    final r = _redemptions[i];
    _redemptions[i] = RewardRedemption(
      id: r.id,
      rewardId: r.rewardId,
      profileId: r.profileId,
      costPoints: r.costPoints,
      status: approve ? RedemptionStatus.approved : RedemptionStatus.declined,
      requestedAt: r.requestedAt,
      decidedAt: DemoClock.now(),
      note: note,
    );
    if (approve) _credit(r.profileId, -r.costPoints, LedgerReason.redemption);
    return const Ok(null);
  }

  @override
  Future<Result<void>> fulfilReward({
    required String? actor,
    required String redemptionId,
  }) async {
    actors.add(actor);
    final i = _redemptions.indexWhere((r) => r.id == redemptionId);
    if (i >= 0) {
      final r = _redemptions[i];
      _redemptions[i] = RewardRedemption(
        id: r.id,
        rewardId: r.rewardId,
        profileId: r.profileId,
        costPoints: r.costPoints,
        status: RedemptionStatus.fulfilled,
        requestedAt: r.requestedAt,
        decidedAt: r.decidedAt,
        note: r.note,
      );
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> seedStarter({required String? actor}) async {
    actors.add(actor);
    return const Ok(null);
  }
}

/// A redemption as the household's request for [cost] points, not yet decided.
RewardRedemption _requested({
  required String id,
  required String rewardId,
  required String profileId,
  required int cost,
  required DateTime at,
}) => RewardRedemption(
  id: id,
  rewardId: rewardId,
  profileId: profileId,
  costPoints: cost,
  status: RedemptionStatus.requested,
  requestedAt: at,
);
