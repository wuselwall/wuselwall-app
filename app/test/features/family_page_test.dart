import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';

import '../support/fakes.dart';

final _de = lookupAppLocalizations(const Locale('de'));

/// Step 10.2: the family's name, and under Advanced its time zone, can be corrected.
void main() {
  Future<FakeIdentityRepository> openFamily(
    WidgetTester t, {
    SettingsView view = SettingsView.basic,
  }) async {
    final identity = FakeIdentityRepository(current: device());
    final container = await pumpApp(
      t,
      overrides: baseOverrides(identity: identity, settingsView: view),
    );
    container.read(routerProvider).go(Routes.settings);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('settings-family')));
    await t.pumpAndSettle();
    return identity;
  }

  testWidgets('Basic renames the family and hides the rest', (t) async {
    final identity = await openFamily(t);
    expect(find.text('Familie Test'), findsOneWidget);
    expect(find.byKey(const ValueKey('family-timezone')), findsNothing);
    expect(find.byKey(const ValueKey('export-data')), findsNothing);

    await t.enterText(find.byKey(const ValueKey('family-name')), 'Familie Neu');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('family-save-name')));
    await t.pumpAndSettle();

    expect(identity.householdUpdates.single.name, 'Familie Neu');
    expect(find.text(_de.savedMessage), findsOneWidget);
  });

  testWidgets('Advanced moves the time zone through a searchable list', (
    t,
  ) async {
    final identity = await openFamily(t, view: SettingsView.advanced);
    expect(find.textContaining('Europe/Berlin'), findsOneWidget);
    expect(find.byKey(const ValueKey('export-data')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('family-timezone')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('timezone-search')), 'zurich');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('timezone-Europe/Zurich')));
    await t.pumpAndSettle();

    expect(identity.householdUpdates.single.timezone, 'Europe/Zurich');
    expect(find.textContaining('Europe/Zurich'), findsOneWidget);
  });
}
