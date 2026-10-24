import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
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

/// Things waiting for a guardian: chores to check and reward requests; none while
/// either list is still loading.
final pendingApprovalsProvider = Provider.autoDispose<PendingApprovals>(
  (ref) => PendingApprovals.of(
    checks: ref.watch(pendingVerificationsProvider).value ?? const [],
    redemptions: ref.watch(redemptionsProvider).value ?? const [],
  ),
);

/// Drives the badge on the Freigaben tab.
final approvalCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(pendingApprovalsProvider).total,
);

/// [pendingApprovalsProvider] for the acting guardian only (specs/16 step 10.5): the
/// card on Today and the badge on the Tasks destination. Members, and a device with
/// nobody at it, get none and fetch nothing. Derived from the lists of the Freigaben
/// tab, so it clears as soon as a request is decided and needs nothing new from the
/// server.
final guardianApprovalsProvider = Provider.autoDispose<PendingApprovals>((ref) {
  final acting = ref.watch(actingProfileProvider);
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  if (!members.any((m) => m.id == acting && m.isGuardian)) {
    return PendingApprovals.none;
  }
  return ref.watch(pendingApprovalsProvider);
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
