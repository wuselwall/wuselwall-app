import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';
import 'package:wuselwall/features/rituals/domain/table_question.dart';

/// The household's walk through its questions after the lighter-day review: a rank per
/// question, so hiding or adding one moves nothing else, and the same order on every
/// platform.
void main() {
  List<TableQuestion> deck(int n, {String lang = 'de'}) => [
    for (var i = 0; i < n; i++)
      TableQuestion(key: '$lang:q-${i.toString().padLeft(4, '0')}', text: '$i'),
  ];

  group('the rank', () {
    test('is FNV-1a, with the published test vectors', () {
      expect(fnv1a32(''), 0x811c9dc5);
      expect(fnv1a32('a'), 0xe40c292c);
      expect(fnv1a32('foobar'), 0xbf9cf968);
      // UTF-8, not UTF-16 code units.
      expect(fnv1a32('Grüße'), 3089264184);
    });

    test('mixes the hash with a fixed finaliser (golden values)', () {
      expect(questionRank(''), 2872998923);
      expect(questionRank('a'), 444641715);
      expect(questionRank('foobar'), 202221276);
    });

    test('gives a fixed order for a fixed household and walk (golden)', () {
      final keys = [for (var i = 0; i < 6; i++) 'de:q-$i'];
      List<String> order(int cycle) => [
        for (final q in householdShuffle(
          [for (final k in keys) TableQuestion(key: k, text: k)],
          'h-1',
          cycle: cycle,
        ))
          q.key,
      ];
      expect(order(0), [
        'de:q-0',
        'de:q-2',
        'de:q-5',
        'de:q-1',
        'de:q-4',
        'de:q-3',
      ]);
      expect(order(1), [
        'de:q-5',
        'de:q-4',
        'de:q-1',
        'de:q-3',
        'de:q-0',
        'de:q-2',
      ]);
    });
  });

  group('the walk', () {
    test('does not depend on the order the questions arrive in', () {
      final d = deck(40);
      for (var w = 1000; w < 1040; w++) {
        expect(
          householdQuestion(d, 'h', w)!.key,
          householdQuestion(d.reversed.toList(), 'h', w)!.key,
        );
      }
    });

    test('differs between households', () {
      final d = deck(40);
      final a = [
        for (var w = 0; w < 10; w++) householdQuestion(d, 'a', w)!.key,
      ];
      final b = [
        for (var w = 0; w < 10; w++) householdQuestion(d, 'b', w)!.key,
      ];
      expect(a, isNot(b));
    });

    test('repeats no question before the deck is through, walk after walk', () {
      final d = deck(50);
      for (final start in const [0, 50, 100, 950]) {
        final seen = {
          for (var w = start; w < start + 50; w++)
            householdQuestion(d, 'h', w, cycleLength: 50)!.key,
        };
        expect(seen.length, 50, reason: 'walk from $start');
      }
    });

    test('hiding the question of the moment brings the next one; the rest keep '
        'their order', () {
      final d = deck(50);
      const w = 1234;
      List<String> walk(List<TableQuestion> questions, int from, int to) => [
        for (var i = from; i < to; i++)
          householdQuestion(questions, 'h', i, cycleLength: 50)!.key,
      ];
      // 1234 is 34 windows into its walk of 50.
      final before = walk(d, w, w + 10);
      final hidden = before.first;
      final after = walk(
        [
          for (final q in d)
            if (q.key != hidden) q,
        ],
        w,
        w + 9,
      );
      expect(after, before.sublist(1));
      // The windows already past in this walk are untouched.
      final earlier = walk(d, w - 34, w);
      expect(
        walk(
          [
            for (final q in d)
              if (q.key != hidden) q,
          ],
          w - 34,
          w,
        ),
        earlier,
      );
    });

    test(
      'a question of the family\'s own slots in without reshuffling the rest',
      () {
        final d = deck(50);
        const w = 1200; // the start of a walk of 50
        final before = [
          for (var i = w; i < w + 50; i++)
            householdQuestion(d, 'h', i, cycleLength: 50)!.key,
        ];
        final withOwn = [
          ...d,
          const TableQuestion(key: 'row-1', text: 'Was war heute schön?'),
        ];
        final after = [
          for (var i = w; i < w + 51; i++)
            householdQuestion(withOwn, 'h', i, cycleLength: 50)!.key,
        ];
        expect([...after.where((k) => k != 'row-1')].take(49), before.take(49));
      },
    );

    test('Andere Frage steps forward on this device only', () {
      final d = deck(30);
      expect(
        householdQuestion(d, 'h', 77, skip: 1)!.key,
        householdQuestion(d, 'h', 78)!.key,
      );
    });

    test('an empty deck asks nothing', () {
      expect(householdQuestion(const [], 'h', 3), isNull);
    });
  });

  group('the deck', () {
    final bundled = [
      const TableQuestion(key: 'de:q-1', text: 'a'),
      const TableQuestion(key: 'de:q-2', text: 'b', deck: 'older'),
      const TableQuestion(key: 'de:q-3', text: 'c'),
    ];

    test('follows the household\'s ages, its hidden and its own questions', () {
      final family = [
        const FamilyQuestion(id: 'h1', hiddenKey: 'de:q-3'),
        const FamilyQuestion(
          id: 'own-1',
          text: 'Was war lustig?',
          createdBy: 'p',
        ),
      ];
      expect(
        [
          for (final q in householdDeck(
            bundled: bundled,
            family: family,
            older: false,
          ))
            q.key,
        ],
        ['de:q-1', 'own-1'],
      );
      expect(
        [
          for (final q in householdDeck(
            bundled: bundled,
            family: family,
            older: true,
          ))
            q.key,
        ],
        ['de:q-1', 'de:q-2', 'own-1'],
      );
    });

    test('the walk\'s length is the bundled deck for the ages, hidden ones '
        'included', () {
      expect(tableCycleLength(bundled: bundled, older: false, deckSize: 1), 2);
      expect(tableCycleLength(bundled: bundled, older: true, deckSize: 1), 3);
      expect(tableCycleLength(bundled: const [], older: false, deckSize: 4), 4);
    });
  });

  group('the moment', () {
    final questions = deck(20);
    TableMoment? at(
      int hour,
      int minute, {
      Object? mode = 'warm_meal',
      Object? lunch,
      Object? dinner,
      bool warmIsDinner = true,
    }) => tableMomentAt(
      now: DateTime(2026, 10, 26, hour, minute),
      mode: mode,
      lunch: lunch,
      dinner: dinner,
      warmIsDinner: (_) => warmIsDinner,
      deck: questions,
      householdId: 'h',
    );

    test('asks during the warm meal\'s window only', () {
      expect(at(18, 0), isNotNull);
      expect(at(18, 0)!.dinner, isTrue);
      expect(at(12, 0), isNull, reason: 'lunch is not the warm meal');
      expect(at(12, 0, warmIsDinner: false), isNotNull);
      expect(at(18, 0, warmIsDinner: false), isNull);
      expect(at(17, 29), isNull);
      expect(at(19, 30), isNull, reason: 'the end is not in the window');
    });

    test('asks at both main meals with main_meals, two windows a day', () {
      final lunch = at(12, 0, mode: 'main_meals');
      final dinner = at(18, 0, mode: 'main_meals');
      expect(lunch!.dinner, isFalse);
      expect(dinner!.window, lunch.window + 1);
    });

    test('asks nothing when switched off or with no questions', () {
      expect(at(18, 0, mode: 'off'), isNull);
      expect(
        tableMomentAt(
          now: DateTime(2026, 10, 26, 18),
          mode: 'warm_meal',
          lunch: null,
          dinner: null,
          warmIsDinner: (_) => true,
          deck: const [],
          householdId: 'h',
        ),
        isNull,
      );
    });

    test('follows the household\'s windows', () {
      const dinner = {'from': '18:30', 'to': '20:00'};
      expect(at(18, 0, dinner: dinner), isNull);
      expect(at(19, 45, dinner: dinner), isNotNull);
    });

    test('a window past midnight belongs to the day it began', () {
      const late = {'from': '22:00', 'to': '01:00'};
      final evening = at(23, 0, mode: 'main_meals', dinner: late);
      final night = tableMomentAt(
        now: DateTime(2026, 10, 27, 0, 30),
        mode: 'main_meals',
        lunch: null,
        dinner: late,
        warmIsDinner: (_) => true,
        deck: questions,
        householdId: 'h',
      );
      expect(evening, isNotNull);
      expect(night, isNotNull);
      expect(night!.window, evening!.window);
      expect(at(1, 0, mode: 'main_meals', dinner: late), isNull);
    });

    test(
      'a malformed window falls back to the default instead of throwing',
      () {
        expect(at(18, 0, dinner: {'from': 'abc', 'to': '25:99'}), isNotNull);
        expect(at(18, 0, dinner: {'from': '18'}), isNotNull);
        expect(at(18, 0, dinner: 'nonsense'), isNotNull);
        expect(minutesOfDay('7:05'), 425);
        expect(minutesOfDay('24:00'), isNull);
        expect(minutesOfDay('x:y'), isNull);
        expect(minutesOfDay(1830), isNull);
      },
    );
  });
}
