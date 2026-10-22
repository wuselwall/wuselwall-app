import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

import '../support/fake_school.dart';
import '../support/fakes.dart';

SchoolData _withoutTerms({bool withTimetable = false}) {
  final source = referenceSchoolData(withTimetable: withTimetable);
  return SchoolData(
    schools: source.schools,
    periods: source.periods,
    terms: const [],
    subjects: source.subjects,
    timetables: source.timetables,
    lessons: source.lessons,
    exceptions: source.exceptions,
    holidays: source.holidays,
  );
}

class _FailedTermRepository extends FakeSchoolRepository {
  _FailedTermRepository() : super(data: _withoutTerms());

  @override
  Future<Result<String>> saveTerm({
    required String? actor,
    required TermRecord term,
  }) async => const Err(NetworkFailure());
}

Future<void> _completeTerm(WidgetTester t, Locale locale) async {
  final l10n = lookupAppLocalizations(locale);
  final dialog = find.byType(AlertDialog);
  await t.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)).first,
    'New term',
  );
  await t.pumpAndSettle();
  // A date range is an explicit choice, rather than silently saving a one-day term.
  final next = find.widgetWithText(FilledButton, l10n.schoolTermContinue);
  expect(t.widget<FilledButton>(next).onPressed, isNull);
  await t.tap(find.byKey(const ValueKey('term-to')));
  await t.pumpAndSettle();
  final material = MaterialLocalizations.of(
    t.element(find.byType(DatePickerDialog)),
  );
  await t.tap(find.text(material.okButtonLabel));
  await t.pumpAndSettle();
  await t.tap(next);
  await t.pumpAndSettle();
}

void main() {
  for (final language in ['de', 'en', 'fr', 'es']) {
    for (final brightness in Brightness.values) {
      testWidgets('create a timetable without a term: $language $brightness', (
        t,
      ) async {
        final locale = Locale(language);
        final l10n = lookupAppLocalizations(locale);
        t.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
        final school = FakeSchoolRepository(data: _withoutTerms());
        final container = await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
          school: school,
          locale: locale,
        );
        final monday = container.read(selectedWeekProvider);
        await t.tap(find.text(l10n.scheduleTitle));
        await t.pumpAndSettle();
        t.view.physicalSize = const Size(390, 844);
        await t.pumpAndSettle();
        final enter = find.widgetWithText(
          FilledButton,
          l10n.schoolEnterTimetableAction,
        );
        await t.ensureVisible(enter);
        await t.pumpAndSettle();
        await t.tap(enter);
        await t.pumpAndSettle();
        expect(find.text(l10n.schoolTimetableNeedsTerm), findsOneWidget);
        expect(find.text(l10n.schoolSetupTitle), findsNothing);
        await _completeTerm(t, locale);

        expect(school.termSaves.single.startsOn, monday);
        expect(school.actors.single, guardianId);
        expect(find.textContaining('New term'), findsOneWidget);
        final save = find.widgetWithText(
          FilledButton,
          l10n.schoolSaveTimetable,
        );
        expect(save.hitTestable(), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('cell-1-1')));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(ChoiceChip, 'Ma'));
        await t.pumpAndSettle();
        await t.tap(find.text(l10n.schoolApply));
        await t.pumpAndSettle();
        await t.tap(save);
        await t.pumpAndSettle();

        expect(school.timetableSaves.single.profileId, kidId);
        expect(school.timetableSaves.single.termId, 'term-new-1');
        expect(
          school.timetableSaves.single.schoolId,
          school.data.schools.single.id,
        );
        expect(school.lessonSets.single.lessons.single.subjectId, 'sub-ma');
        // Saving again updates the created timetable rather than creating another.
        await t.tap(save);
        await t.pumpAndSettle();
        expect(school.timetableSaves, hasLength(1));
        expect(school.lessonSets, hasLength(2));
        expect(
          find.widgetWithText(FilledButton, l10n.schoolEnterTimetableAction),
          findsNothing,
        );
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('an old current term is not reused for a different week', (
    t,
  ) async {
    final school = FakeSchoolRepository();
    final l10n = lookupAppLocalizations(const Locale('de'));
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: school,
    );
    // Outside the reference term, which still has is_current=true and a timetable.
    while (container.read(selectedWeekProvider).isBefore(DateTime(2028))) {
      container.read(selectedWeekProvider.notifier).next();
    }
    await t.tap(find.text(l10n.scheduleTitle));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip(l10n.schoolEditTimetable));
    await t.pumpAndSettle();
    expect(find.text(l10n.schoolTimetableNeedsTerm), findsOneWidget);
    await t.tap(find.text(l10n.cancel));
    await t.pumpAndSettle();
    expect(school.termSaves, isEmpty);
    expect(school.timetableSaves, isEmpty);
    expect(find.text(l10n.schoolSaveTimetable), findsNothing);
  });

  testWidgets('failed term creation does not open an unusable editor', (
    t,
  ) async {
    final school = _FailedTermRepository();
    final l10n = lookupAppLocalizations(const Locale('de'));
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      school: school,
    );
    await t.tap(find.text(l10n.scheduleTitle));
    await t.pumpAndSettle();
    await t.tap(
      find.widgetWithText(FilledButton, l10n.schoolEnterTimetableAction),
    );
    await t.pumpAndSettle();
    await _completeTerm(t, const Locale('de'));
    expect(
      find.widgetWithText(FilledButton, l10n.schoolEnterTimetableAction),
      findsOneWidget,
    );
    expect(find.text(l10n.schoolSaveTimetable), findsNothing);
    expect(school.timetableSaves, isEmpty);
    expect(t.takeException(), isNull);
  });
}
