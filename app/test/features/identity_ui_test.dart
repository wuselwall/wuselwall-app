import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/week_board_page.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

import '../support/fakes.dart';

void main() {
  /// A shared kid device: the avatars and the shopping list are on the home page.
  Future<ProviderContainer> pumpShared(
    WidgetTester t, {
    FakeIdentityRepository? identity,
    FakeShoppingRepository? shopping,
  }) => pumpApp(
    t,
    overrides: [
      ...baseOverrides(
        identity:
            identity ??
            FakeIdentityRepository(
              current: device(
                deviceClass: DeviceClass.shared,
                register: UiRegister.kid,
              ),
            ),
        shopping: shopping ?? FakeShoppingRepository([item('1', 'Milch')]),
      ),
      // The kid home reads the week board for tonight's meal; a fixed board keeps the
      // wall's refetch timers out of these shared-device tests.
      boardProvider.overrideWith(_StaticBoard.new),
    ],
  );

  /// The kiosk home: the week board, no avatars, no app bar. The wall is landscape.
  Future<ProviderContainer> pumpKiosk(WidgetTester t) => pumpApp(
    t,
    size: const Size(1920, 1200),
    overrides: baseOverrides(
      identity: FakeIdentityRepository(
        current: device(
          deviceClass: DeviceClass.kiosk,
          register: UiRegister.kiosk,
        ),
      ),
      shopping: FakeShoppingRepository([item('1', 'Milch')]),
    ),
  );

  testWidgets('tap-to-switch: tapping an avatar changes the acting profile', (
    t,
  ) async {
    final container = await pumpShared(t);
    expect(container.read(actingProfileProvider), isNull);
    expect(find.text('Wer bist du?'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('avatar-$kidId')));
    await t.pump();
    expect(container.read(actingProfileProvider), kidId);
  });

  testWidgets('the kiosk home shows the week board, not the avatars', (
    t,
  ) async {
    final container = await pumpKiosk(t);
    expect(find.byType(WeekBoardPage), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-$kidId')), findsNothing);
    expect(find.byIcon(Icons.settings), findsNothing);
    await unmountApp(t, container);
  });

  testWidgets('the kiosk reverts to nobody after 60 s without touch', (
    t,
  ) async {
    final container = await pumpKiosk(t);
    container.read(actingProfileProvider.notifier).select(kidId);
    await t.pump();
    expect(container.read(actingProfileProvider), kidId);

    await t.pump(const Duration(seconds: 59));
    expect(container.read(actingProfileProvider), kidId);
    await t.pump(const Duration(seconds: 2));
    expect(container.read(actingProfileProvider), isNull);
    await unmountApp(t, container);
  });

  testWidgets('every write names the acting profile', (t) async {
    final shopping = FakeShoppingRepository([item('1', 'Milch')]);
    await pumpShared(t, shopping: shopping);
    await t.tap(find.byKey(const ValueKey('avatar-$kidId')));
    await t.pump();
    // On the kid home the list is its own tab.
    await t.tap(find.text('Einkaufen'));
    await t.pumpAndSettle();

    await t.tap(find.text('Milch'));
    await t.pumpAndSettle();
    expect(shopping.toggles.single, (actor: kidId, id: '1'));
  });

  group('PIN pad', () {
    Future<void> openSettingsAndTryGuardianAction(
      WidgetTester t,
      FakeIdentityRepository identity,
    ) async {
      final container = await pumpShared(t, identity: identity);
      container.read(actingProfileProvider.notifier).select(guardianId);
      await t.pump();
      await t.tap(find.byTooltip('Einstellungen'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.person_add_alt_1));
      await t.pumpAndSettle();
    }

    Future<void> enter(WidgetTester t, String digits) async {
      for (final d in digits.split('')) {
        await t.tap(find.widgetWithText(OutlinedButton, d));
        await t.pump();
      }
      await t.pumpAndSettle();
    }

    FakeIdentityRepository sharedIdentity() => FakeIdentityRepository(
      current: device(
        deviceClass: DeviceClass.shared,
        register: UiRegister.kid,
      ),
    );

    testWidgets('a guardian action on a shared device asks for the PIN', (
      t,
    ) async {
      await openSettingsAndTryGuardianAction(t, sharedIdentity());
      expect(find.text('PIN für Erziehungsberechtigte'), findsOneWidget);
    });

    testWidgets('digits are never echoed, only dots', (t) async {
      await openSettingsAndTryGuardianAction(t, sharedIdentity());
      await t.tap(find.widgetWithText(OutlinedButton, '7'));
      await t.pump();
      // The pad's own "7" key is the only "7" on screen; entering it adds no text.
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('a wrong PIN reports the attempts left and clears the dots', (
      t,
    ) async {
      final identity = sharedIdentity();
      await openSettingsAndTryGuardianAction(t, identity);
      await enter(t, '111111');
      expect(identity.pinAttempts, ['111111']);
      expect(find.text('Falsche PIN. Noch 8 Versuche.'), findsOneWidget);
    });

    testWidgets(
      'a correct PIN closes the pad and unlocks the guardian window',
      (t) async {
        final identity = sharedIdentity()
          ..pinResult = PinVerified(
            DateTime.now().add(const Duration(minutes: 15)),
          );
        await openSettingsAndTryGuardianAction(t, identity);
        await enter(t, '123456');
        expect(find.text('PIN für Erziehungsberechtigte'), findsNothing);
        expect(find.text('Mitglied hinzufügen'), findsWidgets);
      },
    );

    testWidgets('a member cannot start a guardian action', (t) async {
      final container = await pumpShared(t, identity: sharedIdentity());
      container.read(actingProfileProvider.notifier).select(kidId);
      await t.pump();
      await t.tap(find.byTooltip('Einstellungen'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.person_add_alt_1));
      await t.pumpAndSettle();
      expect(find.text('PIN für Erziehungsberechtigte'), findsNothing);
      expect(
        find.text('Das darf nur ein Erziehungsberechtigter.'),
        findsOneWidget,
      );
    });
  });
}

class _StaticBoard extends BoardNotifier {
  @override
  BoardSnapshot build() =>
      BoardSnapshot(board: emptyWeekBoard(), fetchedAt: DateTime.now());
}
