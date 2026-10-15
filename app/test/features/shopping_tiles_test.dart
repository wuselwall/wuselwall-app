import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';

import '../support/fakes.dart';

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

  testWidgets('on the wall the tiles are one row and leave room for the list', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          uiRegisterProvider.overrideWithValue(UiRegister.kiosk),
          shoppingViewProvider.overrideWithValue(
            AsyncData(
              ShoppingView(
                items: [item('1', 'Milch')],
                lists: const [
                  ShoppingList(
                    id: 'l1',
                    name: 'Supermarkt',
                    isDefault: true,
                    openCount: 1,
                  ),
                ],
                categories: const [],
                catalog: catalog,
                pendingCount: 0,
              ),
            ),
          ),
          shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
          shoppingRepositoryProvider.overrideWithValue(
            FakeShoppingRepository([item('1', 'Milch')]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(UiRegister.kiosk, Shade.light),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          locale: const Locale('de'),
          home: const Scaffold(body: ShoppingBody()),
        ),
      ),
    );
    await t.pump();

    final strip = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(strip, findsOneWidget);
    expect(t.getSize(strip).height, lessThan(200));
  });
}
