import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_english.dart';
import 'package:wuselwall/features/rituals/data/rituals_repository.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';

/// The rituals of the demo family (specs/27): the son has wished for pancakes, the
/// daughter added a table question of her own, and the week has a look-back with one
/// line for everyone.
class DemoRitualsRepository implements RitualsRepository {
  DemoRitualsRepository();

  var _next = 1;

  late final _wishes = <MealWish>[
    MealWish(
      id: 'w-1',
      profileId: DemoData.son,
      title: demoText('Pfannkuchen'),
      freeText: demoText('Pfannkuchen'),
    ),
  ];

  late final _questions = <FamilyQuestion>[
    FamilyQuestion(
      id: 'q-own-1',
      text: demoText('Welches Tier wärst du gern für einen Tag?'),
      createdBy: DemoData.daughter,
    ),
  ];

  @override
  Future<Result<List<MealWish>>> wishes() async => Ok([..._wishes]);

  @override
  Future<Result<void>> setWish({
    required String? actor,
    String? recipeId,
    String? freeText,
    String? iconKey,
  }) async {
    final who = actor ?? DemoData.daughter;
    _wishes
      ..removeWhere((w) => w.profileId == who && !w.planned)
      ..add(
        MealWish(
          id: 'w-${++_next}',
          profileId: who,
          title: freeText ?? demoText('Lieblingsessen'),
          recipeId: recipeId,
          freeText: freeText,
          iconKey: iconKey,
        ),
      );
    return const Ok(null);
  }

  @override
  Future<Result<void>> withdrawWish({
    required String? actor,
    required String id,
  }) async {
    _wishes.removeWhere((w) => w.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<void>> planWish({
    required String? actor,
    required String id,
    required DateTime onDate,
    required String slot,
  }) async {
    final i = _wishes.indexWhere((w) => w.id == id);
    if (i >= 0) {
      final w = _wishes[i];
      _wishes[i] = MealWish(
        id: w.id,
        profileId: w.profileId,
        title: w.title,
        recipeId: w.recipeId,
        freeText: w.freeText,
        iconKey: w.iconKey,
        planned: true,
        plannedOn: onDate,
        plannedSlot: slot,
      );
    }
    return const Ok(null);
  }

  @override
  Future<Result<List<FamilyQuestion>>> questions() async => Ok([..._questions]);

  @override
  Future<Result<void>> addQuestion({
    required String? actor,
    required String text,
  }) async {
    _questions.add(
      FamilyQuestion(id: 'q-own-${++_next}', text: text, createdBy: actor),
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> hideQuestion({
    required String? actor,
    required String key,
    bool hidden = true,
  }) async {
    _questions.removeWhere((q) => q.hiddenKey == key);
    if (hidden) {
      _questions.add(FamilyQuestion(id: 'q-hide-${++_next}', hiddenKey: key));
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> removeQuestion({
    required String? actor,
    required String id,
  }) async {
    _questions.removeWhere((q) => q.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<WeekReview>> weekReview(DateTime weekStart) async => Ok(
    WeekReview(
      weekStart: weekStart,
      choresDone: 23,
      members: [
        WeekHighlight(
          profileId: DemoData.papa,
          kind: HighlightKind.cooked,
          title: demoText('Spaghetti'),
        ),
        const WeekHighlight(
          profileId: DemoData.mama,
          kind: HighlightKind.helped,
        ),
        WeekHighlight(
          profileId: DemoData.daughter,
          kind: HighlightKind.badge,
          title: demoText('Spülmaschinen-Profi'),
        ),
        WeekHighlight(
          profileId: DemoData.son,
          kind: HighlightKind.wish,
          title: demoText('Pfannkuchen'),
        ),
      ],
      meals: [
        WeekMeal(
          onDate: weekStart,
          slot: 'dinner',
          title: demoText('Spaghetti'),
        ),
        WeekMeal(
          onDate: weekStart.add(const Duration(days: 2)),
          slot: 'dinner',
          title: demoText('Pfannkuchen'),
          wishedBy: DemoData.son,
        ),
        WeekMeal(
          onDate: weekStart.add(const Duration(days: 4)),
          slot: 'dinner',
          title: demoText('Gemüsecurry'),
          firstTime: true,
        ),
      ],
    ),
  );
}
