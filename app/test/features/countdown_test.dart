import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/board/domain/week_board.dart'
    show PresenceState;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

Member _member(String id, {DateTime? birthday, bool child = true}) => Member(
  id: id,
  displayName: id,
  color: const Color(0xFF7B3FE4),
  role: Role.member,
  active: true,
  isChild: child,
  birthday: birthday,
);

Occurrence _occ(
  String id,
  DateTime from,
  DateTime to, {
  bool countdown = false,
  PresenceState? presence,
  List<String> attendees = const [],
}) => Occurrence(
  id: id,
  eventId: id,
  calendarId: 'c',
  title: id,
  kind: presence == null ? EventKind.appointment : EventKind.presence,
  presenceState: presence,
  status: EventStatus.confirmed,
  importance: Importance.normal,
  allDay: true,
  start: from,
  end: to,
  localStartDate: from,
  localEndDate: to,
  attendeeIds: attendees,
  countdown: countdown,
);

void main() {
  final today = DateTime(2026, 10, 24);

  test('a birthday counts down from the horizon and is gone the day after', () {
    final olivia = _member('olivia', birthday: DateTime(2016, 10, 27));
    final list = countdowns(today: today, horizonDays: 14, members: [olivia]);
    expect(list.single.kind, CountdownKind.birthday);
    expect(list.single.daysFrom(today), 3);
    expect(
      countdowns(
        today: DateTime(2026, 10, 28),
        horizonDays: 14,
        members: [olivia],
      ),
      isEmpty,
    );
    expect(
      countdowns(today: today, horizonDays: 2, members: [olivia]),
      isEmpty,
    );
  });

  test('a birthday on 29 February comes round every year', () {
    expect(
      nextBirthday(DateTime(2016, 2, 29), DateTime(2027, 2, 20)),
      DateTime(2027, 3, 1),
    );
  });

  test('the holidays count down to their first day, once per date', () {
    final h = [
      HolidayRecord(
        id: 'a',
        name: 'Herbstferien',
        startsOn: DateTime(2026, 10, 29),
        endsOn: DateTime(2026, 11, 6),
      ),
      HolidayRecord(
        id: 'b',
        schoolId: 's2',
        name: 'Herbstferien',
        startsOn: DateTime(2026, 10, 29),
        endsOn: DateTime(2026, 11, 6),
      ),
    ];
    final list = countdowns(
      today: today,
      horizonDays: 14,
      members: const [],
      holidays: h,
    );
    expect(list.single.kind, CountdownKind.ferien);
    expect(list.single.daysFrom(today), 5);
  });

  test('a parent away two nights or more counts down to the way home', () {
    final papa = _member('papa', child: false);
    final trip = _occ(
      'trip',
      DateTime(2026, 10, 22),
      DateTime(2026, 10, 26),
      presence: PresenceState.travel,
      attendees: ['papa'],
    );
    final list = countdowns(
      today: today,
      horizonDays: 14,
      members: [papa],
      occurrences: [trip],
    );
    expect(list.single.kind, CountdownKind.homecoming);
    expect(list.single.daysFrom(today), 2);
    // Not before they have left, and not when the household switched it off.
    expect(
      countdowns(
        today: DateTime(2026, 10, 20),
        horizonDays: 14,
        members: [papa],
        occurrences: [trip],
      ),
      isEmpty,
    );
    expect(
      countdowns(
        today: today,
        horizonDays: 14,
        members: [papa],
        occurrences: [trip],
        homecomings: false,
      ),
      isEmpty,
    );
  });

  test('a marked event counts down to its next occurrence only', () {
    final zoo1 = _occ(
      'zoo',
      DateTime(2026, 10, 31),
      DateTime(2026, 10, 31),
      countdown: true,
      attendees: ['olivia'],
    );
    final unmarked = _occ(
      'dentist',
      DateTime(2026, 10, 25),
      DateTime(2026, 10, 25),
    );
    final list = countdowns(
      today: today,
      horizonDays: 14,
      members: const [],
      occurrences: [zoo1, unmarked],
    );
    expect(list.map((c) => c.title), ['zoo']);
    expect(list.single.isFor('olivia'), isTrue);
    expect(list.single.isFor('jack'), isFalse);
  });

  test('nearest first', () {
    final list = countdowns(
      today: today,
      horizonDays: 30,
      members: [
        _member('a', birthday: DateTime(2016, 11, 10)),
        _member('b', birthday: DateTime(2018, 10, 25)),
      ],
    );
    expect(list.map((c) => c.title), ['b', 'a']);
  });

  test('the horizon counts calendar days across a clock change', () {
    // The clocks go back on 25 October 2026 in Europe; 7 November is 14 days on.
    final list = countdowns(
      today: DateTime(2026, 10, 24),
      horizonDays: 14,
      members: [_member('a', birthday: DateTime(2016, 11, 7))],
    );
    expect(list.single.daysFrom(DateTime(2026, 10, 24)), 14);
  });
}
