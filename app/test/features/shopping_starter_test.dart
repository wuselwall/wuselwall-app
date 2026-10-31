import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/settings/application/app_locale_provider.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/application/starter_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_mode_store.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/data/starter_catalog.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';

import '../support/fakes.dart';

StarterItem s(String name, {String category = 'produce', String? icon}) =>
    StarterItem(name: name, category: category, icon: icon);

CatalogEntry entry(String name, int count, {String listId = 'l1'}) =>
    CatalogEntry(
      id: name,
      listId: listId,
      name: name,
      foldedName: name.toLowerCase(),
      categoryId: null,
      purchaseCount: count,
      lastPurchasedAt: null,
    );

/// [n] starter names "Vorschlag 01" … in popularity order.
List<StarterItem> numbered(int n) => [
  for (var i = 1; i <= n; i++) s('Vorschlag ${i.toString().padLeft(2, '0')}'),
];

class _SpySync extends ShoppingSync {
  final added = <String>[];

  @override
  Future<String> add({
    required String? actor,
    required String listId,
    required String name,
    String? quantity,
  }) async {
    added.add(name);
    return 'new';
  }
}

const _json = '''
{ "version": 1, "source": "test", "kinds": {
  "supermarket": { "categories": ["produce"], "items": {
    "de": [ { "name": "Bananen", "category": "produce", "icon": "banana" },
            { "name": "Brötchen", "category": "bakery", "icon": null } ],
    "de-CH": [ { "name": "Bananen", "category": "produce", "icon": "banana" },
               { "name": "Gipfeli", "category": "bakery", "icon": null } ],
    "en": [ { "name": "Bananas", "category": "produce", "icon": "banana" } ]
  } },
  "drugstore": { "categories": ["care"], "items": {
    "de": [ { "name": "Zahnpasta", "category": "care", "icon": null } ]
  } } } }
''';

void main() {
  group('the language tag', () {
    test('maps the locale to the tags of the bundle, German by default', () {
      expect(starterTagFor(const Locale('de')), 'de');
      expect(starterTagFor(const Locale('de', 'DE')), 'de');
      expect(starterTagFor(const Locale('de', 'CH')), 'de-CH');
      expect(starterTagFor(const Locale('de', 'LI')), 'de-CH');
      expect(starterTagFor(const Locale('de', 'AT')), 'de-AT');
      expect(starterTagFor(const Locale('en')), 'en');
      expect(starterTagFor(const Locale('en', 'GB')), 'en');
      expect(starterTagFor(const Locale('fr')), 'fr');
      expect(starterTagFor(const Locale('es')), 'es');
      expect(starterTagFor(const Locale('it')), 'de');
    });

    test(
      'the Swiss list overrides the German one, a missing tag falls back',
      () {
        final catalog = StarterCatalog.parse(_json);
        expect(catalog.items('supermarket', 'de').map((i) => i.name), [
          'Bananen',
          'Brötchen',
        ]);
        expect(catalog.items('supermarket', 'de-CH').map((i) => i.name), [
          'Bananen',
          'Gipfeli',
        ]);
        // de-AT is not in this bundle: German.
        expect(catalog.items('supermarket', 'de-AT').first.name, 'Bananen');
        expect(catalog.items('supermarket', 'en').single.name, 'Bananas');
        expect(catalog.items('hardware', 'de'), isEmpty);
        expect(StarterCatalog.empty.items('supermarket', 'de'), isEmpty);
      },
    );
  });

  test(
    'the bundled file has every kind in every language, with known pictures',
    () {
      final catalog = StarterCatalog.parse(
        File('assets/matching/starter.json').readAsStringSync(),
      );
      for (final kind in ['supermarket', 'drugstore', 'hardware']) {
        for (final tag in ['de', 'de-CH', 'de-AT', 'en', 'fr', 'es']) {
          final items = catalog.items(kind, tag);
          expect(items, isNotEmpty, reason: '$kind $tag');
          final names = items.map((i) => i.folded).toList();
          expect(
            names.toSet(),
            hasLength(names.length),
            reason: 'doubles $kind $tag',
          );
          for (final i in items) {
            expect(
              i.icon == null || shoppingIconKeys.contains(i.icon),
              isTrue,
              reason:
                  '${i.name} ($kind $tag): picture ${i.icon} is not bundled',
            );
          }
        }
      }
    },
  );

  group('the kind of a list', () {
    test('is told from its categories', () {
      String? kind(bool d, List<String?> keys) =>
          starterKindOf(isDefault: d, categoryKeys: keys);
      expect(kind(false, ['produce', 'bakery']), 'supermarket');
      expect(kind(false, ['care', 'baby']), 'drugstore');
      expect(kind(false, ['tools', 'screws']), 'hardware');
      expect(kind(false, ['produce', 'care']), 'supermarket');
    });

    test(
      'without a hint the default list is a supermarket, others have none',
      () {
        expect(starterKindOf(isDefault: true, categoryKeys: []), 'supermarket');
        expect(
          starterKindOf(isDefault: true, categoryKeys: [null, 'other']),
          'supermarket',
        );
        expect(starterKindOf(isDefault: false, categoryKeys: []), isNull);
        expect(starterKindOf(isDefault: false, categoryKeys: ['x']), isNull);
      },
    );
  });

  group('starterTiles', () {
    test('without a query keeps the popularity order, up to the limit', () {
      final names = starterTiles(numbered(30), '').map((i) => i.name).toList();
      expect(names, hasLength(24));
      expect(names.first, 'Vorschlag 01');
      expect(names.last, 'Vorschlag 24');
      expect(starterTiles(numbered(30), '', limit: 3), hasLength(3));
      expect(starterTiles(numbered(30), '', limit: 0), isEmpty);
    });

    test('skips the excluded names without counting them', () {
      final names = starterTiles(
        numbered(5),
        '',
        exclude: {'vorschlag 01', 'vorschlag 03'},
        limit: 2,
      ).map((i) => i.name);
      expect(names, ['Vorschlag 02', 'Vorschlag 04']);
    });

    test('a query ranks prefix, word start, substring; ties by popularity', () {
      final items = [
        s('Buttermilch'),
        s('Haferdrink mit Milch'),
        s('Milchreis'),
        s('Milch'),
        s('Zucker'),
      ];
      expect(starterTiles(items, 'milch').map((i) => i.name), [
        'Milchreis',
        'Milch',
        'Haferdrink mit Milch',
        'Buttermilch',
      ]);
      expect(
        starterTiles(items, 'MILCH', exclude: {'milch'}).map((i) => i.name),
        ['Milchreis', 'Haferdrink mit Milch', 'Buttermilch'],
      );
      expect(starterTiles(items, 'xyz'), isEmpty);
    });

    test('umlauts and case are forgiven', () {
      final items = [s('Brötchen'), s('Käse')];
      expect(starterTiles(items, 'broet').single.name, 'Brötchen');
      expect(starterTiles(items, 'KAESE').single.name, 'Käse');
    });
  });

  group('what the picker adds', () {
    final set = StarterSet(numbered(40));

    test('fills below 24 entries up to 24 tiles in all', () {
      final catalog = [entry('Milch', 5), entry('Brot', 3)];
      final starters = set.forPicker(
        catalog: catalog,
        shown: catalog,
        onList: const [],
        query: '',
      );
      expect(starters, hasLength(22));
      expect(starters.first.name, 'Vorschlag 01');
    });

    test('adds none at 24 entries or more', () {
      final catalog = [for (var i = 0; i < 24; i++) entry('Eigen $i', 24 - i)];
      expect(
        set.forPicker(
          catalog: catalog,
          shown: catalog,
          onList: const [],
          query: '',
        ),
        isEmpty,
      );
      expect(
        set.forPicker(
          catalog: catalog.take(23).toList(),
          shown: catalog.take(23).toList(),
          onList: const [],
          query: '',
        ),
        hasLength(1),
      );
    });

    test('skips names of the catalogue and open items', () {
      final catalog = [entry('Vorschlag 01', 5)];
      final starters = set.forPicker(
        catalog: catalog,
        shown: catalog,
        onList: [item('1', 'vorschlag 02'), item('2', 'Vorschlag 03')],
        query: '',
      );
      expect(starters.first.name, 'Vorschlag 04');
      expect(starters, hasLength(23));
    });

    test('a search appends the matches the catalogue does not show', () {
      final catalog = [entry('Vorschlag 05', 5)];
      final starters = set.forPicker(
        catalog: catalog,
        shown: catalog,
        onList: [item('1', 'Vorschlag 06')],
        query: 'vorschlag 0',
      );
      // Names on the list stay: the tile says "already on the list".
      expect(starters.map((i) => i.name), [
        'Vorschlag 01',
        'Vorschlag 02',
        'Vorschlag 03',
        'Vorschlag 04',
        'Vorschlag 06',
        'Vorschlag 07',
        'Vorschlag 08',
        'Vorschlag 09',
      ]);
    });

    test('a search still finds suggestions beside a big catalogue', () {
      final catalog = [for (var i = 0; i < 30; i++) entry('Eigen $i', 1)];
      final shown = catalog.take(3).toList();
      expect(
        set.forPicker(
          catalog: catalog,
          shown: shown,
          onList: const [],
          query: 'vorschlag 01',
        ),
        hasLength(1),
      );
    });
  });

  group('the picture bridge', () {
    final set = StarterSet([
      s('Bananen', icon: 'banana'),
      s('Brot'),
      s('Bananen', icon: 'other'),
    ]);

    test('gives an entry without a picture the one of its name', () {
      expect(set.pictureKey(null, 'Bananen'), 'banana');
      expect(set.pictureKey(null, 'bANANEN'), 'banana');
      expect(set.pictureKey(null, 'Brot'), isNull);
      expect(set.pictureKey(null, 'Fisch'), isNull);
    });

    test('keeps the server\'s own picture', () {
      expect(set.pictureKey('milk', 'Bananen'), 'milk');
    });
  });

  group('in the picker', () {
    late _SpySync spy;

    Future<void> pump(
      WidgetTester t, {
      required List<CatalogEntry> catalog,
      required List<StarterItem> starters,
      UiRegister register = UiRegister.adult,
      List<ShoppingItem>? items,
      Locale locale = const Locale('de'),
      List<ShoppingCategory> categories = const [],
      List<ShoppingList>? lists,
      Size size = const Size(1280, 1400),
      String kind = 'supermarket',
    }) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final shown = items ?? [item('1', 'Milch')];
      final bundle = StarterCatalog({
        kind: {'de': starters, 'de-CH': starters, 'en': starters},
      });
      spy = _SpySync();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            uiRegisterProvider.overrideWithValue(register),
            appLocaleProvider.overrideWithValue(locale),
            starterCatalogProvider.overrideWith((ref) async => bundle),
            shoppingViewProvider.overrideWithValue(
              AsyncData(
                ShoppingView(
                  items: shown,
                  lists:
                      lists ??
                      const [
                        ShoppingList(
                          id: 'l1',
                          name: 'Supermarkt',
                          isDefault: true,
                          openCount: 1,
                        ),
                      ],
                  categories: categories,
                  catalog: catalog,
                  pendingCount: 0,
                ),
              ),
            ),
            shoppingSyncProvider.overrideWith(() => spy),
            shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
            shoppingModeStoreProvider.overrideWithValue(
              MemoryShoppingModeStore(),
            ),
            shoppingRepositoryProvider.overrideWithValue(
              FakeShoppingRepository(shown),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.build(register, Shade.light),
            localizationsDelegates: localizationsDelegates,
            supportedLocales: supportedLocales,
            locale: locale,
            home: const Scaffold(body: ShoppingBody()),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    Finder starterTiles_() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('shopping-starter-'),
    );
    Finder ownTiles() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('shopping-tile-'),
    );

    testWidgets('a small catalogue is filled up to 24 tiles, in order', (
      t,
    ) async {
      await pump(
        t,
        catalog: [entry('Milch', 9), entry('Brot', 4)],
        starters: [s('Milch'), ...numbered(40)],
      );
      expect(ownTiles(), findsNWidgets(2));
      // "Milch" is the family's own already, the open item "Milch" too.
      expect(starterTiles_(), findsNWidgets(22));
      expect(
        find.byKey(const ValueKey('shopping-starter-milch')),
        findsNothing,
      );
      final order = [
        for (final e in starterTiles_().evaluate())
          (e.widget.key! as ValueKey<String>).value,
      ];
      expect(order.first, 'shopping-starter-vorschlag 01');
      // The suggested ones follow the family's own, left to right.
      expect(
        t.getTopLeft(find.byKey(const ValueKey('shopping-tile-brot'))).dx,
        lessThan(
          t
              .getTopLeft(
                find.byKey(const ValueKey('shopping-starter-vorschlag 01')),
              )
              .dx,
        ),
      );
    });

    testWidgets('an empty catalogue shows the suggestions alone', (t) async {
      await pump(t, catalog: const [], starters: numbered(30), items: const []);
      expect(ownTiles(), findsNothing);
      expect(starterTiles_(), findsNWidgets(24));
      expect(find.textContaining('Kacheln erscheinen'), findsNothing);
    });

    testWidgets('a catalogue of 24 entries has none', (t) async {
      await pump(
        t,
        catalog: [for (var i = 0; i < 24; i++) entry('Eigen $i', 30 - i)],
        starters: numbered(40),
      );
      expect(starterTiles_(), findsNothing);
      expect(ownTiles(), findsNWidgets(24));
    });

    testWidgets('a tap adds by name, the tile says it is a suggestion', (
      t,
    ) async {
      await pump(
        t,
        catalog: const [],
        starters: [s('Bananen')],
        items: const [],
      );
      expect(find.byTooltip('Vorschlag'), findsOneWidget);
      await t.tap(find.text('Bananen'));
      await t.pump();
      expect(spy.added, ['Bananen']);
    });

    testWidgets('the tile uses its picture, else its category icon', (t) async {
      await pump(
        t,
        catalog: const [],
        starters: [
          s('Bananen', icon: 'banana'),
          s('Zahnpasta', category: 'care'),
        ],
        items: const [],
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/emoji/shopping/banana.png',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.soap_outlined,
        ),
        findsOneWidget,
      );
    });

    testWidgets('a long press offers adding, not renaming or forgetting', (
      t,
    ) async {
      await pump(
        t,
        catalog: [entry('Brot', 4)],
        starters: [s('Bananen')],
        items: const [],
      );
      await t.longPress(find.byKey(const ValueKey('shopping-starter-bananen')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('tile-add')), findsOneWidget);
      expect(find.text('Hinzufügen'), findsOneWidget);
      expect(find.text('Hinzufügen und bearbeiten'), findsOneWidget);
      expect(find.byKey(const ValueKey('tile-rename')), findsNothing);
      expect(find.byKey(const ValueKey('tile-forget')), findsNothing);
      expect(find.byKey(const ValueKey('tile-pin')), findsNothing);

      await t.tap(find.byKey(const ValueKey('tile-add')));
      await t.pumpAndSettle();
      expect(spy.added, ['Bananen']);

      // The family's own tile keeps its sheet.
      await t.longPress(find.byKey(const ValueKey('shopping-tile-brot')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('tile-forget')), findsOneWidget);
    });

    testWidgets(
      'a search finds a suggestion and keeps "neu anlegen" for the rest',
      (t) async {
        await pump(
          t,
          catalog: [for (var i = 0; i < 30; i++) entry('Eigen $i', 30 - i)],
          starters: [s('Bananen'), s('Brötchen')],
          items: const [],
          size: const Size(390, 900),
        );
        expect(starterTiles_(), findsNothing);

        final field = find.byType(TextField);
        await t.enterText(field, 'Bana');
        await t.pump();
        expect(
          find.byKey(const ValueKey('shopping-starter-bananen')),
          findsOne,
        );
        expect(find.textContaining('neu anlegen'), findsOneWidget);

        await t.enterText(field, 'Bananen');
        await t.pump();
        expect(
          find.byKey(const ValueKey('shopping-starter-bananen')),
          findsOne,
        );
        expect(find.textContaining('neu anlegen'), findsNothing);

        await t.enterText(field, 'Kiwi');
        await t.pump();
        expect(starterTiles_(), findsNothing);
        expect(find.textContaining('neu anlegen'), findsOneWidget);
      },
    );

    testWidgets('an open item without a picture takes the starter one', (
      t,
    ) async {
      await pump(
        t,
        catalog: [entry('Bananen', 3)],
        starters: [s('Bananen', icon: 'banana')],
        items: [item('1', 'Bananen')],
      );
      final banana = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/emoji/shopping/banana.png',
      );
      // The family's tile and the plain row of the open item, neither from the server.
      expect(banana, findsNWidgets(2));
    });

    testWidgets('the wall shows them too, in its one row', (t) async {
      await pump(
        t,
        register: UiRegister.kiosk,
        catalog: const [],
        starters: numbered(10),
        items: const [],
      );
      expect(starterTiles_(), findsNWidgets(10));
    });

    testWidgets('the children\'s register shows them', (t) async {
      await pump(
        t,
        register: UiRegister.kid,
        catalog: const [],
        starters: numbered(10),
        items: const [],
      );
      expect(starterTiles_(), findsNWidgets(10));
    });

    testWidgets('a list of another kind gets its own, none without a hint', (
      t,
    ) async {
      await pump(
        t,
        kind: 'drugstore',
        catalog: const [],
        starters: [s('Zahnpasta', category: 'care')],
        items: const [],
        lists: const [
          ShoppingList(
            id: 'l1',
            name: 'Drogerie',
            isDefault: false,
            openCount: 0,
          ),
        ],
        categories: const [
          ShoppingCategory(
            id: 'c1',
            listId: 'l1',
            key: 'care',
            name: null,
            sortOrder: 0,
          ),
        ],
      );
      expect(starterTiles_(), findsOneWidget);

      await pump(
        t,
        catalog: const [],
        starters: numbered(5),
        items: const [],
        lists: const [
          ShoppingList(
            id: 'l1',
            name: 'Garten',
            isDefault: false,
            openCount: 0,
          ),
        ],
      );
      expect(starterTiles_(), findsNothing);
    });
  });
}
