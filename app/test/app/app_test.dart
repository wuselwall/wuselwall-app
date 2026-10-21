import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
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
      expect(find.text('Willkommen bei WuselWall'), findsOneWidget);
      expect(
        find.text('Familien-Tablet oder Wanddisplay verbinden'),
        findsOneWidget,
      );
    });

    testWidgets('shows English on an English device', (t) async {
      await pump(t, locale: const Locale('en'));
      expect(find.text('Welcome to WuselWall'), findsOneWidget);
    });

    testWidgets('falls back to German for unsupported locales', (t) async {
      await pump(t, locale: const Locale('it'));
      expect(find.text('Willkommen bei WuselWall'), findsOneWidget);
    });

    testWidgets('a wrong enrolment code shows a localized error', (t) async {
      await pump(t);
      await t.tap(find.text('Familien-Tablet oder Wanddisplay verbinden'));
      await t.pump();
      await t.pump();
      await t.tap(find.text('Ich habe einen Code vom Handy (ältere Version)'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'ABCD2345');
      await t.tap(find.text('Verbinden'));
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
      // The adult home opens on the calendar; the shopping tab is one tap away. Its
      // label is the same text as the app bar title, so the title is found in the bar.
      await t.tap(find.text('Einkauf'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Einkaufsliste'), findsOneWidget);
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
      // The account still has a family: a revoked phone is signed out. (Without one, the
      // account starts afresh instead; see household_leave_test.dart.)
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          household: FakeHouseholdOnboardingRepository(
            identity: identity,
            accountValue: const Account(
              userId: 'user-1',
              hasHousehold: true,
              creation: HouseholdCreation.code,
            ),
          ),
        ),
      );
      expect(identity.signedOut, isTrue);
      expect(find.text('Willkommen bei WuselWall'), findsOneWidget);
    });
  });
}
