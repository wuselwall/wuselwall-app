import 'package:flutter/foundation.dart';
import 'package:wuselwall/features/board/domain/week_board.dart' show parseDate;

/// A child's meal wish (specs/27 "Wunschessen"), a row of `api.meal_wishes`. Open until a
/// grown-up puts it on the plan; never declined.
@immutable
class MealWish {
  const MealWish({
    required this.id,
    required this.profileId,
    required this.title,
    this.recipeId,
    this.freeText,
    this.iconKey,
    this.planned = false,
    this.plannedOn,
    this.plannedSlot,
  });

  factory MealWish.fromJson(Map<String, dynamic> json) => MealWish(
    id: json['id'] as String,
    profileId: json['profile_id'] as String,
    title: json['title'] as String? ?? json['free_text'] as String? ?? '',
    recipeId: json['recipe_id'] as String?,
    freeText: json['free_text'] as String?,
    iconKey: json['icon_key'] as String?,
    planned: json['status'] == 'planned',
    plannedOn: json['planned_on'] == null
        ? null
        : parseDate(json['planned_on'] as String),
    plannedSlot: json['planned_slot'] as String?,
  );

  final String id;
  final String profileId;
  final String title;
  final String? recipeId;
  final String? freeText;
  final String? iconKey;
  final bool planned;
  final DateTime? plannedOn;
  final String? plannedSlot;
}

/// A row of `api.table_questions`: the family's own question, or a bundled one it hid.
@immutable
class FamilyQuestion {
  const FamilyQuestion({
    required this.id,
    this.text,
    this.hiddenKey,
    this.createdBy,
  });

  factory FamilyQuestion.fromJson(Map<String, dynamic> json) => FamilyQuestion(
    id: json['id'] as String,
    text: json['text'] as String?,
    hiddenKey: json['hidden_key'] as String?,
    createdBy: json['created_by_profile_id'] as String?,
  );

  final String id;
  final String? text;

  /// `de:q-0042` for a hidden bundled question.
  final String? hiddenKey;
  final String? createdBy;
}

/// What a member's line of the look-back says (specs/27 "Wochenrückblick"). Never a number.
enum HighlightKind {
  badge,
  streak,
  allDone,
  reward,
  wish,
  cooked,
  helped,
  here,
}

@immutable
class WeekHighlight {
  const WeekHighlight({
    required this.profileId,
    required this.kind,
    this.title,
    this.iconKey,
  });

  factory WeekHighlight.fromJson(Map<String, dynamic> json) {
    final h = (json['highlight'] as Map).cast<String, dynamic>();
    return WeekHighlight(
      profileId: json['profile_id'] as String,
      kind: switch (h['kind']) {
        'badge' => HighlightKind.badge,
        'streak' => HighlightKind.streak,
        'all_done' => HighlightKind.allDone,
        'reward' => HighlightKind.reward,
        'wish' => HighlightKind.wish,
        'cooked' => HighlightKind.cooked,
        'helped' => HighlightKind.helped,
        _ => HighlightKind.here,
      },
      title: h['title'] as String?,
      iconKey: h['icon_key'] as String?,
    );
  }

  final String profileId;
  final HighlightKind kind;
  final String? title;
  final String? iconKey;
}

@immutable
class WeekMeal {
  const WeekMeal({
    required this.onDate,
    required this.slot,
    required this.title,
    this.wishedBy,
    this.firstTime = false,
  });

  factory WeekMeal.fromJson(Map<String, dynamic> json) => WeekMeal(
    onDate: parseDate(json['on_date'] as String),
    slot: json['slot'] as String,
    title: json['title'] as String? ?? '',
    wishedBy: json['wished_by_profile_id'] as String?,
    firstTime: json['first_time'] as bool? ?? false,
  );

  final DateTime onDate;
  final String slot;
  final String title;
  final String? wishedBy;
  final bool firstTime;
}

/// `api.week_review`: the family's week in one document.
@immutable
class WeekReview {
  const WeekReview({
    required this.weekStart,
    required this.choresDone,
    required this.members,
    required this.meals,
  });

  factory WeekReview.fromJson(Map<String, dynamic> json) => WeekReview(
    weekStart: parseDate(json['week_start'] as String),
    choresDone: (json['chores_done'] as num?)?.toInt() ?? 0,
    members: [
      for (final m in (json['members'] as List?) ?? const [])
        WeekHighlight.fromJson((m as Map).cast<String, dynamic>()),
    ],
    meals: [
      for (final m in (json['meals'] as List?) ?? const [])
        WeekMeal.fromJson((m as Map).cast<String, dynamic>()),
    ],
  );

  final DateTime weekStart;

  /// The family's chores done that week: one number, the family's.
  final int choresDone;

  /// One line per active member, in board order.
  final List<WeekHighlight> members;
  final List<WeekMeal> meals;
}
