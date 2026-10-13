import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';

/// Every tasks provider refetches when the household's `tasks` topic is invalidated.
/// The payload carries no data, so a stale message can only cause a refetch.
void _watchTasksTopic(Ref ref) {
  ref.watch(deviceKeyProvider);
  final householdId = ref.watch(deviceProvider).value?.householdId;
  if (householdId != null) {
    refreshOnInvalidation(ref, householdId: householdId, topic: 'tasks');
  }
}

/// Today's instances (see [TasksRepository.instancesOn]), in the device's date.
final tasksTodayProvider = FutureProvider.autoDispose<List<TaskInstance>>((
  ref,
) async {
  _watchTasksTopic(ref);
  final now = DateTime.now();
  return (await ref
          .watch(tasksRepositoryProvider)
          .instancesOn(DateTime(now.year, now.month, now.day)))
      .unwrap();
});

final taskDefinitionsProvider =
    FutureProvider.autoDispose<List<TaskDefinition>>((ref) async {
      _watchTasksTopic(ref);
      return (await ref.watch(tasksRepositoryProvider).definitions()).unwrap();
    });

final pendingVerificationsProvider =
    FutureProvider.autoDispose<List<TaskInstance>>((ref) async {
      _watchTasksTopic(ref);
      return (await ref.watch(tasksRepositoryProvider).pendingVerifications())
          .unwrap();
    });

/// Each member's balance as a map from profile id; members without rows have none.
final pointBalancesProvider = FutureProvider.autoDispose<Map<String, int>>((
  ref,
) async {
  _watchTasksTopic(ref);
  final rows = (await ref.watch(tasksRepositoryProvider).balances()).unwrap();
  return {for (final r in rows) r.profileId: r.balance};
});

final pointLedgerProvider = FutureProvider.autoDispose<List<PointTransaction>>((
  ref,
) async {
  _watchTasksTopic(ref);
  return (await ref.watch(tasksRepositoryProvider).ledger()).unwrap();
});

final rewardsProvider = FutureProvider.autoDispose<List<Reward>>((ref) async {
  _watchTasksTopic(ref);
  return (await ref.watch(tasksRepositoryProvider).rewards()).unwrap();
});

final redemptionsProvider = FutureProvider.autoDispose<List<RewardRedemption>>((
  ref,
) async {
  _watchTasksTopic(ref);
  return (await ref.watch(tasksRepositoryProvider).redemptions()).unwrap();
});

final streaksProvider = FutureProvider.autoDispose<List<Streak>>((ref) async {
  _watchTasksTopic(ref);
  return (await ref.watch(tasksRepositoryProvider).streaks()).unwrap();
});

/// Things waiting for a guardian: chores to check and reward requests. Drives the badge
/// on the Freigaben tab; zero while either list is still loading.
final approvalCountProvider = Provider.autoDispose<int>((ref) {
  final checks = ref.watch(pendingVerificationsProvider).value?.length ?? 0;
  final requests =
      (ref.watch(redemptionsProvider).value ?? const <RewardRedemption>[])
          .where((r) => r.status == RedemptionStatus.requested)
          .length;
  return checks + requests;
});

/// Drops every tasks provider so the screen refetches after one of its own writes, not
/// only after the Realtime echo. Pass `ref.invalidate` from a widget or a provider.
void invalidateTasks(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(tasksTodayProvider);
  invalidate(taskDefinitionsProvider);
  invalidate(pendingVerificationsProvider);
  invalidate(pointBalancesProvider);
  invalidate(pointLedgerProvider);
  invalidate(rewardsProvider);
  invalidate(redemptionsProvider);
  invalidate(streaksProvider);
}
