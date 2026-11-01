import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:wuselwall/core/matching/dictionary.dart';
import 'package:wuselwall/core/matching/matcher.dart';

const _json = '''
{"version": 1, "domains": {
  "shopping": {"entries": [
    {"key": "milk", "categories": ["dairy"], "words": ["milch", "milk", "lait"]},
    {"key": "carrot", "categories": ["vegetables"],
     "words": ["karotte", "karotten", "rueebli", "carrot", "carrots", "carotte"]},
    {"key": "juice", "categories": ["drinks"], "words": ["saft", "juice", "jus", "zumo"]},
    {"key": "orange", "categories": ["fruit"], "words": ["orange", "orangen", "naranja"]},
    {"key": "tomato", "categories": ["vegetables"], "words": ["tomate", "tomaten", "tomato"]},
    {"key": "cheese", "categories": ["dairy"], "words": ["kaese", "cheese", "fromage"]}
  ]},
  "meals": {"entries": [
    {"key": "pasta", "categories": ["main"], "words": ["Spaghetti", "Nudeln"]}
  ]}
}}
''';

void main() {
  final dictionaries = MatchDictionaries.parse(_json);
  final shopping = dictionaries.byDomain['shopping']!;
  final matcher = Matcher(shopping);

  void expectMatch(String text, String key, MatchLayer layer) {
    final m = matcher.match(text);
    expect(m, isNotNull, reason: text);
    expect(m!.key, key, reason: text);
    expect(m.layer, layer, reason: text);
  }

  group('dictionary', () {
    test('both domains load, words are normalised', () {
      expect(dictionaries.byDomain.keys, containsAll(['shopping', 'meals']));
      expect(dictionaries.byDomain['meals']!.byPhrase.keys, [
        'spaghetti',
        'nudeln',
      ]);
    });

    test('indexes', () {
      expect(shopping.byPhrase['milch']!.key, 'milk');
      expect(shopping.singleWords, contains('saft'));
      expect(shopping.singleWordsByLength[4], containsAll(['saft', 'lait']));
    });

    test('phrases with spaces are not single words', () {
      final d = MatchDictionary.fromJson('x', {
        'entries': [
          {
            'key': 'cream',
            'categories': <String>[],
            'words': ['Crème fraîche'],
          },
        ],
      });
      expect(d.byPhrase.keys, ['creme fraiche']);
      expect(d.singleWords, isEmpty);
    });
  });

  group('layers', () {
    test('phrase', () {
      expectMatch('Milch', 'milk', MatchLayer.phrase);
      expectMatch('  MILCH! ', 'milk', MatchLayer.phrase);
    });

    test('quantity is stripped first', () {
      expectMatch('Rüebli 1kg', 'carrot', MatchLayer.phrase);
      expectMatch('2 Liter Milch', 'milk', MatchLayer.phrase);
      expectMatch('Tomaten 6', 'tomato', MatchLayer.phrase);
    });

    test('without stripping the quantity is part of the text', () {
      final raw = Matcher(shopping, stripQuantity: false);
      expect(raw.match('Rüebli 1kg')!.layer, isNot(MatchLayer.phrase));
    });

    test('word: the last word heads an English or German phrase', () {
      expectMatch('orange juice', 'juice', MatchLayer.word);
    });

    test('word: a connector makes the first word the head', () {
      expectMatch("jus d'orange", 'juice', MatchLayer.word);
      expectMatch('zumo de naranja', 'juice', MatchLayer.word);
    });

    test('stem', () {
      final m = matcher.match('Tomates')!;
      expect(m.key, 'tomato');
      expect(m.layer, MatchLayer.stem);
      expect(m.matchedWord, 'tomate');
    });

    test('compound', () {
      final m = matcher.match('Bio Vollmilch 1,5l')!;
      expect(m.key, 'milk');
      expect(m.layer, MatchLayer.compound);
      expect(m.matchedWord, 'milch');
    });

    test('compound: the end of the word is the head, not the start', () {
      // "karotten" is in the dictionary too, but the word ends in "saft".
      expectMatch('Karottensaft', 'juice', MatchLayer.compound);
    });

    test('compound with a plural ending', () {
      expectMatch('Cherrytomaten', 'tomato', MatchLayer.compound);
      expectMatch('Cocktailtomate', 'tomato', MatchLayer.compound);
    });

    test('fuzzy', () {
      final m = matcher.match('Tomatten')!;
      expect(m.key, 'tomato');
      expect(m.layer, MatchLayer.fuzzy);
      expect(m.matchedWord, 'tomaten');
    });

    test('fuzzy takes two typos in a long word only', () {
      expect(matcher.match('Fromagee'), isNotNull);
      expect(matcher.match('Frmgae'), isNull);
      expect(matcher.match('Spaghetti'), isNull);
    });

    test('fuzzy never guesses at stopwords or digits', () {
      expect(matcher.match('frisch'), isNull);
      expect(matcher.match('12345'), isNull);
    });

    test('household override wins over everything', () {
      final m = Matcher(
        shopping,
        householdOverrides: {'gipfeli': 'cheese', 'milch': 'cheese'},
      );
      final hit = m.match('Gipfeli')!;
      expect(hit.key, 'cheese');
      expect(hit.layer, MatchLayer.household);
      expect(hit.categories, ['dairy']);
      expect(m.match('Milch')!.key, 'cheese');
    });

    test(
      'household override for a key the dictionary lacks has no categories',
      () {
        final m = Matcher(shopping, householdOverrides: {'zopf': 'bread'});
        final hit = m.match('Zopf')!;
        expect(hit.key, 'bread');
        expect(hit.categories, isEmpty);
      },
    );
  });

  group('no match', () {
    test('empty and unknown', () {
      expect(matcher.match(''), isNull);
      expect(matcher.match('   '), isNull);
      expect(matcher.match('!!'), isNull);
      expect(matcher.match('xyz'), isNull);
    });
  });

  group('confidence', () {
    test('falls from layer to layer', () {
      const order = [
        MatchLayer.household,
        MatchLayer.phrase,
        MatchLayer.word,
        MatchLayer.stem,
        MatchLayer.compound,
        MatchLayer.fuzzy,
      ];
      final values = [
        for (final l in order)
          Match(
            key: 'k',
            categories: const [],
            layer: l,
            matchedWord: 'w',
          ).confidence,
      ];
      expect(values, [1.0, 0.95, 0.9, 0.8, 0.75, 0.6]);
    });
  });
}
