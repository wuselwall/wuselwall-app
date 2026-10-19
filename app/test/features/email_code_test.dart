import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/application/sign_in_choice.dart';
import 'package:wuselwall/features/identity/domain/email_code.dart';

import '../support/fakes.dart';

const _codeTitle = 'Code aus der E-Mail';
const _choiceTitle = 'Wie möchtest du dich künftig anmelden?';
const _wrongCode =
    'Der Code stimmt nicht oder ist abgelaufen. Probier es noch einmal oder fordere einen neuen an.';

/// Opens E1 from the front door and mails a code to [address] (E1 → E2).
Future<ProviderContainer> _toCodeScreen(
  WidgetTester t,
  FakeIdentityRepository identity, {
  String address = 'thomas@example.org',
}) async {
  final container = await pumpApp(
    t,
    overrides: baseOverrides(identity: identity, signedIn: false),
  );
  await t.tap(find.text('Mit E-Mail fortfahren'));
  await t.pump();
  await t.pump();
  await t.enterText(find.byType(TextField), address);
  await t.tap(find.text('Weiter'));
  await t.pump();
  await t.pump();
  return container;
}

/// What the hidden field holds: the digits the boxes show.
String _typed(WidgetTester t) => t
    .widget<TextField>(find.byKey(const ValueKey('email-code-field')))
    .controller!
    .text;

void main() {
  group('the rules', () {
    test('a password is rated by length first, then character classes', () {
      expect(ratePassword(''), PasswordStrength.tooShort);
      expect(ratePassword('Abcdefgh1'), PasswordStrength.tooShort);
      expect(ratePassword('abcdefghij'), PasswordStrength.weak);
      expect(ratePassword('Abcdefghij1'), PasswordStrength.fair);
      expect(ratePassword('Ein-gutes-Passwort-42'), PasswordStrength.strong);
    });

    test('E3 is owed to a young account without the marker only', () {
      final now = DateTime.utc(2026, 10, 15, 12);
      bool owed({String? created, Map<String, dynamic>? meta}) =>
          isFirstCodeSignIn(
            createdAt:
                created ??
                now.subtract(const Duration(minutes: 1)).toIso8601String(),
            userMetadata: meta,
            now: now,
          );

      expect(owed(), isTrue);
      expect(owed(meta: {signInChoiceKey: 'code'}), isFalse);
      expect(
        owed(
          created: now.subtract(const Duration(minutes: 30)).toIso8601String(),
        ),
        isFalse,
      );
      expect(owed(created: 'not a date'), isFalse);
      expect(owed(meta: {'other': true}), isTrue);
    });
  });

  group('E1 — the address', () {
    testWidgets('a code goes to any address the same way', (t) async {
      for (final address in ['thomas@example.org', 'niemand@example.org']) {
        final identity = FakeIdentityRepository();
        await _toCodeScreen(t, identity, address: address);
        expect(find.text(_codeTitle), findsOneWidget);
        expect(identity.codeRequests, [address]);
        expect(find.textContaining('stimmt nicht'), findsNothing);
      }
    });

    testWidgets(
      'a wrong password says so without saying which, and offers a code',
      (t) async {
        final identity = FakeIdentityRepository();
        await pumpApp(
          t,
          overrides: baseOverrides(identity: identity, signedIn: false),
        );
        await t.tap(find.text('Mit E-Mail fortfahren'));
        await t.pump();
        await t.pump();
        await t.enterText(find.byType(TextField), 'thomas@example.org');
        await t.tap(find.text('Ich habe ein Passwort'));
        await t.pump();
        await t.enterText(find.byType(TextField).at(1), 'falsch');
        await t.tap(find.text('Anmelden'));
        await t.pump();
        await t.pump();

        expect(identity.signIns, [('thomas@example.org', 'falsch')]);
        expect(find.text('E-Mail oder Passwort stimmt nicht.'), findsOneWidget);

        await t.tap(find.text('Stattdessen Code per E-Mail'));
        await t.pump();
        await t.pump();
        expect(identity.codeRequests, ['thomas@example.org']);
        expect(find.text(_codeTitle), findsOneWidget);
      },
    );

    testWidgets('offline, the address cannot be sent', (t) async {
      final identity = FakeIdentityRepository();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          signedIn: false,
          online: false,
        ),
      );
      container.read(routerProvider).go(Routes.signIn);
      await t.pump();
      await t.pump();
      expect(
        find.text(
          'Keine Verbindung – die Anmeldung per E-Mail braucht eine Verbindung.',
        ),
        findsOneWidget,
      );
      final button = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Weiter'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('E2 — the code', () {
    testWidgets('a pasted or typed sixth digit submits itself, once', (
      t,
    ) async {
      final identity = FakeIdentityRepository();
      await _toCodeScreen(t, identity);

      await t.enterText(
        find.byKey(const ValueKey('email-code-field')),
        '12345',
      );
      await t.pump();
      expect(identity.codeChecks, isEmpty);

      await t.enterText(
        find.byKey(const ValueKey('email-code-field')),
        '123456',
      );
      await t.pump();
      await t.pump();
      expect(identity.codeChecks, ['123456']);
    });

    testWidgets('a wrong code explains itself and clears the boxes', (t) async {
      final identity = FakeIdentityRepository()
        ..verifyFor = (_) => const Err(AuthFailure(code: 'otp_expired'));
      await _toCodeScreen(t, identity);

      await t.enterText(
        find.byKey(const ValueKey('email-code-field')),
        '000000',
      );
      await t.pump();
      await t.pump();
      expect(find.text(_wrongCode), findsOneWidget);
      expect(_typed(t), '');
    });

    testWidgets(
      'resend waits 60 s, then offers the spam hint and the way out',
      (t) async {
        final identity = FakeIdentityRepository();
        await _toCodeScreen(t, identity);

        expect(find.text('Kein Code? Erneut senden (in 60 s)'), findsOneWidget);
        await t.pump(const Duration(seconds: 1));
        expect(find.text('Kein Code? Erneut senden (in 59 s)'), findsOneWidget);
        expect(find.text('Schau im Spam-Ordner nach.'), findsNothing);

        await t.pump(const Duration(seconds: 59));
        expect(find.text('Kein Code? Erneut senden'), findsOneWidget);
        expect(find.text('Schau im Spam-Ordner nach.'), findsOneWidget);
        expect(find.text('Andere Methode wählen'), findsOneWidget);

        await t.tap(find.text('Kein Code? Erneut senden'));
        await t.pump();
        await t.pump();
        expect(identity.codeRequests, hasLength(2));
        expect(find.text('Kein Code? Erneut senden (in 60 s)'), findsOneWidget);
      },
    );

    testWidgets('a new account owes E3, an existing one does not', (t) async {
      final identity = FakeIdentityRepository()..verifyResult = const Ok(true);
      final container = await _toCodeScreen(t, identity);
      await t.enterText(
        find.byKey(const ValueKey('email-code-field')),
        '123456',
      );
      await t.pump();
      await t.pump();
      expect(container.read(signInChoiceOwedProvider), isTrue);
    });

    testWidgets('an existing account goes on without E3', (t) async {
      final identity = FakeIdentityRepository();
      final container = await _toCodeScreen(t, identity);
      await t.enterText(
        find.byKey(const ValueKey('email-code-field')),
        '123456',
      );
      await t.pump();
      await t.pump();
      expect(container.read(signInChoiceOwedProvider), isFalse);
      expect(find.text(_choiceTitle), findsNothing);
    });
  });

  group('E3 — how to sign in next time', () {
    Future<ProviderContainer> pumpNewAccount(
      WidgetTester t,
      FakeIdentityRepository identity,
    ) async {
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          household: FakeHouseholdOnboardingRepository(
            accountValue: const Account(
              userId: 'user-1',
              hasHousehold: false,
              creation: HouseholdCreation.open,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Neue Familie'), findsOneWidget);
      container.read(signInChoiceOwedProvider.notifier).owe();
      await t.pumpAndSettle();
      return container;
    }

    testWidgets(
      'comes once, before the household steps, with the code as default',
      (t) async {
        final identity = FakeIdentityRepository();
        final container = await pumpNewAccount(t, identity);

        expect(find.text(_choiceTitle), findsOneWidget);
        expect(find.text('Neue Familie'), findsNothing);
        expect(find.text('Zurück'), findsNothing);

        await t.tap(find.text('Weiter'));
        await t.pumpAndSettle();
        expect(identity.choices, ['code']);
        expect(container.read(signInChoiceOwedProvider), isFalse);
        expect(find.text('Neue Familie'), findsOneWidget);
        expect(find.text(_choiceTitle), findsNothing);
      },
    );

    testWidgets('a password must have at least 10 characters', (t) async {
      final identity = FakeIdentityRepository();
      await pumpNewAccount(t, identity);

      await t.tap(find.text('Mit Passwort'));
      await t.pump();
      await t.enterText(find.byType(TextField), 'kurz');
      await t.pump();
      expect(find.text('Noch zu kurz'), findsOneWidget);
      await t.tap(find.text('Weiter'));
      await t.pump();
      expect(
        find.text('Das Passwort braucht mindestens 10 Zeichen.'),
        findsOneWidget,
      );
      expect(identity.passwordsSet, isEmpty);

      await t.enterText(find.byType(TextField), 'Ein-gutes-Passwort-42');
      await t.pump();
      expect(find.text('Stark'), findsOneWidget);
      await t.tap(find.text('Weiter'));
      await t.pumpAndSettle();
      expect(identity.passwordsSet, ['Ein-gutes-Passwort-42']);
      expect(identity.choices, ['password']);
    });
  });

  group('Settings — the password', () {
    testWidgets('sets a password, then offers to change it', (t) async {
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

      expect(find.text('daniel@example.org — immer verfügbar'), findsOneWidget);
      await t.ensureVisible(find.text('Passwort festlegen'));
      await t.tap(find.text('Passwort festlegen'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'zu kurz');
      await t.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await t.pump();
      expect(identity.passwordsSet, isEmpty);

      await t.enterText(find.byType(TextField), 'Ein-gutes-Passwort-42');
      await t.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await t.pumpAndSettle();
      expect(identity.passwordsSet, ['Ein-gutes-Passwort-42']);
      expect(find.text('Passwort ändern'), findsOneWidget);
    });
  });
}
