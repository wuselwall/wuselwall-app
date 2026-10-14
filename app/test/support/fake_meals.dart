import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';

/// In-memory meals backend. Keeps the entries and recipes it is given and applies the
/// writes to them, so the screen reloads what was saved, and records every call so tests
/// can assert the arguments the screens sent.
class FakeMealsRepository implements MealsRepository {
  FakeMealsRepository({
    List<MealEntry> entries = const [],
    List<Recipe> recipes = const [],
    List<MealShoppingItem> preview = const [],
    List<MealHistoryEntry> history = const [],
  }) : _entries = [...entries],
       _recipes = [...recipes],
       _preview = [...preview],
       _history = [...history];

  final List<MealEntry> _entries;
  final List<Recipe> _recipes;
  final List<MealShoppingItem> _preview;
  final List<MealHistoryEntry> _history;

  final setMeals =
      <({DateTime date, PlanSlot slot, String? recipeId, String? freeText})>[];
  final moves =
      <
        ({
          DateTime fromDate,
          PlanSlot fromSlot,
          DateTime toDate,
          PlanSlot toSlot,
        })
      >[];
  final eatingCalls =
      <
        ({
          String? actor,
          DateTime date,
          PlanSlot slot,
          String profileId,
          bool? eating,
        })
      >[];
  final savedRecipes = <Recipe>[];
  final deletedRecipes = <String>[];
  final generated = <({String? actor, List<String> keys})>[];

  var _nextId = 0;

  @override
  Future<Result<List<MealEntry>>> entries({
    required DateTime from,
    required DateTime to,
  }) async => Ok([
    for (final e in _entries)
      if (!e.onDate.isBefore(from) && !e.onDate.isAfter(to)) e,
  ]);

  @override
  Future<Result<List<MealHistoryEntry>>> history() async => Ok(_history);

  @override
  Future<Result<List<Recipe>>> recipes() async => Ok(List.of(_recipes));

  @override
  Future<Result<String>> saveRecipe({
    required String? actor,
    required Recipe recipe,
  }) async {
    savedRecipes.add(recipe);
    final id = recipe.id.isEmpty ? 'new-recipe-${_nextId++}' : recipe.id;
    _recipes
      ..removeWhere((r) => r.id == id)
      ..add(
        Recipe(
          id: id,
          title: recipe.title,
          servingsDefault: recipe.servingsDefault,
          steps: recipe.steps,
          tags: recipe.tags,
          ingredients: recipe.ingredients,
        ),
      );
    return Ok(id);
  }

  @override
  Future<Result<void>> deleteRecipe({
    required String? actor,
    required String id,
  }) async {
    deletedRecipes.add(id);
    _recipes.removeWhere((r) => r.id == id);
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
    setMeals.add((
      date: date,
      slot: slot,
      recipeId: recipeId,
      freeText: freeText,
    ));
    final id = 'entry-${_nextId++}';
    _entries
      ..removeWhere((e) => e.onDate == date && e.slot == slot)
      ..add(
        MealEntry(
          id: id,
          onDate: date,
          slot: slot,
          recipeId: recipeId,
          freeText: freeText,
          title:
              _recipes.where((r) => r.id == recipeId).firstOrNull?.title ??
              freeText,
          servings: servings,
          cookProfileId: cookProfileId,
          atTime: time,
          guests: guests,
        ),
      );
    return Ok(id);
  }

  @override
  Future<Result<void>> clearMeal({
    required String? actor,
    required DateTime date,
    required PlanSlot slot,
  }) async {
    _entries.removeWhere((e) => e.onDate == date && e.slot == slot);
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
    moves.add((
      fromDate: fromDate,
      fromSlot: fromSlot,
      toDate: toDate,
      toSlot: toSlot,
    ));
    for (final (i, e) in _entries.indexed) {
      if (e.onDate == fromDate && e.slot == fromSlot) {
        _entries[i] = MealEntry(
          id: e.id,
          onDate: toDate,
          slot: toSlot,
          recipeId: e.recipeId,
          freeText: e.freeText,
          title: e.title,
          servings: e.servings,
          cookProfileId: e.cookProfileId,
          atTime: e.atTime,
          guests: e.guests,
        );
      }
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
    eatingCalls.add((
      actor: actor,
      date: date,
      slot: slot,
      profileId: profileId,
      eating: eating,
    ));
    return const Ok(null);
  }

  @override
  Future<Result<List<MealShoppingItem>>> shoppingPreview({
    required String? actor,
    required DateTime from,
    required DateTime to,
  }) async => Ok(_preview);

  @override
  Future<Result<int>> shoppingGenerate({
    required String? actor,
    required DateTime from,
    required DateTime to,
    required List<String> keys,
  }) async {
    generated.add((actor: actor, keys: keys));
    return Ok(keys.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
