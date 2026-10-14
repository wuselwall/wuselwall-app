import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

/// Monday of the week containing [day], at midnight.
DateTime mondayOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - 1));

/// The week on screen, as its Monday. Shared by the section's toolbar and its grid.
class MealsWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => mondayOf(DateTime.now());

  void shift(int weeks) =>
      state = DateTime(state.year, state.month, state.day + 7 * weeks);

  void today() => state = mondayOf(DateTime.now());
}

final mealsWeekProvider = NotifierProvider<MealsWeekNotifier, DateTime>(
  MealsWeekNotifier.new,
);

/// The week's entries, from Monday to Sunday. Refetched on the `meals` topic.
final mealEntriesProvider = FutureProvider.autoDispose
    .family<List<MealEntry>, DateTime>((ref, weekStart) async {
      _refreshOnMeals(ref);
      final to = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
      return (await ref
              .watch(mealsRepositoryProvider)
              .entries(from: weekStart, to: to))
          .unwrap();
    });

/// Every recipe of the household with its ingredients. Refetched on the `meals` topic.
final recipesProvider = FutureProvider.autoDispose<List<Recipe>>((ref) async {
  _refreshOnMeals(ref);
  return (await ref.watch(mealsRepositoryProvider).recipes()).unwrap();
});

/// The household's meal history for the editor's suggestions. Refetched on the `meals`
/// topic. The editor treats a failure as no suggestions.
final mealHistoryProvider = FutureProvider.autoDispose<List<MealHistoryEntry>>((
  ref,
) async {
  _refreshOnMeals(ref);
  return (await ref.watch(mealsRepositoryProvider).history()).unwrap();
});

void _refreshOnMeals(Ref ref) {
  final householdId = ref.watch(deviceProvider).value?.householdId;
  if (householdId != null) {
    refreshOnInvalidation(ref, householdId: householdId, topic: 'meals');
  }
}

/// Which slot of [day] is the warm meal (specs/21 `meals.warm_meal.*`): on Monday to
/// Friday the school-day setting, at weekends the free-day one. The household's setting
/// wins; without it, the curated defaults (dinner, lunch). The server, not the app,
/// knows about holidays; the wall uses the same settings.
PlanSlot warmSlotOf(DateTime day, List<SettingEntry> settings) {
  final schoolDay = day.weekday <= DateTime.friday;
  final entry = resolveSetting(
    settings,
    schoolDay ? 'meals.warm_meal.school_day' : 'meals.warm_meal.free_day',
  );
  final value = entry?.value ?? entry?.defaultValue;
  return switch (value) {
    'lunch' => PlanSlot.lunch,
    'dinner' => PlanSlot.dinner,
    _ => schoolDay ? PlanSlot.dinner : PlanSlot.lunch,
  };
}

/// The warm slot of [day] under the household's settings.
final warmSlotProvider = Provider.family<PlanSlot, DateTime>((ref, day) {
  final settings = ref.watch(householdSettingsProvider).value ?? const [];
  return warmSlotOf(day, settings);
});

/// The entry in [entries] for [day] and [slot], if any.
MealEntry? entryAt(Iterable<MealEntry> entries, DateTime day, PlanSlot slot) =>
    entries
        .where(
          (e) =>
              e.slot == slot &&
              e.onDate.year == day.year &&
              e.onDate.month == day.month &&
              e.onDate.day == day.day,
        )
        .firstOrNull;
