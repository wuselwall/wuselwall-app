import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_english.dart';
import 'package:wuselwall/features/rituals/data/rituals_repository.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';

/// The rituals of the demo family (specs/27): Wednesday's chili is the son's wish, the
/// one the wall and the meal plan show with his star, and his next wish, pancakes,
/// waits in the planner's tray. The daughter added a table question of her own, and the
/// week has a look-back with one line for everyone, made of this week's meals.
class DemoRitualsRepository implements RitualsRepository {
  DemoRitualsRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  var _next = 2;

  DateTime get _monday {
    final now = _clock();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  late final _wishes = <MealWish>[
    MealWish(
      id: 'w-1',
      profileId: DemoData.son,
      title: demoText('Chili sin Carne'),
      freeText: demoText('Chili sin Carne'),
      planned: true,
      plannedOn: DateTime(_monday.year, _monday.month, _monday.day + 2),
      plannedSlot: 'dinner',
    ),
    MealWish(
      id: 'w-2',
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
    String? wishId,
  }) async {
    final who = actor ?? DemoData.daughter;
    // One open wish each, as the default `meals.wishes_per_week`: a new one changes it.
    _wishes
      ..removeWhere(
        (w) => wishId == null
            ? w.profileId == who && !w.planned
            : w.id == wishId && !w.planned,
      )
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
    bool replace = false,
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
          title: demoText('Nudelauflauf'),
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
          title: demoText('Chili sin Carne'),
        ),
      ],
      // The meals of the demo's meal plan, the son's wish on Wednesday.
      meals: [
        for (final (day, slot, dish, wishedBy, firstTime) in [
          (0, 'dinner', 'Kürbissuppe', null, false),
          (1, 'dinner', 'Nudelauflauf', null, false),
          (2, 'dinner', 'Chili sin Carne', DemoData.son, false),
          (3, 'dinner', 'Fischstäbchen', null, false),
          (5, 'lunch', 'Nudeln mit Pesto', null, true),
          (6, 'lunch', 'Rinderbraten', null, false),
        ])
          WeekMeal(
            onDate: DateTime(
              weekStart.year,
              weekStart.month,
              weekStart.day + day,
            ),
            slot: slot,
            title: demoText(dish),
            wishedBy: wishedBy,
            firstTime: firstTime,
          ),
      ],
    ),
  );
}
