import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/ui/edge_fade.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_mode_store.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';
import 'package:wuselwall/features/shopping/ui/shopping_widgets.dart';

import '../support/fakes.dart';

CatalogEntry entry(
  String name,
  int count, {
  DateTime? last,
  bool pinned = false,
}) => CatalogEntry(
  id: name,
  listId: 'l1',
  name: name,
  foldedName: name.toLowerCase(),
  categoryId: null,
  purchaseCount: count,
  lastPurchasedAt: last,
  pinned: pinned,
);

/// Pumps the shopping body on the wall (or in [register]), with [catalog] as the
/// household's catalogue, [items] on the list and [lists] to switch between.
Future<void> pumpBody(
  WidgetTester t,
  List<CatalogEntry> catalog, {
  UiRegister register = UiRegister.kiosk,
  Size size = const Size(1280, 800),
  List<ShoppingItem>? items,
  List<ShoppingCategory> categories = const [],
  List<ShoppingList> lists = const [
    ShoppingList(id: 'l1', name: 'Supermarkt', isDefault: true, openCount: 1),
  ],
}) async {
  final shown = items ?? [item('1', 'Milch')];
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        uiRegisterProvider.overrideWithValue(register),
        shoppingViewProvider.overrideWithValue(
          AsyncData(
            ShoppingView(
              items: shown,
              lists: lists,
              categories: categories,
              catalog: catalog,
              pendingCount: 0,
            ),
          ),
        ),
        shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
        shoppingModeStoreProvider.overrideWithValue(MemoryShoppingModeStore()),
        shoppingRepositoryProvider.overrideWithValue(
          FakeShoppingRepository(shown),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.build(register, Shade.light),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        locale: const Locale('de'),
        home: const Scaffold(body: ShoppingBody()),
      ),
    ),
  );
  await t.pump();
}

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
    await pumpBody(t, catalog);

    final strip = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(strip, findsOneWidget);
    expect(t.getSize(strip).height, lessThan(200));
  });

  final many = [
    for (final n in [
      'Milch',
      'Brot',
      'Bananen',
      'Äpfel',
      'Butter',
      'Eier',
      'Käse',
      'Joghurt',
      'Gurke',
    ])
      entry(n, 3),
  ];

  testWidgets('a short phone keeps more than one list row in sight', (t) async {
    await pumpBody(
      t,
      many,
      register: UiRegister.adult,
      size: const Size(360, 640),
      items: [
        for (final (i, n) in ['Tomaten', 'Gurke', 'Brot', 'Käse'].indexed)
          item('$i', n),
      ],
    );
    // 30% of the screen (192 of 640), not two and a half rows: the list below keeps
    // its rows.
    final grid = find
        .ancestor(
          of: find.byType(Wrap),
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    expect(t.getSize(grid).height, lessThanOrEqualTo(192));
    final finish = t.getRect(find.text('Einkaufen gehen')).top;
    final whole = [
      for (final n in ['Tomaten', 'Gurke', 'Brot', 'Käse'])
        for (final e in find.text(n).evaluate())
          if (e.findAncestorWidgetOfExactType<ListTile>() != null)
            t.getRect(find.byWidget(e.widget).first),
    ].where((r) => r.bottom <= finish);
    expect(whole.length, greaterThanOrEqualTo(2));
  });

  test('the tile grid is 30% of the screen, between 112 and 240', () {
    expect(tileGridHeight(300), 112);
    expect(tileGridHeight(400), closeTo(120, 0.01));
    expect(tileGridHeight(640), closeTo(192, 0.01));
    expect(tileGridHeight(800), 240);
    expect(tileGridHeight(1400), 240);
  });

  test('pinned tiles come first, most bought first, then by name', () {
    final tiles = rankTiles([
      entry('Milch', 9),
      entry('Brot', 7, pinned: true),
      entry('Zucker', 1, pinned: true),
      entry('Apfel', 1, pinned: true),
      entry('Kaffee', 20, last: DateTime(2026, 10, 10)),
    ], '');
    expect(tiles.map((t) => t.name), [
      'Brot',
      'Apfel',
      'Zucker',
      'Kaffee',
      'Milch',
    ]);
  });

  test(
    'with a query a pinned match beats an unpinned one of the same score',
    () {
      final names = rankTiles([
        entry('Milch', 9),
        entry('Milchreis', 2, pinned: true),
        entry('Buttermilch', 30),
      ], 'milch').map((t) => t.name);
      // Both prefix matches first (the pinned one ahead), the word-less substring last.
      expect(names, ['Milchreis', 'Milch', 'Buttermilch']);
    },
  );

  testWidgets('the tiles fill the width of a wide phone', (t) async {
    await pumpBody(
      t,
      many,
      register: UiRegister.adult,
      size: const Size(540, 1100),
    );
    final tiles = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('shopping-tile-'),
    );
    expect(tiles, findsNWidgets(many.length));
    var right = 0.0;
    for (final e in tiles.evaluate()) {
      final r = t.getRect(find.byWidget(e.widget).first);
      if (r.right > right) right = r.right;
    }
    // The last column ends at the right margin, not ¾ across.
    expect(right, closeTo(540 - 16, 2));
  });

  testWidgets('a tinted tile says it is on the list already', (t) async {
    await pumpBody(
      t,
      many,
      register: UiRegister.adult,
      size: const Size(390, 844),
    );
    expect(find.byTooltip('Schon auf der Liste'), findsOneWidget);
  });

  testWidgets('the list chips fade at the edge while more lie beyond', (
    t,
  ) async {
    await pumpBody(
      t,
      many,
      register: UiRegister.adult,
      size: const Size(390, 844),
      lists: [
        for (final (i, n) in [
          'Supermarkt',
          'Drogerie',
          'Baumarkt',
          'Apotheke',
        ].indexed)
          ShoppingList(
            id: 'l${i + 1}',
            name: n,
            isDefault: i == 0,
            openCount: 3,
          ),
      ],
    );
    final fade = find.byType(EdgeFade);
    expect(fade, findsOneWidget);
    final state = t.state(fade) as dynamic;
    expect((state.fades as ({bool start, bool end})).end, isTrue);
    // The pencil sits beside the row, never over a chip.
    final pencil = t.getRect(find.byKey(const ValueKey('edit-list')));
    final row = t.getRect(fade);
    expect(row.right, lessThanOrEqualTo(pencil.left));
  });

  testWidgets('a tile shows its item\'s picture, else the category icon', (
    t,
  ) async {
    await pumpBody(t, [
      CatalogEntry(
        id: 'm',
        listId: 'l1',
        name: 'Milch',
        foldedName: 'milch',
        categoryId: null,
        purchaseCount: 5,
        lastPurchasedAt: null,
        iconKey: 'milk',
      ),
      CatalogEntry(
        id: 'u',
        listId: 'l1',
        name: 'Einhorn',
        foldedName: 'einhorn',
        categoryId: null,
        purchaseCount: 2,
        lastPurchasedAt: null,
        iconKey: 'unicorn',
      ),
    ]);

    final milkPicture = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/emoji/shopping/milk.png',
    );
    expect(milkPicture, findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    // The unknown key falls back to the category icon (no category: the basket).
    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.shopping_basket_outlined,
      ),
      findsOneWidget,
    );
  });
}
