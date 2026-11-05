import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';
import 'package:wuselwall/features/rituals/domain/table_question.dart';

void main() {
  for (final lang in tableQuestionLanguages) {
    test('the $lang deck parses, with unique keys and answers on riddles', () {
      final deck = parseDeck(
        File('assets/table_questions/$lang.json').readAsStringSync(),
      );
      expect(deck.length, greaterThanOrEqualTo(100));
      expect(deck.map((q) => q.key).toSet().length, deck.length);
      for (final q in deck) {
        expect(q.key, startsWith('$lang:'));
        expect(q.text.length, lessThanOrEqualTo(140), reason: q.key);
        expect(
          q.minAge,
          inInclusiveRange(tableQuestionYoungest, tableQuestionOldest),
          reason: q.key,
        );
        if (q.maxAge case final max?) {
          expect(
            max,
            inInclusiveRange(q.minAge, tableQuestionOldest),
            reason: q.key,
          );
        }
        expect(q.category == 'riddle', q.answer != null, reason: q.key);
      }
      // Gratitude stays rare: at most one in ten.
      expect(
        deck.where((q) => q.category == 'thanks').length,
        lessThanOrEqualTo(deck.length ~/ 10),
      );
      // Every age has enough to walk through for some weeks.
      for (var age = tableQuestionYoungest; age <= tableQuestionOldest; age++) {
        expect(
          deck.where((q) => q.fits((youngest: age, oldest: age))).length,
          greaterThanOrEqualTo(15),
          reason: 'age $age',
        );
      }
    });
  }

  group('who the questions are for', () {
    List<TableAges> groups(List<int> ages, {bool hasChildren = true}) =>
        tableAgeGroups(ages, hasChildren: hasChildren);

    test('children close in age share one question', () {
      expect(groups([7, 9]), [(youngest: 7, oldest: 9)]);
      expect(groups([6, 8, 10]), [(youngest: 6, oldest: 10)]);
      expect(groups([6, 10]), [(youngest: 6, oldest: 10)]);
    });

    test('children five years apart or more get a question each', () {
      expect(groups([5, 10]), [
        (youngest: 5, oldest: 5),
        (youngest: 10, oldest: 10),
      ]);
      expect(groups([14, 5, 7]), [
        (youngest: 5, oldest: 7),
        (youngest: 14, oldest: 14),
      ]);
    });

    test('a baby does not split the table, a young adult counts as 16', () {
      expect(groups([1, 9]), [(youngest: 9, oldest: 9)]);
      expect(groups([2]), [(youngest: 4, oldest: 4)]);
      expect(groups([19, 15]), [(youngest: 15, oldest: 16)]);
    });

    test('without a birthday it stays with young children, without children '
        'everything is open', () {
      expect(groups(const []), [(youngest: 5, oldest: 7)]);
      expect(groups(const [], hasChildren: false), [
        (youngest: tableQuestionYoungest, oldest: tableQuestionOldest),
      ]);
    });
  });

  group('the age of a question', () {
    const open = TableQuestion(key: 'q', text: 't', minAge: 8);
    const capped = TableQuestion(key: 'q', text: 't', minAge: 5, maxAge: 9);

    test('suits a group when the ages overlap', () {
      expect(open.fits((youngest: 6, oldest: 8)), isTrue);
      expect(open.fits((youngest: 5, oldest: 7)), isFalse);
      expect(open.fits((youngest: 16, oldest: 16)), isTrue);
      expect(capped.fits((youngest: 9, oldest: 12)), isTrue);
      expect(capped.fits((youngest: 10, oldest: 12)), isFalse);
    });
  });

  group('two questions at the table', () {
    const a = TableQuestion(key: 'a', text: 'a', maxAge: 7);
    const both = TableQuestion(key: 'both', text: 'both');
    const b = TableQuestion(key: 'b', text: 'b', minAge: 12);

    test('are for different ages and never the same', () {
      final tracks = tableTracks(
        groups: [(youngest: 5, oldest: 5), (youngest: 14, oldest: 14)],
        bundled: const [a, both, b],
        family: const [],
      );
      expect(tracks[0].questions.map((q) => q.key), ['a', 'both']);
      expect(tracks[1].questions.map((q) => q.key), ['both', 'b']);
      for (var window = 0; window < 200; window++) {
        final asked = tableMomentQuestions((
          window: window,
          dinner: true,
          tracks: tracks,
          householdId: 'h',
        ));
        expect(asked, hasLength(2));
        expect(asked[0].question.key, isNot(asked[1].question.key));
      }
    });

    test('the family\'s own question comes up once, a hidden one never', () {
      final tracks = tableTracks(
        groups: [(youngest: 5, oldest: 5), (youngest: 14, oldest: 14)],
        bundled: const [a, both, b],
        family: const [
          FamilyQuestion(id: 'own', text: 'Unsere Frage', createdBy: 'p'),
          FamilyQuestion(id: 'h1', hiddenKey: 'both'),
        ],
      );
      expect(tracks[0].questions.map((q) => q.key), ['a', 'own']);
      expect(tracks[1].questions.map((q) => q.key), ['b']);
    });

    test('the age limit blocks from its age upwards', () {
      final tracks = tableTracks(
        groups: [(youngest: 14, oldest: 14)],
        bundled: const [both, b],
        family: const [],
        ageLimit: 12,
      );
      expect(tracks.single.questions.map((q) => q.key), ['both']);
      expect(tracks.single.cycleLength, 1);
    });

    test('a track with nothing to ask is left out', () {
      final asked = tableMomentQuestions((
        window: 3,
        dinner: true,
        tracks: tableTracks(
          groups: [(youngest: 5, oldest: 5), (youngest: 14, oldest: 14)],
          bundled: const [a],
          family: const [],
        ),
        householdId: 'h',
      ));
      expect(asked.map((q) => (q.question.key, q.track)), [('a', 0)]);
    });
  });

  test('every app language has a deck (Q53)', () {
    expect(tableQuestionLanguages, {'de', 'en', 'fr', 'es'});
  });

  test('a household walks the same shuffle on every device', () {
    final deck = [
      for (var i = 0; i < 30; i++) TableQuestion(key: 'de:q-$i', text: '$i'),
    ];
    final a = householdShuffle(deck, 'household-1');
    final b = householdShuffle(deck.reversed.toList(), 'household-1');
    expect(a.map((q) => q.key), b.map((q) => q.key));
    final other = householdShuffle(deck, 'household-2');
    expect(other.map((q) => q.key), isNot(a.map((q) => q.key)));
  });

  test('no question repeats before the deck is through', () {
    final deck = [
      for (var i = 0; i < 12; i++) TableQuestion(key: 'en:q-$i', text: '$i'),
    ];
    final shuffled = householdShuffle(deck, 'h');
    final start = mealWindowIndex(DateTime(2026, 10, 24), dinner: false);
    final seen = {
      for (var w = start; w < start + 12; w++) questionFor(shuffled, w)!.key,
    };
    expect(seen.length, 12);
  });

  test('lunch and dinner are two windows a day', () {
    final lunch = mealWindowIndex(DateTime(2026, 10, 24), dinner: false);
    expect(mealWindowIndex(DateTime(2026, 10, 24), dinner: true), lunch + 1);
    expect(mealWindowIndex(DateTime(2026, 10, 25), dinner: false), lunch + 2);
  });

  test(
    'with one warm meal a day the whole deck comes round (review finding)',
    () {
      final deck = [
        for (var i = 0; i < 150; i++) TableQuestion(key: 'de:q-$i', text: '$i'),
      ];
      final shuffled = householdShuffle(deck, 'h');
      final seen = {
        for (var d = 0; d < 150; d++)
          questionFor(
            shuffled,
            mealWindowIndex(
              DateTime(2026, 10, 24 + d),
              dinner: true,
              twoADay: false,
            ),
          )!.key,
      };
      expect(seen.length, 150);
    },
  );
}
