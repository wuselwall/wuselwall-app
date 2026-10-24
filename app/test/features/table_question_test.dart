import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
        expect(q.deck, anyOf('family', 'older'), reason: q.key);
        expect(q.category == 'riddle', q.answer != null, reason: q.key);
      }
      // Gratitude stays rare: at most one in ten.
      expect(
        deck.where((q) => q.category == 'thanks').length,
        lessThanOrEqualTo(deck.length ~/ 10),
      );
    });
  }

  test('French and Spanish decks come later (Q53)', () {
    expect(tableQuestionLanguages, isNot(contains('fr')));
    expect(tableQuestionLanguages, isNot(contains('es')));
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
}
