import 'package:flutter/foundation.dart';
import 'package:wuselwall/features/board/domain/week_board.dart'
    show PresenceState;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

/// Where a countdown comes from (specs/27 "Vorfreude").
enum CountdownKind {
  /// A member's birthday.
  birthday,

  /// The first day of the school holidays.
  ferien,

  /// An adult coming back from two nights or more away.
  homecoming,

  /// An event someone marked "Darauf freuen wir uns".
  event,
}

/// Something the family is looking forward to.
@immutable
class Countdown {
  const Countdown({
    required this.kind,
    required this.date,
    required this.title,
    this.memberId,
    this.iconKey,
    this.forMembers = const [],
    this.age,
  });

  final CountdownKind kind;

  /// The day it happens (local).
  final DateTime date;

  /// The event's or the holidays' name; for a birthday or a homecoming the member's
  /// display name (the screen words it).
  final String title;

  /// The member whose birthday or homecoming it is.
  final String? memberId;

  /// An event's content icon.
  final String? iconKey;

  /// Who it is for: an event's attendees. Empty means the whole family.
  final List<String> forMembers;

  /// For a birthday, the age the member turns on [date] ("Paul wird 8"); null for
  /// everything else, and for a birthday whose age is unknown or zero.
  final int? age;

  /// Whole days from [today] until it happens: 0 today, 1 tomorrow.
  int daysFrom(DateTime today) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

  /// Whether a child (or anyone) should see it among their own things.
  bool isFor(String profileId) =>
      forMembers.isEmpty || forMembers.contains(profileId);
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The next birthday of [birthday] on or after [today].
DateTime nextBirthday(DateTime birthday, DateTime today) {
  final t = _day(today);
  var next = DateTime(t.year, birthday.month, birthday.day);
  // A birthday on 29 February is celebrated on 1 March in other years (DateTime rolls
  // over), which is what most families do.
  if (next.isBefore(t)) {
    next = DateTime(t.year + 1, birthday.month, birthday.day);
  }
  return next;
}

/// How old someone born on [birthday] is on [date]: whole years, counting the
/// birthday itself. A 29 February birthday is reached on 1 March in other years, as
/// [nextBirthday] has it.
int ageOn(DateTime birthday, DateTime date) {
  final d = _day(date);
  final thisYear = DateTime(d.year, birthday.month, birthday.day);
  final age = d.year - birthday.year;
  return d.isBefore(thisYear) ? age - 1 : age;
}

/// Everything to look forward to from [today] until [horizonDays] ahead, nearest first
/// (specs/27 "Vorfreude"). Nothing in the past and nothing "missed": a countdown is
/// gone the day after.
List<Countdown> countdowns({
  required DateTime today,
  required int horizonDays,
  required List<Member> members,
  List<Occurrence> occurrences = const [],
  List<HolidayRecord> holidays = const [],
  bool homecomings = true,
  bool birthdays = true,
  bool ferien = true,
}) {
  final t = _day(today);
  // Calendar days, not 24-hour durations: a clock change must not move the edge.
  final last = DateTime(t.year, t.month, t.day + horizonDays);
  int nights(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
  bool within(DateTime d) => !d.isBefore(t) && !d.isAfter(last);
  final out = <Countdown>[];

  if (birthdays) {
    for (final m in members) {
      if (!m.active || m.birthday == null) continue;
      final next = nextBirthday(m.birthday!, t);
      if (within(next)) {
        final age = ageOn(m.birthday!, next);
        out.add(
          Countdown(
            kind: CountdownKind.birthday,
            date: next,
            title: m.displayName,
            memberId: m.id,
            iconKey: 'cake',
            age: age > 0 ? age : null,
          ),
        );
      }
    }
  }

  if (ferien) {
    final seen = <DateTime>{};
    for (final h in holidays) {
      if (h.kind != 'holiday') continue;
      final start = _day(h.startsOn);
      if (!within(start) || !seen.add(start)) continue;
      out.add(
        Countdown(
          kind: CountdownKind.ferien,
          date: start,
          title: h.name,
          iconKey: 'beach',
        ),
      );
    }
  }

  final adults = {
    for (final m in members)
      if (m.active && !m.isChild) m.id,
  };
  final byId = {for (final m in members) m.id: m};
  final seenEvents = <String>{};
  // Nearest first, whatever order they came in: a recurring event keeps only its next
  // occurrence below.
  final byStart = [...occurrences]
    ..sort((a, b) => a.localStartDate.compareTo(b.localStartDate));
  for (final o in byStart) {
    if (o.isImported) continue;
    if (homecomings &&
        o.isPresence &&
        o.presenceState == PresenceState.travel &&
        nights(o.localStartDate, o.localEndDate) >= 2 &&
        !o.localStartDate.isAfter(t) &&
        within(o.localEndDate)) {
      // Counted only while the person is away: "Papa ist in 2× schlafen zurück".
      for (final id in o.attendeeIds) {
        if (!adults.contains(id)) continue;
        out.add(
          Countdown(
            kind: CountdownKind.homecoming,
            date: _day(o.localEndDate),
            title: byId[id]!.displayName,
            memberId: id,
            iconKey: 'house',
          ),
        );
      }
      continue;
    }
    if (o.countdown && !o.isPresence && within(o.localStartDate)) {
      // A recurring event counts down to its next occurrence only.
      if (!seenEvents.add(o.eventId)) continue;
      out.add(
        Countdown(
          kind: CountdownKind.event,
          date: _day(o.localStartDate),
          title: o.title,
          iconKey: o.iconKey,
          forMembers: o.attendeeIds,
        ),
      );
    }
  }

  out.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.kind.index.compareTo(b.kind.index);
  });
  return out;
}
