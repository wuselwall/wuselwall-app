import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';

import '../support/fakes.dart';

void main() {
  group('the setup screen', () {
    testWidgets('offers email, in German, and no provider buttons', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          signedIn: false,
        ),
      );
      expect(find.text('Mit E-Mail fortfahren'), findsOneWidget);
      expect(find.text('oder'), findsOneWidget);
      expect(find.textContaining('Apple'), findsNothing);
      expect(find.textContaining('Google'), findsNothing);
    });

    testWidgets(
      'explains offline access and exposes it to assistive technology',
      (t) async {
        await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(),
            signedIn: false,
            online: false,
          ),
        );

        expect(
          find.textContaining(
            'Du bist offline. Verbinde dich mit dem Internet',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.container &&
                widget.properties.liveRegion == true,
          ),
          findsOneWidget,
        );
        expect(
          t
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Mit E-Mail fortfahren'),
              )
              .onPressed,
          isNull,
        );
      },
    );
  });

  group('email sign-in validation', () {
    testWidgets('does not send an empty or malformed address', (t) async {
      final identity = FakeIdentityRepository();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(identity: identity, signedIn: false),
      );
      container.read(routerProvider).go(Routes.signIn);
      await t.pumpAndSettle();

      await t.tap(find.text('Weiter'));
      await t.pumpAndSettle();
      expect(find.text('Gib deine E-Mail-Adresse ein.'), findsOneWidget);
      expect(identity.codeRequests, isEmpty);

      await t.enterText(find.byType(TextFormField).first, 'kein-email');
      await t.tap(find.text('Weiter'));
      await t.pumpAndSettle();
      expect(find.text('Gib eine gültige E-Mail-Adresse ein.'), findsOneWidget);
      expect(identity.codeRequests, isEmpty);
    });

    testWidgets('requires a password and trims a valid email before sign-in', (
      t,
    ) async {
      final identity = FakeIdentityRepository();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(identity: identity, signedIn: false),
      );
      container.read(routerProvider).go(Routes.signIn);
      await t.pumpAndSettle();
      await t.enterText(
        find.byType(TextFormField).first,
        ' daniel@example.org ',
      );
      await t.tap(find.text('Ich habe ein Passwort'));
      await t.pumpAndSettle();

      await t.tap(find.text('Anmelden'));
      await t.pumpAndSettle();
      expect(find.text('Gib dein Passwort ein.'), findsOneWidget);
      expect(identity.signIns, isEmpty);

      await t.enterText(find.byType(TextFormField).last, 'secret');
      await t.tap(find.text('Anmelden'));
      await t.pumpAndSettle();
      expect(identity.signIns, [('daniel@example.org', 'secret')]);

      await t.tap(find.text('Stattdessen Code per E-Mail'));
      await t.pumpAndSettle();
      expect(identity.codeRequests, ['daniel@example.org']);
    });

    testWidgets('email-code fallback works with a blank password', (t) async {
      final identity = FakeIdentityRepository();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(identity: identity, signedIn: false),
      );
      final router = container.read(routerProvider);
      router.go(Routes.signIn);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'daniel@example.org');
      await t.tap(find.text('Ich habe ein Passwort'));
      await t.pumpAndSettle();

      // Show the required-password error first, then use the email-code fallback.
      await t.tap(find.text('Anmelden'));
      await t.pumpAndSettle();
      expect(find.text('Gib dein Passwort ein.'), findsOneWidget);

      await t.tap(find.text('Stattdessen Code per E-Mail'));
      await t.pumpAndSettle();
      expect(identity.codeRequests, ['daniel@example.org']);
      expect(find.text('Code aus der E-Mail'), findsOneWidget);
    });

    testWidgets('offline sign-in shows no in-progress status', (t) async {
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          signedIn: false,
          online: false,
        ),
      );
      container.read(routerProvider).go(Routes.signIn);
      await t.pumpAndSettle();

      expect(find.textContaining('Keine Verbindung'), findsOneWidget);
      expect(find.text('Code wird gesendet …'), findsNothing);
      expect(find.text('Anmeldung läuft …'), findsNothing);
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('ignores repeat taps and keyboard submissions while sending', (
      t,
    ) async {
      final identity = _DelayedEmailIdentity();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(identity: identity, signedIn: false),
      );
      container.read(routerProvider).go(Routes.signIn);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, 'daniel@example.org');

      await t.tap(find.text('Weiter'));
      await t.pump();
      expect(find.text('Code wird gesendet …'), findsOneWidget);
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pump();
      expect(identity.codeRequests, ['daniel@example.org']);

      identity.complete.complete(const Ok(null));
      await t.pumpAndSettle();
    });
  });

  group('settings → sign-in', () {
    testWidgets('shows the email code and the password', (t) async {
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
      await openSettingsGroup(t, SettingsGroup.account);

      expect(find.text('Anmeldung'), findsOneWidget);
      expect(find.text('daniel@example.org — immer verfügbar'), findsOneWidget);
      expect(find.text('Passwort festlegen'), findsOneWidget);
      expect(find.text('Verbinden'), findsNothing);
    });
  });
}

class _DelayedEmailIdentity extends FakeIdentityRepository {
  final complete = Completer<Result<void>>();

  @override
  Future<Result<void>> sendEmailCode(String email, {required String locale}) {
    codeRequests.add(email);
    return complete.future;
  }
}
