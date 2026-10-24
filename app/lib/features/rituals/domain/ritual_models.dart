import 'package:flutter/foundation.dart';
import 'package:wuselwall/features/board/domain/week_board.dart' show parseDate;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';

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
    this.wishedOn,
    this.earlierWeek = false,
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
    // Both absent on servers before 20261025130000: every wish reads as this week's.
    wishedOn: json['wished_on'] == null
        ? null
        : parseDate(json['wished_on'] as String),
    earlierWeek: json['earlier_week'] as bool? ?? false,
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

  /// The household day the wish was made or last changed.
  final DateTime? wishedOn;

  /// An open wish made before this household week began: the tray marks it "von letzter
  /// Woche" (specs/27). The server decides, in the household's time zone.
  final bool earlierWeek;
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

  /// A tradition or a key event they were at (computed in the app, see
  /// [withEventHighlights]).
  attended,
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

/// The highlights that give way to a tradition or key event a member was at: the plain
/// facts of a week (specs/27 lists "a tradition or key event they attended" after the
/// badges, streaks, rewards, wishes and days with everything done, and before the
/// fallback facts).
const _givesWayToEvents = {
  HighlightKind.cooked,
  HighlightKind.helped,
  HighlightKind.here,
};

/// [highlights] with "a tradition or key event they attended" put in (specs/27, card 2).
///
/// Recurring events are expanded only in the Edge Functions, never in SQL, so
/// `api.week_review` cannot see them; the story already reads the week's occurrences for
/// its traditions card, and the wall and the phones read the same ones, so this is
/// decided here, the way Vorfreude's countdowns are. A member whose line is one of the
/// plain facts gets the event instead: a tradition before a key event, the later one
/// first, only events that have begun by [today], never a cancelled, presence or
/// subscribed one. A tradition without attendees is the whole family's. The line names
/// the event and never counts anything (P10).
List<WeekHighlight> withEventHighlights(
  List<WeekHighlight> highlights,
  List<Occurrence> occurrences, {
  required DateTime weekStart,
  required DateTime today,
}) {
  final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
  final last = today.isBefore(weekEnd) ? today : weekEnd;
  final events =
      [
        for (final o in occurrences)
          if (!o.isPresence &&
              !o.isImported &&
              o.status != EventStatus.cancelled &&
              (o.tradition || o.importance == Importance.key) &&
              !o.localStartDate.isBefore(weekStart) &&
              !o.localStartDate.isAfter(last))
            o,
      ]..sort((a, b) {
        if (a.tradition != b.tradition) return a.tradition ? -1 : 1;
        return b.start.compareTo(a.start);
      });
  if (events.isEmpty) return highlights;
  return [
    for (final h in highlights)
      if (!_givesWayToEvents.contains(h.kind))
        h
      else if (events
              .where(
                (o) =>
                    o.attendeeIds.contains(h.profileId) ||
                    (o.tradition && o.attendeeIds.isEmpty),
              )
              .firstOrNull
          case final o?)
        WeekHighlight(
          profileId: h.profileId,
          kind: HighlightKind.attended,
          title: o.title,
          iconKey: o.iconKey,
        )
      else
        h,
  ];
}
