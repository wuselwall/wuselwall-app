import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/enrolment_qr.dart';

import '../support/fakes.dart';

void main() {
  testWidgets(
    'a guardian with a pending second factor is sent to the code page',
    (t) async {
      final identity = FakeIdentityRepository(
        current: device(),
        mfa: MfaState.challengeRequired,
      );
      final container = await pumpApp(
        t,
        overrides: baseOverrides(identity: identity),
      );
      expect(find.text('Zweiter Faktor'), findsOneWidget);
      expect(find.text('Einkaufsliste'), findsNothing);

      await t.enterText(find.byType(TextField), '123456');
      await t.tap(find.text('Bestätigen'));
      await t.pump();
      expect(identity.mfaCodes, ['123456']);

      // Once the session is aal2 the router lets the guardian through.
      container.invalidate(sessionStateProvider);
      await t.pumpAndSettle();
      expect(find.text('Einkauf'), findsOneWidget);
    },
  );

  testWidgets('a signed-in guardian on a new phone names the device first', (
    t,
  ) async {
    final identity = FakeIdentityRepository(
      profile: const GuardianProfile(
        profileId: guardianId,
        displayName: 'Papa',
      ),
    );
    await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          identity: identity,
          shopping: FakeShoppingRepository([]),
        ),
      ],
    );
    expect(find.text('Dieses Gerät benennen'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Handy von Papa'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'Papas iPhone');
    await t.tap(find.text('Dieses Gerät verwenden'));
    await t.pumpAndSettle();
    expect(identity.registeredLabels, ['Papas iPhone']);
    expect(find.text('Einkauf'), findsOneWidget);
  });

  testWidgets('a rate-limited enrolment explains itself', (t) async {
    final identity = FakeIdentityRepository(
      enrolResult: const Err(PermissionFailure(code: 'rate_limited')),
    );
    await pumpApp(
      t,
      overrides: baseOverrides(identity: identity, signedIn: false),
    );
    await t.tap(find.text('Mit Code verbinden'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'ABCD2345');
    await t.tap(find.text('Verbinden'));
    await t.pumpAndSettle();
    expect(find.textContaining('Zu viele Versuche'), findsOneWidget);
  });

  testWidgets('a malformed code is rejected before any request', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        signedIn: false,
      ),
    );
    await t.tap(find.text('Mit Code verbinden'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'nope');
    await t.tap(find.text('Verbinden'));
    await t.pumpAndSettle();
    expect(
      find.text('Dieser Code ist falsch oder abgelaufen.'),
      findsOneWidget,
    );
  });

  group('settings', () {
    testWidgets('the enrolment code is also shown as a QR code', (t) async {
      final identity = FakeIdentityRepository(current: device());
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          shopping: FakeShoppingRepository([]),
        ),
      );
      await t.tap(find.byIcon(Icons.settings));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.add_to_home_screen));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Wand');
      await t.tap(find.text('Code erzeugen'));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('enrolment-code')), findsOneWidget);
      final qr = t.widget<EnrolmentQr>(
        find.byKey(const ValueKey('enrolment-qr')),
      );
      expect(qr.payload, 'wuselwall://enrol?code=ABCD2345');
    });

    testWidgets('security options show on a personal phone only', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          shopping: FakeShoppingRepository([]),
        ),
      );
      await t.tap(find.byIcon(Icons.settings));
      await t.pumpAndSettle();
      expect(find.text('Zwei-Faktor-Anmeldung'), findsOneWidget);
      expect(find.text('Passkey'), findsOneWidget);
    });
  });
}
