import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_english.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';

/// The meals of the reference week, in memory, for `lib/main_demo.dart`. The dishes are
/// the ones the demo's week board shows (`demo_board.dart`), so the wall and the meal plan
/// agree. Two of them are recipes with ingredients; the rest are free text.
class DemoMealsRepository implements MealsRepository {
  DemoMealsRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _seed();
  }

  final DateTime Function() _clock;
  final _entries = <MealEntry>[];
  final _recipes = <Recipe>[];
  var _next = 0;

  String _id() => 'demo-meal-${_next++}';

  /// The Monday of the demo week, the same one the demo board uses.
  DateTime get _monday {
    final now = _clock();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  void _seed() {
    _recipes
      ..add(
        Recipe(
          id: 'r-braten',
          title: demoText('Rinderbraten'),
          servingsDefault: 4,
          steps: demoText(
            'Fleisch würzen und scharf anbraten.\n'
            'Gemüse dazugeben und kurz mitrösten.\n'
            'Mit Brühe und Rotwein ablöschen und zwei Stunden schmoren.\n'
            'Soße abschmecken und mit dem Fleisch servieren.',
          ),
          tags: [demoText('Sonntag'), demoText('Ofen')],
          ingredients: [
            RecipeIngredient(
              id: 'i1',
              rawName: demoText('Rindfleisch'),
              quantity: 800,
              unit: 'g',
            ),
            RecipeIngredient(
              id: 'i2',
              rawName: demoText('Zwiebeln'),
              quantity: 2,
              unit: demoText('Stück'),
            ),
            RecipeIngredient(
              id: 'i3',
              rawName: demoText('Karotten'),
              quantity: 3,
              unit: demoText('Stück'),
            ),
            RecipeIngredient(
              id: 'i4',
              rawName: demoText('Rotwein'),
              quantity: 250,
              unit: 'ml',
            ),
            RecipeIngredient(
              id: 'i5',
              rawName: demoText('Rinderbrühe'),
              quantity: 500,
              unit: 'ml',
            ),
            RecipeIngredient(
              id: 'i6',
              rawName: demoText('Tomatenmark'),
              quantity: 2,
              unit: demoText('EL'),
            ),
            RecipeIngredient(
              id: 'i7',
              rawName: demoText('Salz'),
              note: demoText('nach Geschmack'),
            ),
          ],
        ),
      )
      ..add(
        Recipe(
          id: 'r-pesto',
          title: demoText('Nudeln mit Pesto'),
          servingsDefault: 4,
          steps: demoText(
            'Nudeln in Salzwasser kochen.\n'
            'Pesto mit etwas Nudelwasser verrühren.\n'
            'Alles mischen und mit Parmesan servieren.',
          ),
          tags: [demoText('schnell')],
          ingredients: [
            RecipeIngredient(
              id: 'p1',
              rawName: demoText('Nudeln'),
              quantity: 500,
              unit: 'g',
            ),
            RecipeIngredient(
              id: 'p2',
              rawName: demoText('Basilikumpesto'),
              quantity: 150,
              unit: 'g',
            ),
            RecipeIngredient(
              id: 'p3',
              rawName: demoText('Parmesan'),
              quantity: 50,
              unit: 'g',
            ),
            RecipeIngredient(
              id: 'p4',
              rawName: demoText('Pinienkerne'),
              quantity: 30,
              unit: 'g',
              note: demoText('optional'),
            ),
          ],
        ),
      );

    // (day index, slot, dish, recipe id, cook, time, guests, servings)
    final week = <(int, PlanSlot, String, String?, String, String, int, int?)>[
      (
        0,
        PlanSlot.dinner,
        demoText('Kürbissuppe'),
        null,
        DemoData.mama,
        '18:30',
        0,
        null,
      ),
      (
        1,
        PlanSlot.dinner,
        demoText('Nudelauflauf'),
        null,
        DemoData.papa,
        '18:30',
        0,
        null,
      ),
      (
        2,
        PlanSlot.dinner,
        demoText('Chili sin Carne'),
        null,
        DemoData.mama,
        '18:30',
        0,
        null,
      ),
      (
        3,
        PlanSlot.dinner,
        demoText('Fischstäbchen'),
        null,
        DemoData.mama,
        '18:30',
        0,
        null,
      ),
      (
        5,
        PlanSlot.lunch,
        demoText('Nudeln mit Pesto'),
        'r-pesto',
        DemoData.papa,
        '12:30',
        0,
        4,
      ),
      (
        6,
        PlanSlot.lunch,
        demoText('Rinderbraten'),
        'r-braten',
        DemoData.mama,
        '12:30',
        2,
        6,
      ),
    ];
    for (final (day, slot, dish, recipe, cook, time, guests, servings)
        in week) {
      final (h, m) = (
        int.parse(time.split(':')[0]),
        int.parse(time.split(':')[1]),
      );
      _entries.add(
        MealEntry(
          id: _id(),
          onDate: _day(day),
          slot: slot,
          recipeId: recipe,
          freeText: recipe == null ? dish : null,
          title: dish,
          servings: servings,
          cookProfileId: cook,
          atTime: TimeOfDay(hour: h, minute: m),
          guests: guests,
          // Thursday: Papa is at the late meeting, set by hand.
          eatingOverrides: day == 3 ? {DemoData.papa: false} : const {},
          // Wednesday's chili is the son's wish, as on the wall (specs/27).
          wishedBy: day == 2 ? DemoData.son : null,
        ),
      );
    }
  }

  DateTime _day(int index) {
    final m = _monday;
    return DateTime(m.year, m.month, m.day + index);
  }

  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  MealEntry? _at(DateTime day, PlanSlot slot) =>
      _entries.where((e) => e.slot == slot && _same(e.onDate, day)).firstOrNull;

  String? _titleOf(String? recipeId, String? freeText) => recipeId == null
      ? freeText
      : _recipes.where((r) => r.id == recipeId).firstOrNull?.title;

  MealEntry _copy(
    MealEntry e, {
    String? recipeId,
    String? freeText,
    int? servings,
    String? cookProfileId,
    Map<String, bool>? eatingOverrides,
    TimeOfDay? atTime,
    int? guests,
    DateTime? onDate,
    PlanSlot? slot,
    bool clearDish = false,
  }) => MealEntry(
    id: e.id,
    onDate: onDate ?? e.onDate,
    slot: slot ?? e.slot,
    recipeId: clearDish ? null : (recipeId ?? e.recipeId),
    freeText: clearDish ? null : (freeText ?? e.freeText),
    title: clearDish
        ? null
        : _titleOf(recipeId ?? e.recipeId, freeText ?? e.freeText),
    servings: servings ?? e.servings,
    cookProfileId: cookProfileId ?? e.cookProfileId,
    atTime: atTime ?? e.atTime,
    guests: guests ?? e.guests,
    eatingOverrides: eatingOverrides ?? e.eatingOverrides,
    shoppingGeneratedAt: e.shoppingGeneratedAt,
  );

  @override
  Future<Result<List<MealEntry>>> entries({
    required DateTime from,
    required DateTime to,
  }) async => Ok([
    for (final e in _entries)
      if (!e.onDate.isBefore(from) && !e.onDate.isAfter(to)) e,
  ]);

  /// A year of cooking for the suggestions: the week's dishes were cooked often, and a
  /// few older ones have not been on the table for months.
  @override
  Future<Result<List<MealHistoryEntry>>> history() async {
    final today = _clock();
    DateTime ago(int days) =>
        DateTime(today.year, today.month, today.day - days);
    return Ok(
      [
        MealHistoryEntry(
          title: demoText('Nudelauflauf'),
          times: 7,
          firstOn: ago(300),
          lastOn: ago(2),
        ),
        MealHistoryEntry(
          recipeId: 'r-braten',
          title: demoText('Rinderbraten'),
          times: 4,
          firstOn: ago(150),
          lastOn: ago(9),
        ),
        MealHistoryEntry(
          title: demoText('Fischstäbchen'),
          times: 6,
          firstOn: ago(200),
          lastOn: ago(70),
        ),
        MealHistoryEntry(
          title: demoText('Chili sin Carne'),
          times: 3,
          firstOn: ago(120),
          lastOn: ago(5),
        ),
        MealHistoryEntry(
          recipeId: 'r-pesto',
          title: demoText('Nudeln mit Pesto'),
          times: 3,
          firstOn: ago(280),
          lastOn: ago(40),
        ),
        MealHistoryEntry(
          title: demoText('Kürbissuppe'),
          times: 2,
          firstOn: ago(180),
          lastOn: ago(75),
        ),
        MealHistoryEntry(
          title: demoText('Gulaschsuppe'),
          times: 5,
          firstOn: ago(340),
          lastOn: ago(120),
        ),
        MealHistoryEntry(
          title: demoText('Linseneintopf'),
          times: 3,
          firstOn: ago(330),
          lastOn: ago(210),
        ),
        MealHistoryEntry(
          title: demoText('Pizza selbst gemacht'),
          times: 2,
          firstOn: ago(260),
          lastOn: ago(95),
        ),
        MealHistoryEntry(
          title: demoText('Hühnercurry'),
          times: 2,
          firstOn: ago(250),
          lastOn: ago(130),
        ),
      ]..sort((a, b) => b.times.compareTo(a.times)),
    );
  }

  @override
  Future<Result<List<Recipe>>> recipes() async => Ok(List.of(_recipes));

  @override
  Future<Result<String>> saveRecipe({
    required String? actor,
    required Recipe recipe,
  }) async {
    final id = recipe.id.isEmpty ? _id() : recipe.id;
    final saved = Recipe(
      id: id,
      title: recipe.title,
      servingsDefault: recipe.servingsDefault,
      steps: recipe.steps,
      sourceUrl: recipe.sourceUrl,
      tags: recipe.tags,
      ingredients: [
        for (final (i, ing) in recipe.ingredients.indexed)
          RecipeIngredient(
            id: '$id-$i',
            rawName: ing.rawName,
            catalogItemId: ing.catalogItemId,
            quantity: ing.quantity,
            unit: ing.unit,
            note: ing.note,
          ),
      ],
    );
    _recipes
      ..removeWhere((r) => r.id == id)
      ..add(saved);
    return Ok(id);
  }

  @override
  Future<Result<void>> deleteRecipe({
    required String? actor,
    required String id,
  }) async {
    final title = _titleOf(id, null);
    _recipes.removeWhere((r) => r.id == id);
    // Meals that used it keep their name as free text, as the server does.
    for (final e in [..._entries]) {
      if (e.recipeId == id) {
        final i = _entries.indexOf(e);
        _entries[i] = MealEntry(
          id: e.id,
          onDate: e.onDate,
          slot: e.slot,
          freeText: title,
          title: title,
          cookProfileId: e.cookProfileId,
          atTime: e.atTime,
          guests: e.guests,
          eatingOverrides: e.eatingOverrides,
        );
      }
    }
    return const Ok(null);
  }

  @override
  Future<Result<String>> setMeal({
    required String? actor,
    required DateTime date,
    required PlanSlot slot,
    String? recipeId,
    String? freeText,
    int? servings,
    String? cookProfileId,
    TimeOfDay? time,
    int guests = 0,
  }) async {
    final existing = _at(date, slot);
    final entry = MealEntry(
      id: existing?.id ?? _id(),
      onDate: date,
      slot: slot,
      recipeId: recipeId,
      freeText: freeText,
      title: _titleOf(recipeId, freeText),
      servings: servings,
      cookProfileId: cookProfileId,
      atTime: time,
      guests: guests,
      eatingOverrides: existing?.eatingOverrides ?? const {},
    );
    _entries
      ..removeWhere((e) => e.id == entry.id)
      ..add(entry);
    return Ok(entry.id);
  }

  @override
  Future<Result<void>> clearMeal({
    required String? actor,
    required DateTime date,
    required PlanSlot slot,
  }) async {
    _entries.removeWhere((e) => e.slot == slot && _same(e.onDate, date));
    return const Ok(null);
  }

  @override
  Future<Result<void>> moveMeal({
    required String? actor,
    required DateTime fromDate,
    required PlanSlot fromSlot,
    required DateTime toDate,
    required PlanSlot toSlot,
  }) async {
    final from = _at(fromDate, fromSlot);
    if (from == null) return const Ok(null);
    final to = _at(toDate, toSlot);
    final i = _entries.indexOf(from);
    _entries[i] = _copy(from, onDate: toDate, slot: toSlot);
    if (to != null) {
      final j = _entries.indexOf(to);
      _entries[j] = _copy(to, onDate: fromDate, slot: fromSlot);
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> setEating({
    required String? actor,
    required DateTime date,
    required PlanSlot slot,
    required String profileId,
    required bool? eating,
  }) async {
    final existing = _at(date, slot);
    final overrides = {...?existing?.eatingOverrides};
    if (eating == null) {
      overrides.remove(profileId);
    } else {
      overrides[profileId] = eating;
    }
    if (existing == null) {
      _entries.add(
        MealEntry(
          id: _id(),
          onDate: date,
          slot: slot,
          eatingOverrides: overrides,
        ),
      );
    } else {
      _entries[_entries.indexOf(existing)] = _copy(
        existing,
        eatingOverrides: overrides,
      );
    }
    return const Ok(null);
  }

  /// The ingredients of the range's recipes, scaled and summed by name and unit.
  List<MealShoppingItem> _preview(DateTime from, DateTime to) {
    final sums = <String, (String, double?, String?, List<String>)>{};
    for (final e in _entries) {
      final recipeId = e.recipeId;
      if (recipeId == null || e.shoppingGeneratedAt != null) continue;
      if (e.onDate.isBefore(from) || e.onDate.isAfter(to)) continue;
      final recipe = _recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) continue;
      final ratio =
          (e.servings ?? recipe.servingsDefault) / recipe.servingsDefault;
      for (final ing in recipe.ingredients) {
        final key = '${ing.rawName.toLowerCase()}|${ing.unit ?? ''}';
        final (name, qty, unit, ids) =
            sums[key] ?? (ing.rawName, null, ing.unit, <String>[]);
        final scaled = ing.quantity == null ? null : ing.quantity! * ratio;
        sums[key] = (
          name,
          scaled == null ? qty : (qty ?? 0) + scaled,
          unit,
          [...ids, if (!ids.contains(e.id)) e.id],
        );
      }
    }
    return [
      for (final MapEntry(key: key, value: (name, qty, unit, ids))
          in sums.entries)
        MealShoppingItem(
          key: key,
          name: name,
          quantity: qty == null ? null : double.parse(qty.toStringAsFixed(1)),
          unit: unit,
          mealEntryIds: ids,
          alreadyOnList: name == demoText('Nudeln'),
        ),
    ];
  }

  @override
  Future<Result<List<MealShoppingItem>>> shoppingPreview({
    required String? actor,
    required DateTime from,
    required DateTime to,
  }) async => Ok(_preview(from, to));

  @override
  Future<Result<int>> shoppingGenerate({
    required String? actor,
    required DateTime from,
    required DateTime to,
    required List<String> keys,
  }) async {
    final chosen = [
      for (final i in _preview(from, to))
        if (keys.contains(i.key)) i,
    ];
    final stamp = _clock();
    final used = {for (final i in chosen) ...i.mealEntryIds};
    for (final e in [..._entries]) {
      if (used.contains(e.id)) {
        _entries[_entries.indexOf(e)] = MealEntry(
          id: e.id,
          onDate: e.onDate,
          slot: e.slot,
          recipeId: e.recipeId,
          freeText: e.freeText,
          title: e.title,
          servings: e.servings,
          cookProfileId: e.cookProfileId,
          atTime: e.atTime,
          guests: e.guests,
          eatingOverrides: e.eatingOverrides,
          shoppingGeneratedAt: stamp,
        );
      }
    }
    return Ok(chosen.length);
  }
}
