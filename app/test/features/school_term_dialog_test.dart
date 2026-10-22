import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/school_setup_page.dart';

/// The Monday of ISO week 43 of 2026.
final _monday = DateTime(2026, 10, 19);
final _l10n = lookupAppLocalizations(const Locale('en'));

/// Opens the dialog and returns what it pops with once it closes.
Future<TermRecord? Function()> _open(
  WidgetTester t, {
  TermRecord? term,
  DateTime? forTimetableOn,
}) async {
  TermRecord? result;
  await t.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showDialog<TermRecord>(
                context: context,
                builder: (_) => SchoolTermDialog(
                  schoolId: 'school-1',
                  term: term,
                  forTimetableOn: forTimetableOn,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return () => result;
}

Future<void> _pick(WidgetTester t, String field, {String? day}) async {
  await t.tap(find.byKey(ValueKey(field)));
  await t.pumpAndSettle();
  if (day != null) {
    await t.tap(find.text(day));
    await t.pumpAndSettle();
  }
  final material = MaterialLocalizations.of(
    t.element(find.byType(DatePickerDialog)),
  );
  await t.tap(find.text(material.okButtonLabel));
  await t.pumpAndSettle();
}

Finder get _save => find.byType(FilledButton);
bool _enabled(WidgetTester t) =>
    t.widget<FilledButton>(_save).onPressed != null;

void main() {
  testWidgets('a new term for a week needs a name and an end date', (t) async {
    final result = await _open(t, forTimetableOn: _monday);
    expect(find.text(_l10n.schoolTermNew), findsOneWidget);
    expect(find.text(_l10n.schoolTimetableNeedsTerm), findsOneWidget);
    expect(find.text('Oct 19, 2026'), findsOneWidget);
    expect(find.text(_l10n.schoolTermPickDate), findsOneWidget);
    expect(find.text(_l10n.schoolTermContinue), findsOneWidget);
    expect(_enabled(t), isFalse);
    // The A/B detail stays hidden until the family says the weeks alternate.
    expect(find.byKey(const ValueKey('term-anchor')), findsNothing);

    await t.enterText(find.byType(TextField).first, 'School year 2026/27');
    await t.pumpAndSettle();
    expect(_enabled(t), isFalse);
    await _pick(t, 'term-to');
    expect(find.text('Oct 19, 2026'), findsNWidgets(2));
    expect(_enabled(t), isTrue);
    await t.tap(_save);
    await t.pumpAndSettle();

    final term = result()!;
    expect(term.name, 'School year 2026/27');
    expect(term.startsOn, _monday);
    expect(term.endsOn, _monday);
    expect(term.abAnchorWeek, isNull);
    expect(term.isCurrent, isFalse);
  });

  testWidgets('dates that miss the week shown say so next to the field', (
    t,
  ) async {
    await _open(t, forTimetableOn: _monday);
    await t.enterText(find.byType(TextField).first, 'Term');
    await _pick(t, 'term-from', day: '26');
    final mustCover = _l10n.schoolTermMustCoverWeek('10/19 – 10/25');
    expect(find.text(mustCover), findsOneWidget);
    expect(_enabled(t), isFalse);

    await _pick(t, 'term-to', day: '21');
    expect(find.text(_l10n.schoolTermEndBeforeStart), findsOneWidget);
    expect(_enabled(t), isFalse);

    await _pick(t, 'term-from', day: '12');
    expect(find.text(mustCover), findsNothing);
    expect(find.text(_l10n.schoolTermEndBeforeStart), findsNothing);
    expect(_enabled(t), isTrue);

    await _pick(t, 'term-to', day: '14');
    expect(find.text(mustCover), findsOneWidget);
    expect(_enabled(t), isFalse);
  });

  testWidgets('A and B weeks need a valid calendar week', (t) async {
    final result = await _open(t, forTimetableOn: _monday);
    await t.enterText(find.byType(TextField).first, 'Term');
    await _pick(t, 'term-to');
    await t.tap(find.widgetWithText(SwitchListTile, _l10n.schoolAbWeeks));
    await t.pumpAndSettle();
    final anchor = find.byKey(const ValueKey('term-anchor'));
    expect(anchor, findsOneWidget);
    expect(find.textContaining(_l10n.schoolAbWeekShown(43)), findsOneWidget);
    // Switched on but empty: nothing to save yet.
    expect(_enabled(t), isFalse);

    await t.enterText(anchor, '60');
    await t.pumpAndSettle();
    expect(find.text(_l10n.schoolAbWeekInvalid), findsOneWidget);
    expect(_enabled(t), isFalse);

    await t.enterText(anchor, '43');
    await t.pumpAndSettle();
    expect(find.text(_l10n.schoolAbWeekInvalid), findsNothing);
    expect(_enabled(t), isTrue);
    await t.tap(_save);
    await t.pumpAndSettle();
    expect(result()!.abAnchorWeek, 43);
  });

  testWidgets('switching A and B weeks off drops the anchor', (t) async {
    final result = await _open(
      t,
      term: TermRecord(
        id: 'term-1',
        schoolId: 'school-1',
        name: 'First half',
        startsOn: DateTime(2026, 8, 10),
        endsOn: DateTime(2027, 1, 31),
        abAnchorWeek: 43,
      ),
    );
    expect(find.text(_l10n.schoolTermEdit), findsOneWidget);
    expect(find.text(_l10n.save), findsOneWidget);
    expect(find.text('Aug 10, 2026'), findsOneWidget);
    expect(find.text('Jan 31, 2027'), findsOneWidget);
    final anchor = find.byKey(const ValueKey('term-anchor'));
    expect(t.widget<TextField>(anchor).controller!.text, '43');
    // Not opened from a timetable: no week to point at.
    expect(find.textContaining('calendar week 43'), findsNothing);

    await t.tap(find.widgetWithText(SwitchListTile, _l10n.schoolAbWeeks));
    await t.pumpAndSettle();
    expect(anchor, findsNothing);
    await t.tap(find.widgetWithText(SwitchListTile, _l10n.schoolCurrentTerm));
    await t.pumpAndSettle();
    await t.tap(_save);
    await t.pumpAndSettle();

    final term = result()!;
    expect(term.id, 'term-1');
    expect(term.abAnchorWeek, isNull);
    expect(term.isCurrent, isTrue);
  });
}
