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

  group('ageOn', () {
    test('counts whole years, the birthday itself included', () {
      final b = DateTime(2018, 10, 24);
      expect(ageOn(b, DateTime(2026, 10, 23)), 7);
      expect(ageOn(b, DateTime(2026, 10, 24)), 8);
      expect(ageOn(b, DateTime(2026, 10, 24, 23, 59)), 8);
    });

    test(
      '29 February: reached on the day in a leap year, on 1 March in others',
      () {
        final b = DateTime(2016, 2, 29);
        expect(ageOn(b, DateTime(2024, 2, 28)), 7);
        expect(ageOn(b, DateTime(2024, 2, 29)), 8);
        expect(ageOn(b, DateTime(2027, 2, 28)), 10);
        expect(ageOn(b, DateTime(2027, 3, 1)), 11);
      },
    );
  });

  test('a birthday countdown knows the age turned on the day', () {
    final paul = _member('paul', birthday: DateTime(2018, 10, 27));
    final c = countdowns(today: today, horizonDays: 14, members: [paul]).single;
    expect(c.age, 8);
  });

  test('a birthday today counts 0 days and carries the new age', () {
    final paul = _member('paul', birthday: DateTime(2018, 10, 24));
    final c = countdowns(today: today, horizonDays: 14, members: [paul]).single;
    expect(c.daysFrom(today), 0);
    expect(c.age, 8);
  });

  test(
    'a birthday early in January is counted down to across the new year',
    () {
      final paul = _member('paul', birthday: DateTime(2019, 1, 2));
      final c = countdowns(
        today: DateTime(2026, 12, 30),
        horizonDays: 14,
        members: [paul],
      ).single;
      expect(c.date, DateTime(2027, 1, 2));
      expect(c.daysFrom(DateTime(2026, 12, 30)), 3);
      expect(c.age, 8);
    },
  );

  test('29 February counts down to 1 March in a common year, and to the day in a leap year', () {
    final leap = _member('leap', birthday: DateTime(2016, 2, 29));
    final common = countdowns(
      today: DateTime(2027, 2, 25),
      horizonDays: 14,
      members: [leap],
    ).single;
    expect(common.date, DateTime(2027, 3, 1));
    expect(common.age, 11);
    final leapYear = countdowns(
      today: DateTime(2028, 2, 25),
      horizonDays: 14,
      members: [leap],
    ).single;
    expect(leapYear.date, DateTime(2028, 2, 29));
    expect(leapYear.age, 12);
  });

  test('a baby born today has no age to tell yet', () {
    final baby = _member('baby', birthday: today);
    final c = countdowns(today: today, horizonDays: 14, members: [baby]).single;
    expect(c.age, isNull);
  });

  test('a recurring marked event counts down to its next occurrence only', () {
    Occurrence week(DateTime day) => Occurrence(
      id: 'pizza-${day.day}',
      eventId: 'pizza',
      calendarId: 'c',
      title: 'Pizza-Freitag',
      kind: EventKind.appointment,
      status: EventStatus.confirmed,
      importance: Importance.key,
      allDay: true,
      start: day,
      end: day,
      localStartDate: day,
      localEndDate: day,
      isRecurring: true,
      countdown: true,
    );
    final list = countdowns(
      today: today,
      horizonDays: 14,
      members: const [],
      occurrences: [
        week(DateTime(2026, 10, 23)),
        week(DateTime(2026, 11, 6)),
        week(DateTime(2026, 10, 30)),
      ],
    );
    // The one of last week is gone; of this week's and the next, only the nearest.
    expect(list.single.date, DateTime(2026, 10, 30));
  });

  test('a homecoming still counts on the last day, as "today"', () {
    final papa = _member('papa', child: false);
    final trip = _occ(
      'trip',
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 24),
      presence: PresenceState.travel,
      attendees: ['papa'],
    );
    final c = countdowns(
      today: today,
      horizonDays: 14,
      members: [papa],
      occurrences: [trip],
    ).single;
    expect(c.kind, CountdownKind.homecoming);
    expect(c.daysFrom(today), 0);
    expect(
      countdowns(
        today: DateTime(2026, 10, 25),
        horizonDays: 14,
        members: [papa],
        occurrences: [trip],
      ),
      isEmpty,
      reason: 'the day after, it is gone',
    );
  });

  test('a child away is not counted down to', () {
    final emma = _member('emma');
    final trip = _occ(
      'camp',
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 26),
      presence: PresenceState.travel,
      attendees: ['emma'],
    );
    expect(
      countdowns(
        today: today,
        horizonDays: 14,
        members: [emma],
        occurrences: [trip],
      ),
      isEmpty,
    );
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
