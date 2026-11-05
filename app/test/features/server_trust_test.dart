import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/config/app_config.dart';

import '../support/fakes.dart';

// Security review 2026-11-01: the server's host on every page that takes a code, a
// password or the setup key (F7), and no address in a location (F25).
void main() {
  const config = AppConfig(
    environment: 'test',
    supabaseUrl: 'https://api.example.org',
    supabasePublishableKey: 'key',
  );

  testWidgets('the front door and the credential pages name the server', (
    t,
  ) async {
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(),
        signedIn: false,
        appConfig: config,
      ),
    );
    expect(find.text('Server: api.example.org'), findsOneWidget);

    final router = container.read(routerProvider);
    for (final route in [
      Routes.signIn,
      Routes.passwordReset,
      Routes.claim,
      Routes.enrol,
    ]) {
      router.go(route);
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Server: api.example.org'),
        ),
        findsOneWidget,
        reason: route,
      );
    }
  });

  testWidgets('an address goes to the code page in state, not in the URL', (
    t,
  ) async {
    final identity = FakeIdentityRepository();
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: identity,
        signedIn: false,
        appConfig: config,
      ),
    );
    await t.tap(find.text('Anmelden oder Konto erstellen'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'lea@example.org');
    await t.tap(find.text('Code senden'));
    await t.pumpAndSettle();

    final router = container.read(routerProvider);
    expect(router.state.uri.path, Routes.emailCode);
    expect(router.state.uri.toString(), isNot(contains('example.org')));
    // What the browser would show and keep in its history.
    expect(
      router.routeInformationProvider.value.uri.toString(),
      isNot(contains('example.org')),
    );
    expect(find.textContaining('lea@example.org'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Server: api.example.org'),
      ),
      findsOneWidget,
    );
  });
}
