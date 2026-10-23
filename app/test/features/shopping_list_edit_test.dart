import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

import '../support/fakes.dart';

final _de = lookupAppLocalizations(const Locale('de'));

/// Step 10.3: a list is renamed and removed, its categories added and removed, from
/// "Liste bearbeiten" (specs/16).
void main() {
  Future<FakeShoppingRepository> openEditor(
    WidgetTester t, {
    SettingsView view = SettingsView.basic,
  }) async {
    final shopping = FakeShoppingRepository([item('1', 'Milch')])
      ..lists_ = const [
        ShoppingList(
          id: 'l1',
          name: 'Supermarkt',
          isDefault: true,
          openCount: 1,
        ),
        ShoppingList(
          id: 'l2',
          name: 'Baumarkt',
          isDefault: false,
          openCount: 0,
        ),
      ]
      ..categories_ = const [
        ShoppingCategory(
          id: 'c-tools',
          listId: 'l2',
          key: 'tools',
          name: null,
          sortOrder: 0,
        ),
        ShoppingCategory(
          id: 'c-paint',
          listId: 'l2',
          key: null,
          name: 'Farbe',
          sortOrder: 10,
        ),
      ];
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
        shopping: shopping,
        settingsView: view,
      ),
    );
    await t.tap(find.text('Einkauf'));
    await t.pumpAndSettle();
    await t.tap(find.text('Baumarkt'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('edit-list')));
    await t.pumpAndSettle();
    return shopping;
  }

  testWidgets('Basic renames the list and offers the default', (t) async {
    final shopping = await openEditor(t);
    expect(find.byKey(const ValueKey('list-default')), findsOneWidget);
    expect(find.byKey(const ValueKey('list-categories')), findsNothing);

    await t.enterText(find.byKey(const ValueKey('list-name')), 'Baumarkt Nord');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('list-save-name')));
    await t.pumpAndSettle();

    expect(shopping.renames.single, (id: 'l2', name: 'Baumarkt Nord'));
    expect(find.text(_de.savedMessage), findsOneWidget);
  });

  testWidgets('Advanced edits the categories and deletes the list', (t) async {
    final shopping = await openEditor(t, view: SettingsView.advanced);
    expect(find.text(_de.shoppingCat_tools), findsOneWidget);
    expect(find.text('Farbe'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('category-add')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('category-name')), 'Garten');
    await t.tap(find.text(_de.save));
    await t.pumpAndSettle();
    expect(shopping.savedCategories.single, (
      listId: 'l2',
      id: null,
      name: 'Garten',
    ));

    await t.tap(find.byKey(const ValueKey('category-delete-c-paint')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, _de.delete));
    await t.pumpAndSettle();
    expect(shopping.deletedCategories, ['c-paint']);

    await t.scrollUntilVisible(
      find.byKey(const ValueKey('list-delete')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.byKey(const ValueKey('list-delete')));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, _de.shoppingListDelete));
    await t.pumpAndSettle();
    expect(shopping.deletedLists, ['l2']);
    // Back on the list, which now shows the default.
    expect(find.byKey(const ValueKey('edit-list')), findsOneWidget);
  });
}
