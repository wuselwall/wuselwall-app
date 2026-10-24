import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';

/// The rituals' own data (specs/27): meal wishes, the family's table questions and the
/// Sunday look-back. Everything else they show is read where it already lives.
class RitualsRepository {
  const RitualsRepository(this._api);

  final ApiClient _api;

  Future<Result<List<MealWish>>> wishes() => _api.select(
    'meal_wishes',
    parse: MealWish.fromJson,
    build: (q) => q.order('created_at'),
  );

  /// The actor's own wish: a recipe, or a few words with an optional icon. Replaces
  /// their open wish when they have used up `meals.wishes_per_week`.
  Future<Result<void>> setWish({
    required String? actor,
    String? recipeId,
    String? freeText,
    String? iconKey,
  }) => _api.rpc(
    'meal_wish_set',
    params: {
      'p_actor': actor,
      'p_recipe_id': recipeId,
      'p_free_text': freeText,
      'p_icon_key': iconKey,
    },
    parse: (_) {},
  );

  Future<Result<void>> withdrawWish({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'meal_wish_withdraw',
    params: {'p_actor': actor, 'p_wish': id},
    parse: (_) {},
  );

  /// Puts the wish on the plan, on [onDate] at [slot].
  Future<Result<void>> planWish({
    required String? actor,
    required String id,
    required DateTime onDate,
    required String slot,
  }) => _api.rpc(
    'meal_wish_plan',
    params: {
      'p_actor': actor,
      'p_wish': id,
      'p_on_date':
          '${onDate.year.toString().padLeft(4, '0')}-'
          '${onDate.month.toString().padLeft(2, '0')}-'
          '${onDate.day.toString().padLeft(2, '0')}',
      'p_slot': slot,
    },
    parse: (_) {},
  );

  Future<Result<List<FamilyQuestion>>> questions() => _api.select(
    'table_questions',
    parse: FamilyQuestion.fromJson,
    build: (q) => q.order('created_at'),
  );

  Future<Result<void>> addQuestion({
    required String? actor,
    required String text,
  }) => _api.rpc(
    'table_question_add',
    params: {'p_actor': actor, 'p_text': text.trim()},
    parse: (_) {},
  );

  Future<Result<void>> hideQuestion({
    required String? actor,
    required String key,
    bool hidden = true,
  }) => _api.rpc(
    'table_question_hide',
    params: {'p_actor': actor, 'p_key': key, 'p_hidden': hidden},
    parse: (_) {},
  );

  Future<Result<void>> removeQuestion({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'table_question_remove',
    params: {'p_actor': actor, 'p_id': id},
    parse: (_) {},
  );

  Future<Result<WeekReview>> weekReview(DateTime weekStart) => _api.rpc(
    'week_review',
    params: {
      'p_week_start':
          '${weekStart.year.toString().padLeft(4, '0')}-'
          '${weekStart.month.toString().padLeft(2, '0')}-'
          '${weekStart.day.toString().padLeft(2, '0')}',
    },
    parse: (json) =>
        WeekReview.fromJson((json! as Map).cast<String, dynamic>()),
  );
}

final ritualsRepositoryProvider = Provider<RitualsRepository>(
  (ref) => RitualsRepository(ref.watch(apiClientProvider)),
);
