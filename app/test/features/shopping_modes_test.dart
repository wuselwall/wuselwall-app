import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

import '../support/fakes.dart';
import 'shopping_tiles_test.dart' show entry, pumpBody;

const _planKey = ValueKey('shopping-mode-plan');
const _shopKey = ValueKey('shopping-mode-shop');

ProviderContainer containerOf(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(ShoppingBody)));

ShoppingMode modeOf(WidgetTester t) =>
    containerOf(t).read(shoppingModeProvider);

Finder get ring => find.byKey(const ValueKey('shopping-focus-ring'));

Finder get searchField => find.byType(TextField);

void main() {
  final catalog = [entry('Milch', 9), entry('Brot', 7)];

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  group('the mode to start in', () {
    testWidgets('is planning when nothing is ticked', (t) async {
      await pumpBody(t, catalog, register: UiRegister.adult);
      expect(modeOf(t), ShoppingMode.plan);
      expect(find.byKey(const ValueKey('shopping-start')), findsOneWidget);
    });

    testWidgets('is shopping when something is ticked', (t) async {
      await pumpBody(
        t,
        catalog,
        register: UiRegister.adult,
        items: [item('1', 'Milch'), item('2', 'Brot', checked: true)],
      );
      expect(modeOf(t), ShoppingMode.shop);
      expect(find.byKey(const ValueKey('shopping-add-in-store')), findsOne);
    });

    testWidgets('the kid register has both modes too', (t) async {
      await pumpBody(t, catalog, register: UiRegister.kid);
      expect(find.byKey(_planKey), findsOneWidget);
      expect(find.byKey(_shopKey), findsOneWidget);
    });
  });

  group('planning', () {
    testWidgets('shows the search, the tiles and no tick', (t) async {
      await pumpBody(
        t,
        catalog,
        register: UiRegister.adult,
        items: [item('1', 'Milch'), item('2', 'Brot')],
      );
      expect(searchField, findsOneWidget);
      expect(find.byKey(const ValueKey('shopping-tiles')), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      // The rows are still there, with the basket for want of a picture.
      expect(find.text('Milch'), findsWidgets);
      expect(find.text('Brot'), findsWidgets);
    });

    testWidgets('a tap on a row opens the item, not a tick', (t) async {
      await pumpBody(t, const [], register: UiRegister.adult);
      await t.tap(find.widgetWithText(ListTile, 'Milch'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('a ticked item waits in the trolley and unticks on a tap', (
      t,
    ) async {
      await pumpBody(
        t,
        catalog,
        register: UiRegister.adult,
        items: [item('1', 'Milch'), item('2', 'Brot', checked: true)],
      );
      containerOf(t)
          .read(shoppingModeProvider.notifier)
          .select(ShoppingMode.plan);
      await t.pumpAndSettle();
      expect(find.text('Im Wagen (1)'), findsOneWidget);
      await t.tap(find.text('Im Wagen (1)'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Brot'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets(
      '"Einkaufen gehen" switches to shopping, and is off when empty',
      (t) async {
        await pumpBody(t, catalog, register: UiRegister.adult);
        await t.tap(find.byKey(const ValueKey('shopping-start')));
        await t.pumpAndSettle();
        expect(modeOf(t), ShoppingMode.shop);
        expect(searchField, findsNothing);
      },
    );

    testWidgets('"Einkaufen gehen" is disabled with nothing to buy', (t) async {
      await pumpBody(t, catalog, register: UiRegister.adult, items: const []);
      final button = t.widget<FilledButton>(
        find.byKey(const ValueKey('shopping-start')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('shopping', () {
    Future<void> shop(WidgetTester t, {List<ShoppingItem>? items}) async {
      await pumpBody(
        t,
        catalog,
        register: UiRegister.adult,
        items: items ?? [item('1', 'Milch'), item('2', 'Brot')],
      );
      await t.tap(find.byKey(_shopKey));
      await t.pumpAndSettle();
    }

    testWidgets('has ticks and no search field or tiles', (t) async {
      await shop(t);
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(searchField, findsNothing);
      expect(find.byKey(const ValueKey('shopping-tiles')), findsNothing);
    });

    testWidgets('has no "−" for a count above one', (t) async {
      final two = item('1', 'Milch');
      await pumpBody(
        t,
        catalog,
        register: UiRegister.adult,
        items: [
          ShoppingItem(
            id: two.id,
            name: two.name,
            quantity: null,
            checked: false,
            createdAt: two.createdAt,
            count: 2,
          ),
        ],
      );
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
      await t.tap(find.byKey(_shopKey));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
      expect(find.text('2 ×'), findsOneWidget);
    });

    testWidgets('an empty list says where to add', (t) async {
      await shop(t, items: const []);
      expect(find.textContaining('Zum Hinzufügen wechsle'), findsOneWidget);
    });

    testWidgets('the plus opens the picker, which adds and stays open', (
      t,
    ) async {
      await shop(t);
      await t.tap(find.byKey(const ValueKey('shopping-add-in-store')));
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

    testWidgets('finishing the trip goes back to planning', (t) async {
      await pumpBody(
        t,
        catalog,
        register: UiRegister.adult,
        items: [item('1', 'Milch', checked: true), item('2', 'Brot')],
      );
      expect(modeOf(t), ShoppingMode.shop);
      await t.tap(find.text('Einkauf beenden'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Einkauf beenden').last);
      await t.pumpAndSettle();
      expect(modeOf(t), ShoppingMode.plan);
      expect(searchField, findsOneWidget);
    });
  });

  group('the wall', () {
    testWidgets('keeps one view: no mode control, no sheet button', (t) async {
      await pumpBody(t, catalog);
      expect(find.byKey(_planKey), findsNothing);
      expect(find.byKey(_shopKey), findsNothing);
      expect(find.byKey(const ValueKey('shopping-add-in-store')), findsNothing);
      expect(find.byKey(const ValueKey('shopping-start')), findsNothing);
      // Both at once, as before: tiles and ticks.
      expect(find.byKey(const ValueKey('shopping-tiles')), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('Einkauf beenden'), findsOneWidget);
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

      // The mode control's row has empty space at its edge: a tap there drops the focus.
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

    testWidgets('the sheet\'s field has the clear button too', (t) async {
      await pumpBody(
        t,
        catalog,
        register: UiRegister.adult,
        items: [item('1', 'Milch', checked: true)],
      );
      await t.tap(find.byKey(const ValueKey('shopping-add-in-store')));
      await t.pumpAndSettle();
      final node = t.widget<TextField>(searchField).focusNode!;
      expect(node.hasFocus, isTrue);
      await t.tap(find.byKey(const ValueKey('shopping-search-clear')));
      await t.pump();
      expect(node.hasFocus, isFalse);
      expect(FocusManager.instance.primaryFocus, isNot(same(node)));
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
