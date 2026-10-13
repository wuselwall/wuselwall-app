import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/kid/data/kid_badges_repository.dart';
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
/// it, else their baseline. Null when neither says anything.
({PresenceState state, String? label})? kidPresenceOf(
  WeekBoard board,
  BoardMember member,
  int? index,
) {
  if (index != null) {
    final band = board.presenceOn(member.id, index).firstOrNull;
    if (band != null) return (state: band.state, label: band.label);
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
