import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';

import '../support/fakes.dart';

/// Records the moments claimed and the trips celebrated, without a platform channel.
class _SpyCelebration extends Celebration {
  _SpyCelebration(super.ref);

  final claimed = <String>[];
  int trips = 0;

  @override
  bool claimMoment(String key, {DateTime? now}) {
    final ok = super.claimMoment(key, now: now);
    if (ok) claimed.add(key);
    return ok;
  }

  @override
  Future<void> shoppingTrip() async => trips++;
}

/// A list whose tiles the household already has.
class _WithTiles extends FakeShoppingRepository {
  _WithTiles(super.list);

  @override
  Future<Result<ShoppingSnapshot>> snapshot() async => Ok(
    ShoppingSnapshot(
      items: list,
      lists: lists_,
      categories: categories_,
      catalog: const [
        CatalogEntry(
          id: 'c1',
          listId: 'l1',
          name: 'Milch',
          foldedName: 'milch',
          categoryId: null,
          purchaseCount: 4,
          lastPurchasedAt: null,
        ),
      ],
    ),
  );
}

/// [i] on the default list, as the server returns it.
ShoppingItem _onList(ShoppingItem i) => ShoppingItem(
  id: i.id,
  name: i.name,
  quantity: i.quantity,
  checked: i.checked,
  createdAt: i.createdAt,
  listId: 'l1',
);

Future<_SpyCelebration> _shopping(
  WidgetTester t,
  FakeShoppingRepository shopping, {
  bool trip = true,
}) async {
  final container = await pumpApp(
    t,
    overrides: [
      ...baseOverrides(
        identity: FakeIdentityRepository(current: device()),
        shopping: shopping,
      ),
      celebrationProvider.overrideWith(_SpyCelebration.new),
    ],
  );
  await t.tap(find.text('Einkauf').last);
  await t.pumpAndSettle();
  // The trip is a page of its own.
  if (trip) {
    await t.tap(find.byKey(const ValueKey('shopping-start')));
    await t.pumpAndSettle();
  }
  return container.read(celebrationProvider) as _SpyCelebration;
}

/// specs/26 "Celebrations": a shopping trip finished.
void main() {
  testWidgets('the last item ticked ends the trip once; finishing it is the '
      'same moment', (t) async {
    final shopping = FakeShoppingRepository([
      _onList(item('1', 'Milch')),
      _onList(item('2', 'Brot', checked: true)),
    ]);
    final spy = await _shopping(t, shopping);

    await t.tap(find.text('Milch'));
    await t.pump();
    expect(spy.trips, 1);
    expect(spy.claimed, [
      Celebration.tripOf('l1', ['1', '2']),
    ]);
    // The tick is sent after its short pause.
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();

    await t.tap(find.widgetWithText(FilledButton, 'Einkauf beenden'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Einkauf beenden'),
      ),
    );
    await t.pumpAndSettle();
    expect(spy.trips, 1);
    expect(spy.claimed, hasLength(1));
  });

  testWidgets('ticking one of several open items is no celebration yet', (
    t,
  ) async {
    final spy = await _shopping(
      t,
      FakeShoppingRepository([item('1', 'Milch'), item('2', 'Brot')]),
    );
    await t.tap(find.text('Milch'));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(spy.trips, 0);
  });

  testWidgets('finishing a trip with items left over celebrates what was '
      'bought', (t) async {
    final spy = await _shopping(
      t,
      FakeShoppingRepository([
        _onList(item('1', 'Milch', checked: true)),
        _onList(item('2', 'Brot')),
      ]),
    );
    await t.tap(find.widgetWithText(FilledButton, 'Einkauf beenden'));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Einkauf beenden'),
      ),
    );
    await t.pumpAndSettle();
    expect(spy.trips, 1);
    expect(spy.claimed, [
      Celebration.tripOf('l1', ['1']),
    ]);
  });

  testWidgets('an empty list with tiles says to tap one, and Wusel peeks', (
    t,
  ) async {
    await _shopping(t, _WithTiles([]), trip: false);
    expect(
      find.text('Noch nichts auf der Liste. Tipp auf eine Kachel.'),
      findsOneWidget,
    );
    expect(find.byType(Wusel), findsOneWidget);
  });

  testWidgets('without tiles the empty list keeps its plain line', (t) async {
    await _shopping(t, FakeShoppingRepository([]), trip: false);
    expect(find.text('Nichts zu kaufen'), findsOneWidget);
  });
}
