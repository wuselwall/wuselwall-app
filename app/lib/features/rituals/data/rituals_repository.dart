import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:wuselwall/core/error/failure.dart';
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

  /// The actor's own wish: a recipe, or a few words with an optional icon. [wishId]
  /// names the open wish to change; without it a new wish is made, or the newest one
  /// changes once they have used up `meals.wishes_per_week`.
  Future<Result<void>> setWish({
    required String? actor,
    String? recipeId,
    String? freeText,
    String? iconKey,
    String? wishId,
  }) async {
    Map<String, Object?> params({required bool withWish}) => {
      'p_actor': actor,
      'p_recipe_id': recipeId,
      'p_free_text': freeText,
      'p_icon_key': iconKey,
      if (withWish && wishId != null) 'p_wish': wishId,
    };
    final result = await _api.rpc(
      'meal_wish_set',
      params: params(withWish: true),
      parse: (_) {},
    );
    // The previous server release has no p_wish: there the call changes the newest wish.
    if (wishId != null && _missingFunction(result)) {
      return _api.rpc(
        'meal_wish_set',
        params: params(withWish: false),
        parse: (_) {},
      );
    }
    return result;
  }

  Future<Result<void>> withdrawWish({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'meal_wish_withdraw',
    params: {'p_actor': actor, 'p_wish': id},
    parse: (_) {},
  );

  /// Puts the wish on the plan, on [onDate] at [slot]. A slot that already has a meal
  /// is refused (`slot_taken`) unless [replace]; replacing keeps the meal's servings,
  /// cook and time.
  Future<Result<void>> planWish({
    required String? actor,
    required String id,
    required DateTime onDate,
    required String slot,
    bool replace = false,
  }) async {
    Map<String, Object?> params({required bool withReplace}) => {
      'p_actor': actor,
      'p_wish': id,
      'p_on_date': _date(onDate),
      'p_slot': slot,
      if (withReplace && replace) 'p_replace': true,
    };
    final result = await _api.rpc(
      'meal_wish_plan',
      params: params(withReplace: true),
      parse: (_) {},
    );
    // The previous server release has no p_replace: there planning always replaces.
    if (replace && _missingFunction(result)) {
      return _api.rpc(
        'meal_wish_plan',
        params: params(withReplace: false),
        parse: (_) {},
      );
    }
    return result;
  }

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
    params: {'p_week_start': _date(weekStart)},
    parse: (json) =>
        WeekReview.fromJson((json! as Map).cast<String, dynamic>()),
  );
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Whether [result] failed because the server has no function of that shape (PGRST202):
/// a server one release older, without the parameter just sent.
bool _missingFunction(Result<void> result) => switch (result) {
  Err(failure: NotFoundFailure(cause: PostgrestException(code: 'PGRST202'))) =>
    true,
  _ => false,
};

final ritualsRepositoryProvider = Provider<RitualsRepository>(
  (ref) => RitualsRepository(ref.watch(apiClientProvider)),
);
