import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

import '../support/fakes.dart';

/// The list as a phone in a shop with no signal shows it (specs/07#offline): the change
/// is there at once, marked as waiting, and the banner counts what is not sent yet.
class FlakyShoppingRepository extends FakeShoppingRepository {
  FlakyShoppingRepository(super.list);

  bool online = true;

  @override
  Future<Result<ApplyResult>> apply({
    required String? actor,
    required List<ShoppingOp> ops,
  }) async => online
      ? super.apply(actor: actor, ops: ops)
      : const Err(NetworkFailure());
}

void main() {
  testWidgets('offline, an added item shows at once and waits to be sent', (
    t,
  ) async {
    final shopping = FlakyShoppingRepository([item('1', 'Milch')]);
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
    shopping.online = false;

    await t.enterText(find.byType(TextField), 'Brot');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    expect(find.text('Brot'), findsOneWidget);
    expect(find.text('1 Änderung wartet aufs Senden'), findsOneWidget);
    expect(find.byTooltip('Wartet aufs Senden'), findsOneWidget);
    expect(shopping.list.map((i) => i.name), ['Milch']);

    shopping.online = true;
    await container.read(shoppingSyncProvider.notifier).sync();
    await t.pumpAndSettle();

    expect(find.text('1 Änderung wartet aufs Senden'), findsNothing);
    expect(find.byTooltip('Wartet aufs Senden'), findsNothing);
    expect(shopping.list.map((i) => i.name), ['Milch', 'Brot']);
  });
}
