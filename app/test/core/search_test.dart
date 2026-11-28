import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/text/search.dart';

/// The rank of [query] against [fields]; null when it does not answer.
int? _rank(String query, List<String?> fields) =>
    searchRank(searchTerms(query), fields);

void main() {
  group('searchTerms', () {
    test('folds case, umlauts and accents', () {
      expect(searchTerms('Käse'), ['kaese']);
      expect(searchTerms('CAFÉ'), ['cafe']);
    });

    test('splits at any run of blanks and drops the empty pieces', () {
      expect(searchTerms('  Zahnarzt \t Müller  '), ['zahnarzt', 'mueller']);
    });

    test('a query of blanks, or nothing, has no terms', () {
      expect(searchTerms(''), isEmpty);
      expect(searchTerms('   \n '), isEmpty);
    });
  });

  group('searchRank', () {
    test('case, umlauts and accents do not matter, in either direction', () {
      expect(_rank('kaese', ['Käse']), isNotNull);
      expect(_rank('KÄSE', ['kaese']), isNotNull);
      expect(_rank('käse', ['Käse']), isNotNull);
      expect(_rank('cafe', ['Café Müller']), isNotNull);
      expect(_rank('ecole', ['École']), isNotNull);
      expect(_rank('strasse', ['Straße']), isNotNull);
    });

    test('a term in none of the fields does not answer', () {
      expect(_rank('käse', ['Brot', 'Bäckerei']), isNull);
    });

    test('every term has to be found, possibly in different fields', () {
      const fields = ['Zahnarzt', 'Praxis Berger'];
      expect(_rank('zahnarzt berger', fields), isNotNull);
      expect(_rank('berger zahnarzt', fields), isNotNull);
      expect(_rank('zahnarzt müller', fields), isNull);
    });

    test('with no terms, or no fields, nothing answers', () {
      expect(searchRank(const [], ['Zahnarzt']), isNull);
      expect(searchRank(const ['zahnarzt'], const []), isNull);
      expect(searchRank(const ['zahnarzt'], [null, '']), isNull);
    });

    test('a missing field never answers but keeps its place', () {
      final first = _rank('müller', ['Müller']);
      final second = _rank('müller', ['Schmidt', 'Müller']);
      final secondAfterGap = _rank('müller', [null, 'Müller']);
      expect(secondAfterGap, second);
      expect(secondAfterGap, greaterThan(first!));
      // A later field's rank does not shift when an earlier one is null.
      expect(
        _rank('müller', ['Schmidt', null, 'Müller']),
        greaterThan(second!),
      );
      expect(
        _rank('müller', ['Schmidt', null, 'Müller']),
        _rank('müller', ['Schmidt', 'Meier', 'Müller']),
      );
    });

    test(
      'the start of the field beats the start of a word beats the middle',
      () {
        final start = _rank('arzt', ['Arztpraxis'])!;
        final word = _rank('arzt', ['Frau Arzt'])!;
        final inside = _rank('arzt', ['Zahnarzt'])!;
        expect(start, lessThan(word));
        expect(word, lessThan(inside));
      },
    );

    test('a word that starts with the term counts, wherever it stands', () {
      // The first "arzt" is inside "Zahnarzt"; the later one starts a word.
      expect(
        _rank('arzt', ['Zahnarzt oder Arzt']),
        _rank('arzt', ['Frau Arzt']),
      );
      expect(_rank('taxi', ['Mama-Taxi']), _rank('taxi', ['Frau Taxi']));
    });

    test('an earlier field beats a later one, whatever the position in it', () {
      final inTitle = _rank('arzt', ['Zahnarzt', 'Notiz'])!;
      final inNote = _rank('arzt', ['Notiz', 'Arzt'])!;
      expect(inTitle, lessThan(inNote));
    });

    test('the title counts before the place, the place before the note', () {
      final title = _rank('halle', ['Halle B', 'Turnen', 'Bitte pünktlich'])!;
      final place = _rank('halle', ['Turnen', 'Halle B', 'Bitte pünktlich'])!;
      final note = _rank('halle', ['Turnen', 'Bitte pünktlich', 'Halle B'])!;
      expect(title, lessThan(place));
      expect(place, lessThan(note));
    });

    test('more terms found lower in the fields rank worse in total', () {
      final both = _rank('zahnarzt berger', ['Zahnarzt Berger'])!;
      final spread = _rank('zahnarzt berger', ['Zahnarzt', 'Berger'])!;
      expect(both, lessThan(spread));
    });
  });

  group('searchIn', () {
    List<String?> title(String item) => [item];

    test('finds what answers and leaves out what does not', () {
      expect(searchIn('kaese', ['Brot', 'Käse', 'Milch'], title), ['Käse']);
    });

    test('puts the best answer first', () {
      expect(searchIn('arzt', ['Zahnarzt', 'Frau Arzt', 'Arztpraxis'], title), [
        'Arztpraxis',
        'Frau Arzt',
        'Zahnarzt',
      ]);
    });

    test('answers that rank equally keep the order they came in', () {
      expect(
        searchIn('apfel', [
          'Apfelsaft',
          'Apfelmus',
          'Apfel',
          'Apfelkuchen',
        ], title),
        ['Apfelsaft', 'Apfelmus', 'Apfel', 'Apfelkuchen'],
      );
      expect(searchIn('b', ['Bb', 'Ba', 'Bc'], title), ['Bb', 'Ba', 'Bc']);
    });

    test('an earlier field beats a later one across the items', () {
      final items = [
        (title: 'Turnen', place: 'Halle'),
        (title: 'Halle putzen', place: 'Keller'),
      ];
      final found = searchIn('halle', items, (e) => [e.title, e.place]);
      expect(found.map((e) => e.title), ['Halle putzen', 'Turnen']);
    });

    test('a null field is skipped', () {
      final items = <({String title, String? place})>[
        (title: 'Turnen', place: null),
        (title: 'Schwimmen', place: 'Hallenbad'),
      ];
      final found = searchIn('halle', items, (e) => [e.title, e.place]);
      expect(found.map((e) => e.title), ['Schwimmen']);
    });

    test('the limit keeps the best answers, not the first ones', () {
      final found = searchIn(
        'arzt',
        ['Zahnarzt', 'Arzt', 'Tierarzt', 'Arztpraxis'],
        title,
        limit: 2,
      );
      expect(found, ['Arzt', 'Arztpraxis']);
    });

    test('a limit above the number of answers changes nothing', () {
      expect(searchIn('arzt', ['Arzt'], title, limit: 10), ['Arzt']);
    });

    test('an empty query, or one of blanks, finds nothing', () {
      expect(searchIn('', ['Arzt', 'Brot'], title), isEmpty);
      expect(searchIn('   ', ['Arzt', 'Brot'], title), isEmpty);
    });

    test('nothing to look through finds nothing', () {
      expect(searchIn('arzt', const <String>[], title), isEmpty);
    });

    test('it works through any iterable', () {
      expect(searchIn('r', {'Arzt', 'Brot'}, title), ['Arzt', 'Brot']);
    });
  });
}
