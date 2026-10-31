import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Opens the app as the device's household member and goes to the shopping tab; returns the
/// fake repository, which records every tick it receives.
Future<FakeShoppingRepository> openShopping(WidgetTester t) async {
  t.view.physicalSize = const Size(1280, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final shopping = FakeShoppingRepository([
    item('1', 'Milch'),
    item('2', 'Brot'),
  ]);
  await pumpApp(
    t,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device()),
      shopping: shopping,
    ),
  );
  // The adult home opens on the calendar: go to the shopping tab first.
  await t.tap(find.text('Einkauf'));
  await t.pumpAndSettle();
  // Ticking is what the shopping trip is for (planning has no ticks).
  await t.tap(find.byKey(const ValueKey('shopping-start')));
  await t.pumpAndSettle();
  return shopping;
}

/// The ticked state of the first row (Milch sorts first in the open list).
bool firstRowTicked(WidgetTester t) =>
    t.widget<Checkbox>(find.byType(Checkbox).first).value ?? false;

void main() {
  testWidgets('a tick stays in place, ticked, until the taps stop', (t) async {
    final shopping = await openShopping(t);

    await t.tap(find.text('Milch'));
    await t.pump(const Duration(milliseconds: 300));

    // Still in its row, shown ticked, not yet sent.
    expect(find.text('Milch'), findsOneWidget);
    expect(firstRowTicked(t), isTrue);
    expect(shopping.toggles, isEmpty);

    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(shopping.toggles.map((r) => r.id), ['1']);
  });

  testWidgets('tapping a settling tick again unticks it before it is sent', (
    t,
  ) async {
    final shopping = await openShopping(t);

    await t.tap(find.text('Milch'));
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.text('Milch'));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();

    expect(shopping.toggles, isEmpty);
  });

  testWidgets('a run of quick ticks is sent together after the pause', (
    t,
  ) async {
    final shopping = await openShopping(t);

    await t.tap(find.text('Milch'));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Brot'));
    await t.pump(const Duration(milliseconds: 400));
    expect(shopping.toggles, isEmpty);

    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(shopping.toggles.map((r) => r.id).toSet(), {'1', '2'});
  });

  testWidgets('the item sheet\'s plus changes the row behind it at once', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
        shopping: FakeShoppingRepository([item('1', 'Milch')]),
      ),
    );
    await t.tap(find.text('Einkauf'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-count-1')), findsNothing);

    await t.tap(find.byKey(const ValueKey('shopping-item-1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('item-more')));
    await t.pump();
    // Offline-capable: queued and shown before the server has answered.
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('item-count-1')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('item-count'))).data, '2');
    await t.tap(find.byKey(const ValueKey('item-less')));
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('item-count-1')), findsNothing);
    await t.tap(find.byKey(const ValueKey('item-done')));
    await t.pumpAndSettle();
  });
}
