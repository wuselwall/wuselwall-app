import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/matching/quantity_parser.dart';

ParsedItem item(String name, {String? quantity, int? count}) =>
    ParsedItem(name: name, quantity: quantity, count: count);

void main() {
  group('leading amounts (as the server reads them)', () {
    test('units and numbers', () {
      expect(parseShoppingText('2 Liter Milch und Eier'), [
        item('Milch', quantity: '2 l'),
        item('Eier'),
      ]);
      expect(parseShoppingText('3 Äpfel, Brot'), [
        item('Äpfel', count: 3),
        item('Brot'),
      ]);
      expect(parseShoppingText('zwei Gurken'), [item('Gurken', count: 2)]);
      expect(parseShoppingText('500g Mehl'), [item('Mehl', quantity: '500 g')]);
      expect(parseShoppingText('1,5 kg Kartoffeln'), [
        item('Kartoffeln', quantity: '1,5 kg'),
      ]);
      expect(parseShoppingText('eine Packung Reis'), [
        item('Reis', quantity: '1 Packung'),
      ]);
      expect(parseShoppingText('2 Liter Milch'), [
        item('Milch', quantity: '2 l'),
      ]);
    });

    test('fillers, punctuation and English', () {
      expect(parseShoppingText('Bitte noch Butter.'), [item('Butter')]);
      expect(parseShoppingText('Bitte Milch'), [item('Milch')]);
      expect(parseShoppingText('a dozen eggs and milk'), [
        item('Eggs', quantity: '1 dozen'),
        item('Milk'),
      ]);
      expect(parseShoppingText('2 cans of tomatoes'), [
        item('Tomatoes', quantity: '2 cans'),
      ]);
      expect(parseShoppingText('Milch & Brot + Käse'), [
        item('Milch'),
        item('Brot'),
        item('Käse'),
      ]);
    });

    test('a word that only looks like a number stays the name', () {
      expect(parseShoppingText('Eis'), [item('Eis')]);
      expect(parseShoppingText('7 Up'), [item('Up', count: 7)]);
      expect(parseShoppingText(''), isEmpty);
      expect(parseShoppingText(' , und '), isEmpty);
    });

    test('at most twenty items, or the limit given', () {
      final many = List.generate(25, (i) => 'Ding$i').join(', ');
      expect(parseShoppingText(many), hasLength(20));
      expect(parseShoppingText(many, maxItems: 3), hasLength(3));
    });

    test('French and Spanish', () {
      expect(parseShoppingText('deux litres de lait et trois pommes'), [
        item('Lait', quantity: '2 l'),
        item('Pommes', count: 3),
      ]);
      expect(parseShoppingText('dos litros de leche y una docena de huevos'), [
        item('Leche', quantity: '2 l'),
        item('Huevos', quantity: '1 docena'),
      ]);
    });

    test('a count of one is no count; long names are cut', () {
      expect(parseShoppingItem('eine Gurke'), item('Gurke'));
      expect(parseShoppingItem('2 ${'x' * 200}')!.name, hasLength(120));
    });

    test('a decimal comma does not split', () {
      expect(parseShoppingText('1,5 l Milch, Brot'), [
        item('Milch', quantity: '1,5 l'),
        item('Brot'),
      ]);
    });
  });

  group('trailing amounts (the app only)', () {
    test('a unit glued to the number', () {
      expect(parseShoppingItem('Milch 1l'), item('Milch', quantity: '1 l'));
      expect(parseShoppingItem('Cola 1,5l'), item('Cola', quantity: '1,5 l'));
      expect(parseShoppingItem('Mehl 500g'), item('Mehl', quantity: '500 g'));
    });

    test('a number and a unit', () {
      expect(
        parseShoppingItem('Kartoffeln 2 kg'),
        item('Kartoffeln', quantity: '2 kg'),
      );
      expect(
        parseShoppingItem('Bio Milch 1,5 Liter'),
        item('Bio Milch', quantity: '1,5 l'),
      );
    });

    test('a bare number is the count', () {
      expect(parseShoppingItem('Eier 6'), item('Eier', count: 6));
      expect(parseShoppingItem('Joghurt 4x'), item('Joghurt', count: 4));
      expect(parseShoppingItem('Joghurt x4'), item('Joghurt', count: 4));
      expect(parseShoppingItem('Eier 1'), item('Eier'));
    });

    test('a number that is not 1 to 99 whole becomes the quantity', () {
      expect(parseShoppingItem('Mehl 0,5'), item('Mehl', quantity: '0,5'));
      expect(parseShoppingItem('Reis 100'), item('Reis', quantity: '100'));
      expect(parseShoppingItem('Reis 0'), item('Reis', quantity: '0'));
    });

    test('a leading amount wins and the trailing one stays in the name', () {
      expect(
        parseShoppingItem('2 Liter Milch 3'),
        item('Milch 3', quantity: '2 l'),
      );
      expect(parseShoppingItem('zwei Brote 4'), item('Brote 4', count: 2));
    });

    test('a lone number or word is the name', () {
      expect(parseShoppingItem('6'), item('6'));
      expect(parseShoppingItem('Milch'), item('Milch'));
      expect(parseShoppingItem('   '), isNull);
    });

    test('trailing forms work inside a list', () {
      expect(parseShoppingText('Milch 1l, Eier 6 und Joghurt 4x'), [
        item('Milch', quantity: '1 l'),
        item('Eier', count: 6),
        item('Joghurt', count: 4),
      ]);
    });
  });
}
