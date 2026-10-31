import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_mode_store.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';
import 'package:wuselwall/features/shopping/ui/shopping_trip_page.dart';

import '../support/fakes.dart';

/// A6: the actual rendered hit area must be >=56x56 logical px for kid/kiosk
/// controls, not just a nominal `minimumSize` that `VisualDensity.comfortable`
/// then shrinks (specs/17 "Clarified 2026-10-17 (A6, t_da411148)"). These tests
/// pump the real theme at the real UiRegister, as the board and kiosk app do,
/// and measure the widget's actual laid-out size rather than reading back the
/// style's requested minimum.
Future<void> _pumpShopping(
  WidgetTester t,
  UiRegister register, {
  bool trip = false,
}) async {
  t.view.physicalSize = const Size(1280, 800);
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
              catalog: const [],
              pendingCount: 0,
            ),
          ),
        ),
        shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
        shoppingModeStoreProvider.overrideWithValue(MemoryShoppingModeStore()),
        shoppingRepositoryProvider.overrideWithValue(
          FakeShoppingRepository([item('1', 'Milch')]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.build(register, Shade.light),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        locale: const Locale('de'),
        home: trip
            ? const ShoppingTripPage()
            : const Scaffold(body: ShoppingBody()),
      ),
    ),
  );
  await t.pump();
}

void main() {
  for (final register in [UiRegister.kid, UiRegister.kiosk]) {
    testWidgets('${register.name}: "Einkauf beenden" is at least 56x56', (
      t,
    ) async {
      // The wall has one combined view; the kid's register finishes on the trip page.
      await _pumpShopping(t, register, trip: register == UiRegister.kid);

      final finishButton = find.ancestor(
        of: find.text('Einkauf beenden'),
        matching: find.byType(FilledButton),
      );
      expect(finishButton, findsOneWidget);
      final size = t.getSize(finishButton);
      expect(size.width, greaterThanOrEqualTo(56));
      expect(size.height, greaterThanOrEqualTo(56));
    });
  }

  testWidgets('kid: "Einkaufen gehen" is at least 56 high', (t) async {
    await _pumpShopping(t, UiRegister.kid);

    final start = find.byKey(const ValueKey('shopping-start'));
    expect(start, findsOneWidget);
    expect(t.getSize(start).height, greaterThanOrEqualTo(56));
    expect(find.byType(SegmentedButton<ShoppingMode>), findsNothing);
  });

  testWidgets('kid: the trip page\'s three controls are at least 56 high', (
    t,
  ) async {
    await _pumpShopping(t, UiRegister.kid, trip: true);

    for (final key in [
      'shopping-add-in-store',
      'shopping-mode-plan',
      'shopping-finish',
    ]) {
      final size = t.getSize(find.byKey(ValueKey(key)));
      expect(size.height, greaterThanOrEqualTo(56), reason: key);
      expect(size.width, greaterThanOrEqualTo(56), reason: key);
    }
  });

  testWidgets('kid: the shopping history icon action is at least 56x56', (
    t,
  ) async {
    await _pumpShopping(t, UiRegister.kid);

    final historyButton = find.ancestor(
      of: find.byIcon(Icons.history),
      matching: find.byType(IconButton),
    );
    expect(historyButton, findsOneWidget);
    final size = t.getSize(historyButton);
    expect(size.width, greaterThanOrEqualTo(56));
    expect(size.height, greaterThanOrEqualTo(56));
  });

  testWidgets(
    'kiosk: the shopping history icon is not shown (kiosk has no detail nav)',
    (t) async {
      await _pumpShopping(t, UiRegister.kiosk);
      expect(find.byIcon(Icons.history), findsNothing);
    },
  );
}
