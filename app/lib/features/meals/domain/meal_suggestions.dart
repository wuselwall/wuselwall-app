import 'package:wuselwall/features/meals/domain/meal_models.dart';

/// How many chips each suggestion row shows (FR-3.8).
const mealSuggestionCount = 6;

/// "Oft bei uns": meals cooked within this many days.
const mealOftenWithinDays = 90;

/// "Lange nicht gegessen": meals last cooked more than this many days ago.
const mealRareAfterDays = 60;

/// The two rows the meal editor offers when its title is empty.
class MealSuggestions {
  const MealSuggestions({this.often = const [], this.rare = const []});

  /// Cooked recently, most often first.
  final List<MealHistoryEntry> often;

  /// Not cooked for a while, most often first; never a meal already shown in [often].
  final List<MealHistoryEntry> rare;

  bool get isEmpty => often.isEmpty && rare.isEmpty;
}

/// Whole days from [earlier] to [today], comparing calendar dates only.
int daysBetween(DateTime earlier, DateTime today) => DateTime.utc(
  today.year,
  today.month,
  today.day,
).difference(DateTime.utc(earlier.year, earlier.month, earlier.day)).inDays;

/// Picks the suggestions from [history] as of [today]. Pure, so the thresholds stay in
/// one place and the rules can be tested without a widget.
MealSuggestions suggestMeals(List<MealHistoryEntry> history, DateTime today) {
  int byTimesThenRecent(MealHistoryEntry a, MealHistoryEntry b) {
    final times = b.times.compareTo(a.times);
    return times != 0 ? times : b.lastOn.compareTo(a.lastOn);
  }

  final often = [
    for (final m in history)
      if (daysBetween(m.lastOn, today) <= mealOftenWithinDays) m,
  ]..sort(byTimesThenRecent);
  final shownOften = often.take(mealSuggestionCount).toList();

  final rare = [
    for (final m in history)
      if (daysBetween(m.lastOn, today) > mealRareAfterDays &&
          !shownOften.contains(m))
        m,
  ]..sort(byTimesThenRecent);

  return MealSuggestions(
    often: shownOften,
    rare: rare.take(mealSuggestionCount).toList(),
  );
}
