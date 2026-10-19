import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/demo/demo_board.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_english.dart';

void main() {
  tearDown(() => DemoData.useLanguageOf(const [Locale('de')]));

  test('the demo family has the language names of all four locales', () {
    final expected = {
      'de': ['Thomas', 'Julia', 'Emma', 'Paul'],
      'en': ['David', 'Sarah', 'Olivia', 'Jack'],
      'fr': ['Thomas', 'Julie', 'Emma', 'Paul'],
      'es': ['David', 'Sara', 'Olivia', 'Pablo'],
    };
    for (final entry in expected.entries) {
      DemoData.useLanguageOf([Locale(entry.key)]);
      expect(DemoData.members.map((m) => m.displayName), entry.value);
    }
    // The possessive is per language: German appends, French and Spanish rephrase.
    DemoData.useLanguageOf(const [Locale('de')]);
    expect(DemoData.papaPhone, 'Thomas’ iPhone');
    DemoData.useLanguageOf(const [Locale('fr')]);
    expect(DemoData.papaPhone, 'iPhone de Thomas');
    DemoData.useLanguageOf(const [Locale('es')]);
    expect(DemoData.papaPhone, 'iPhone de David');
  });

  test('German names for languages the app does not ship', () {
    for (final locales in [
      const [Locale('de', 'CH')],
      const [Locale('it'), Locale('nl')],
      const [Locale('it'), Locale('de')],
    ]) {
      DemoData.useLanguageOf(locales);
      expect(DemoData.members.map((m) => m.displayName), [
        'Thomas',
        'Julia',
        'Emma',
        'Paul',
      ]);
    }
  });

  test('the first supported language wins, as in MaterialApp', () {
    DemoData.useLanguageOf(const [Locale('it'), Locale('en'), Locale('de')]);
    expect(DemoData.english, isTrue);
    DemoData.useLanguageOf(const [Locale('it'), Locale('fr'), Locale('es')]);
    expect(DemoData.languageCode, 'fr');
  });

  test('every shipped language has its own demo prose', () {
    const german = 'Mathematik';
    const expected = {
      'de': 'Mathematik',
      'en': 'Maths',
      'fr': 'Maths',
      'es': 'Mates',
    };
    for (final entry in expected.entries) {
      DemoData.useLanguageOf([Locale(entry.key)]);
      expect(demoText(german), entry.value, reason: entry.key);
    }
  });

  test(
    'the board names the members and the free day in the demo language',
    () async {
      for (final entry in {
        'en': ('Jack', 'INSET day'),
        'fr': ('Paul', 'Jour férié mobile'),
        'es': ('Pablo', 'Día festivo móvil'),
      }.entries) {
        DemoData.useLanguageOf([Locale(entry.key)]);
        final board = (await DemoBoardRepository(
          clock: () => DateTime(2026, 10, 14, 9),
        ).week()).unwrap();
        expect(board.member(DemoData.son)!.displayName, entry.value.$1);
        expect(board.days[3].holiday!.name, entry.value.$2);
        expect(board.days[3].holiday!.isHousehold, isTrue);
      }
    },
  );

  test(
    'every text on the French and Spanish board has its own translation',
    () async {
      Future<List<String?>> texts() async {
        final board = (await DemoBoardRepository(
          clock: () => DateTime(2026, 10, 14, 9),
        ).week()).unwrap();
        return [
          for (final m in board.members) m.baseline?.label,
          for (final p in board.presence) p.label,
          for (final t in board.timetables) ...[t.classLabel, t.schoolName],
          for (final d in board.days) ...[
            d.holiday?.name,
            for (final e in d.events) ...[e.title, e.location],
            d.meal?.title,
            for (final s in d.school.values) ...[
              ...s.notable,
              s.careLabel,
              for (final l in s.lessons) ...[
                l.subject,
                l.room,
                l.note,
                l.equipment,
              ],
            ],
          ],
        ];
      }

      DemoData.useLanguageOf(const [Locale('de')]);
      final german = await texts();
      for (final language in ['fr', 'es']) {
        DemoData.useLanguageOf([Locale(language)]);
        final translated = await texts();
        // Words that are the same in the source and the translation.
        const same = {null, '5a', 'Chili sin Carne'};
        final untranslated = {
          for (final (i, de) in german.indexed)
            if (translated[i] == de && !same.contains(de)) de,
        };
        expect(untranslated, isEmpty, reason: language);
      }
    },
  );
}
