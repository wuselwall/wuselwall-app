// Social sign-in (Apple, Google) is gone: the front door and Settings offer e-mail (a
// code or a password) only, and the app never takes a session from a link.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/supabase_bootstrap.dart';

import '../support/fakes.dart';

/// What a social sign-in affordance would say, in either language.
final _social = RegExp(
  r'(with|mit) (Apple|Google)|(Apple|Google)[- ](account|Konto)',
  caseSensitive: false,
);

void _expectNoSocialSignIn() {
  expect(find.byIcon(Icons.apple), findsNothing);
  expect(find.textContaining(_social), findsNothing);
  expect(find.text('Apple'), findsNothing);
  expect(find.text('Google'), findsNothing);
  expect(
    find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('sign_in'),
    ),
    findsNothing,
  );
}

void main() {
  group('the front door', () {
    for (final locale in const [Locale('de'), Locale('en')]) {
      testWidgets('offers email and no social sign-in ($locale)', (t) async {
        await pumpApp(
          t,
          locale: locale,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(),
            signedIn: false,
          ),
        );
        _expectNoSocialSignIn();
        expect(
          find.text(
            locale.languageCode == 'de'
                ? 'Mit E-Mail fortfahren'
                : 'Continue with email',
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('signs in with an email code', (t) async {
      final identity = FakeIdentityRepository();
      await pumpApp(
        t,
        overrides: baseOverrides(identity: identity, signedIn: false),
      );
      await t.tap(find.text('Mit E-Mail fortfahren'));
      await t.pump();
      await t.pump();
      _expectNoSocialSignIn();
      await t.enterText(find.byType(TextField), 'lukas@example.org');
      await t.tap(find.text('Weiter'));
      await t.pump();
      await t.pump();
      expect(identity.codeRequests, ['lukas@example.org']);
    });

    testWidgets('explains an address without an account', (t) async {
      final identity = FakeIdentityRepository()
        ..sendCodeResult = const Err(AuthFailure(code: 'signup_disabled'));
      await pumpApp(
        t,
        locale: const Locale('en'),
        overrides: baseOverrides(identity: identity, signedIn: false),
      );
      await t.tap(find.text('Continue with email'));
      await t.pump();
      await t.pump();
      await t.enterText(find.byType(TextField), 'new@example.org');
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('There is no WuselWall account for this address'),
        findsOneWidget,
      );
      expect(find.textContaining(_social), findsNothing);
    });
  });

  group('settings → sign-in', () {
    testWidgets('shows the email code and the password, nothing to connect', (
      t,
    ) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          shopping: FakeShoppingRepository([]),
        ),
      );
      await t.tap(find.byIcon(Icons.settings));
      await t.pumpAndSettle();

      expect(find.text('Anmeldung'), findsOneWidget);
      expect(find.text('E-Mail-Code'), findsOneWidget);
      expect(find.text('papa@example.org — immer verfügbar'), findsOneWidget);
      expect(find.text('Passwort festlegen'), findsOneWidget);
      expect(find.text('Verbinden'), findsNothing);
      expect(find.text('Entfernen'), findsNothing);
      _expectNoSocialSignIn();
    });
  });

  group('old social sign-in links', () {
    test('the client never takes a session from a link', () {
      final options = authClientOptions(const EmptyLocalStorage());
      expect(options.detectSessionInUri, isFalse);
    });
  });

  group('the build carries nothing for social sign-in', () {
    String read(String path) => File(path).readAsStringSync();

    test('no social sign-in packages or assets', () {
      final pubspec = read('pubspec.yaml');
      for (final p in ['google_sign_in', 'sign_in_with_apple', 'sign_in/']) {
        expect(pubspec, isNot(contains(p)), reason: p);
      }
      expect(Directory('assets/sign_in').existsSync(), isFalse);
    });

    test('no client IDs or switches in the env files', () {
      for (final f in Directory('env').listSync().whereType<File>()) {
        final env = f.readAsStringSync();
        for (final key in [
          'APPLE_SIGN_IN',
          'GOOGLE_WEB_CLIENT_ID',
          'GOOGLE_IOS_CLIENT_ID',
          'googleusercontent',
        ]) {
          expect(env, isNot(contains(key)), reason: '${f.path}: $key');
        }
      }
    });

    test('no callback scheme or Apple sign-in capability on the platforms', () {
      expect(
        read('ios/Runner/Info.plist'),
        isNot(contains('CFBundleURLTypes')),
      );
      expect(
        read('ios/Runner/Runner.entitlements'),
        isNot(contains('applesignin')),
      );
      expect(File('ios/Flutter/SignIn.xcconfig').existsSync(), isFalse);
      expect(
        read('android/app/src/main/AndroidManifest.xml'),
        isNot(contains('login-callback')),
      );
    });

    test('no social sign-in text in either language', () {
      for (final arb in ['l10n/app_en.arb', 'l10n/app_de.arb']) {
        expect(read(arb), isNot(matches(_social)), reason: arb);
      }
    });
  });
}
