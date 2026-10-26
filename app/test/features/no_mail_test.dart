import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';

import '../support/fakes.dart';

// A server without mail (specs/20 "Choosing the server", Q48): E1 signs up and signs in with a
// password, a forgotten password is reset with a guardian's code, and nothing promises a code
// by email.

/// The app configured for a server that does or does not send mail.
AppConfig serverConfig({required bool emailCode}) => AppConfig.forServer(
  const AppConfig(
    environment: 'test',
    supabaseUrl: 'http://localhost',
    supabasePublishableKey: 'key',
  ),
  ServerInfo(
    supabaseUrl: Uri.parse('https://family.example.org'),
    publishableKey: 'sb_publishable_abc',
    apiVersion: 1,
    minAppVersion: '1.0.0',
    features: const [featurePasswordReset],
    emailCode: emailCode,
  ),
);

const mamaId = 'p-mama';

/// Papa (acting guardian), Mama (an adult member with an account), Anna (a child).
final people = [
  testMembers.first,
  const Member(
    id: mamaId,
    displayName: 'Mama',
    color: Color(0xFF9A5300),
    role: Role.member,
    active: true,
  ),
  testMembers.last,
];

Future<(FakeIdentityRepository, dynamic)> pumpSignIn(
  WidgetTester t, {
  FakeIdentityRepository? identity,
}) async {
  final id = identity ?? FakeIdentityRepository();
  final container = await pumpApp(
    t,
    overrides: baseOverrides(
      identity: id,
      signedIn: false,
      appConfig: serverConfig(emailCode: false),
    ),
  );
  container.read(routerProvider).go(Routes.signIn);
  await t.pumpAndSettle();
  return (id, container);
}

void main() {
  group('E1 without mail', () {
    testWidgets('opens on a new account, with no code by email', (t) async {
      final (identity, _) = await pumpSignIn(t);
      expect(find.text('Neues Konto'), findsOneWidget);
      expect(find.text('Konto erstellen'), findsOneWidget);
      expect(find.textContaining('verschickt keine E-Mails'), findsOneWidget);
      expect(find.text('Ich habe ein Passwort'), findsNothing);
      expect(find.text('Weiter'), findsNothing);

      await t.enterText(find.byType(TextFormField).first, ' lea@example.org ');
      await t.enterText(find.byType(TextField).last, 'short');
      await t.tap(find.text('Konto erstellen'));
      await t.pumpAndSettle();
      expect(
        find.text('Das Passwort braucht mindestens 10 Zeichen.'),
        findsOneWidget,
      );
      expect(identity.signUps, isEmpty);

      await t.enterText(find.byType(TextField).last, 'a long enough one');
      await t.tap(find.text('Konto erstellen'));
      await t.pumpAndSettle();
      expect(identity.signUps, [('lea@example.org', 'a long enough one')]);
      expect(
        identity.codeRequests,
        isEmpty,
        reason: 'no mail is ever asked for',
      );
    });

    testWidgets(
      'an address with an account tries its password, then signs in',
      (t) async {
        final identity = FakeIdentityRepository()
          ..signUpResult = const Err(AuthFailure(code: 'user_already_exists'));
        await pumpSignIn(t, identity: identity);
        await t.enterText(find.byType(TextFormField).first, 'lea@example.org');
        await t.enterText(find.byType(TextField).last, 'not her password');
        await t.tap(find.text('Konto erstellen'));
        await t.pumpAndSettle();

        expect(identity.signIns, [('lea@example.org', 'not her password')]);
        expect(find.textContaining('gibt es schon ein Konto'), findsOneWidget);
        expect(find.text('Passwort vergessen?'), findsOneWidget);
        expect(find.text('Konto erstellen'), findsNothing);
      },
    );

    testWidgets('sign-in says nothing about which part was wrong', (t) async {
      final identity = FakeIdentityRepository();
      await pumpSignIn(t, identity: identity);
      await t.tap(find.text('Anmelden').first);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'lea@example.org');
      await t.enterText(find.byType(TextFormField).last, 'wrong');
      await t.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await t.pumpAndSettle();
      expect(identity.signIns, [('lea@example.org', 'wrong')]);
      expect(find.text('E-Mail oder Passwort stimmt nicht.'), findsOneWidget);
    });

    testWidgets('a forgotten password is reset with the guardian’s code', (
      t,
    ) async {
      final identity = FakeIdentityRepository();
      await pumpSignIn(t, identity: identity);
      await t.tap(find.text('Anmelden').first);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'lea@example.org');
      await t.tap(find.text('Passwort vergessen?'));
      await t.pumpAndSettle();

      expect(find.text('Neues Passwort'), findsWidgets);
      expect(find.textContaining('Passwort zurücksetzen'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('password-reset-code')),
        'k7qm3xrp',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('password-reset-code')),
          matching: find.text('K7QM-3XRP'),
        ),
        findsOneWidget,
        reason: 'typed like the code on screen',
      );
      await t.enterText(find.byType(TextField).last, 'a brand new password');
      await t.tap(find.text('Speichern und anmelden'));
      await t.pumpAndSettle();
      expect(identity.resetRedeems, [
        ('lea@example.org', 'K7QM-3XRP', 'a brand new password'),
      ]);
    });

    testWidgets('an expired code says so', (t) async {
      final identity = FakeIdentityRepository()
        ..resetRedeemResult = const Err(
          ValidationFailure(code: 'reset_code_expired'),
        );
      final (_, container) = await pumpSignIn(t, identity: identity);
      container
          .read(routerProvider)
          .push('${Routes.passwordReset}?email=lea%40example.org');
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('password-reset-code')),
        'K7QM3XRP',
      );
      await t.enterText(find.byType(TextField).last, 'a brand new password');
      await t.tap(find.text('Speichern und anmelden'));
      await t.pumpAndSettle();
      expect(
        find.text('Dieser Code ist abgelaufen. Bitte um einen neuen.'),
        findsOneWidget,
      );
    });

    testWidgets('a server with mail keeps E1 as it was', (t) async {
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          signedIn: false,
          appConfig: serverConfig(emailCode: true),
        ),
      );
      container.read(routerProvider).go(Routes.signIn);
      await t.pumpAndSettle();
      expect(find.text('Weiter'), findsOneWidget);
      expect(find.text('Ich habe ein Passwort'), findsOneWidget);
      expect(find.text('Neues Konto'), findsNothing);
    });
  });

  group('Settings without mail', () {
    testWidgets('the sign-in section promises no email code', (t) async {
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          settingsView: SettingsView.advanced,
          identity: FakeIdentityRepository(current: device()),
          appConfig: serverConfig(emailCode: false),
        ),
      );
      container.read(routerProvider).go(Routes.settingsAccount);
      await t.pumpAndSettle();
      expect(find.textContaining('immer verfügbar'), findsNothing);
      expect(find.textContaining('verschickt keine E-Mails'), findsOneWidget);
    });
  });

  group('deleting the account without mail', () {
    testWidgets('an old sign-in asks for the password, not a code', (t) async {
      final identity = FakeIdentityRepository(current: device())
        ..signInResult = const Ok(null);
      final admin = FakeAccountAdminRepository()
        ..deleteResults = [
          const Err(PermissionFailure(code: 'reauth_required')),
          const Ok(null),
        ]
        ..recent = true;
      final container = await pumpApp(
        t,
        size: const Size(1000, 1600),
        overrides: baseOverrides(
          settingsView: SettingsView.advanced,
          identity: identity,
          accountAdmin: admin,
          household: FakeHouseholdOnboardingRepository(
            identity: identity,
            accountValue: const Account(
              userId: 'user-1',
              email: 'daniel@example.org',
              hasHousehold: true,
              householdId: 'h1',
              profileId: guardianId,
              creation: HouseholdCreation.code,
              householdName: 'Huser',
            ),
          ),
          appConfig: serverConfig(emailCode: false),
        ),
      );
      container.read(routerProvider).go(Routes.settingsAccount);
      await t.pumpAndSettle();
      final tile = find.byKey(const ValueKey('delete-account'));
      await t.scrollUntilVisible(tile, 200);
      await t.pumpAndSettle();
      await t.tap(tile);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('delete-account-confirm')));
      await t.pumpAndSettle();

      expect(
        find.textContaining('Gib das Passwort von daniel@example.org'),
        findsOneWidget,
      );
      expect(find.text('Code senden'), findsNothing);
      await t.enterText(
        find.byKey(const ValueKey('reauth-password')),
        'secret',
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Bestätigen'));
      await t.pumpAndSettle();

      expect(identity.signIns, [('daniel@example.org', 'secret')]);
      expect(identity.codeRequests, isEmpty);
      expect(admin.deleteCalls, 2, reason: 'retried once after the password');
      await unmountApp(t, container);
    });
  });

  group('the guardian’s reset code (Mitglieder)', () {
    final resetButton = find.byKey(const ValueKey('password-reset-$mamaId'));

    Future<(FakeAccountAdminRepository, dynamic)> pumpMembers(
      WidgetTester t, {
      required bool emailCode,
      DeviceInfo? onDevice,
    }) async {
      final identity = FakeIdentityRepository(
        current: onDevice ?? device(),
        members: people,
      );
      final admin = FakeAccountAdminRepository();
      final container = await pumpApp(
        t,
        size: const Size(1000, 1600),
        overrides: baseOverrides(
          settingsView: SettingsView.advanced,
          identity: identity,
          accountAdmin: admin,
          appConfig: serverConfig(emailCode: emailCode),
        ),
      );
      container.read(routerProvider).go(Routes.settingsMembers);
      await t.pumpAndSettle();
      return (admin, container);
    }

    testWidgets(
      'a guardian creates a code for another adult and sees it once',
      (t) async {
        final (admin, _) = await pumpMembers(t, emailCode: false);
        await t.ensureVisible(resetButton);
        await t.tap(resetButton);
        await t.pumpAndSettle();
        expect(find.text('Neues Passwort für Mama?'), findsOneWidget);
        await t.tap(find.text('Code erstellen'));
        await t.pumpAndSettle();

        expect(admin.resetCodes, [
          (actorProfileId: guardianId, profileId: mamaId),
        ]);
        expect(find.text('Code für Mama'), findsOneWidget);
        expect(find.text('K7QM-3XRP'), findsOneWidget);
        expect(find.textContaining('Passwort vergessen?'), findsOneWidget);
      },
    );

    testWidgets('not on a server with mail, and never for a child', (t) async {
      await pumpMembers(t, emailCode: true);
      expect(resetButton, findsNothing);
      expect(
        find.byKey(ValueKey('password-reset-${testMembers.last.id}')),
        findsNothing,
      );
    });

    testWidgets('not on a shared tablet', (t) async {
      await pumpMembers(
        t,
        emailCode: false,
        onDevice: device(deviceClass: DeviceClass.shared),
      );
      expect(resetButton, findsNothing);
    });
  });
}
