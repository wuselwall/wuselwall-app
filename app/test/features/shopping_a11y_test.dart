import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';

import '../support/fakes.dart';

/// A4/A5 (t_a535f616, from the accessibility audit t_d7ce38d4): the shopping body's
/// keyboard focus order, its focus indicator's touch target, and the item list's
/// reachability at 200% text on a 320 px phone.

CatalogEntry _entry(String name) => CatalogEntry(
  id: name,
  listId: 'l1',
  name: name,
  foldedName: name.toLowerCase(),
  categoryId: null,
  purchaseCount: 1,
  lastPurchasedAt: null,
);

/// Pumps the adult shopping body (search + catalogue + a list switcher, unlike the
/// kiosk register) with one list, a small catalogue and two open items.
Future<void> _pumpAdultBody(
  WidgetTester t, {
  Size size = const Size(1280, 800),
  double textScale = 1,
  bool includeOnListTile = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final items = [
    ShoppingItem(
      id: 'i1',
      name: 'Nudeln',
      quantity: null,
      checked: false,
      createdAt: DateTime(2026, 10, 11),
    ),
    ShoppingItem(
      id: 'i2',
      name: 'Käse',
      quantity: null,
      checked: false,
      createdAt: DateTime(2026, 10, 11),
    ),
  ];

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        uiRegisterProvider.overrideWithValue(UiRegister.adult),
        shoppingViewProvider.overrideWithValue(
          AsyncData(
            ShoppingView(
              items: items,
              lists: const [
                ShoppingList(
                  id: 'l1',
                  name: 'Supermarkt',
                  isDefault: true,
                  openCount: 2,
                ),
              ],
              categories: const <ShoppingCategory>[],
              catalog: [
                _entry('Kartoffeln'),
                _entry('Milch'),
                if (includeOnListTile) _entry('Nudeln'),
              ],
              pendingCount: 0,
            ),
          ),
        ),
        shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
        shoppingRepositoryProvider.overrideWithValue(
          FakeShoppingRepository(items),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData.fromView(t.view)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          theme: AppTheme.build(UiRegister.adult, Shade.light),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          locale: const Locale('de'),
          home: const Scaffold(body: ShoppingBody()),
        ),
      ),
    ),
  );
  await t.pump();
}

/// The `debugLabel`s of every focus stop this file tags, in the order Tab visits
/// them, stopping once nothing new gains focus (the end of the traversal group) or
/// after [maxTabs] presses, whichever comes first.
Future<List<String>> _tabOrder(WidgetTester t, {int maxTabs = 20}) async {
  final seen = <String>[];
  String? last;
  for (var i = 0; i < maxTabs; i++) {
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    final label = FocusManager.instance.primaryFocus?.debugLabel;
    if (label == null || label == last) continue;
    // A full lap: traversal wrapped back to the first tagged stop.
    if (seen.isNotEmpty && label == seen.first) break;
    seen.add(label);
    last = label;
  }
  return seen;
}

void main() {
  testWidgets(
    'A4: tab order is lists, then search, then catalogue, then items',
    (t) async {
      await _pumpAdultBody(t);
      final order = await _tabOrder(t);

      int at(String label) => order.indexOf(label);
      expect(at('shopping-list:Supermarkt · 2'), greaterThanOrEqualTo(0));
      expect(
        at('shopping-new-list'),
        greaterThan(at('shopping-list:Supermarkt · 2')),
      );
      expect(at('shopping-search'), greaterThan(at('shopping-new-list')));
      expect(
        at('shopping-tile:Kartoffeln'),
        greaterThan(at('shopping-search')),
      );
      expect(
        at('shopping-item:Nudeln'),
        greaterThan(at('shopping-tile:Milch')),
      );
      expect(at('shopping-item:Käse'), greaterThan(at('shopping-item:Nudeln')));
      // Each item is one stop: the checkbox used to add a second one right after it.
      expect(order.where((l) => l == 'shopping-item:Nudeln'), hasLength(1));
    },
  );

  testWidgets('A5: each item is one named checked control', (t) async {
    final semantics = t.ensureSemantics();
    try {
      await _pumpAdultBody(t);
      final checkedNodes = <SemanticsNode>[];
      void visit(SemanticsNode node) {
        if (!node.isMergedIntoParent &&
            node.getSemanticsData().flagsCollection.isChecked !=
                CheckedState.none) {
          checkedNodes.add(node);
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(
        t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
      );
      expect(checkedNodes.map((node) => node.getSemanticsData().label), [
        'Nudeln',
        'Käse',
      ]);
      for (final node in checkedNodes) {
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('A5: an on-list tile keeps its hint on its named action', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    try {
      await _pumpAdultBody(t, includeOnListTile: true);
      final hint = t.element(find.byType(ShoppingBody)).l10n.shoppingTileOnList;
      final hintedNodes = <SemanticsNode>[];
      void visit(SemanticsNode node) {
        if (!node.isMergedIntoParent && node.getSemanticsData().hint == hint) {
          hintedNodes.add(node);
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(
        t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
      );
      expect(hintedNodes, hasLength(1));
      expect(hintedNodes.single.getSemanticsData().label, contains('Nudeln'));
      expect(
        hintedNodes.single.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('A4: adding from search keeps keyboard focus in the field', (
    t,
  ) async {
    await _pumpAdultBody(t);
    await t.tap(find.byType(TextField));
    await t.pump();
    await t.enterText(find.byType(TextField), 'Brot');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    expect(FocusManager.instance.primaryFocus?.debugLabel, 'shopping-search');
  });

  testWidgets('A6: the list chips are at least the register touch target', (
    t,
  ) async {
    await _pumpAdultBody(t);
    final chip = t.getSize(find.byType(ChoiceChip).first);
    final action = t.getSize(find.byType(ActionChip).first);
    expect(chip.height, greaterThanOrEqualTo(48));
    expect(action.height, greaterThanOrEqualTo(48));
  });

  testWidgets('A5: the item list stays reachable at 320x640 with 200% text', (
    t,
  ) async {
    await _pumpAdultBody(t, size: const Size(320, 640), textScale: 2);

    final item = find.text('Nudeln');
    // Regardless of how much room the search field and catalogue take above it,
    // the item is reachable by scrolling instead of being squeezed into ~0 px.
    await t.ensureVisible(item);
    await t.pumpAndSettle();

    final size = t.getSize(item);
    expect(size.height, greaterThan(0));
    final topLeft = t.getTopLeft(item);
    expect(topLeft.dy, greaterThanOrEqualTo(0));
    expect(topLeft.dy, lessThan(640));
  });
}
