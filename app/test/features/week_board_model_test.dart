import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/demo/demo_board.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';

/// Pure model tests on the week board's read model, fed by the demo JSON (which is
/// shaped like `api.board_week`) and by small hand-written fragments.
void main() {
  late WeekBoard board;

  setUpAll(() async {
    board = (await DemoBoardRepository().week()).unwrap();
  });

  test('the demo week runs Monday to Sunday, starting this week', () {
    final now = DateTime.now();
    expect(board.days, hasLength(7));
    expect(board.weekStart.weekday, DateTime.monday);
    expect(
      board.weekStart,
      DateTime(now.year, now.month, now.day - (now.weekday - 1)),
    );
    for (var i = 0; i < 7; i++) {
      expect(
        board.days[i].date,
        DateTime(
          board.weekStart.year,
          board.weekStart.month,
          board.weekStart.day + i,
        ),
      );
    }
  });

  test('members come in household order with their kinds', () {
    expect(board.members.map((m) => m.id), [
      DemoData.lotta,
      DemoData.hanna,
      DemoData.mama,
      DemoData.papa,
    ]);
    expect(board.members.map((m) => m.kind), [
      MemberKind.child,
      MemberKind.child,
      MemberKind.adult,
      MemberKind.adult,
    ]);
    expect(
      board.member(DemoData.papa)!.baseline!.state,
      PresenceState.homeOffice,
    );
    expect(board.member(DemoData.lotta)!.baseline, isNull);
  });

  test('todayIndex is the weekday of now', () {
    expect(board.todayIndex, DateTime.now().weekday - 1);
  });

  test('presenceOn returns the travel band for Lukas on Thursday', () {
    final bands = board.presenceOn(DemoData.papa, 3);
    expect(bands, hasLength(1));
    expect(bands.single.state, PresenceState.travel);
    expect(bands.single.label, 'Dienstreise Berlin');
    expect(bands.single.dayCount, 2);
    expect(bands.single.starts, isNull);
  });

  test('presenceOn is empty on a day without bands', () {
    expect(board.presenceOn(DemoData.papa, 6), isEmpty);
    expect(board.presenceOn(DemoData.lotta, 0), isEmpty);
  });

  test('day parts split at the household settings', () {
    final settings = board.settings;
    expect(
      settings.partOf(const TimeOfDay(hour: 11, minute: 59)),
      DayPart.morning,
    );
    expect(
      settings.partOf(const TimeOfDay(hour: 12, minute: 0)),
      DayPart.afternoon,
    );
    expect(
      settings.partOf(const TimeOfDay(hour: 16, minute: 59)),
      DayPart.afternoon,
    );
    expect(
      settings.partOf(const TimeOfDay(hour: 17, minute: 0)),
      DayPart.evening,
    );
    expect(settings.partOf(null), DayPart.morning);
  });

  test('ISO week numbers, including the year edges', () {
    expect(isoWeekOf(DateTime(2026, 9, 2)), 36);
    expect(isoWeekOf(DateTime(2027, 1, 1)), 53);
    expect(isoWeekOf(DateTime(2026, 1, 1)), 1);
  });

  test('parseTime accepts seconds', () {
    expect(parseTime('08:30:00'), const TimeOfDay(hour: 8, minute: 30));
    expect(parseTime('08:30'), const TimeOfDay(hour: 8, minute: 30));
  });

  test('equipment leaves out cancelled lessons', () {
    final day = SchoolDay.fromJson({
      'member_id': 'x',
      'lessons': [
        {
          'starts': '08:00',
          'ends': '08:45',
          'subject': 'Sport',
          'status': 'cancelled',
          'equipment': 'Sportsachen',
        },
        {
          'starts': '08:50',
          'ends': '09:35',
          'subject': 'Schwimmen',
          'equipment': 'Schwimmzeug',
        },
      ],
    });
    expect(day.equipment, ['Schwimmzeug']);
  });

  test(
    'Lotta has a cancelled lesson on Friday, and its equipment still shows',
    () {
      final friday = board.days[4].school[DemoData.lotta]!;
      expect(
        friday.lessons.where((l) => l.status == LessonStatus.cancelled),
        isNotEmpty,
      );
      expect(friday.equipment, ['Sportsachen']);
    },
  );

  test('keyEvents leaves out the non-key appointments', () {
    final monday = board.days[0];
    expect(monday.events.map((e) => e.title), contains('Müll rausstellen'));
    expect(
      monday.keyEvents.map((e) => e.title),
      isNot(contains('Müll rausstellen')),
    );
    expect(monday.keyEvents.every((e) => e.isKey), isTrue);
  });

  test('a minimal board parses with defaults for the missing parts', () {
    final minimal = WeekBoard.fromJson({
      'week_start': '2026-10-12',
      'today': '2026-10-13',
      'generated_at': '2026-10-13T08:00:00Z',
      'members': <Object>[],
      'presence': <Object>[],
      'timetables': <Object>[],
      'days': [
        {'date': '2026-10-12', 'events': <Object>[], 'school': <Object>[]},
      ],
    });
    expect(minimal.settings.morningEnds, const TimeOfDay(hour: 12, minute: 0));
    expect(
      minimal.settings.eveningStarts,
      const TimeOfDay(hour: 17, minute: 0),
    );
    expect(minimal.days.single.meal, isNull);
    expect(minimal.openTasks, isEmpty);
    expect(minimal.shoppingCount, 0);
    expect(minimal.todayIndex, 1);
  });

  test('a presence band carries the edges of the week', () {
    final band = PresenceBand.fromJson({
      'id': 'b',
      'member_id': DemoData.papa,
      'state': 'travel',
      'first_day': '2026-10-12',
      'last_day': '2026-10-18',
      'starts_before_week': true,
      'ends_after_week': true,
    });
    expect(band.startsBeforeWeek, isTrue);
    expect(band.endsAfterWeek, isTrue);
    expect(band.tentative, isFalse);
    expect(band.dayCount, 7);
  });
}
