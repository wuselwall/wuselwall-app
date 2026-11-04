import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';
import 'package:wuselwall/features/kid/data/kid_badges_repository.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';

/// The destinations of the kid register (specs/09 "Screens by register"); which of them a
/// family has says [kidTabsProvider].
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

/// The tabs this family's children see: Shopping only when a guardian switched it on
/// (`household.kid_shopping`). A server older than the switch has no row and keeps the tab;
/// so does a device that cannot read the settings, as a child only adds and ticks there.
/// While they load the tab waits, so a family without it never sees it come and go.
final kidTabsProvider = Provider<List<KidTab>>((ref) {
  final settings = ref.watch(householdSettingsProvider);
  final entries = settings.value;
  final shopping = entries == null
      ? settings.hasError
      : switch (resolveSetting(entries, 'household.kid_shopping')) {
          null => true,
          final entry => entry.value == true,
        };
  return [
    for (final tab in KidTab.values)
      if (tab != KidTab.shopping || shopping) tab,
  ];
});

class KidTabNotifier extends Notifier<KidTab> {
  @override
  KidTab build() => KidTab.today;

  bool _cameBack = false;

  void select(KidTab tab) {
    // Back on "Mein Tag" from another tab: Wusel hops in (specs/25 "Wusel on the
    // move"), but not on the first open, where it waves.
    if (tab == KidTab.today && state != KidTab.today) _cameBack = true;
    state = tab;
  }

  /// Whether "Mein Tag" was just chosen from another tab; asking answers once.
  bool takeCameBack() {
    final back = _cameBack;
    _cameBack = false;
    return back;
  }
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

/// The child's badge earned in the last two days, newest first; null for none. A badge
/// usually arrives with the nightly job, so "new" lasts long enough to be seen the next
/// day (specs/25: Wusel is proud of it).
final kidNewBadgeProvider = Provider.autoDispose.family<KidBadge?, String>((
  ref,
  profileId,
) {
  final now = ref.watch(
    nowProvider.select((n) => DateTime(n.year, n.month, n.day)),
  );
  final since = DateTime(now.year, now.month, now.day - 1);
  final fresh = [
    for (final b
        in ref.watch(kidBadgesProvider(profileId)).value ?? const <KidBadge>[])
      if (b.earned && b.awardedAt != null && !b.awardedAt!.isBefore(since)) b,
  ]..sort((a, b) => b.awardedAt!.compareTo(a.awardedAt!));
  return fresh.firstOrNull;
});
