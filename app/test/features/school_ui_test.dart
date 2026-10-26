import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
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

class _ControlledSchoolRepository extends FakeSchoolRepository {
  bool rejectPeriods = false;
  Completer<void>? gate;
  int attempts = 0;

  @override
  Future<Result<void>> setPeriods({
    required String? actor,
    required String schoolId,
    required List<PeriodRecord> periods,
  }) async {
    attempts++;
    await gate?.future;
    if (rejectPeriods) return const Err(NetworkFailure());
    return super.setPeriods(actor: actor, schoolId: schoolId, periods: periods);
  }
}

void main() {
  group('repository parsing', () {
    test('bell times request chronological order from the server', () async {
      final client = SupabaseClient(
        'https://example.org',
        'test-anon-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/school_periods');
          expect(
            request.url.queryParameters['order'],
            'starts_at.asc.nullslast',
          );
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await SchoolRepository(ApiClient(client)).periods();
      expect(
        result.isOk,
        isTrue,
        reason: result.failureOrNull?.cause.toString(),
      );
      expect(result.unwrap(), isEmpty);
    });

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

  testWidgets('a phone week shows icon and short code, never a cut word', (
    t,
  ) async {
    await pumpApp(
      t,
      size: const Size(390, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: FakeSchoolRepository(),
    );
    // Under 600 px the bar labels only the selected tab.
    await t.tap(find.byTooltip('Stundenplan'));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    // The short code stays, struck through when cancelled; room and change move
    // into the tooltip ("Tur…", "Ent…" no more).
    expect(_struck('Ma'), findsOneWidget);
    expect(find.text('Entfall'), findsNothing);
    expect(find.text('Turnhalle'), findsNothing);
    expect(find.byTooltip('Mathematik · R1 · Entfall'), findsOneWidget);
    expect(find.byTooltip(RegExp('^Sport · Turnhalle')), findsWidgets);
  });

  testWidgets('a break row shows its whole label, also at large text', (
    t,
  ) async {
    t.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: FakeSchoolRepository(),
    );
    await _openSchedule(t);

    expect(t.takeException(), isNull);
    final label = find.text(de.boardBreak);
    expect(label, findsWidgets);
    expect(t.getSize(label.first).height, greaterThanOrEqualTo(11));
  });

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

    expect(find.text(de.save), findsNothing);
    await t.ensureVisible(find.text(de.schoolAddLesson));
    await t.tap(find.text(de.schoolAddLesson));
    await t.pumpAndSettle();
    final bellsSave = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(de.save),
    );
    await t.ensureVisible(bellsSave);
    await t.tap(bellsSave);
    await t.pumpAndSettle();

    final periods = school.periodSets.single;
    expect(
      periods.map((p) => p.starts.hour * 60 + p.starts.minute),
      orderedEquals([480, 525, 530, 575, 595, 640]),
    );
    expect(periods.map((p) => p.index), [1, 1, 2, 2, 3, 4]);
    expect(periods.where((p) => !p.isBreak).length, 4);
    expect(periods.where((p) => p.isBreak).length, 2);
    expect(periods.first.toJson(), containsPair('kind', 'lesson'));
    expect(school.schoolSaves, isEmpty);
    expect(find.text(de.save), findsNothing);
  });

  testWidgets('school Save appears only for changes and saves both sections', (
    t,
  ) async {
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
    expect(find.text(de.save), findsNothing);
    final name = school.data.schools.first.name;
    await t.enterText(find.byType(TextField).first, 'Changed school');
    await t.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text(de.save)),
      findsOneWidget,
    );
    await t.enterText(find.byType(TextField).first, name);
    await t.pumpAndSettle();
    expect(find.text(de.save), findsNothing);
    await t.enterText(find.byType(TextField).first, 'Changed school');
    await t.ensureVisible(find.text(de.schoolAddLesson));
    await t.tap(find.text(de.schoolAddLesson));
    await t.pumpAndSettle();
    await t.tap(find.text(de.save));
    await t.pumpAndSettle();
    expect(school.schoolSaves.single.name, 'Changed school');
    expect(school.periodSets.single.where((p) => !p.isBreak), hasLength(4));
    expect(find.text(de.save), findsNothing);
  });

  testWidgets('adding and removing the same bell time clears unsaved changes', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: FakeSchoolRepository(),
    );
    await _openSchedule(t);
    await t.tap(find.byTooltip(de.schoolEditSchool));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text(de.schoolAddLesson));
    await t.tap(find.text(de.schoolAddLesson));
    await t.pumpAndSettle();
    expect(find.text(de.save), findsOneWidget);
    await t.ensureVisible(find.byTooltip(de.schoolRemove).last);
    await t.tap(find.byTooltip(de.schoolRemove).last);
    await t.pumpAndSettle();
    expect(find.text(de.save), findsNothing);
  });

  testWidgets(
    'failed bell save keeps changes and retries only unsaved sections',
    (t) async {
      final school = _ControlledSchoolRepository()..rejectPeriods = true;
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
      await t.enterText(find.byType(TextField).first, 'Changed school');
      await t.ensureVisible(find.text(de.schoolAddLesson));
      await t.tap(find.text(de.schoolAddLesson));
      await t.pumpAndSettle();
      await t.tap(find.text(de.save));
      await t.pumpAndSettle();
      expect(school.schoolSaves, hasLength(1));
      expect(school.periodSets, isEmpty);
      expect(find.text(de.save), findsOneWidget);
      school.rejectPeriods = false;
      await t.tap(find.text(de.save));
      await t.pumpAndSettle();
      expect(school.schoolSaves, hasLength(1));
      expect(school.periodSets, hasLength(1));
      expect(find.text(de.save), findsNothing);
    },
  );

  testWidgets('Save is disabled while a school write is pending', (t) async {
    final gate = Completer<void>();
    final school = _ControlledSchoolRepository()..gate = gate;
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
    await t.ensureVisible(find.text(de.schoolAddLesson));
    await t.tap(find.text(de.schoolAddLesson));
    await t.pumpAndSettle();
    await t.tap(find.text(de.save));
    await t.pump();
    expect(
      t.widget<TextButton>(find.widgetWithText(TextButton, de.save)).onPressed,
      isNull,
    );
    expect(school.attempts, 1);
    gate.complete();
    await t.pumpAndSettle();
    expect(find.text(de.save), findsNothing);
  });

  testWidgets('bell times line up: start and end on one line with tooltips', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: FakeSchoolRepository(),
    );
    await _openSchedule(t);
    // Phone width only for the setup page: the tab bar needs the default size.
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    await t.pumpAndSettle();
    await t.tap(find.byTooltip(de.schoolEditSchool));
    await t.pumpAndSettle();

    final start = find.byTooltip(de.schoolStart).first;
    final end = find.byTooltip(de.schoolEnd).first;
    expect(
      t.getCenter(start).dy,
      closeTo(t.getCenter(end).dy, 1),
      reason: 'the start and end times sit on the same line',
    );
    expect(t.takeException(), isNull);
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
