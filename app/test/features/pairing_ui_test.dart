import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';
import 'package:wuselwall/features/identity/application/pairing_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';

import '../support/fake_pairing.dart';
import '../support/fakes.dart';

/// The new device's front-door page (P1), reached as a signed-out device would reach it.
Future<ProviderContainer> pumpPair(
  WidgetTester t, {
  required FakePairingRepository pairing,
  FakeIdentityRepository? identity,
}) async {
  final container = await pumpApp(
    t,
    overrides: baseOverrides(
      identity: identity ?? FakeIdentityRepository(),
      pairing: pairing,
      signedIn: false,
    ),
  );
  container.read(routerProvider).go(Routes.pair);
  // The first frame shows the spinner; the fake's start answers in the next.
  await t.pump();
  await t.pump();
  return container;
}

/// A guardian's personal phone on the device-pairing page (G1), optionally with a kind.
Future<ProviderContainer> pumpDevicePair(
  WidgetTester t, {
  required FakePairingRepository pairing,
  FakeIdentityRepository? identity,
  String? kind,
}) async {
  final container = await pumpApp(
    t,
    overrides: baseOverrides(
      identity: identity ?? FakeIdentityRepository(current: device()),
      pairing: pairing,
    ),
  );
  final query = kind == null ? '' : '?kind=$kind';
  container.read(routerProvider).go('${Routes.devicePair}$query');
  await t.pumpAndSettle();
  return container;
}

void main() {
  group('the new device (P1)', () {
    testWidgets('shows the code in large type and the QR code, and polls', (
      t,
    ) async {
      final pairing = FakePairingRepository();
      final container = await pumpPair(t, pairing: pairing);

      expect(find.text('K7QM-3XRP'), findsOneWidget);
      expect(find.byKey(const ValueKey('pair-qr')), findsOneWidget);
      expect(
        find.text('Öffne WuselWall auf deinem Handy und scanne diesen Code.'),
        findsOneWidget,
      );
      expect(pairing.starts, 1);

      await t.pump(const Duration(seconds: 4));
      expect(pairing.polls, 2, reason: 'one poll every two seconds');

      await unmountApp(t, container);
    });

    testWidgets('renews the code before it runs out, with no error screen', (
      t,
    ) async {
      final pairing = FakePairingRepository();
      final container = await pumpPair(t, pairing: pairing);

      await t.pump(const Duration(minutes: 9, seconds: 31));
      expect(pairing.starts, 2);
      expect(find.text('H4NT-7WBC'), findsOneWidget);

      await unmountApp(t, container);
    });

    testWidgets('waits out a rate limit instead of showing an error', (
      t,
    ) async {
      final pairing = FakePairingRepository()
        ..startFailures.add(const PermissionFailure(code: 'rate_limited'));
      final container = await pumpPair(t, pairing: pairing);

      expect(find.text('K7QM-3XRP'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await t.pump(const Duration(seconds: 31));
      expect(pairing.starts, 2);
      expect(find.text('H4NT-7WBC'), findsOneWidget);

      await unmountApp(t, container);
    });

    testWidgets('an expired code is replaced by a fresh one', (t) async {
      final pairing = FakePairingRepository()
        ..pollQueue.add(const PairingExpired());
      final container = await pumpPair(t, pairing: pairing);

      await t.pump(const Duration(seconds: 2));
      expect(pairing.starts, 2);
      expect(find.text('H4NT-7WBC'), findsOneWidget);

      await unmountApp(t, container);
    });

    testWidgets('an approval signs in and greets the household', (t) async {
      final pairing = FakePairingRepository()
        ..pollQueue.add(
          PairingApproved(
            email: 'device-1@devices.wuselwall.invalid',
            password: 'pw',
            householdName: 'Familie Huser',
            deviceClass: DeviceClass.shared,
            register: UiRegister.kid,
          ),
        );
      final identity = FakeIdentityRepository()..signInResult = const Ok(null);
      final container = await pumpPair(t, pairing: pairing, identity: identity);

      await t.pump(const Duration(seconds: 2));
      expect(identity.signIns, [('device-1@devices.wuselwall.invalid', 'pw')]);
      expect(find.text('Verbunden mit Familie Huser'), findsOneWidget);
      expect(container.read(pairingHandoffProvider), 'Familie Huser');

      // The greeting lasts two seconds, then the router takes over.
      await t.pump(const Duration(seconds: 3));
      await unmountApp(t, container);
    });

    testWidgets(
      'a failed sign-in starts again rather than showing an error screen',
      (t) async {
        final pairing = FakePairingRepository()
          ..pollQueue.add(
            PairingApproved(
              email: 'device-1@devices.wuselwall.invalid',
              password: 'pw',
              householdName: 'Familie Huser',
              deviceClass: DeviceClass.shared,
              register: UiRegister.kid,
            ),
          );
        final container = await pumpPair(t, pairing: pairing);

        await t.pump(const Duration(seconds: 2));
        expect(pairing.starts, 2);
        expect(find.text('H4NT-7WBC'), findsOneWidget);
        expect(container.read(pairingHandoffProvider), isNull);

        await unmountApp(t, container);
      },
    );
  });

  group('the guardian\'s phone (G1, G2)', () {
    testWidgets(
      'a typed code opens the review, and a child\'s phone is bound to the child',
      (t) async {
        final pairing = FakePairingRepository();
        final container = await pumpDevicePair(t, pairing: pairing);

        await t.enterText(find.byType(TextField), 'k7qm3xrp');
        expect(
          t.widget<TextField>(find.byType(TextField)).controller!.text,
          'K7QM-3XRP',
        );
        await t.tap(find.text('Weiter'));
        await t.pumpAndSettle();

        expect(find.text('K7QM-3XRP'), findsOneWidget);
        expect(
          find.text('Nur bestätigen, wenn du dieses Gerät vor dir siehst.'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('pair-child')), findsNothing);

        await t.tap(find.text('Handy eines Kindes'));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('pair-child')), findsOneWidget);
        expect(
          t
              .widget<TextField>(find.byKey(const ValueKey('pair-name')))
              .controller!
              .text,
          'Handy von Anna',
        );

        await t.tap(find.text('Verbinden'));
        await t.pumpAndSettle();
        expect(pairing.approvals.single.code, 'K7QM3XRP');
        expect(pairing.approvals.single.kind, PairingKind.childPhone);
        expect(pairing.approvals.single.childProfileId, kidId);
        expect(pairing.approvals.single.label, 'Handy von Anna');

        await unmountApp(t, container);
      },
    );

    testWidgets(
      'a wall display opens preselected, named by its kind, with no child picker',
      (t) async {
        final pairing = FakePairingRepository();
        final container = await pumpDevicePair(
          t,
          pairing: pairing,
          kind: PairingKind.wallDisplay.wire,
        );

        await t.enterText(find.byType(TextField), 'K7QM3XRP');
        await t.tap(find.text('Weiter'));
        await t.pumpAndSettle();

        expect(
          t
              .widget<TextField>(find.byKey(const ValueKey('pair-name')))
              .controller!
              .text,
          'Wanddisplay',
        );
        expect(find.byKey(const ValueKey('pair-child')), findsNothing);

        await t.tap(find.text('Verbinden'));
        await t.pumpAndSettle();
        expect(pairing.approvals.single.kind, PairingKind.wallDisplay);
        expect(pairing.approvals.single.childProfileId, isNull);

        await unmountApp(t, container);
      },
    );

    testWidgets('the PIN is asked for only when this guardian has none (G2)', (
      t,
    ) async {
      final pairing = FakePairingRepository()
        ..approveResult = const Ok(
          PairingApproval(deviceId: 'd-9', label: 'Tablet', needsPin: true),
        );
      final identity = FakeIdentityRepository(current: device());
      final container = await pumpDevicePair(
        t,
        pairing: pairing,
        identity: identity,
        kind: PairingKind.familyTablet.wire,
      );

      await t.enterText(find.byType(TextField), 'K7QM3XRP');
      await t.tap(find.text('Weiter'));
      await t.pumpAndSettle();
      await t.tap(find.text('Verbinden'));
      await t.pumpAndSettle();

      expect(find.text('Eltern-PIN festlegen'), findsOneWidget);
      for (final round in const [1, 2]) {
        for (final digit in const ['1', '2', '3', '4', '5', '6']) {
          await t.tap(find.widgetWithText(OutlinedButton, digit));
          await t.pump();
        }
        if (round == 1) await t.pump();
      }
      await t.pumpAndSettle();
      expect(identity.pins, ['123456']);

      await unmountApp(t, container);
    });

    testWidgets('a guardian with a PIN is not asked for one again', (t) async {
      final pairing = FakePairingRepository();
      final identity = FakeIdentityRepository(current: device());
      final container = await pumpDevicePair(
        t,
        pairing: pairing,
        identity: identity,
      );

      await t.enterText(find.byType(TextField), 'K7QM3XRP');
      await t.tap(find.text('Weiter'));
      await t.pumpAndSettle();
      await t.tap(find.text('Verbinden'));
      await t.pumpAndSettle();

      expect(find.text('Eltern-PIN festlegen'), findsNothing);
      expect(identity.pins, isEmpty);

      await unmountApp(t, container);
    });

    testWidgets('a refused code is said, and the page stays', (t) async {
      final pairing = FakePairingRepository()
        ..approveResult = const Err(ValidationFailure(code: 'code_invalid'));
      final container = await pumpDevicePair(t, pairing: pairing);

      await t.enterText(find.byType(TextField), 'K7QM3XRP');
      await t.tap(find.text('Weiter'));
      await t.pumpAndSettle();
      await t.tap(find.text('Verbinden'));
      await t.pumpAndSettle();

      expect(
        find.text('Dieser Code ist falsch oder abgelaufen.'),
        findsOneWidget,
      );
      expect(find.text('K7QM-3XRP'), findsOneWidget);

      await unmountApp(t, container);
    });
  });

  group('the approval is for a guardian on a personal phone', () {
    test('a guardian\'s personal phone may approve', () async {
      final container = ProviderContainer(
        overrides: [
          deviceProvider.overrideWithValue(
            AsyncData(device(profileId: guardianId)),
          ),
          membersProvider.overrideWith((ref) async => testMembers),
        ],
      );
      addTearDown(container.dispose);
      await container.read(membersProvider.future);
      expect(container.read(canApprovePairingProvider), isTrue);
    });

    test('a child\'s phone, a shared tablet and a kiosk may not', () async {
      Future<bool> canApprove(DeviceInfo? info) async {
        final container = ProviderContainer(
          overrides: [
            deviceProvider.overrideWithValue(AsyncData(info)),
            membersProvider.overrideWith((ref) async => testMembers),
          ],
        );
        addTearDown(container.dispose);
        await container.read(membersProvider.future);
        return container.read(canApprovePairingProvider);
      }

      expect(
        await canApprove(device(profileId: kidId)),
        isFalse,
        reason: 'a member on a personal phone',
      );
      expect(
        await canApprove(
          device(deviceClass: DeviceClass.shared, register: UiRegister.kid),
        ),
        isFalse,
      );
      expect(
        await canApprove(
          device(deviceClass: DeviceClass.kiosk, register: UiRegister.kiosk),
        ),
        isFalse,
      );
      expect(await canApprove(null), isFalse);
    });
  });

  group('the first-run introduction', () {
    testWidgets('a new wall display shows the checklist once', (t) async {
      final store = FakeFirstRunStore();
      final container = await pumpApp(
        t,
        size: const Size(1920, 1200),
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(
              current: device(
                deviceClass: DeviceClass.kiosk,
                register: UiRegister.kiosk,
              ),
            ),
            shopping: FakeShoppingRepository([]),
          ),
          firstRunStoreProvider.overrideWithValue(store),
        ],
      );

      expect(find.text('Wanddisplay einrichten'), findsOneWidget);
      expect(find.text('Am Strom lassen'), findsOneWidget);

      await t.ensureVisible(find.byKey(const ValueKey('first-run-done')));
      await t.tap(find.byKey(const ValueKey('first-run-done')));
      await t.pumpAndSettle();
      expect(store.seen, {'d1'});
      expect(find.text('Wanddisplay einrichten'), findsNothing);

      await unmountApp(t, container);
    });

    testWidgets('a kids\' tablet is welcomed once, with the picture tip', (
      t,
    ) async {
      final store = FakeFirstRunStore();
      final container = await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(
              current: device(
                deviceClass: DeviceClass.shared,
                register: UiRegister.kid,
              ),
            ),
            shopping: FakeShoppingRepository([]),
          ),
          firstRunStoreProvider.overrideWithValue(store),
        ],
      );

      expect(
        find.text('Tipp auf dein Bild, dann weiß WuselWall, wer du bist.'),
        findsOneWidget,
      );
      expect(find.text('Los geht’s'), findsOneWidget);

      await unmountApp(t, container);
    });

    test('a personal phone and a seen device owe nothing', () async {
      final store = FakeFirstRunStore()..seen.add('d1');
      final container = ProviderContainer(
        overrides: [
          deviceProvider.overrideWithValue(
            AsyncData(
              device(
                deviceClass: DeviceClass.kiosk,
                register: UiRegister.kiosk,
              ),
            ),
          ),
          firstRunStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(pendingFirstRunProvider.future),
        isNull,
        reason: 'already seen',
      );

      final personal = ProviderContainer(
        overrides: [
          deviceProvider.overrideWithValue(AsyncData(device())),
          firstRunStoreProvider.overrideWithValue(FakeFirstRunStore()),
        ],
      );
      addTearDown(personal.dispose);
      expect(
        await personal.read(pendingFirstRunProvider.future),
        isNull,
        reason: 'a personal phone is never introduced',
      );
    });
  });
}
