import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

import '../support/fakes.dart';

void main() {
  testWidgets(
    'an item from the meal plan shows its icon and the meal in its sheet',
    (t) async {
      final shopping = FakeShoppingRepository(
        [
          ShoppingItem(
            id: '1',
            name: 'Nudeln',
            quantity: null,
            checked: false,
            createdAt: DateTime(2026, 10, 11),
            sourceMealEntryIds: const ['m1'],
          ),
          item('2', 'Milch'),
        ],
        mealsByItem: {
          '1': [
            ShoppingItemMeal(
              mealEntryId: 'm1',
              onDate: DateTime(2026, 10, 20),
              title: 'Lasagne',
            ),
            // A meal whose recipe is gone has no dish name and is left out.
            ShoppingItemMeal(mealEntryId: 'm2', onDate: DateTime(2026, 10, 21)),
          ],
        },
      );
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          shopping: shopping,
        ),
      );
      // The adult home opens on the calendar: go to the shopping tab first.
      await t.tap(find.text('Einkauf'));
      await t.pumpAndSettle();

      // The icon sits on the item's tile; the navigation bar has one of its own.
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Nudeln'),
          matching: find.byIcon(Icons.restaurant_menu),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Milch'),
          matching: find.byIcon(Icons.restaurant_menu),
        ),
        findsNothing,
      );

      await t.longPress(find.text('Nudeln'));
      await t.pumpAndSettle();
      expect(find.textContaining('Für: Lasagne · '), findsOneWidget);
      expect(find.textContaining('Für:'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.tap(find.widgetWithText(TextButton, 'Abbrechen'));
      await t.pumpAndSettle();
      await t.longPress(find.text('Milch'));
      await t.pumpAndSettle();
      expect(find.textContaining('Für:'), findsNothing);
      expect(find.text('Milch'), findsWidgets);
      expect(t.takeException(), isNull);
      await unmountApp(t, container);
    },
  );
}
