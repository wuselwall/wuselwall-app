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

  static int _order(UsualPlace p) =>
      p.starts == null ? -1 : minutesOf(p.starts!);
}
