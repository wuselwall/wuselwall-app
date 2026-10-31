import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_mode_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

import '../support/fakes.dart';
import '../support/shopping_flow.dart';
import 'shopping_tiles_test.dart' show entry, pumpBody;

const _startKey = ValueKey('shopping-start');
const _addKey = ValueKey('shopping-add-in-store');
const _planKey = ValueKey('shopping-mode-plan');
const _sheetKey = ValueKey('shopping-item-sheet');

Finder get ring => find.byKey(const ValueKey('shopping-focus-ring'));

Finder get searchField => find.byType(TextField);

Finder get homeNav => find.byKey(homeNavKey);

Finder get tripTitle => find.byKey(const ValueKey('shopping-trip-title'));

ShoppingItem counted(String id, String name, int count, {bool auto = false}) =>
    ShoppingItem(
      id: id,
      name: name,
      quantity: null,
      checked: false,
      createdAt: DateTime(2026, 10, 11),
      listId: 'l1',
      count: count,
      categoryAuto: auto,
    );

void main() {
  final catalog = [entry('Milch', 9), entry('Brot', 7)];

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('planning', () {
    testWidgets('is the tab: search, tiles, plain rows, no ticks, no switch', (
      t,
    ) async {
      await pumpShoppingFlow(t, catalog);
      expect(homeNav, findsOneWidget);
      expect(searchField, findsOneWidget);
      expect(find.byKey(const ValueKey('shopping-tiles')), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(SegmentedButton<ShoppingMode>), findsNothing);
      expect(find.byKey(const ValueKey('shopping-mode-shop')), findsNothing);
      expect(find.byKey(_startKey), findsOneWidget);
      expect(find.byKey(const ValueKey('shopping-item-1')), findsOneWidget);
    });

    testWidgets('a tap on a row opens the item sheet, not a tick', (t) async {
      await pumpShoppingFlow(t, const []);
      await t.tap(find.byKey(const ValueKey('shopping-item-1')));
      await t.pumpAndSettle();
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('a ticked item waits in the trolley and unticks on a tap', (
      t,
    ) async {
      await pumpShoppingFlow(
        t,
        catalog,
        items: [item('1', 'Milch'), item('2', 'Brot', checked: true)],
      );
      expect(find.text('Im Wagen (1)'), findsOneWidget);
      await t.tap(find.text('Im Wagen (1)'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Brot'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('"Einkaufen gehen" is disabled with nothing to buy', (t) async {
      await pumpShoppingFlow(t, catalog, items: const []);
      final button = t.widget<FilledButton>(find.byKey(_startKey));
      expect(button.onPressed, isNull);
    });

    testWidgets(
      '"Einkaufen gehen" opens the trip, which hides the navigation',
      (t) async {
        final store = MemoryShoppingModeStore();
        await pumpShoppingFlow(t, catalog, modeStore: store);
        await t.tap(find.byKey(_startKey));
        await t.pumpAndSettle();

        expect(tripTitle, findsOneWidget);
        expect(t.widget<Text>(tripTitle).data, 'Supermarkt · 2');
        // No app bar and no navigation: the normal chrome is below the trip.
        expect(homeNav, findsNothing);
        expect(find.text('Home'), findsNothing);
        expect(searchField, findsNothing);
        expect(find.byKey(const ValueKey('shopping-tiles')), findsNothing);
        expect(find.byType(Checkbox), findsNWidgets(2));
        expect(store.mode, ShoppingMode.shop);
      },
    );
  });

  group('the trip', () {
    Future<void> trip(
      WidgetTester t, {
      List<ShoppingItem>? items,
      UiRegister register = UiRegister.adult,
      Size size = const Size(390, 844),
      ShoppingModeStore? store,
    }) async {
      await pumpShoppingFlow(
        t,
        catalog,
        items: items,
        register: register,
        size: size,
        modeStore: store,
      );
      await t.tap(find.byKey(_startKey));
      await t.pumpAndSettle();
    }

    testWidgets('has the three controls and the kid register has them too', (
      t,
    ) async {
      await trip(t, register: UiRegister.kid);
      expect(find.byKey(_addKey), findsOneWidget);
      expect(find.byKey(_planKey), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Einkauf beenden'), findsOne);
      expect(homeNav, findsNothing);
    });

    testWidgets('"Planen" goes back and keeps planning on the device', (
      t,
    ) async {
      final store = MemoryShoppingModeStore();
      await trip(t, store: store);
      await t.tap(find.byKey(_planKey));
      await t.pumpAndSettle();
      expect(tripTitle, findsNothing);
      expect(homeNav, findsOneWidget);
      expect(store.mode, ShoppingMode.plan);
      expect(containerOfFlow(t).read(shoppingModeProvider), ShoppingMode.plan);
      // And it does not open again by itself.
      await t.pumpAndSettle();
      expect(tripTitle, findsNothing);
    });

    testWidgets('the system back leaves the trip and keeps planning', (
      t,
    ) async {
      final store = MemoryShoppingModeStore();
      await trip(t, store: store);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(tripTitle, findsNothing);
      expect(homeNav, findsOneWidget);
      expect(store.mode, ShoppingMode.plan);
    });

    testWidgets('finishing the trip leaves it and goes back to planning', (
      t,
    ) async {
      final store = MemoryShoppingModeStore();
      await trip(
        t,
        items: [item('1', 'Milch', checked: true), item('2', 'Brot')],
        store: store,
      );
      await t.tap(find.widgetWithText(FilledButton, 'Einkauf beenden'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Einkauf beenden').last);
      await t.pumpAndSettle();
      expect(tripTitle, findsNothing);
      expect(homeNav, findsOneWidget);
      expect(store.mode, ShoppingMode.plan);
    });

    testWidgets('a device closed in the store reopens into the trip', (
      t,
    ) async {
      final store = MemoryShoppingModeStore(ShoppingMode.shop);
      await pumpShoppingFlow(t, catalog, modeStore: store);
      expect(tripTitle, findsOneWidget);
      expect(homeNav, findsNothing);
      // Planen leaves it, once.
      await t.tap(find.byKey(_planKey));
      await t.pumpAndSettle();
      expect(tripTitle, findsNothing);
      expect(homeNav, findsOneWidget);
    });

    testWidgets('has ticks and no search field or tiles', (t) async {
      await trip(t);
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(searchField, findsNothing);
      expect(find.byKey(const ValueKey('shopping-tiles')), findsNothing);
    });

    testWidgets('the add button is a labelled button on a wide phone', (
      t,
    ) async {
      await trip(t, size: const Size(600, 900));
      expect(find.widgetWithText(OutlinedButton, 'Hinzufügen'), findsOne);
      expect(find.byKey(_addKey), findsOneWidget);
    });

    testWidgets(
      'under 400 px the add button is only its icon, with a tooltip',
      (t) async {
        await trip(t, size: const Size(360, 780));
        expect(find.widgetWithText(OutlinedButton, 'Hinzufügen'), findsNothing);
        final add = find.byKey(_addKey);
        expect(t.widget(add), isA<IconButton>());
        expect(find.byTooltip('Hinzufügen'), findsOneWidget);
        expect(t.getSize(add).width, greaterThanOrEqualTo(48));
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('all three controls fit a 320 px phone', (t) async {
      await trip(t, size: const Size(320, 640));
      expect(t.takeException(), isNull);
      final plan = t.getRect(find.byKey(_planKey));
      final finish = t.getRect(
        find.widgetWithText(FilledButton, 'Einkauf beenden'),
      );
      expect(plan.right, lessThanOrEqualTo(finish.left));
      expect(finish.right, lessThanOrEqualTo(320));
    });

    testWidgets('the bottom controls are at least 48 (adult) / 56 (kid) high', (
      t,
    ) async {
      for (final (register, min) in [
        (UiRegister.adult, 48.0),
        (UiRegister.kid, 56.0),
      ]) {
        await trip(t, register: register, size: const Size(600, 900));
        for (final f in [
          find.byKey(_addKey),
          find.byKey(_planKey),
          find.widgetWithText(FilledButton, 'Einkauf beenden'),
        ]) {
          expect(t.getSize(f).height, greaterThanOrEqualTo(min), reason: '$f');
        }
        // Back to a fresh page for the next register.
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('has no "−" for a count above one, and shows the pill', (
      t,
    ) async {
      await pumpShoppingFlow(t, catalog, items: [counted('1', 'Milch', 2)]);
      // Planning: the "−" and the pill.
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
      expect(find.byKey(const ValueKey('item-count-1')), findsOneWidget);
      await t.tap(find.byKey(_startKey));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
      expect(find.byKey(const ValueKey('item-count-1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('item-count-1')),
          matching: find.text('2×'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an empty list says where to add', (t) async {
      await pumpShoppingFlow(
        t,
        catalog,
        items: const [],
        modeStore: MemoryShoppingModeStore(ShoppingMode.shop),
      );
      expect(tripTitle, findsOneWidget);
      expect(find.textContaining('Tippe auf „Hinzufügen“'), findsOneWidget);
    });

    testWidgets('the plus opens the picker, which adds and stays open', (
      t,
    ) async {
      await trip(t);
      await t.tap(find.byKey(_addKey));
      await t.pumpAndSettle();
      // The field is there and has the focus.
      expect(searchField, findsOneWidget);
      expect(t.widget<TextField>(searchField).focusNode!.hasFocus, isTrue);

      await t.enterText(searchField, 'Käse');
      await t.pump();
      await t.tap(find.text('„Käse“ neu anlegen'));
      await t.pumpAndSettle();
      // Still open for the next one.
      expect(searchField, findsOneWidget);
      expect(t.widget<TextField>(searchField).controller!.text, isEmpty);
    });

    testWidgets('the sheet\'s field has the clear button too', (t) async {
      await trip(t);
      await t.tap(find.byKey(_addKey));
      await t.pumpAndSettle();
      final node = t.widget<TextField>(searchField).focusNode!;
      expect(node.hasFocus, isTrue);
      await t.tap(find.byKey(const ValueKey('shopping-search-clear')));
      await t.pump();
      expect(node.hasFocus, isFalse);
      expect(FocusManager.instance.primaryFocus, isNot(same(node)));
    });
  });

  group('the count', () {
    testWidgets('is a pill in a planning row, and the note stays below', (
      t,
    ) async {
      await pumpShoppingFlow(
        t,
        catalog,
        items: [
          ShoppingItem(
            id: '1',
            name: 'Milch',
            quantity: '1,5 %',
            checked: false,
            createdAt: DateTime(2026, 10, 11),
            count: 3,
          ),
          item('2', 'Brot'),
        ],
      );
      expect(find.byKey(const ValueKey('item-count-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('item-count-2')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('item-count-1')),
          matching: find.text('3×'),
        ),
        findsOneWidget,
      );
      // The old "3 × · 1,5 %" subtitle is gone: only the note is left.
      expect(find.text('1,5 %'), findsOneWidget);
      expect(find.text('3 × · 1,5 %'), findsNothing);
    });

    testWidgets('is excluded from the semantics; the row carries it', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await pumpShoppingFlow(t, catalog, items: [counted('1', 'Milch', 2)]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('item-count-1')),
          matching: find.byType(ExcludeSemantics),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('item-count-1')),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(
        t.getSemantics(find.byKey(const ValueKey('shopping-item-1'))).value,
        '2 ×',
      );
      handle.dispose();
    });
  });

  group('the item sheet', () {
    final categories = [
      const ShoppingCategory(
        id: 'c1',
        listId: 'l1',
        key: 'dairy',
        name: null,
        sortOrder: 10,
      ),
      const ShoppingCategory(
        id: 'c0',
        listId: 'l1',
        key: 'produce',
        name: null,
        sortOrder: 0,
      ),
      const ShoppingCategory(
        id: 'c2',
        listId: 'l1',
        key: null,
        name: 'Mein Regal',
        sortOrder: 20,
      ),
    ];

    Future<void> open(
      WidgetTester t,
      ShoppingItem it, {
      UiRegister register = UiRegister.adult,
    }) async {
      await pumpShoppingFlow(
        t,
        catalog,
        items: [it],
        categories: categories,
        register: register,
      );
      await t.tap(find.byKey(const ValueKey('shopping-item-1')));
      await t.pumpAndSettle();
    }

    testWidgets('the stepper sends plus and minus one, minus stops at one', (
      t,
    ) async {
      await open(t, counted('1', 'Milch', 1));
      Finder less() => find.byKey(const ValueKey('item-less'));
      Finder more() => find.byKey(const ValueKey('item-more'));
      expect(t.widget<IconButton>(less()).onPressed, isNull);
      await t.tap(more());
      await t.pump();
      expect(spyOf(t).counts, [(itemId: '1', delta: 1)]);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('minus works above one', (t) async {
      await open(t, counted('1', 'Milch', 3));
      expect(find.byKey(const ValueKey('item-count')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('item-count'))).data,
        '3',
      );
      await t.tap(find.byKey(const ValueKey('item-less')));
      await t.pump();
      expect(spyOf(t).counts, [(itemId: '1', delta: -1)]);
    });

    testWidgets('a long press opens it in the trip too', (t) async {
      await pumpShoppingFlow(t, catalog, items: [counted('1', 'Milch', 1)]);
      await t.tap(find.byKey(_startKey));
      await t.pumpAndSettle();
      await t.longPress(find.byKey(const ValueKey('shopping-item-1')));
      await t.pumpAndSettle();
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('the stepper targets are 48 (adult) and 56 (kid)', (t) async {
      for (final (register, min) in [
        (UiRegister.adult, 48.0),
        (UiRegister.kid, 56.0),
      ]) {
        await open(t, counted('1', 'Milch', 2), register: register);
        for (final key in ['item-less', 'item-more']) {
          final size = t.getSize(find.byKey(ValueKey(key)));
          expect(size.width, greaterThanOrEqualTo(min), reason: key);
          expect(size.height, greaterThanOrEqualTo(min), reason: key);
        }
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the category chips: none first, then the walking order', (
      t,
    ) async {
      await open(t, counted('1', 'Milch', 1));
      final chips = find.descendant(
        of: find.byKey(const ValueKey('item-category-chips')),
        matching: find.byType(ChoiceChip),
      );
      final labels = [
        for (final c in t.widgetList<ChoiceChip>(chips)) (c.label as Text).data,
      ];
      expect(labels, [
        'Ohne Kategorie',
        'Obst & Gemüse',
        'Milch & Käse',
        'Mein Regal',
      ]);
      // The item has none: that chip is the selected one.
      expect(t.widget<ChoiceChip>(chips.first).selected, isTrue);
    });

    testWidgets('a tap on a chip saves the category at once', (t) async {
      await open(t, counted('1', 'Milch', 1));
      await t.ensureVisible(find.byKey(const ValueKey('item-category-c1')));
      await t.tap(find.byKey(const ValueKey('item-category-c1')));
      await t.pump();
      expect(spyOf(t).categories, [(itemId: '1', categoryId: 'c1')]);
      await t.ensureVisible(find.byKey(const ValueKey('item-category-none')));
      await t.tap(find.byKey(const ValueKey('item-category-none')));
      await t.pump();
      expect(spyOf(t).categories.last, (itemId: '1', categoryId: null));
    });

    testWidgets('the automatic line shows only for an automatic category', (
      t,
    ) async {
      await open(t, counted('1', 'Milch', 1));
      expect(find.byKey(const ValueKey('item-category-auto')), findsNothing);
      await t.pumpWidget(const SizedBox());

      await open(t, counted('1', 'Milch', 1, auto: true));
      expect(find.byKey(const ValueKey('item-category-auto')), findsOneWidget);
      expect(
        find.text('Kategorie automatisch aus dem Namen gewählt'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    });

    testWidgets('"Fertig" saves the note; Entfernen is for adults', (t) async {
      await open(t, counted('1', 'Milch', 1));
      expect(find.byKey(const ValueKey('item-remove')), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('item-note')), 'Bio');
      await t.tap(find.byKey(const ValueKey('item-done')));
      await t.pumpAndSettle();
      expect(find.byKey(_sheetKey), findsNothing);
      expect(spyOf(t).specs, [(itemId: '1', text: 'Bio')]);
      await t.pumpWidget(const SizedBox());

      await open(t, counted('1', 'Milch', 1), register: UiRegister.kid);
      expect(find.byKey(const ValueKey('item-remove')), findsNothing);
    });

    testWidgets('a note typed and then dragged away is saved on close', (
      t,
    ) async {
      await open(t, counted('1', 'Milch', 1));
      await t.enterText(find.byKey(const ValueKey('item-note')), 'Bio');
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      expect(find.byKey(_sheetKey), findsNothing);
      expect(spyOf(t).specs, [(itemId: '1', text: 'Bio')]);
    });
  });

  group('pinned tiles', () {
    testWidgets('a pinned tile carries a pin and says so', (t) async {
      await pumpShoppingFlow(
        t,
        [entry('Milch', 9, pinned: true), entry('Brot', 7)],
        items: [item('1', 'Käse')],
      );
      final milk = find.byKey(const ValueKey('shopping-tile-milch'));
      expect(
        find.descendant(of: milk, matching: find.byIcon(Icons.push_pin)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shopping-tile-brot')),
          matching: find.byIcon(Icons.push_pin),
        ),
        findsNothing,
      );
      expect(find.byTooltip('Angeheftet'), findsOneWidget);
    });

    testWidgets('the tile sheet pins and unpins', (t) async {
      final repo = FakeShoppingRepository([item('1', 'Milch')]);
      await pumpShoppingFlow(t, [
        entry('Milch', 9, pinned: true),
        entry('Brot', 7),
      ], repo: repo);
      await t.longPress(find.byKey(const ValueKey('shopping-tile-brot')));
      await t.pumpAndSettle();
      expect(find.text('Kachel anheften'), findsOneWidget);
      expect(
        find.text('Angeheftete Kacheln stehen immer vorn.'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('tile-pin')));
      await t.pumpAndSettle();
      expect(repo.pins, [(id: 'Brot', pinned: true)]);

      await t.longPress(find.byKey(const ValueKey('shopping-tile-milch')));
      await t.pumpAndSettle();
      expect(find.text('Anheften aufheben'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tile-pin')));
      await t.pumpAndSettle();
      expect(repo.pins.last, (id: 'Milch', pinned: false));
    });
  });

  group('the wall', () {
    testWidgets('keeps one view: no start button, no trip, ticks and tiles', (
      t,
    ) async {
      await pumpBody(t, catalog);
      expect(find.byKey(_addKey), findsNothing);
      expect(find.byKey(_startKey), findsNothing);
      expect(find.byKey(_planKey), findsNothing);
      // Both at once, as before: tiles and ticks.
      expect(find.byKey(const ValueKey('shopping-tiles')), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('Einkauf beenden'), findsOneWidget);
    });
  });

  group('the mode on the device', () {
    test('the stored mode is read, and a choice is written', () async {
      final store = MemoryShoppingModeStore(ShoppingMode.shop);
      final container = ProviderContainer(
        overrides: [shoppingModeStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      // Planning until the store has answered, then what it held.
      expect(container.read(shoppingModeProvider), ShoppingMode.plan);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(shoppingModeProvider), ShoppingMode.shop);

      container.read(shoppingModeProvider.notifier).select(ShoppingMode.plan);
      expect(container.read(shoppingModeProvider), ShoppingMode.plan);
      expect(store.mode, ShoppingMode.plan);
    });

    test('a choice made before the store answers wins over it', () async {
      final store = MemoryShoppingModeStore(ShoppingMode.shop);
      final container = ProviderContainer(
        overrides: [shoppingModeStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      container.read(shoppingModeProvider);
      container.read(shoppingModeProvider.notifier).select(ShoppingMode.plan);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(shoppingModeProvider), ShoppingMode.plan);
    });
  });

  group('the data', () {
    test('an item from an older server has no automatic category', () {
      final json = {
        'id': 'i',
        'name': 'Milch',
        'quantity': null,
        'checked': false,
        'created_at': '2026-10-11T09:00:00Z',
      };
      expect(ShoppingItem.fromJson(json).categoryAuto, isFalse);
      expect(
        ShoppingItem.fromJson({...json, 'category_auto': null}).categoryAuto,
        isFalse,
      );
      final auto = ShoppingItem.fromJson({...json, 'category_auto': true});
      expect(auto.categoryAuto, isTrue);
      expect(auto.toJson()['category_auto'], isTrue);
      expect(auto.copyWith(count: 2).categoryAuto, isTrue);
    });

    test('a tile from an older server is not pinned', () {
      final json = {
        'id': 'k',
        'list_id': 'l1',
        'name': 'Milch',
        'folded_name': 'milch',
        'category_id': null,
        'purchase_count': 3,
        'last_purchased_at': null,
      };
      final old = CatalogEntry.fromJson(json);
      expect(old.pinned, isFalse);
      expect(old.categoryAuto, isFalse);
      final pinned = CatalogEntry.fromJson({...json, 'pinned': true});
      expect(pinned.pinned, isTrue);
      expect(pinned.toJson()['pinned'], isTrue);
    });

    test('a category chosen on the device is no longer automatic', () {
      final snapshot = ShoppingSnapshot(
        items: [counted('1', 'Milch', 1, auto: true)],
        lists: const [],
        categories: const [],
        catalog: const [],
      );
      final view = projectShopping(snapshot, [
        const CategoriseItemOp(
          opId: 'o',
          actor: null,
          itemId: '1',
          categoryId: 'c1',
        ),
      ]);
      expect(view.items.single.categoryId, 'c1');
      expect(view.items.single.categoryAuto, isFalse);
    });
  });

  group('the focus', () {
    testWidgets('a tap in the search field draws no ring through it', (
      t,
    ) async {
      await pumpBody(t, catalog, register: UiRegister.adult);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await t.tap(searchField);
      await t.pump();
      expect(t.widget<TextField>(searchField).focusNode!.hasFocus, isTrue);
      expect(ring, findsNothing);
      // The search shows its hint, not a floating label.
      expect(t.widget<TextField>(searchField).decoration!.labelText, isNull);
      expect(find.text('Suchen oder hinzufügen'), findsOneWidget);
    });

    testWidgets('keyboard focus draws the ring', (t) async {
      await pumpBody(t, catalog, register: UiRegister.adult);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      t.widget<TextField>(searchField).focusNode!.requestFocus();
      await t.pump();
      expect(ring, findsOneWidget);
    });

    testWidgets('a tile keeps its ring for the keyboard only', (t) async {
      await pumpBody(t, catalog, register: UiRegister.adult);
      final tile = find.byKey(const ValueKey('shopping-tile-milch'));
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final node = t
          .widget<Focus>(
            find
                .descendant(
                  of: find.descendant(of: tile, matching: find.byType(InkWell)),
                  matching: find.byType(Focus),
                )
                .first,
          )
          .focusNode!;
      node.requestFocus();
      await t.pump();
      expect(ring, findsOneWidget);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await t.pump();
      expect(ring, findsNothing);
    });

    testWidgets('Enter keeps the focus; a tap on empty space drops it', (
      t,
    ) async {
      await pumpBody(t, catalog, register: UiRegister.adult);
      final node = t.widget<TextField>(searchField).focusNode!;
      await t.tap(searchField);
      await t.enterText(searchField, 'Käse');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(node.hasFocus, isTrue);

      // The list chips' row has empty space at its edge: a tap there drops the focus.
      await t.tapAt(const Offset(2, 300));
      await t.pump();
      expect(node.hasFocus, isFalse);
    });

    testWidgets('the clear button empties the field and drops the focus', (
      t,
    ) async {
      await pumpBody(t, catalog, register: UiRegister.adult);
      final node = t.widget<TextField>(searchField).focusNode!;
      expect(find.byKey(const ValueKey('shopping-search-clear')), findsNothing);
      await t.tap(searchField);
      await t.enterText(searchField, 'Käse');
      await t.pump();
      expect(node.hasFocus, isTrue);

      await t.tap(find.byKey(const ValueKey('shopping-search-clear')));
      await t.pump();
      expect(node.hasFocus, isFalse);
      expect(t.widget<TextField>(searchField).controller!.text, isEmpty);
      expect(find.byTooltip('Leeren und schließen'), findsNothing);
    });

    testWidgets('dragging the list dismisses the keyboard', (t) async {
      await pumpBody(t, catalog, register: UiRegister.adult);
      final scroll = t.widget<CustomScrollView>(find.byType(CustomScrollView));
      expect(
        scroll.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );
    });
  });

  test('the snacks category has its label and its icon', () {
    const snacks = ShoppingCategory(
      id: 'c',
      listId: 'l1',
      key: 'snacks',
      name: null,
      sortOrder: 0,
    );
    expect(categoryIcon(snacks), Icons.cookie_outlined);
    expect(
      categoryLabel(lookupAppLocalizations(const Locale('de')), snacks),
      'Snacks',
    );
    expect(
      categoryLabel(lookupAppLocalizations(const Locale('fr')), snacks),
      'Snacks',
    );
  });
}
