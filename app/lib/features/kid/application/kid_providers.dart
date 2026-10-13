import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';
import 'package:wuselwall/features/kid/data/kid_badges_repository.dart';

/// The five destinations of the kid register (specs/09 "Screens by register").
enum KidTab {
  today,
  school,
  points,
  shopping,
  family;

  /// Whose things these tabs show. Shopping and family are for everyone, so they open
  /// without an acting child.
  bool get needsPerson => this != shopping && this != family;
}

class KidTabNotifier extends Notifier<KidTab> {
  @override
  KidTab build() => KidTab.today;

  void select(KidTab tab) => state = tab;
}

final kidTabProvider = NotifierProvider<KidTabNotifier, KidTab>(
  KidTabNotifier.new,
);

/// Today at local midnight. Changes only when the day does, so watching it does not
/// rebuild every second.
final kidTodayProvider = Provider<DateTime>(
  (ref) => ref.watch(nowProvider.select(kidDayOf)),
);

/// Minutes since midnight, changing once a minute: drives the "current lesson".
final kidMinutesProvider = Provider<int>(
  (ref) => ref.watch(nowProvider.select((now) => now.hour * 60 + now.minute)),
);

/// A child's badges (earned and unearned). Refetched on the `tasks` topic, with the
/// rest of the chores.
final kidBadgesProvider = FutureProvider.autoDispose
    .family<List<KidBadge>, String>((ref, profileId) async {
      ref.watch(deviceKeyProvider);
      final householdId = ref.watch(deviceProvider).value?.householdId;
      if (householdId != null) {
        refreshOnInvalidation(ref, householdId: householdId, topic: 'tasks');
      }
      return (await ref.watch(kidBadgesRepositoryProvider).badges(profileId))
          .unwrap();
    });
