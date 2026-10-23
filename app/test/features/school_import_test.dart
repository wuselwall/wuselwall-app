import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';

import '../support/fake_school.dart';
import '../support/fakes.dart';

final de = lookupAppLocalizations(const Locale('de'));

/// Anna's sheet: two subjects the household has, one it has not, a care row.
const _payload = '''
{"format": "wuselwall-timetable/1", "member": "Anna", "class": "3b",
 "lessons": [
   {"day": "Mo", "period": 1, "subject": "Ma", "room": "R1"},
   {"day": "Mo", "period": 2, "subject": "D"},
   {"day": "Di", "period": 1, "subject": "En", "name": "Englisch"}
 ],
 "care": [{"title": "Hort", "days": ["Mo"], "starts": "13:30", "ends": "15:30"}]}
''';

Future<void> _openSchedule(WidgetTester t) async {
  await t.tap(find.text(de.scheduleTitle));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('paste import: preview, then one tap writes everything', (
    t,
  ) async {
    final school = FakeSchoolRepository(
      data: referenceSchoolData(withTimetable: false),
    );
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: school,
    );
    await _openSchedule(t);
    // The child without a timetable offers the import next to the entry.
    await t.tap(find.widgetWithText(OutlinedButton, de.schoolImportAction));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('import-way-text')));
    await t.pumpAndSettle();
    expect(find.text(de.schoolImportPasteTitle), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('import-paste')), _payload);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('import-read')));
    await t.pumpAndSettle();

    // The preview: the child, the count, the term, the new subject.
    expect(find.text(de.schoolImportTitle), findsOneWidget);
    expect(
      find.text(
        '${de.schoolImportLessons(3)} · ${de.schoolEditorClass} 3b · ${de.schoolCycleWeekly}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(de.schoolImportTermExisting('Schuljahr 2026/27')),
      findsOneWidget,
    );
    expect(find.text('Englisch (En)'), findsOneWidget);
    expect(school.subjectSaves, isEmpty, reason: 'nothing before Übernehmen');

    await t.tap(find.byKey(const ValueKey('import-apply')));
    await t.pumpAndSettle();

    expect(school.subjectSaves.single.name, 'Englisch');
    expect(school.subjectSaves.single.shortName, 'En');
    expect(
      school.termSaves,
      isEmpty,
      reason: 'the reference term covers today',
    );
    expect(school.timetableSaves.single.profileId, kidId);
    expect(school.timetableSaves.single.classLabel, '3b');
    final sent = school.lessonSets.single.lessons;
    expect(sent, hasLength(4));
    expect(sent[0].toJson(), containsPair('subject_id', 'sub-ma'));
    expect(sent[0].toJson(), containsPair('room', 'R1'));
    expect(sent[2].toJson(), containsPair('subject_id', 'sub-new-1'));
    expect(sent[3].toJson(), containsPair('kind', 'care'));
    expect(sent[3].toJson(), containsPair('title', 'Hort'));
    expect(find.text(de.schoolImportApplied), findsOneWidget);
  });

  testWidgets('a text that is no payload says why, and nothing is written', (
    t,
  ) async {
    final school = FakeSchoolRepository(
      data: referenceSchoolData(withTimetable: false),
    );
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: school,
    );
    await _openSchedule(t);
    await t.tap(find.widgetWithText(OutlinedButton, de.schoolImportAction));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('import-way-text')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('import-paste')),
      'Sorry, I cannot read the photo.',
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('import-read')));
    await t.pumpAndSettle();
    expect(find.text(de.schoolImportErrNotJson), findsOneWidget);
    expect(find.text(de.schoolImportTitle), findsNothing);
    expect(school.timetableSaves, isEmpty);
  });

  testWidgets(
    'a proposal on Today: review, apply, and the verdict is recorded',
    (t) async {
      final school = FakeSchoolRepository(
        data: referenceSchoolData(withTimetable: false),
      );
      final proposals = FakeProposalsRepository(open: [proposalFrom(_payload)]);
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        school: school,
        proposals: proposals,
      );
      expect(find.text(de.schoolProposalTitle('Claude')), findsOneWidget);
      expect(find.text(de.schoolProposalSummary('Anna', 3)), findsOneWidget);
      await t.tap(find.text(de.schoolProposalReview));
      await t.pumpAndSettle();
      expect(find.text(de.schoolImportProposedBy('Claude')), findsOneWidget);
      expect(find.byKey(const ValueKey('import-discard')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('import-apply')));
      await t.pumpAndSettle();
      expect(proposals.resolved, [(id: 'prop-1', applied: true)]);
      expect(school.lessonSets.single.lessons, hasLength(4));
      expect(find.text(de.schoolProposalTitle('Claude')), findsNothing);
    },
  );

  testWidgets('a proposal can be discarded from its card without a look', (
    t,
  ) async {
    final proposals = FakeProposalsRepository(open: [proposalFrom(_payload)]);
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: FakeSchoolRepository(
        data: referenceSchoolData(withTimetable: false),
      ),
      proposals: proposals,
    );
    await t.tap(find.text(de.schoolImportDiscard));
    await t.pumpAndSettle();
    expect(proposals.resolved, [(id: 'prop-1', applied: false)]);
    expect(find.text(de.schoolImportDiscarded), findsOneWidget);
  });

  testWidgets('a subject typed into a cell is created on the spot', (t) async {
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
    await t.enterText(find.byKey(const ValueKey('cell-subject-search')), 'Phy');
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('cell-create-subject')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('cell-create-subject')));
    await t.pumpAndSettle();
    expect(school.subjectSaves.single.name, 'Phy');
    expect(school.subjectSaves.single.shortName, 'Phy');
    // The new subject is selected; a typed name that exists offers no creation.
    expect(find.byKey(const ValueKey('cell-create-subject')), findsNothing);
    await t.tap(find.text(de.schoolApply));
    await t.pumpAndSettle();
    await t.tap(find.text(de.schoolSaveTimetable));
    await t.pumpAndSettle();
    final cell = school.lessonSets.single.lessons
        .where((l) => l.weekday == 1 && l.periodIndex == 1)
        .single;
    expect(cell.subjectId, 'sub-new-1');
  });

  testWidgets(
    'the first school: name, region, one button, then the next steps',
    (t) async {
      final school = FakeSchoolRepository(
        data: referenceSchoolData(withSchool: false, withTimetable: false),
      );
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        school: school,
      );
      await _openSchedule(t);
      expect(find.text(de.schoolSetupCardBody), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, de.schoolSetupAction));
      await t.pumpAndSettle();
      expect(find.text(de.schoolSetupFirstHint), findsOneWidget);
      expect(find.text(de.schoolBellTimes), findsNothing);
      expect(find.text(de.schoolSubjects), findsNothing);
      final create = find.byKey(const ValueKey('school-create'));
      expect(t.widget<FilledButton>(create).onPressed, isNull);
      await t.enterText(find.byType(TextField).first, 'Grundschule Lindenhof');
      await t.pumpAndSettle();
      await t.tap(create);
      await t.pumpAndSettle();
      expect(school.schoolSaves.single.name, 'Grundschule Lindenhof');

      // The school exists: bell times and subjects appear, and the child is a next step.
      expect(find.text(de.schoolNextSteps), findsOneWidget);
      expect(find.text(de.schoolBellTimes), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('next-step-$kidId')));
      await t.pumpAndSettle();
      // No term yet: the school year is proposed, one tap continues to the editor.
      expect(find.text(de.schoolTermProposedHint), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, de.schoolTermContinue));
      await t.pumpAndSettle();
      final year = schoolYearAround(DateTime.now());
      expect(school.termSaves.single.startsOn, year.from);
      expect(school.termSaves.single.isCurrent, isTrue);
      expect(find.text(de.schoolSaveTimetable), findsOneWidget);
      expect(container.read(selectedWeekProvider), isNotNull);
    },
  );
}
