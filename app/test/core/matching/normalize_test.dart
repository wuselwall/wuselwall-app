import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/matching/normalize.dart';

void main() {
  group('normalizeText', () {
    test('punctuation becomes one space', () {
      expect(normalizeText('WC-Papier'), 'wc papier');
      expect(normalizeText("Jus d'orange"), 'jus d orange');
      expect(normalizeText('  Milch,  1,5 %  '), 'milch 1 5');
    });

    test('folds umlauts and accents', () {
      expect(normalizeText('Rüebli'), 'rueebli');
      expect(normalizeText('Crème fraîche'), 'creme fraiche');
      expect(normalizeText('Straße'), 'strasse');
    });

    test('nothing left gives an empty string', () {
      expect(normalizeText(''), '');
      expect(normalizeText(' - ! '), '');
    });
  });

  group('tokens', () {
    test('splits on spaces and drops empties', () {
      expect(tokens('jus d orange'), ['jus', 'd', 'orange']);
      expect(tokens('milch'), ['milch']);
      expect(tokens(''), isEmpty);
      expect(tokens('a  b'), ['a', 'b']);
    });
  });
}
