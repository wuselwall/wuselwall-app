import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/kid/data/kid_badges_repository.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';

/// Pure rules of the kid register. Kept apart from the widgets so they can be read and
/// tested without a tree. Nothing here compares children with each other.

/// The day at local midnight.
DateTime kidDayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// The next calendar day at local midnight (no 24 h arithmetic across a DST change).
DateTime kidTomorrowOf(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// The chores a child sees: their own and the ones open for anyone. Open ones first,
/// then the ticked ones, so the child sees what is left.
List<TaskInstance> kidMyTasks(List<TaskInstance> all, String actor) {
  final mine = [
    for (final t in all)
      if (t.assignedProfileId == actor || t.assignedProfileId == null) t,
  ];
  return [...mine.where((t) => !t.isTicked), ...mine.where((t) => t.isTicked)];
}

/// The acting child's balance. Other members' balances never leave this function.
int kidBalanceOf(Map<String, int> balances, String actor) =>
    balances[actor] ?? 0;

/// Whether [lesson] is running at [minutesNow] (minutes since midnight).
bool kidLessonIsNow(Lesson lesson, int minutesNow) =>
    minutesOf(lesson.starts) <= minutesNow &&
    minutesNow < minutesOf(lesson.ends);

/// The appointments a child attends on [day]: never presence bands, always in the
/// order all-day first, then by start time.
List<Occurrence> kidEventsFor(
  List<Occurrence> all,
  String actor,
  DateTime day,
) {
  final mine = [
    for (final o in all)
      if (!o.isPresence && o.attendeeIds.contains(actor) && o.coversDay(day)) o,
  ];
  int key(TimeOfDay? t) => t == null ? -1 : minutesOf(t);
  mine.sort((a, b) => key(a.localStarts).compareTo(key(b.localStarts)));
  return mine;
}

/// Where a member is on the day at [index] of the board: the presence band that covers
/// it, else their usual place (today the slot at [nowMinutes]); outside the week, their
/// most common usual place. Null when neither says anything.
({PresenceState state, String? label})? kidPresenceOf(
  WeekBoard board,
  BoardMember member,
  int? index, {
  int? nowMinutes,
}) {
  if (index != null) {
    final band = board.presenceOn(member.id, index).firstOrNull;
    if (band != null) return (state: band.state, label: band.label);
    final usual = board.usualShownOn(member.id, index, nowMinutes: nowMinutes);
    if (usual == null) return null;
    return (state: usual.place.state, label: usual.place.label);
  }
  final baseline = member.baseline;
  if (baseline != null) return (state: baseline.state, label: baseline.label);
  return null;
}

/// What a reward card shows for the acting child.
enum KidRewardState {
  /// Not affordable yet: encouraging, with the missing points.
  needMore,

  /// Asked for and waiting for a guardian.
  waiting,
  soldOut,

  /// Affordable and free to ask for.
  ready,
}

KidRewardState kidRewardState({
  required int costPoints,
  required int balance,
  required bool waiting,
  required bool soldOut,
}) {
  if (waiting) return KidRewardState.waiting;
  if (soldOut) return KidRewardState.soldOut;
  if (balance < costPoints) return KidRewardState.needMore;
  return KidRewardState.ready;
}

/// Points still missing for a reward, never negative.
int kidPointsMissing(int costPoints, int balance) =>
    (costPoints - balance).clamp(0, costPoints);

/// Earned badges first, then the rest, at most [max] in all.
List<KidBadge> kidBadgeRow(List<KidBadge> badges, {int max = 8}) {
  final sorted = [...badges]
    ..sort((a, b) => (b.earned ? 1 : 0).compareTo(a.earned ? 1 : 0));
  return sorted.take(max).toList();
}

/// The streaks of the acting child that are running, with their chore's title. A streak
/// whose chore is no longer active is left out.
List<({int days, String title})> kidStreakRows({
  required List<Streak> streaks,
  required List<TaskDefinition> definitions,
  required String actor,
}) {
  final titles = {for (final d in definitions) d.id: d.title};
  return [
    for (final s in streaks)
      if (s.profileId == actor &&
          s.currentLength > 0 &&
          titles[s.definitionId] != null)
        (days: s.currentLength, title: titles[s.definitionId]!),
  ]..sort((a, b) => b.days.compareTo(a.days));
}

/// The one fact Wusel adds to a child's greeting (specs/25 "Where Wusel appears"):
/// the most useful thing about today, never a list.
sealed class KidFact {
  const KidFact();
}

/// It is the child's own birthday.
class KidBirthdayFact extends KidFact {
  const KidBirthdayFact();
}

/// Today is one of the family's traditions ("Pizza-Freitag").
class KidTraditionFact extends KidFact {
  const KidTraditionFact(this.title);

  final String title;
}

/// School starts with this subject; said until the first lesson begins.
class KidFirstLessonFact extends KidFact {
  const KidFirstLessonFact(this.subject);

  final String subject;
}

/// Today's warm meal.
class KidMealFact extends KidFact {
  const KidMealFact(this.slot, this.dish);

  final MealSlot slot;
  final String dish;
}

/// The nearest thing the child looks forward to.
class KidCountdownFact extends KidFact {
  const KidCountdownFact(this.countdown);

  final Countdown countdown;
}

/// Lunch stops being news at two (minutes since midnight).
const _lunchOver = 14 * 60;

/// The first useful fact of a child's day, in the order of specs/25: their own
/// birthday, today's tradition, the first lesson (until it starts), today's warm meal
/// (lunch until two), then the nearest countdown. Null when there is nothing to say.
KidFact? kidFirstFact({
  required bool ownBirthday,
  required int minutesNow,
  String? tradition,
  SchoolDay? school,
  BoardMeal? meal,
  Countdown? countdown,
}) {
  if (ownBirthday) return const KidBirthdayFact();
  if (tradition != null && tradition.trim().isNotEmpty) {
    return KidTraditionFact(tradition);
  }
  if (school != null && school.hasSchool) {
    final lessons = [
      for (final l in school.lessons)
        if (l.kind == LessonKind.lesson && l.status != LessonStatus.cancelled)
          l,
    ]..sort((a, b) => minutesOf(a.starts).compareTo(minutesOf(b.starts)));
    if (lessons.isNotEmpty && minutesNow < minutesOf(lessons.first.starts)) {
      return KidFirstLessonFact(lessons.first.subject);
    }
  }
  if (meal != null &&
      meal.title != null &&
      (meal.slot == MealSlot.dinner || minutesNow < _lunchOver)) {
    return KidMealFact(meal.slot, meal.title!);
  }
  if (countdown != null) return KidCountdownFact(countdown);
  return null;
}

/// The redemptions of [actor] that were waiting in [before] and that a grown-up has
/// since approved or handed over in [after]: a yes that arrived from another device.
List<String> kidNewlyApproved(
  List<RewardRedemption> before,
  List<RewardRedemption> after,
  String actor,
) {
  final waiting = {
    for (final r in before)
      if (r.profileId == actor && r.status == RedemptionStatus.requested) r.id,
  };
  return [
    for (final r in after)
      if (waiting.contains(r.id) &&
          (r.status == RedemptionStatus.approved ||
              r.status == RedemptionStatus.fulfilled))
        r.id,
  ];
}
