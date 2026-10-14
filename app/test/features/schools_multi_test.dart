import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';

import '../support/fake_school.dart';
import '../support/fakes.dart';

/// Opens the Stundenplan tab of the adult home.
Future<void> _openSchedule(WidgetTester t) async {
  await t.tap(find.text('Stundenplan'));
  await t.pumpAndSettle();
}

Future<void> _pump(WidgetTester t, FakeSchoolRepository school) => pumpApp(
  t,
  overrides: baseOverrides(identity: FakeIdentityRepository(current: device())),
  school: school,
);

final de = lookupAppLocalizations(const Locale('de'));

void main() {
  testWidgets(
    'switching schools in the setup shows that school\'s bell times',
    (t) async {
      final school = FakeSchoolRepository(
        data: referenceSchoolData(secondSchool: true),
      );
      await _pump(t, school);
      await _openSchedule(t);
      await t.tap(find.byTooltip(de.schoolEditSchool));
      await t.pumpAndSettle();

      expect(find.textContaining('8:00'), findsOneWidget);
      expect(find.textContaining('7:45'), findsNothing);

      await t.tap(find.text('Gymnasium Lindenhof'));
      await t.pumpAndSettle();

      expect(find.textContaining('7:45'), findsOneWidget);
      expect(find.textContaining('8:00'), findsNothing);
    },
  );

  testWidgets(
    'adding a second school saves it without a timezone and selects it',
    (t) async {
      final school = FakeSchoolRepository();
      await _pump(t, school);
      await _openSchedule(t);
      await t.tap(find.byTooltip(de.schoolEditSchool));
      await t.pumpAndSettle();

      await t.tap(find.text(de.schoolsUiAddSchool));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Gymnasium Lindenhof');
      await t.tap(find.text(de.save).first);
      await t.pumpAndSettle();

      final saved = school.schoolSaves.single;
      expect(saved.id, isNull);
      expect(saved.name, 'Gymnasium Lindenhof');
      expect(
        saved.timezone,
        isNull,
        reason: 'the server takes the household timezone for a new school',
      );
      expect(school.data.schools, hasLength(2));
      expect(
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text('Grundschule Lindenhof'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text('Gymnasium Lindenhof'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a timetable for a child asks the school when there are two', (
    t,
  ) async {
    final school = FakeSchoolRepository(
      data: referenceSchoolData(secondSchool: true),
    );
    await _pump(t, school);
    await _openSchedule(t);
    await t.tap(find.byTooltip(de.schoolEditTimetable));
    await t.pumpAndSettle();

    expect(find.text(de.schoolsUiAskSchool), findsOneWidget);
    await t.tap(find.text('Gymnasium Lindenhof'));
    await t.pumpAndSettle();

    expect(
      find.text(de.schoolsUiSchoolOf('Gymnasium Lindenhof')),
      findsOneWidget,
    );
  });

  group('day operations in the editor', () {
    /// Opens the editor on the varied reference timetable (Friday's third lesson is
    /// the Aula's German, the others are Sport in the Turnhalle).
    Future<FakeSchoolRepository> openEditor(WidgetTester t) async {
      final school = FakeSchoolRepository(
        data: referenceSchoolData(varied: true),
      );
      await _pump(t, school);
      await _openSchedule(t);
      await t.tap(find.byTooltip(de.schoolEditTimetable));
      await t.pumpAndSettle();
      return school;
    }

    testWidgets('swap saves the exchanged days, and Undo saves them back', (
      t,
    ) async {
      final school = await openEditor(t);

      await t.tap(find.byTooltip(de.schoolsUiDayMenu).first);
      await t.pumpAndSettle();
      await t.tap(find.text(de.schoolsUiSwapDay));
      await t.pumpAndSettle();
      await t.tap(find.text('Freitag'));
      await t.pumpAndSettle();

      final swapped = school.lessonSets.last.lessons;
      expect(
        swapped
            .where((l) => l.weekday == 1 && l.periodIndex == 3)
            .single
            .toJson(),
        containsPair('subject_id', 'sub-d'),
      );
      expect(
        swapped
            .where((l) => l.weekday == 5 && l.periodIndex == 3)
            .single
            .toJson(),
        allOf(
          containsPair('subject_id', 'sub-sp'),
          containsPair('room', 'Turnhalle'),
        ),
      );
      expect(
        swapped.where((l) => l.weekday == 2).length,
        3,
        reason: 'untouched',
      );

      await t.tap(find.text(de.schoolsUiUndo));
      await t.pumpAndSettle();

      final restored = school.lessonSets.last.lessons;
      expect(
        restored
            .where((l) => l.weekday == 1 && l.periodIndex == 3)
            .single
            .toJson(),
        allOf(
          containsPair('subject_id', 'sub-sp'),
          containsPair('room', 'Turnhalle'),
        ),
      );
      expect(
        restored
            .where((l) => l.weekday == 5 && l.periodIndex == 3)
            .single
            .toJson(),
        containsPair('subject_id', 'sub-d'),
      );
    });

    testWidgets(
      'copy replaces the chosen day with a copy of Friday, Undo restores it',
      (t) async {
        final school = await openEditor(t);

        await t.tap(find.byTooltip(de.schoolsUiDayMenu).at(4));
        await t.pumpAndSettle();
        await t.tap(find.text(de.schoolsUiCopyDay));
        await t.pumpAndSettle();
        await t.tap(find.text('Dienstag'));
        await t.pumpAndSettle();
        await t.tap(find.text(de.schoolsUiCopyDayApply));
        await t.pumpAndSettle();

        final copied = school.lessonSets.last.lessons;
        final tuesday = copied.where((l) => l.weekday == 2).toList();
        expect(tuesday, hasLength(3));
        expect(
          tuesday.where((l) => l.periodIndex == 3).single.toJson(),
          allOf(
            containsPair('subject_id', 'sub-d'),
            containsPair('room', 'Aula'),
          ),
        );
        expect(
          copied
              .where((l) => l.weekday == 5 && l.periodIndex == 3)
              .single
              .toJson(),
          containsPair('subject_id', 'sub-d'),
          reason: 'the source day stays',
        );

        await t.tap(find.text(de.schoolsUiUndo));
        await t.pumpAndSettle();

        final restored = school.lessonSets.last.lessons;
        expect(
          restored
              .where((l) => l.weekday == 2 && l.periodIndex == 3)
              .single
              .toJson(),
          allOf(
            containsPair('subject_id', 'sub-sp'),
            containsPair('room', 'Turnhalle'),
          ),
        );
      },
    );

    testWidgets('clear day saves the empty day and Undo brings it back', (
      t,
    ) async {
      final school = await openEditor(t);

      await t.tap(find.byTooltip(de.schoolsUiDayMenu).at(2));
      await t.pumpAndSettle();
      await t.tap(find.text(de.schoolClearDay));
      await t.pumpAndSettle();

      expect(
        school.lessonSets.last.lessons.where((l) => l.weekday == 3),
        isEmpty,
      );

      await t.tap(find.text(de.schoolsUiUndo));
      await t.pumpAndSettle();

      expect(
        school.lessonSets.last.lessons.where((l) => l.weekday == 3),
        hasLength(3),
      );
    });
  });
}
