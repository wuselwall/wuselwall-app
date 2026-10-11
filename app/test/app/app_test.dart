import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

import '../support/fakes.dart';

void main() {
  group('an un-enrolled device', () {
    Future<void> pump(WidgetTester t, {Locale locale = const Locale('de')}) =>
        pumpApp(
          t,
          locale: locale,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(),
            signedIn: false,
          ),
        );

    testWidgets('shows the German setup screen', (t) async {
      await pump(t);
      expect(
        find.text('Dieses Gerät ist noch nicht eingerichtet'),
        findsOneWidget,
      );
      expect(find.text('Dieses Gerät mit Code einrichten'), findsOneWidget);
    });

    testWidgets('shows English on an English device', (t) async {
      await pump(t, locale: const Locale('en'));
      expect(find.text('This device is not set up yet'), findsOneWidget);
    });

    testWidgets('falls back to German for unsupported locales', (t) async {
      await pump(t, locale: const Locale('fr'));
      expect(find.text('Einrichtung'), findsWidgets);
    });

    testWidgets('a wrong enrolment code shows a localized error', (t) async {
      await pump(t);
      await t.tap(find.text('Dieses Gerät mit Code einrichten'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'ABCD2345');
      await t.tap(find.text('Einrichten'));
      await t.pumpAndSettle();
      expect(
        find.text('Dieser Code ist falsch oder abgelaufen.'),
        findsOneWidget,
      );
    });
  });

  group('an enrolled device', () {
    testWidgets('a personal device goes straight to the list, no avatar bar', (
      t,
    ) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          shopping: FakeShoppingRepository([item('1', 'Milch')]),
        ),
      );
      expect(find.text('Einkaufsliste'), findsOneWidget);
      expect(find.text('Milch'), findsOneWidget);
      expect(find.text('Wer bist du?'), findsNothing);
    });

    testWidgets('a revoked device is signed out and sent back to setup', (
      t,
    ) async {
      final identity = FakeIdentityRepository(
        current: DeviceInfo(
          deviceId: 'd1',
          householdId: 'h1',
          label: 'x',
          deviceClass: DeviceClass.personal,
          register: device().register,
          profileId: guardianId,
          revoked: true,
          guardianVerifiedUntil: null,
        ),
      );
      await pumpApp(t, overrides: baseOverrides(identity: identity));
      expect(identity.signedOut, isTrue);
      expect(
        find.text('Dieses Gerät ist noch nicht eingerichtet'),
        findsOneWidget,
      );
    });
  });
}
