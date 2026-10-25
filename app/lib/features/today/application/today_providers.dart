import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';
import 'package:wuselwall/features/today/data/notices_repository.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';
import 'package:wuselwall/features/today/domain/notice.dart';

/// The card's items for the acting profile. Empty for nobody acting and for members,
/// so the card only ever shows to a guardian.
final gettingStartedProvider =
    FutureProvider.autoDispose<List<GettingStartedItem>>((ref) async {
      ref.watch(deviceKeyProvider);
      final household = ref.watch(
        deviceProvider.select((d) => d.value?.householdId),
      );
      if (household != null) {
        refreshOnInvalidation(
          ref,
          householdId: household,
          topic: 'members',
          also: {'board', 'school', 'calendar', 'tasks', 'meals', 'shopping'},
        );
      }
      final actor = ref.watch(actingProfileProvider);
      if (actor == null) return const [];
      return (await ref
              .watch(gettingStartedRepositoryProvider)
              .items(actor: actor))
          .unwrap();
    });

/// The notices for the acting profile. A failure (a server without notices, offline)
/// shows none: they are a courtesy, never an error on Today.
final noticesProvider = FutureProvider.autoDispose<List<AppNotice>>((
  ref,
) async {
  ref.watch(deviceKeyProvider);
  final household = ref.watch(
    deviceProvider.select((d) => d.value?.householdId),
  );
  if (household != null) {
    refreshOnInvalidation(
      ref,
      householdId: household,
      topic: 'members',
      also: {'board', 'school', 'calendar', 'tasks', 'meals', 'shopping'},
    );
  }
  final actor = ref.watch(actingProfileProvider);
  if (actor == null) return const [];
  final result = await ref
      .watch(noticesRepositoryProvider)
      .notices(actor: actor);
  return result.valueOrNull ?? const [];
});

/// Today's agenda as the acting profile sees it. Everything here is derived from the
/// providers the modules already have: the calendar's occurrences (recurrence is
/// expanded by the server), today's tasks, and the week's meal plan.
class TodayAgenda {
  const TodayAgenda({
    required this.events,
    required this.tasks,
    required this.warmSlot,
    this.warmMeal,
  });

  /// Appointments for the acting profile and the whole family, all day first.
  final List<Occurrence> events;

  /// Open chores of the acting profile, due or open today.
  final List<TaskInstance> tasks;

  /// The slot that is the warm meal today, and what is planned for it, if anything.
  final PlanSlot warmSlot;
  final MealEntry? warmMeal;

  bool get isEmpty => events.isEmpty && tasks.isEmpty && warmMeal == null;
}

final todayAgendaProvider = FutureProvider.autoDispose<TodayAgenda>((
  ref,
) async {
  final today = ref.watch(todayProvider);
  final actor = ref.watch(actingProfileProvider);

  final window = await ref.watch(
    occurrencesProvider((from: today, to: today)).future,
  );
  final events = [
    for (final o in window.occurrences)
      if (!o.isPresence &&
          (o.attendeeIds.isEmpty ||
              (actor != null && o.attendeeIds.contains(actor))))
        o,
  ]..sort(_byStart);

  final tasks = actor == null
      ? const <TaskInstance>[]
      : [
          for (final t in await ref.watch(tasksTodayProvider.future))
            if (t.assignedProfileId == actor && t.isOpen) t,
        ];

  // Settings are not awaited: without them the defaults apply, and the server keeps
  // the household's real answer for the wall display.
  final settings =
      ref.watch(householdSettingsProvider).value ?? const <SettingEntry>[];
  final warmSlot = warmSlotOf(today, settings);
  final entries = await ref.watch(mealEntriesProvider(mondayOf(today)).future);
  final entry = entryAt(entries, today, warmSlot);

  return TodayAgenda(
    events: events,
    tasks: tasks,
    warmSlot: warmSlot,
    warmMeal: entry != null && entry.hasDish ? entry : null,
  );
});

/// Open items on the household's default shopping list (the list the wall writes to).
final defaultShoppingOpenProvider = Provider<int>((ref) {
  final lists = ref.watch(shoppingListsProvider).value ?? const [];
  return lists.where((l) => l.isDefault).firstOrNull?.openCount ?? 0;
});

int _byStart(Occurrence a, Occurrence b) {
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  return _minutes(a.localStarts).compareTo(_minutes(b.localStarts));
}

int _minutes(TimeOfDay? t) => t == null ? 0 : t.hour * 60 + t.minute;

/// A manual refresh must drop source caches as well as the derived agenda.
Future<void> refreshToday(ProviderContainer ref) async {
  final today = ref.read(todayProvider);
  ref
    ..invalidate(occurrencesProvider((from: today, to: today)))
    ..invalidate(tasksTodayProvider)
    ..invalidate(mealEntriesProvider(mondayOf(today)))
    ..invalidate(householdSettingsProvider)
    ..invalidate(gettingStartedProvider)
    ..invalidate(noticesProvider)
    ..invalidate(pendingVerificationsProvider)
    ..invalidate(redemptionsProvider)
    ..invalidate(todayAgendaProvider);
  await Future.wait([
    // The screen renders the AsyncError; the refresh gesture itself must complete.
    ref
        .read(todayAgendaProvider.future)
        .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    ref.read(shoppingSyncProvider.notifier).sync(),
  ]);
}
