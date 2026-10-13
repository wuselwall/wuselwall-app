import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

import '../support/fake_school.dart';
import '../support/fakes.dart';

Finder _struck(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      w.data == text &&
      w.style?.decoration == TextDecoration.lineThrough,
);

/// Opens the Stundenplan tab of the adult home.
Future<void> _openSchedule(WidgetTester t) async {
  await t.tap(find.text('Stundenplan'));
  await t.pumpAndSettle();
}

final de = lookupAppLocalizations(const Locale('de'));

void main() {
  group('repository parsing', () {
    test('a school-week reply becomes timetables and projected days', () {
      final week = SchoolWeek.fromJson({
        'timetables': [
          {
            'member_id': 'p-kid',
            'class_label': '3b',
            'school_name': 'Schule',
            'periods': [
              {
                'index': 1,
                'starts': '08:00',
                'ends': '08:45',
                'kind': 'lesson',
              },
            ],
          },
        ],
        'days': [
          {
            'date': '2026-10-12',
            'member_id': 'p-kid',
            'starts': '08:00',
            'ends': '08:45',
            'notable': <String>[],
            'lessons': [
              {
                'period': 1,
                'starts': '08:00',
                'ends': '08:45',
                'subject': 'Mathematik',
                'short': 'Ma',
                'kind': 'lesson',
                'status': 'cancelled',
                'notable': false,
              },
            ],
          },
        ],
      });
      expect(week.timetableOf('p-kid')?.classLabel, '3b');
      final day = week.dayOf('p-kid', DateTime(2026, 10, 12));
      expect(day?.lessons.single.status, LessonStatus.cancelled);
      expect(day?.hasSchool, isTrue);
    });

    test('a lessons-set row carries the grid fields the server reads', () {
      final json = LessonRecord(
        id: '',
        timetableId: 'tt-kid',
        weekday: 2,
        periodIndex: 3,
        subjectId: 'sub-sp',
        room: 'Turnhalle',
        weekParity: 'a',
      ).toJson();
      expect(json, containsPair('weekday', 2));
      expect(json, containsPair('period_index', 3));
      expect(json, containsPair('subject_id', 'sub-sp'));
      expect(json, containsPair('room', 'Turnhalle'));
      expect(json, containsPair('week_parity', 'a'));
      expect(json.containsKey('is_notable'), isFalse);
    });
  });

  testWidgets(
    'the section draws the week grid with a cancelled lesson struck through and the pack line',
    (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        school: FakeSchoolRepository(),
      );
      await _openSchedule(t);

      expect(find.text('Anna'), findsWidgets);
      expect(
        _struck('Ma'),
        findsOneWidget,
        reason: 'Mathe fällt am Mittwoch aus',
      );
      expect(find.text('Entfall'), findsOneWidget);
      expect(find.text('Morgen einpacken: Sportsachen'), findsOneWidget);
    },
  );

  testWidgets(
    'a long press on a lesson opens the sheet, and Fällt aus saves the exception',
    (t) async {
      final school = FakeSchoolRepository();
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        school: school,
      );
      await _openSchedule(t);

      await t.longPress(find.byKey(const ValueKey('lesson-0-1')));
      await t.pumpAndSettle();
      await t.tap(find.text('Fällt aus'));
      await t.pumpAndSettle();

      final saved = school.exceptionSaves.single;
      expect(saved.kind, 'cancelled');
      expect(saved.periodIndex, 1);
      final monday = mondayOf(DateTime.now());
      expect(saved.onDate, monday);
      expect(saved.timetableId, 'tt-kid');
      expect(school.actors.single, guardianId);
    },
  );

  testWidgets(
    'the editor saves the grid with the lessons JSON of the cell that changed',
    (t) async {
      final school = FakeSchoolRepository();
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        school: school,
      );
      await _openSchedule(t);
      await t.tap(find.byTooltip(de.schoolEditTimetable));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('cell-1-1')));
      await t.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      await t.tap(find.descendant(of: dialog, matching: find.text('Sp')));
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)).at(1),
        'Turnhalle 2',
      );
      await t.tap(find.text('Übernehmen'));
      await t.pumpAndSettle();

      await t.tap(find.text('Stundenplan speichern'));
      await t.pumpAndSettle();

      final sent = school.lessonSets.single;
      expect(sent.timetableId, 'tt-kid');
      final cell = sent.lessons
          .where((l) => l.weekday == 1 && l.periodIndex == 1)
          .single;
      expect(cell.toJson(), containsPair('subject_id', 'sub-sp'));
      expect(cell.toJson(), containsPair('room', 'Turnhalle 2'));
      expect(cell.toJson(), containsPair('week_parity', 'all'));
      expect(
        sent.lessons.length,
        15,
        reason: 'the untouched cells are sent too',
      );
    },
  );

  testWidgets('the setup page saves the bell times', (t) async {
    final school = FakeSchoolRepository();
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: school,
    );
    await _openSchedule(t);
    await t.tap(find.byTooltip(de.schoolEditSchool));
    await t.pumpAndSettle();

    final bellsSave = find.text('Speichern').at(1);
    await t.ensureVisible(bellsSave);
    await t.tap(bellsSave);
    await t.pumpAndSettle();

    final periods = school.periodSets.single;
    expect(periods.where((p) => !p.isBreak).length, 3);
    expect(periods.where((p) => p.isBreak).length, 2);
    expect(periods.first.toJson(), containsPair('kind', 'lesson'));
  });

  testWidgets('without a school the section offers the setup', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: FakeSchoolRepository(
        data: referenceSchoolData(withSchool: false, withTimetable: false),
      ),
    );
    await _openSchedule(t);
    expect(find.text('Schule einrichten'), findsWidgets);
  });

  testWidgets('a child without a timetable offers its entry', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: FakeSchoolRepository(
        data: referenceSchoolData(withTimetable: false),
      ),
    );
    await _openSchedule(t);
    expect(find.text('Stundenplan eingeben'), findsWidgets);
  });
}
