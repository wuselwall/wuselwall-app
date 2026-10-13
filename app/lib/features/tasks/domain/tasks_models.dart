/// The tasks & gamification read models (specs/06, specs/04 "Tasks & gamification").
/// Rows come from the `api` views; points are never stored as a balance, so every
/// balance is the sum of its ledger rows (see [PointTransaction]).
library;

enum TaskKind {
  duty,
  bonus;

  static TaskKind parse(String? v) => v == 'bonus' ? bonus : duty;
}

enum TaskAssignment {
  fixed,
  rotating,
  open,
  each;

  static TaskAssignment parse(String? v) => switch (v) {
    'rotating' => rotating,
    'open' => open,
    'each' => each,
    _ => fixed,
  };
}

enum InstanceStatus {
  open,
  done,
  verified,
  skipped,
  expired;

  static InstanceStatus parse(String? v) => switch (v) {
    'done' => done,
    'verified' => verified,
    'skipped' => skipped,
    'expired' => expired,
    _ => open,
  };
}

enum RedemptionStatus {
  requested,
  approved,
  declined,
  fulfilled;

  static RedemptionStatus parse(String? v) => switch (v) {
    'approved' => approved,
    'declined' => declined,
    'fulfilled' => fulfilled,
    _ => requested,
  };
}

enum LedgerReason {
  task,
  redemption,
  adjustment,
  badge,
  bonus;

  static LedgerReason parse(String? v) => switch (v) {
    'redemption' => redemption,
    'adjustment' => adjustment,
    'badge' => badge,
    'bonus' => bonus,
    _ => task,
  };
}

/// Calendar dates arrive as `YYYY-MM-DD`; parsed as local midnight.
DateTime taskDate(String v) => DateTime.parse(v);

String taskIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime taskDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Icon keys are stable names; the app shows the emoji from [taskIcons]. Keeping the
/// key, not the glyph, in the database lets a later design change the picture.
const taskIcons = <String, String>{
  'dishes': '🍽️',
  'table': '🥄',
  'trash': '🗑️',
  'bed': '🛏️',
  'dog': '🐕',
  'plant': '🌱',
  'bike': '🚲',
  'book': '📚',
  'laundry': '🧺',
  'teeth': '🪥',
  'shopping': '🛒',
  'cooking': '🍳',
  'car': '🚗',
  'toys': '🧸',
  'star': '⭐',
  'cinema': '🎬',
  'moon': '🌙',
  'trip': '🧭',
};

String? taskIconGlyph(String? key) => key == null ? null : taskIcons[key];

class TaskDefinition {
  const TaskDefinition({
    required this.id,
    required this.title,
    required this.kind,
    required this.points,
    required this.startsOn,
    required this.windowDays,
    required this.assignment,
    required this.assigneeIds,
    required this.requiresVerification,
    required this.isActive,
    this.iconKey,
    this.rrule,
  });

  factory TaskDefinition.fromJson(Map<String, dynamic> json) => TaskDefinition(
    id: json['id'] as String,
    title: json['title'] as String,
    kind: TaskKind.parse(json['kind'] as String?),
    points: (json['points'] as num?)?.toInt() ?? 0,
    startsOn: taskDate(json['starts_on'] as String),
    windowDays: (json['window_days'] as num?)?.toInt() ?? 1,
    assignment: TaskAssignment.parse(json['assignment'] as String?),
    assigneeIds: [
      for (final id in (json['assignee_profile_ids'] as List?) ?? const [])
        id as String,
    ],
    requiresVerification: json['requires_verification'] as bool? ?? false,
    isActive: json['is_active'] as bool? ?? true,
    iconKey: json['icon_key'] as String?,
    rrule: json['rrule'] as String?,
  );

  final String id;
  final String title;
  final TaskKind kind;
  final int points;
  final DateTime startsOn;
  final int windowDays;
  final TaskAssignment assignment;
  final List<String> assigneeIds;
  final bool requiresVerification;
  final bool isActive;
  final String? iconKey;

  /// Null for a one-off task.
  final String? rrule;

  bool get recurs => rrule != null;
}

/// One concrete occurrence. Snapshots title, points and kind when it was created.
class TaskInstance {
  const TaskInstance({
    required this.id,
    required this.title,
    required this.kind,
    required this.points,
    required this.dueOn,
    required this.opensOn,
    required this.closesOn,
    required this.status,
    required this.completionCount,
    required this.requiresVerification,
    this.definitionId,
    this.iconKey,
    this.assignedProfileId,
    this.completedByProfileId,
    this.completedAt,
  });

  factory TaskInstance.fromJson(Map<String, dynamic> json) => TaskInstance(
    id: json['id'] as String,
    definitionId: json['definition_id'] as String?,
    title: json['title'] as String,
    kind: TaskKind.parse(json['kind'] as String?),
    points: (json['points'] as num?)?.toInt() ?? 0,
    iconKey: json['icon_key'] as String?,
    dueOn: taskDate(json['due_on'] as String),
    opensOn: taskDate(json['opens_on'] as String),
    closesOn: taskDate(json['closes_on'] as String),
    assignedProfileId: json['assigned_profile_id'] as String?,
    status: InstanceStatus.parse(json['status'] as String?),
    completionCount: (json['completion_count'] as num?)?.toInt() ?? 0,
    completedByProfileId: json['completed_by_profile_id'] as String?,
    completedAt: json['completed_at'] == null
        ? null
        : DateTime.parse(json['completed_at'] as String),
    requiresVerification: json['requires_verification'] as bool? ?? false,
  );

  final String id;
  final String? definitionId;
  final String title;
  final TaskKind kind;
  final int points;
  final String? iconKey;
  final DateTime dueOn;
  final DateTime opensOn;
  final DateTime closesOn;
  final String? assignedProfileId;
  final InstanceStatus status;
  final int completionCount;
  final String? completedByProfileId;
  final DateTime? completedAt;
  final bool requiresVerification;

  /// Ticked by someone; a verification-required task waits for a guardian after that.
  bool get isTicked =>
      status == InstanceStatus.done || status == InstanceStatus.verified;

  /// Waiting for a guardian to check the work.
  bool get awaitsApproval =>
      requiresVerification && status == InstanceStatus.done;

  bool get isOpen => status == InstanceStatus.open;

  /// Open today: the window that started on or before [day] has not closed.
  bool isWindowOpen(DateTime day) =>
      !opensOn.isAfter(day) && !closesOn.isBefore(day);
}

class PointBalance {
  const PointBalance({required this.profileId, required this.balance});

  factory PointBalance.fromJson(Map<String, dynamic> json) => PointBalance(
    profileId: json['profile_id'] as String,
    balance: (json['balance'] as num?)?.toInt() ?? 0,
  );

  final String profileId;
  final int balance;
}

class PointTransaction {
  const PointTransaction({
    required this.id,
    required this.profileId,
    required this.occurredAt,
    required this.amount,
    required this.reason,
    this.sourceType,
    this.note,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) =>
      PointTransaction(
        id: json['id'] as String,
        profileId: json['profile_id'] as String,
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        amount: (json['amount'] as num).toInt(),
        reason: LedgerReason.parse(json['reason'] as String?),
        sourceType: json['source_type'] as String?,
        note: json['note'] as String?,
      );

  final String id;
  final String profileId;
  final DateTime occurredAt;
  final int amount;
  final LedgerReason reason;

  /// `task`, `task_undo`, `redemption`, … : tells a taken-back tick from a finished one.
  final String? sourceType;
  final String? note;
}

class Reward {
  const Reward({
    required this.id,
    required this.title,
    required this.costPoints,
    required this.requiresApproval,
    required this.isActive,
    this.description,
    this.iconKey,
    this.stock,
  });

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    iconKey: json['icon_key'] as String?,
    costPoints: (json['cost_points'] as num).toInt(),
    stock: (json['stock'] as num?)?.toInt(),
    requiresApproval: json['requires_approval'] as bool? ?? true,
    isActive: json['is_active'] as bool? ?? true,
  );

  final String id;
  final String title;
  final String? description;
  final String? iconKey;
  final int costPoints;

  /// Null: unlimited.
  final int? stock;
  final bool requiresApproval;
  final bool isActive;

  bool get soldOut => stock != null && stock! <= 0;
}

class RewardRedemption {
  const RewardRedemption({
    required this.id,
    required this.rewardId,
    required this.profileId,
    required this.costPoints,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.note,
  });

  factory RewardRedemption.fromJson(Map<String, dynamic> json) =>
      RewardRedemption(
        id: json['id'] as String,
        rewardId: json['reward_id'] as String,
        profileId: json['profile_id'] as String,
        costPoints: (json['cost_points'] as num).toInt(),
        status: RedemptionStatus.parse(json['status'] as String?),
        requestedAt: DateTime.parse(json['requested_at'] as String),
        decidedAt: json['decided_at'] == null
            ? null
            : DateTime.parse(json['decided_at'] as String),
        note: json['note'] as String?,
      );

  final String id;
  final String rewardId;
  final String profileId;
  final int costPoints;
  final RedemptionStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;
  final String? note;
}

/// The run of a (profile, definition) pair. Shown as "you're on 12", never compared.
class Streak {
  const Streak({
    required this.profileId,
    required this.definitionId,
    required this.currentLength,
    required this.longestLength,
  });

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
    profileId: json['profile_id'] as String,
    definitionId: json['definition_id'] as String,
    currentLength: (json['current_length'] as num?)?.toInt() ?? 0,
    longestLength: (json['longest_length'] as num?)?.toInt() ?? 0,
  );

  final String profileId;
  final String definitionId;
  final int currentLength;
  final int longestLength;
}

/// Result of ticking or unticking a task (`api.task_complete` / `api.task_undo`).
class TaskCompletion {
  const TaskCompletion({required this.status, required this.pointsCredited});

  factory TaskCompletion.fromJson(Map<String, dynamic> json) => TaskCompletion(
    status: InstanceStatus.parse(json['status'] as String?),
    pointsCredited: (json['points_credited'] as num?)?.toInt() ?? 0,
  );

  final InstanceStatus status;
  final int pointsCredited;
}

/// The repeat choices the editor offers. They map onto the RRULE subset of
/// specs/21 ([taskRrule]); a stored rule outside it is read as the nearest choice.
enum TaskRepeat { once, daily, weekdays, weekly, biweekly, monthly }

const _byDayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// The RRULE for [repeat]. [weekdays] are ISO weekdays (1 = Monday); [startDay] is the
/// day of month for a monthly chore. Null for a one-off.
String? taskRrule(
  TaskRepeat repeat, {
  required Set<int> weekdays,
  required int startDay,
}) {
  String byDay(Set<int> days) {
    final codes = [for (final d in days.toList()..sort()) _byDayCodes[d - 1]];
    return 'BYDAY=${codes.join(',')}';
  }

  return switch (repeat) {
    TaskRepeat.once => null,
    TaskRepeat.daily => 'FREQ=DAILY',
    TaskRepeat.weekdays => 'FREQ=WEEKLY;${byDay(weekdays)}',
    TaskRepeat.weekly => 'FREQ=WEEKLY;${byDay(weekdays)}',
    TaskRepeat.biweekly => 'FREQ=WEEKLY;INTERVAL=2;${byDay(weekdays)}',
    TaskRepeat.monthly => 'FREQ=MONTHLY;BYMONTHDAY=$startDay',
  };
}

/// Reads a stored RRULE back into the editor's choice and weekdays.
({TaskRepeat repeat, Set<int> weekdays}) taskRepeatOf(String? rrule) {
  if (rrule == null) return (repeat: TaskRepeat.once, weekdays: const {});
  final parts = {
    for (final p in rrule.split(';'))
      if (p.contains('=')) p.split('=').first: p.split('=').last,
  };
  final days = {
    for (final code in (parts['BYDAY'] ?? '').split(','))
      if (_byDayCodes.contains(code)) _byDayCodes.indexOf(code) + 1,
  };
  final weekdays = days.isEmpty ? <int>{} : days;
  return switch (parts['FREQ']) {
    'DAILY' => (repeat: TaskRepeat.daily, weekdays: weekdays),
    'MONTHLY' => (repeat: TaskRepeat.monthly, weekdays: weekdays),
    _ when parts['INTERVAL'] == '2' => (
      repeat: TaskRepeat.biweekly,
      weekdays: weekdays,
    ),
    _ when weekdays.length > 1 => (
      repeat: TaskRepeat.weekdays,
      weekdays: weekdays,
    ),
    _ => (repeat: TaskRepeat.weekly, weekdays: weekdays),
  };
}

/// What the editor sends to `api.task_definition_save`. Absent keys take the household
/// defaults on the server, but the editor always sends every field it shows.
class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.kind,
    required this.points,
    required this.rrule,
    required this.startsOn,
    required this.windowDays,
    required this.assignment,
    required this.assigneeIds,
    required this.requiresVerification,
    this.id,
    this.iconKey,
    this.isActive = true,
  });

  final String? id;
  final String title;
  final String? iconKey;
  final TaskKind kind;
  final int points;
  final String? rrule;
  final DateTime startsOn;
  final int windowDays;
  final TaskAssignment assignment;
  final List<String> assigneeIds;
  final bool requiresVerification;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': title,
    'icon_key': iconKey,
    'kind': kind.name,
    'points': points,
    'rrule': rrule,
    'starts_on': taskIsoDate(startsOn),
    'window_days': windowDays,
    'assignment': assignment.name,
    'assignee_profile_ids': assigneeIds,
    'requires_verification': requiresVerification,
    'is_active': isActive,
  };
}

/// What the editor sends to `api.reward_save`.
class RewardDraft {
  const RewardDraft({
    required this.title,
    required this.costPoints,
    required this.requiresApproval,
    this.id,
    this.iconKey,
    this.stock,
    this.isActive = true,
  });

  final String? id;
  final String title;
  final String? iconKey;
  final int costPoints;
  final int? stock;
  final bool requiresApproval;
  final bool isActive;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': title,
    'icon_key': iconKey,
    'cost_points': costPoints,
    'stock': stock,
    'requires_approval': requiresApproval,
    'is_active': isActive,
  };
}
