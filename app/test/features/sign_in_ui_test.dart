import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/domain/sign_in_method.dart';

import '../support/fakes.dart';

void main() {
  group('the setup screen', () {
    testWidgets('offers Apple and Google in the order given, in German', (
      t,
    ) async {
      final methods = FakeSignInMethods(
        offered: [SignInProvider.apple, SignInProvider.google],
      );
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          signInMethods: methods,
          signedIn: false,
        ),
      );

      final apple = t.getTopLeft(find.text('Mit Apple fortfahren'));
      final google = t.getTopLeft(find.text('Mit Google fortfahren'));
      expect(apple.dy, lessThan(google.dy));
      expect(find.text('oder'), findsOneWidget);

      await t.tap(find.text('Mit Google fortfahren'));
      await t.pumpAndSettle();
      expect(methods.signIns, [SignInProvider.google]);
    });

    testWidgets('shows no provider buttons where none is offered', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          signedIn: false,
        ),
      );
      expect(find.text('Mit Apple fortfahren'), findsNothing);
      expect(find.text('oder'), findsNothing);
    });

    testWidgets('explains an address without an account', (t) async {
      await pumpApp(
        t,
        locale: const Locale('en'),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          signInMethods: FakeSignInMethods(
            offered: [SignInProvider.google],
            signInResult: const Err(AuthFailure(code: 'signup_disabled')),
          ),
          signedIn: false,
        ),
      );
      await t.tap(find.text('Continue with Google'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('There is no WuselWall account for this address'),
        findsOneWidget,
      );
    });

    testWidgets('reports a failed redirect that comes back later', (t) async {
      final methods = FakeSignInMethods(offered: [SignInProvider.apple]);
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          signInMethods: methods,
          signedIn: false,
        ),
      );
      methods.redirectErrors.add(const AuthFailure(code: 'provider_failed'));
      await t.pumpAndSettle();
      expect(find.textContaining('Das hat nicht geklappt'), findsOneWidget);
    });
  });

  group('settings → sign-in', () {
    Future<FakeSignInMethods> pump(
      WidgetTester t, {
      List<SignInMethod>? linked,
    }) async {
      final methods = FakeSignInMethods(
        offered: [SignInProvider.google, SignInProvider.apple],
        linkable: {SignInProvider.google},
        linked:
            linked ??
            [
              const SignInMethod(
                identityId: 'identity-email',
                provider: SignInMethodKind.email,
                email: 'papa@example.org',
              ),
            ],
      );
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          shopping: FakeShoppingRepository([]),
          signInMethods: methods,
        ),
      );
      await t.tap(find.byIcon(Icons.settings));
      await t.pumpAndSettle();
      return methods;
    }

    testWidgets('connects Google with the native sheet', (t) async {
      final methods = await pump(t);
      expect(find.text('Anmeldung'), findsOneWidget);
      expect(find.text('papa@example.org'), findsOneWidget);
      // Apple has only the redirect on this platform, so it points elsewhere.
      expect(
        find.text('Verbinden geht in der App auf deinem Handy.'),
        findsOneWidget,
      );

      await t.ensureVisible(find.text('Verbinden'));
      await t.tap(find.text('Verbinden'));
      await t.pumpAndSettle();
      expect(methods.links, [SignInProvider.google]);
      expect(find.text('Google ist verbunden.'), findsOneWidget);
    });

    testWidgets('removes a method after confirmation, never the last one', (
      t,
    ) async {
      final methods = await pump(
        t,
        linked: [
          const SignInMethod(
            identityId: 'identity-email',
            provider: SignInMethodKind.email,
          ),
          const SignInMethod(
            identityId: 'identity-google',
            provider: SignInMethodKind.google,
          ),
        ],
      );
      // Email has no remove action here; Google has one.
      expect(find.text('Entfernen'), findsOneWidget);

      await t.ensureVisible(find.text('Entfernen'));
      await t.tap(find.text('Entfernen'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Entfernen'));
      await t.pumpAndSettle();
      expect(methods.unlinked, ['identity-google']);
    });
  });
}
