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
      await t.pumpAndSettle();
      await t.tap(find.text(de.save).first);
      await t.pumpAndSettle();

      final saved = school.schoolSaves.single;
      expect(saved.id, isNull);
      expect(saved.name, 'Gymnasium Lindenhof');
      expect(
        t.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Gymnasium Lindenhof',
      );
      expect(find.text(de.save), findsNothing);
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

    /// Saves the draft with the page's Save button.
    Future<void> save(WidgetTester t) async {
      final button = find.text(de.schoolSaveTimetable);
      expect(button.hitTestable(), findsOneWidget);
      await t.tap(button);
      await t.pumpAndSettle();
    }

    /// Text shown in one cell of the grid.
    Finder cellText(int weekday, int period, String text) => find.descendant(
      of: find.byKey(ValueKey('cell-$weekday-$period')),
      matching: find.text(text),
    );

    testWidgets('swap changes the grid only; Save sends the exchanged days', (
      t,
    ) async {
      final school = await openEditor(t);

      await t.tap(find.byTooltip(de.schoolsUiDayMenu).first);
      await t.pumpAndSettle();
      await t.tap(find.text(de.schoolsUiSwapDay));
      await t.pumpAndSettle();
      await t.tap(find.text('Freitag'));
      await t.pumpAndSettle();

      expect(cellText(1, 3, 'D'), findsOneWidget);
      expect(cellText(5, 3, 'Sp'), findsOneWidget);
      expect(
        school.lessonSets,
        isEmpty,
        reason: 'nothing is saved before Save',
      );

      await save(t);
      final swapped = school.lessonSets.single.lessons;
      expect(
        swapped
            .where((l) => l.weekday == 1 && l.periodIndex == 3)
            .single
            .toJson(),
        allOf(
          containsPair('subject_id', 'sub-d'),
          containsPair('room', 'Aula'),
        ),
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
    });

    testWidgets(
      'Undo after swap restores the draft, so Save sends the original',
      (t) async {
        final school = await openEditor(t);

        await t.tap(find.byTooltip(de.schoolsUiDayMenu).first);
        await t.pumpAndSettle();
        await t.tap(find.text(de.schoolsUiSwapDay));
        await t.pumpAndSettle();
        await t.tap(find.text('Freitag'));
        await t.pumpAndSettle();
        await t.tap(find.text(de.schoolsUiUndo));
        await t.pumpAndSettle();

        expect(cellText(1, 3, 'Sp'), findsOneWidget);
        expect(cellText(5, 3, 'D'), findsOneWidget);

        await save(t);
        final restored = school.lessonSets.single.lessons;
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
          allOf(
            containsPair('subject_id', 'sub-d'),
            containsPair('room', 'Aula'),
          ),
        );
      },
    );

    testWidgets(
      'copy changes the chosen day in the grid; Save sends the copy',
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

        expect(cellText(2, 3, 'D'), findsOneWidget);
        expect(cellText(5, 3, 'D'), findsOneWidget, reason: 'the source stays');
        expect(school.lessonSets, isEmpty);

        await save(t);
        final copied = school.lessonSets.single.lessons;
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
        );
      },
    );

    testWidgets('Undo after copy restores Tuesday in the draft', (t) async {
      final school = await openEditor(t);

      await t.tap(find.byTooltip(de.schoolsUiDayMenu).at(4));
      await t.pumpAndSettle();
      await t.tap(find.text(de.schoolsUiCopyDay));
      await t.pumpAndSettle();
      await t.tap(find.text('Dienstag'));
      await t.pumpAndSettle();
      await t.tap(find.text(de.schoolsUiCopyDayApply));
      await t.pumpAndSettle();
      await t.tap(find.text(de.schoolsUiUndo));
      await t.pumpAndSettle();

      expect(cellText(2, 3, 'Sp'), findsOneWidget);

      await save(t);
      expect(
        school.lessonSets.single.lessons
            .where((l) => l.weekday == 2 && l.periodIndex == 3)
            .single
            .toJson(),
        allOf(
          containsPair('subject_id', 'sub-sp'),
          containsPair('room', 'Turnhalle'),
        ),
      );
    });

    testWidgets(
      'clear day empties the grid draft, and Save sends the empty day',
      (t) async {
        final school = await openEditor(t);

        await t.tap(find.byTooltip(de.schoolsUiDayMenu).at(2));
        await t.pumpAndSettle();
        await t.tap(find.text(de.schoolClearDay));
        await t.pumpAndSettle();

        expect(cellText(3, 1, 'Ma'), findsNothing);
        expect(school.lessonSets, isEmpty);

        await save(t);
        expect(
          school.lessonSets.single.lessons.where((l) => l.weekday == 3),
          isEmpty,
        );
      },
    );
  });
}
