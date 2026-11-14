import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/text/suggest.dart';

import '../support/fakes.dart';

TextSuggestion _s(String text, {int count = 1, DateTime? lastUsed}) =>
    TextSuggestion(text: text, count: count, lastUsed: lastUsed);

List<String> _texts(List<TextSuggestion> list) => [
  for (final s in list) s.text,
];

void main() {
  group('rankSuggestions', () {
    test('proposes nothing for an empty or blank query', () {
      final entries = [_s('Zahnarzt')];
      expect(rankSuggestions('', entries), isEmpty);
      expect(rankSuggestions('   ', entries), isEmpty);
    });

    test('proposes nothing without entries or with a zero limit', () {
      expect(rankSuggestions('z', const []), isEmpty);
      expect(rankSuggestions('z', [_s('Zahnarzt')], limit: 0), isEmpty);
    });

    test('a prefix match ignores case, umlauts and accents', () {
      final entries = [_s('Ärztin Müller'), _s('Café Ole'), _s('Turnen')];
      expect(_texts(rankSuggestions('aerz', entries)), ['Ärztin Müller']);
      expect(_texts(rankSuggestions('CAFE', entries)), ['Café Ole']);
      expect(_texts(rankSuggestions('tu', entries)), ['Turnen']);
    });

    test('a word inside the entry matches, split on space, dash and slash', () {
      final entries = [
        _s('Elternabend Schule'),
        _s('Eltern-Kind-Turnen'),
        _s('Judo/Turnen'),
      ];
      expect(
        _texts(rankSuggestions('turnen', entries)),
        unorderedEquals(['Eltern-Kind-Turnen', 'Judo/Turnen']),
      );
      expect(_texts(rankSuggestions('schu', entries)), ['Elternabend Schule']);
      // A match in the middle of a word is not a match.
      expect(rankSuggestions('ernabend', entries), isEmpty);
    });

    test('an entry that equals the query is not proposed', () {
      final entries = [_s('Turnen'), _s('Turnen Kinder')];
      expect(_texts(rankSuggestions('turnen', entries)), ['Turnen Kinder']);
      expect(_texts(rankSuggestions('  TURNEN ', entries)), ['Turnen Kinder']);
    });

    test('a prefix match ranks before a word match, however often used', () {
      final entries = [
        _s('Kinder Turnen', count: 9),
        _s('Turnen Mädchen', count: 1),
      ];
      expect(_texts(rankSuggestions('tur', entries)), [
        'Turnen Mädchen',
        'Kinder Turnen',
      ]);
    });

    test('inside a rank: count, then recency, then alphabetical', () {
      final old = testNow().subtract(const Duration(days: 30));
      final recent = testNow().subtract(const Duration(days: 2));
      final entries = [
        _s('Tanz', count: 1, lastUsed: old),
        _s('Tennis', count: 3, lastUsed: old),
        _s('Turnen', count: 1, lastUsed: recent),
        _s('Theater', count: 1, lastUsed: recent),
        _s('Tee', count: 1),
      ];
      expect(_texts(rankSuggestions('t', entries)), [
        'Tennis',
        'Theater',
        'Turnen',
        'Tanz',
        'Tee',
      ]);
    });

    test('proposes at most the limit', () {
      final entries = [for (var i = 0; i < 9; i++) _s('Termin $i')];
      expect(rankSuggestions('t', entries), hasLength(5));
      expect(rankSuggestions('t', entries, limit: 2), hasLength(2));
    });
  });

  group('buildSuggestions', () {
    final now = testNow();
    SuggestionRow row(
      String text, {
      int daysAgo = 0,
      String? location,
      String? iconKey,
    }) => SuggestionRow(
      text: text,
      usedAt: now.subtract(Duration(days: daysAgo)),
      location: location,
      iconKey: iconKey,
    );

    test('groups by folded text and counts the rows', () {
      final list = buildSuggestions([
        row('Zahnärztin', daysAgo: 3),
        row('zahnaerztin', daysAgo: 1),
        row('Turnen'),
      ]);
      expect(list, hasLength(2));
      final dentist = list.firstWhere((s) => s.count == 2);
      // The newest row's spelling, and its date.
      expect(dentist.text, 'zahnaerztin');
      expect(dentist.lastUsed, now.subtract(const Duration(days: 1)));
    });

    test('the place and the picture are the most frequent non-empty ones', () {
      final list = buildSuggestions([
        row('Turnen', daysAgo: 1, location: 'Halle B', iconKey: 'ball'),
        row('Turnen', daysAgo: 2, location: 'Halle A', iconKey: 'ball'),
        row('Turnen', daysAgo: 3, location: 'Halle A'),
        row('Turnen', daysAgo: 4, location: '', iconKey: 'star'),
      ]);
      expect(list.single.location, 'Halle A');
      expect(list.single.iconKey, 'ball');
    });

    test('a tie goes to the more recent value', () {
      final list = buildSuggestions([
        row('Turnen', daysAgo: 5, location: 'Halle A'),
        row('Turnen', daysAgo: 1, location: 'Halle B'),
      ]);
      expect(list.single.location, 'Halle B');
    });

    test('no place or picture stays null; empty texts are dropped', () {
      final list = buildSuggestions([
        row('Turnen'),
        row('   '),
        const SuggestionRow(text: ''),
      ]);
      expect(list, hasLength(1));
      expect(list.single.location, isNull);
      expect(list.single.iconKey, isNull);
    });

    test('rows without dates still group', () {
      final list = buildSuggestions(const [
        SuggestionRow(text: 'Turnen'),
        SuggestionRow(text: 'turnen'),
      ]);
      expect(list.single.count, 2);
      expect(list.single.lastUsed, isNull);
    });
  });
}
