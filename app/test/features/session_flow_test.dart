import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/enrol_code.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/enrolment_qr.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';

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
    await t.tap(find.text('Familien-Tablet oder Wanddisplay verbinden'));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Ich habe einen Code vom Handy (ältere Version)'));
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
    await t.tap(find.text('Familien-Tablet oder Wanddisplay verbinden'));
    await t.pump();
    await t.pump();
    await t.tap(find.text('Ich habe einen Code vom Handy (ältere Version)'));
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
          settingsView: SettingsView.advanced,
          identity: identity,
          shopping: FakeShoppingRepository([]),
        ),
      );
      await t.tap(find.byIcon(Icons.settings));
      await t.pumpAndSettle();
      // A guardian on a personal phone connects devices by scanning; the code for an older
      // device is the secondary action.
      await t.tap(find.text('Code für ein älteres Gerät erzeugen'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Wand');
      await t.tap(find.text('Code erzeugen'));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('enrolment-code')), findsOneWidget);
      final qr = t.widget<EnrolmentQr>(
        find.byKey(const ValueKey('enrolment-qr')),
      );
      // The code and the server in one scan (ADR-018): a fresh store app reads both.
      expect(qr.payload, startsWith('wuselwall://enrol?code=ABCD2345&server='));
      expect(parseEnrolmentCode(qr.payload), 'ABCD2345');
      expect(
        parseServerAddress(qr.payload, allowHttp: true),
        Uri.parse('http://localhost'),
      );
    });

    testWidgets('security options show on a personal phone only', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          settingsView: SettingsView.advanced,
          identity: FakeIdentityRepository(current: device()),
          shopping: FakeShoppingRepository([]),
        ),
      );
      await t.tap(find.byIcon(Icons.settings));
      await t.pumpAndSettle();
      // The security section sits below the settings entries; the list builds lazily.
      await t.scrollUntilVisible(
        find.text('Zwei-Faktor-Anmeldung'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Zwei-Faktor-Anmeldung'), findsOneWidget);
      expect(find.text('Passkey'), findsOneWidget);
    });
  });
}
