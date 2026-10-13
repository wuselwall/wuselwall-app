import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';

/// The household's task defaults (specs/21 "Tasks and gamification"), read once when a
/// task editor opens, so a new chore starts with the household's own numbers.
class TaskDefaults {
  const TaskDefaults({
    required this.kind,
    required this.dutyPoints,
    required this.bonusPoints,
    required this.verification,
    required this.rewardRequiresApproval,
  });

  /// The curated defaults of specs/21, used until the settings have loaded.
  const TaskDefaults.curated()
    : kind = TaskKind.duty,
      dutyPoints = 1,
      bonusPoints = 5,
      verification = false,
      rewardRequiresApproval = true;

  factory TaskDefaults.from(List<SettingEntry> entries) {
    int points(String key, int fallback) {
      final v = resolveSetting(entries, key)?.value;
      return v is num ? v.toInt() : fallback;
    }

    return TaskDefaults(
      kind: TaskKind.parse(
        resolveSetting(entries, 'tasks.kind_default')?.value as String?,
      ),
      dutyPoints: points('tasks.points.duty_default', 1),
      bonusPoints: points('tasks.points.bonus_default', 5),
      verification:
          resolveSetting(entries, 'tasks.verification_default')?.value == true,
      rewardRequiresApproval:
          resolveSetting(entries, 'tasks.reward_approval_default')?.value !=
          'self_serve',
    );
  }

  final TaskKind kind;
  final int dutyPoints;
  final int bonusPoints;
  final bool verification;
  final bool rewardRequiresApproval;

  /// The points a new task of [kind] starts with.
  int pointsFor(TaskKind kind) =>
      kind == TaskKind.bonus ? bonusPoints : dutyPoints;
}

/// The household's defaults, or the curated ones while the settings are unavailable.
final taskDefaultsProvider = FutureProvider.autoDispose<TaskDefaults>((
  ref,
) async {
  try {
    final entries = await ref.watch(householdSettingsProvider.future);
    return TaskDefaults.from(entries);
  } on Object {
    return const TaskDefaults.curated();
  }
});
