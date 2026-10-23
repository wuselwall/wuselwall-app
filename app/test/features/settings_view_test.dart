import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';

import '../support/fakes.dart';

final _de = lookupAppLocalizations(const Locale('de'));

void main() {
  group('SecureSettingsViewStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('is Basic until a choice is saved', () async {
      final store = SecureSettingsViewStore();
      expect(await store.read(), SettingsView.basic);
      await store.write(SettingsView.advanced);
      expect(await SecureSettingsViewStore().read(), SettingsView.advanced);
    });

    test('an unknown stored value falls back to Basic', () async {
      FlutterSecureStorage.setMockInitialValues({
        'wuselwall.settings.view': 'expert',
      });
      expect(await SecureSettingsViewStore().read(), SettingsView.basic);
    });
  });

  Future<ProviderContainer> open(
    WidgetTester t,
    String route, {
    required SettingsViewStore store,
  }) async {
    final container = await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          settingsViewStore: store,
        ),
        householdSettingsRepositoryProvider.overrideWithValue(
          DemoHouseholdSettingsRepository(),
        ),
      ],
    );
    container.read(routerProvider).go(route);
    await t.pumpAndSettle();
    return container;
  }

  group('Einstellungen', () {
    testWidgets('Basic hides the advanced rows and says they still apply', (
      t,
    ) async {
      await open(t, Routes.settings, store: MemorySettingsViewStore());

      expect(find.byKey(const ValueKey('settings-view')), findsOneWidget);
      expect(find.text(_de.householdSettingsTitle), findsOneWidget);
      expect(find.text(_de.settingsMembers), findsOneWidget);
      expect(find.text(_de.feedTitle), findsNothing);
      expect(find.text(_de.extCalTitle), findsNothing);
      expect(find.text(_de.settingsSecurity), findsNothing);
      expect(find.byKey(const ValueKey('export-data')), findsNothing);
      expect(find.byKey(const ValueKey('leave-family')), findsNothing);
      // Account deletion stays easy to find (App Store guideline 5.1.1(v)).
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('delete-account')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.scrollUntilVisible(
        find.text(_de.settingsViewMoreHint),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_de.settingsViewMoreHint), findsOneWidget);
    });

    testWidgets('Advanced shows everything and is kept for the next start', (
      t,
    ) async {
      final store = MemorySettingsViewStore();
      await open(t, Routes.settings, store: store);

      await t.tap(find.text(_de.settingsViewAdvanced));
      await t.pumpAndSettle();

      expect(store.view, SettingsView.advanced);
      // The export lives on the family page now; the page itself is in both views.
      expect(find.byKey(const ValueKey('settings-family')), findsOneWidget);
      await t.scrollUntilVisible(
        find.text(_de.feedTitle),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_de.feedTitle), findsOneWidget);
      expect(find.text(_de.extCalTitle), findsOneWidget);
      await t.scrollUntilVisible(
        find.text(_de.settingsSecurity),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_de.settingsViewMoreHint), findsNothing);
    });

    testWidgets('a saved Advanced applies at start', (t) async {
      await open(
        t,
        Routes.settings,
        store: MemorySettingsViewStore(SettingsView.advanced),
      );
      expect(find.text(_de.feedTitle), findsOneWidget);
    });
  });

  group('Haushalt einstellen', () {
    final kitchen = find.text(_de.settingsSectionKitchen);
    final verification = find.byKey(
      const ValueKey('setting-tasks.verification_default'),
    );

    testWidgets('Basic shows the main settings only', (t) async {
      await open(t, Routes.householdSettings, store: MemorySettingsViewStore());

      expect(
        find.byKey(const ValueKey('setting-household.region')),
        findsOneWidget,
      );
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('settings-show-all')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(kitchen, findsNothing);
      expect(verification, findsNothing);
    });

    testWidgets('"Show all settings" switches to Advanced', (t) async {
      final store = MemorySettingsViewStore();
      await open(t, Routes.householdSettings, store: store);

      final showAll = find.byKey(const ValueKey('settings-show-all'));
      await t.scrollUntilVisible(
        showAll,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(showAll);
      await t.pumpAndSettle();

      expect(store.view, SettingsView.advanced);
      await t.scrollUntilVisible(
        kitchen,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(kitchen, findsOneWidget);
      expect(showAll, findsNothing);
    });
  });
}
