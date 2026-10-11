import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

CatalogEntry entry(String name, int count, {DateTime? last}) => CatalogEntry(
  id: name,
  listId: 'l1',
  name: name,
  foldedName: name.toLowerCase(),
  categoryId: null,
  purchaseCount: count,
  lastPurchasedAt: last,
);

void main() {
  final catalog = [
    entry('Milch', 9),
    entry('Buttermilch', 3),
    entry('Haferdrink mit Milch', 1),
    entry('Brot', 7),
  ];

  test('no query: most bought first, recents lead', () {
    final tiles = rankTiles([
      ...catalog,
      entry('Gummibärchen', 1, last: DateTime(2026, 10, 10)),
    ], '');
    expect(tiles.first.name, 'Gummibärchen');
    expect(tiles.skip(1).first.name, 'Milch');
  });

  test('prefix beats word start beats substring, ties by purchases', () {
    final names = rankTiles(catalog, 'milch').map((t) => t.name);
    expect(names, ['Milch', 'Haferdrink mit Milch', 'Buttermilch']);
  });

  test('umlauts and case are forgiven', () {
    expect(
      rankTiles(
        [entry('Käse', 2)]
            .map(
              (e) => CatalogEntry(
                id: e.id,
                listId: e.listId,
                name: e.name,
                foldedName: 'kaese',
                categoryId: null,
                purchaseCount: 2,
                lastPurchasedAt: null,
              ),
            )
            .toList(),
        'KÄS',
      ).single.name,
      'Käse',
    );
  });
}
