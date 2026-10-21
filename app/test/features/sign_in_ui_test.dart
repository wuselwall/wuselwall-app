import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

      expect(find.text('Anmeldung'), findsOneWidget);
      expect(find.text('daniel@example.org — immer verfügbar'), findsOneWidget);
      expect(find.text('Passwort festlegen'), findsOneWidget);
      expect(find.text('Verbinden'), findsNothing);
    });
  });
}
