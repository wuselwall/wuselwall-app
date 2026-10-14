import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/domain/meal_suggestions.dart';

final _today = DateTime(2026, 10, 14);

DateTime _ago(int days) =>
    DateTime(_today.year, _today.month, _today.day - days);

MealHistoryEntry _meal(String title, int times, int lastOnDaysAgo) =>
    MealHistoryEntry(
      title: title,
      times: times,
      firstOn: _ago(lastOnDaysAgo + 30),
      lastOn: _ago(lastOnDaysAgo),
    );

void main() {
  test('an empty history offers nothing', () {
    expect(suggestMeals(const [], _today).isEmpty, isTrue);
  });

  test('family favourites: cooked in the last 90 days, most often first', () {
    final s = suggestMeals([
      _meal('Pizza', 2, 3),
      _meal('Nudeln', 7, 2),
      _meal('Suppe', 9, 91),
    ], _today);
    expect(s.often.map((m) => m.title), ['Nudeln', 'Pizza']);
  });

  test(
    'not in a while: last cooked more than 60 days ago, most often first',
    () {
      final s = suggestMeals([
        _meal('Eintopf', 3, 61),
        _meal('Curry', 1, 120),
        _meal('Braten', 5, 200),
        _meal('Pizza', 2, 10),
      ], _today);
      // Eintopf (61 days) is a favourite candidate, so it is shown there, not here.
      expect(s.often.map((m) => m.title), ['Eintopf', 'Pizza']);
      expect(s.rare.map((m) => m.title), ['Braten', 'Curry']);
    },
  );

  test('90 days is still a favourite, 91 days is not in a while', () {
    final s = suggestMeals([
      _meal('Genau 90', 1, mealOftenWithinDays),
      _meal('Genau 91', 1, mealOftenWithinDays + 1),
      _meal('Genau 60', 1, mealRareAfterDays),
      _meal('Genau 61', 1, mealRareAfterDays + 1),
    ], _today);
    // Equal counts: the more recent meal first. Up to 90 days counts as cooked lately.
    expect(s.often.map((m) => m.title), ['Genau 60', 'Genau 61', 'Genau 90']);
    expect(s.rare.map((m) => m.title), ['Genau 91']);
  });

  test('a meal shown as a favourite is not repeated as not in a while', () {
    final s = suggestMeals([
      _meal('Nudeln', 7, 75),
      _meal('Suppe', 2, 200),
    ], _today);
    expect(s.often.map((m) => m.title), ['Nudeln']);
    expect(s.rare.map((m) => m.title), ['Suppe']);
  });

  test('each row shows at most six meals', () {
    final s = suggestMeals([
      for (var i = 0; i < 9; i++) _meal('Oft $i', 9 - i, 1),
      for (var i = 0; i < 9; i++) _meal('Lange $i', 9 - i, 100),
    ], _today);
    expect(s.often, hasLength(mealSuggestionCount));
    expect(s.rare, hasLength(mealSuggestionCount));
    expect(s.often.first.title, 'Oft 0');
  });

  test('the day count compares calendar dates, not hours', () {
    expect(
      daysBetween(DateTime(2026, 10, 14, 23, 59), DateTime(2026, 10, 15, 0, 1)),
      1,
    );
  });

  test('a history entry reads its dates from the view', () {
    final m = MealHistoryEntry.fromJson({
      'recipe_id': 'r-braten',
      'title': 'Rinderbraten',
      'times': 4,
      'first_on': '2026-07-01',
      'last_on': '2026-10-05',
    });
    expect(m.recipeId, 'r-braten');
    expect(m.times, 4);
    expect(m.lastOn, DateTime(2026, 10, 5));
  });
}
