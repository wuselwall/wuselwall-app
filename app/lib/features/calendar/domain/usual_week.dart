import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';

/// One place of a member's usual week (`api.usual_weeks.slots`): a weekday of week A
/// (or every week) or of week B, for the whole day or for one time slot.
class UsualSlot {
  const UsualSlot({required this.weekday, required this.place, this.week = 0});

  factory UsualSlot.fromJson(Map<String, dynamic> json) => UsualSlot(
    week: json['week'] as int? ?? 0,
    weekday: json['weekday'] as int,
    place: UsualPlace.fromJson(json),
  );

  /// 0: week A, or every week without an anchor; 1: week B.
  final int week;

  /// ISO: 1 = Monday … 7 = Sunday.
  final int weekday;
  final UsualPlace place;

  /// The element `api.member_usual_week_set` takes.
  Map<String, dynamic> toJson() => {
    'week': week,
    'weekday': weekday,
    'state': place.state.wire,
    'label': place.label,
    'starts': place.starts == null ? null : clockOf(place.starts!),
    'ends': place.ends == null ? null : clockOf(place.ends!),
  };
}

/// A member's usual week (issue #81, specs/15 "The baseline"), as the editor holds it.
class UsualWeek {
  const UsualWeek({
    required this.profileId,
    this.anchor,
    this.slots = const [],
  });

  factory UsualWeek.fromJson(Map<String, dynamic> json) => UsualWeek(
    profileId: json['profile_id'] as String,
    anchor: json['anchor'] == null ? null : parseDate(json['anchor'] as String),
    slots: [
      for (final s in (json['slots'] as List? ?? const []))
        UsualSlot.fromJson(s as Map<String, dynamic>),
    ],
  );

  final String profileId;

  /// The Monday of a week A; null when every week is the same.
  final DateTime? anchor;
  final List<UsualSlot> slots;

  /// The places of [weekday] in [week], in time order (a whole day first).
  List<UsualPlace> day(int weekday, {int week = 0}) => [
    for (final s in slots)
      if (s.week == week && s.weekday == weekday) s.place,
  ]..sort((a, b) => _order(a).compareTo(_order(b)));

  /// This week with [weekday] of [week] replaced by [places]; the other days and
  /// weeks stay as they are.
  UsualWeek withDay(int weekday, List<UsualPlace> places, {int week = 0}) =>
      UsualWeek(
        profileId: profileId,
        anchor: anchor,
        slots: [
          for (final s in slots)
            if (s.week != week || s.weekday != weekday) s,
          for (final p in places)
            UsualSlot(week: week, weekday: weekday, place: p),
        ],
      );

  /// This week alternating from [anchor] (the Monday of a week A), or, with null, the
  /// same every week. Week B stays, unused without an anchor, so switching alternating
  /// on again brings it back.
  UsualWeek withAnchor(DateTime? anchor) =>
      UsualWeek(profileId: profileId, anchor: anchor, slots: slots);

  /// 0 for week A (or every week without an anchor), 1 for week B, counted from the
  /// anchor as the server counts (`_shared/usual_week.ts`).
  int weekOf(DateTime date) {
    final a = anchor;
    if (a == null) return 0;
    final monday = DateTime.utc(
      date.year,
      date.month,
      date.day - (date.weekday - 1),
    );
    final weeks =
        (monday.difference(DateTime.utc(a.year, a.month, a.day)).inDays / 7)
            .round();
    return weeks.isEven ? 0 : 1;
  }

  static int _order(UsualPlace p) =>
      p.starts == null ? -1 : minutesOf(p.starts!);
}

/// Whether [places] can be one day of a usual week, as `api.member_usual_week_set`
/// checks it: nothing, one whole-day place, or up to three time slots that each end
/// after they start and do not overlap.
bool usualDayValid(List<UsualPlace> places) {
  if (places.length == 1 && places.single.isWholeDay) return true;
  if (places.length > 3 || places.any((p) => p.isWholeDay || p.ends == null)) {
    return false;
  }
  final sorted = [...places]
    ..sort((a, b) => minutesOf(a.starts!).compareTo(minutesOf(b.starts!)));
  for (var i = 0; i < sorted.length; i++) {
    if (minutesOf(sorted[i].starts!) >= minutesOf(sorted[i].ends!)) {
      return false;
    }
    if (i > 0 &&
        minutesOf(sorted[i].starts!) < minutesOf(sorted[i - 1].ends!)) {
      return false;
    }
  }
  return true;
}
