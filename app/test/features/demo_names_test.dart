import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/demo/demo_board.dart';
import 'package:wuselwall/demo/demo_data.dart';

void main() {
  tearDown(() => DemoData.useLanguageOf(const [Locale('de')]));

  test('the demo family has English names when the app runs in English', () {
    DemoData.useLanguageOf(const [Locale('en', 'US')]);
    expect(DemoData.members.map((m) => m.displayName), [
      'David',
      'Sarah',
      'Olivia',
      'Jack',
    ]);
    expect(DemoData.papaPhone, "David's iPhone");
  });

  test('German names in German and for languages the app does not ship', () {
    for (final locales in [
      const [Locale('de', 'CH')],
      const [Locale('fr'), Locale('it')],
      const [Locale('fr'), Locale('de')],
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
    DemoData.useLanguageOf(const [Locale('fr'), Locale('en'), Locale('de')]);
    expect(DemoData.english, isTrue);
  });

  test(
    'the board names the members and the free day in the same language',
    () async {
      DemoData.useLanguageOf(const [Locale('en')]);
      final board = (await DemoBoardRepository(
        clock: () => DateTime(2026, 10, 14, 9),
      ).week()).unwrap();
      expect(board.member(DemoData.son)!.displayName, 'Jack');
      expect(board.days[3].holiday!.name, 'Floating school holiday');
      expect(board.days[3].holiday!.isHousehold, isTrue);
    },
  );

  test('every text on the English board has its English', () async {
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
    DemoData.useLanguageOf(const [Locale('en')]);
    final english = await texts();
    // Words that are the same in both languages.
    const same = {null, '5a'};
    final untranslated = {
      for (final (i, de) in german.indexed)
        if (english[i] == de && !same.contains(de)) de,
    };
    expect(untranslated, isEmpty);
  });
}
