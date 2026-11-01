import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/core/server/setup_link.dart';
import 'package:wuselwall/core/server/setup_store.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';

import '../support/fakes.dart';

// S1 "Server einrichten" (specs/20 "Claiming the server"): the setup key announces the
// founder's address before sign-up; the server lets only that address sign up.
void main() {
  const token = '0123456789abcdef01234567';
  final server = Uri.parse('http://localhost');
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  /// The app on a server whose discovery document says whether a family exists.
  AppConfig serverConfig({required bool claimed, bool emailCode = true}) =>
      AppConfig.forServer(
        const AppConfig(
          environment: 'test',
          supabaseUrl: 'http://localhost',
          supabasePublishableKey: 'key',
        ),
        ServerInfo(
          supabaseUrl: server,
          publishableKey: 'sb_publishable_abc',
          apiVersion: 1,
          minAppVersion: '1.0.0',
          emailCode: emailCode,
          claimed: claimed,
        ),
      );

  testWidgets('a setup link lands on the claim: the key is checked, the address announced, '
      'the code sent', (t) async {
    final store = SetupStore();
    await store.save(SetupLink(server, token));
    final identity = FakeIdentityRepository();
    final household = FakeHouseholdOnboardingRepository();
    final container = await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          setupStore: store,
          identity: identity,
          household: household,
          signedIn: false,
        ),
        serverSessionProvider.overrideWithValue(ServerSession(hasSetup: true)),
      ],
    );
    final router = container.read(routerProvider);
    expect(router.routeInformationProvider.value.uri.path, Routes.claim);
    expect(find.text('Server einrichten'), findsOneWidget);
    // The key was checked at once, without an address, and is never shown or typed.
    expect(household.claims, [(key: token, email: null)]);
    expect(find.textContaining('angenommen'), findsOneWidget);
    expect(find.text(token), findsNothing);
    expect(find.byKey(const ValueKey('claim-key')), findsNothing);

    await t.enterText(
      find.byKey(const ValueKey('claim-email')),
      'daniel@example.org',
    );
    await t.tap(find.byKey(const ValueKey('claim-continue')));
    await t.pumpAndSettle();
    expect(household.claims.last, (key: token, email: 'daniel@example.org'));
    expect(identity.codeRequests, ['daniel@example.org']);
    expect(find.text('Code aus der E-Mail'), findsOneWidget);
    expect(
      find.textContaining('localhost wird eingerichtet'),
      findsOneWidget,
      reason: 'E2 names the server being set up',
    );
    expect(
      await store.read(server),
      token,
      reason: 'the key stays for Neue Familie',
    );
  });

  testWidgets('a used key says so and opens the field for another one', (
    t,
  ) async {
    final store = SetupStore();
    await store.save(SetupLink(server, token));
    final household = FakeHouseholdOnboardingRepository()
      ..claimResult = const Ok(ClaimRefused('key_used'));
    await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          setupStore: store,
          identity: FakeIdentityRepository(),
          household: household,
          signedIn: false,
        ),
        serverSessionProvider.overrideWithValue(ServerSession(hasSetup: true)),
      ],
    );
    expect(find.textContaining('schon verwendet'), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-key')), findsOneWidget);
    expect(find.text('Ich habe schon ein Konto'), findsOneWidget);
  });

  testWidgets(
    'on a server without a family the front door leads to the claim, where the key is typed',
    (t) async {
      final identity = FakeIdentityRepository();
      final household = FakeHouseholdOnboardingRepository();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          household: household,
          signedIn: false,
          appConfig: serverConfig(claimed: false, emailCode: false),
        ),
      );
      expect(find.text('Dieser Server hat noch keine Familie'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('door-claim')));
      await t.pumpAndSettle();
      expect(find.text('Server einrichten'), findsOneWidget);
      // Nothing stored: nothing checked, the key is typed next to the address.
      expect(household.claims, isEmpty);
      await t.enterText(
        find.byKey(const ValueKey('claim-key')),
        'Cake-On-Sunday',
      );
      await t.enterText(
        find.byKey(const ValueKey('claim-email')),
        'mama@example.org',
      );
      await t.tap(find.byKey(const ValueKey('claim-continue')));
      await t.pumpAndSettle();
      expect(household.claims, [
        (key: 'Cake-On-Sunday', email: 'mama@example.org'),
      ]);
      // A server without mail: no code, the password page opens with the address.
      expect(identity.codeRequests, isEmpty);
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        Routes.signIn,
      );
      expect(find.text('mama@example.org'), findsOneWidget);
    },
  );

  testWidgets('a server with a family shows no claim on its front door', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        signedIn: false,
        appConfig: serverConfig(claimed: true),
      ),
    );
    expect(find.text('Dieser Server hat noch keine Familie'), findsNothing);
    expect(find.byKey(const ValueKey('door-claim')), findsNothing);
  });
}
