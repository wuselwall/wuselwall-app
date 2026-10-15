import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';

/// Reads the `api.recipes`, `api.recipe_ingredients` and `api.meal_plan_entries` views and
/// writes through the meal functions of the M1.4 contract. Every write names the acting
/// profile; the server establishes the device and checks it.
class MealsRepository {
  const MealsRepository(this._api);

  final ApiClient _api;

  /// Every recipe of the household with its ingredients in order.
  Future<Result<List<Recipe>>> recipes() async {
    final rows = await _api.select<Map<String, dynamic>>(
      'recipes',
      parse: (row) => row,
      build: (q) => q.order('title'),
    );
    final ingredients = await _api.select<Map<String, dynamic>>(
      'recipe_ingredients',
      parse: (row) => row,
      build: (q) => q.order('position'),
    );
    return switch ((rows, ingredients)) {
      (Ok(value: final recipes), Ok(value: final ings)) => () {
        final byRecipe = <String, List<RecipeIngredient>>{};
        for (final row in ings) {
          byRecipe
              .putIfAbsent(row['recipe_id'] as String, () => [])
              .add(RecipeIngredient.fromJson(row));
        }
        return Ok([
          for (final row in recipes)
            Recipe.fromJson(
              row,
              ingredients: byRecipe[row['id'] as String] ?? const [],
            ),
        ]);
      }(),
      (Err(:final failure), _) || (_, Err(:final failure)) => Err(failure),
    };
  }

  /// The entries whose date lies in [from]..[to] (inclusive), in day and slot order.
  Future<Result<List<MealEntry>>> entries({
    required DateTime from,
    required DateTime to,
  }) => _api.select(
    'meal_plan_entries',
    parse: MealEntry.fromJson,
    build: (q) => q
        .gte('on_date', ymd(from))
        .lte('on_date', ymd(to))
        .order('on_date')
        .order('slot'),
  );

  /// The household's meals of the last year, cooked or not, most often first
  /// (`api.meal_history`). The editor's suggestions are picked from it.
  Future<Result<List<MealHistoryEntry>>> history() => _api.select(
    'meal_history',
    parse: MealHistoryEntry.fromJson,
    build: (q) => q.order('times', ascending: false),
  );

  /// Creates or replaces a recipe. An empty id creates; the ingredient list replaces
  /// the old one as a whole.
  Future<Result<String>> saveRecipe({
    required String? actor,
    required Recipe recipe,
  }) => _api.rpc(
    'recipe_save',
    params: {
      'p_actor': actor,
      'p_recipe': {
        if (recipe.id.isNotEmpty) 'id': recipe.id,
        'title': recipe.title,
        'description': recipe.description,
        'servings_default': recipe.servingsDefault,
        'steps': recipe.steps,
        'source_url': recipe.sourceUrl,
        'tags': recipe.tags,
        'ingredients': [for (final i in recipe.ingredients) i.toJson()],
      },
    },
    parse: _idOf,
  );

  Future<Result<void>> deleteRecipe({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'recipe_delete',
    params: {'p_actor': actor, 'p_id': id},
    parse: (_) {},
  );

  /// Sets a slot's dish, servings, cook, time and guests. Exactly one of [recipeId]
  /// and [freeText] is set for a dish; both null keeps a slot that only has overrides.
  /// Eating overrides are not sent, so the server keeps them.
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
  }) => _api.rpc(
    'meal_set',
    params: {
      'p_actor': actor,
      'p_entry': {
        'on_date': ymd(date),
        'slot': slot.wire,
        'recipe_id': recipeId,
        'free_text': freeText,
        'servings': servings,
        'cook_profile_id': cookProfileId,
        'at_time': time == null ? null : hm(time),
        'guests': guests,
      },
    },
    parse: _idOf,
  );

  Future<Result<void>> clearMeal({
    required String? actor,
    required DateTime date,
    required PlanSlot slot,
  }) => _api.rpc(
    'meal_clear',
    params: {'p_actor': actor, 'p_on_date': ymd(date), 'p_slot': slot.wire},
    parse: (_) {},
  );

  /// Drags a meal to another day; the server swaps when the target is occupied.
  Future<Result<void>> moveMeal({
    required String? actor,
    required DateTime fromDate,
    required PlanSlot fromSlot,
    required DateTime toDate,
    required PlanSlot toSlot,
  }) => _api.rpc(
    'meal_move',
    params: {
      'p_actor': actor,
      'p_from_date': ymd(fromDate),
      'p_from_slot': fromSlot.wire,
      'p_to_date': ymd(toDate),
      'p_to_slot': toSlot.wire,
    },
    parse: (_) {},
  );

  /// Sets one member's eating for a slot. Null removes the override, so the default rule
  /// applies again. Allowed on the kiosk (the correction dots).
  Future<Result<void>> setEating({
    required String? actor,
    required DateTime date,
    required PlanSlot slot,
    required String profileId,
    required bool? eating,
  }) => _api.rpc(
    'meal_eating_set',
    params: {
      'p_actor': actor,
      'p_on_date': ymd(date),
      'p_slot': slot.wire,
      'p_profile_id': profileId,
      'p_eating': eating,
    },
    parse: (_) {},
  );

  /// What generating the list would add for [from]..[to]; not written anywhere.
  Future<Result<List<MealShoppingItem>>> shoppingPreview({
    required String? actor,
    required DateTime from,
    required DateTime to,
  }) => _api.rpc(
    'meal_shopping_preview',
    params: {'p_actor': actor, 'p_from': ymd(from), 'p_to': ymd(to)},
    parse: (json) {
      final list = switch (json) {
        final Map<String, dynamic> m => (m['items'] as List?) ?? const [],
        final List<dynamic> l => l,
        _ => const <dynamic>[],
      };
      return [
        for (final row in list)
          MealShoppingItem.fromJson(row as Map<String, dynamic>),
      ];
    },
  );

  /// Adds the chosen preview [keys] to the default list and returns how many were added.
  Future<Result<int>> shoppingGenerate({
    required String? actor,
    required DateTime from,
    required DateTime to,
    required List<String> keys,
  }) => _api.rpc(
    'meal_shopping_generate',
    params: {
      'p_actor': actor,
      'p_from': ymd(from),
      'p_to': ymd(to),
      'p_keys': keys,
    },
    parse: (json) => (json! as Map<String, dynamic>)['added'] as int? ?? 0,
  );
}

String _idOf(Object? json) => (json! as Map<String, dynamic>)['id'] as String;

/// `2026-09-02`.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `18:30`, the wire form of a time of day.
String hm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

final mealsRepositoryProvider = Provider<MealsRepository>(
  (ref) => MealsRepository(ref.watch(apiClientProvider)),
);
