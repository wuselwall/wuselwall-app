import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
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

  Finder groupTile(SettingsGroup g) =>
      find.byKey(ValueKey('settings-group-${g.name}'));

  group('Einstellungen', () {
    testWidgets('Android Back returns to the home tab that opened settings', (
      t,
    ) async {
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      container.read(homeTabProvider.notifier).select(HomeTab.shopping);
      await t.pumpAndSettle();

      await t.tap(find.byTooltip(_de.settingsTitle));
      await t.pumpAndSettle();
      expect(groupTile(SettingsGroup.family), findsOneWidget);

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();

      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        Routes.home,
      );
      expect(container.read(homeTabProvider), HomeTab.shopping);
      expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        5,
      );
    });

    testWidgets('Android Back from directly opened settings falls back home', (
      t,
    ) async {
      final container = await open(
        t,
        Routes.settings,
        store: MemorySettingsViewStore(),
      );

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();

      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        Routes.home,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Back from a group page leads to the list of groups', (
      t,
    ) async {
      final container = await open(
        t,
        Routes.settingsTasks,
        store: MemorySettingsViewStore(),
      );
      expect(find.text(_de.settingsGroupTasksTitle), findsOneWidget);

      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();

      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        Routes.settings,
      );
      expect(groupTile(SettingsGroup.tasks), findsOneWidget);
    });

    testWidgets('Basic lists the groups a family needs and says more exists', (
      t,
    ) async {
      await open(t, Routes.settings, store: MemorySettingsViewStore());

      expect(find.byKey(const ValueKey('settings-view')), findsOneWidget);
      for (final group in const [
        SettingsGroup.personal,
        SettingsGroup.family,
        SettingsGroup.tasks,
        SettingsGroup.calendar,
        SettingsGroup.meals,
        SettingsGroup.rituals,
        SettingsGroup.celebrations,
        SettingsGroup.devices,
        // Account deletion stays easy to find (App Store guideline 5.1.1(v)).
        SettingsGroup.account,
        SettingsGroup.help,
      ]) {
        expect(groupTile(group), findsOneWidget, reason: group.name);
      }
      // These hold Advanced settings only.
      for (final group in const [SettingsGroup.kitchen, SettingsGroup.server]) {
        expect(groupTile(group), findsNothing, reason: group.name);
      }
      await t.scrollUntilVisible(
        find.text(_de.settingsViewMoreHint),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_de.settingsViewMoreHint), findsOneWidget);
    });

    testWidgets('Basic shows all of Konto, as its subtitle promises', (
      t,
    ) async {
      await open(t, Routes.settingsAccount, store: MemorySettingsViewStore());

      expect(find.text(_de.signInMethodsTitle), findsOneWidget);
      expect(find.text(_de.settingsSecurity), findsOneWidget);
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('delete-account')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('delete-account')), findsOneWidget);
      // Nothing is hidden here, so there is no hint either.
      expect(find.text(_de.settingsViewMoreHint), findsNothing);
    });

    testWidgets('Basic subtitles name only what Basic shows', (t) async {
      await open(t, Routes.settings, store: MemorySettingsViewStore());
      expect(find.text(_de.settingsGroupTasksSubtitleBasic), findsOneWidget);
      expect(find.text(_de.settingsGroupTasksSubtitle), findsNothing);

      await t.tap(find.text(_de.settingsViewAdvanced));
      await t.pumpAndSettle();
      expect(find.text(_de.settingsGroupTasksSubtitle), findsOneWidget);
      expect(find.text(_de.settingsGroupTasksSubtitleBasic), findsNothing);
    });

    testWidgets('Basic hides the sharing and the export, Advanced shows them', (
      t,
    ) async {
      final store = MemorySettingsViewStore();
      await open(t, Routes.settingsCalendar, store: store);
      expect(find.text(_de.feedTitle), findsNothing);
      expect(find.text(_de.extCalTitle), findsNothing);
      expect(find.text(_de.settingsViewMoreHint), findsOneWidget);

      await t.tap(find.text(_de.settingsViewAdvanced));
      await t.pumpAndSettle();

      expect(store.view, SettingsView.advanced);
      expect(find.text(_de.feedTitle), findsOneWidget);
      expect(find.text(_de.extCalTitle), findsOneWidget);
      expect(find.text(_de.settingsViewMoreHint), findsNothing);
    });

    testWidgets('Advanced lists every group and is kept for the next start', (
      t,
    ) async {
      final store = MemorySettingsViewStore();
      await open(t, Routes.settings, store: store);

      await t.tap(find.text(_de.settingsViewAdvanced));
      await t.pumpAndSettle();

      expect(store.view, SettingsView.advanced);
      for (final group in SettingsGroup.values) {
        // The server group only exists for a build that chose its server.
        if (group == SettingsGroup.server) continue;
        expect(groupTile(group), findsOneWidget, reason: group.name);
      }
      expect(find.text(_de.settingsViewMoreHint), findsNothing);
    });

    testWidgets('a saved Advanced applies at start', (t) async {
      await open(
        t,
        Routes.settingsCalendar,
        store: MemorySettingsViewStore(SettingsView.advanced),
      );
      expect(find.text(_de.feedTitle), findsOneWidget);
    });

    testWidgets('the old Haushalt einstellen address opens the groups', (
      t,
    ) async {
      final container = await open(
        t,
        Routes.householdSettings,
        store: MemorySettingsViewStore(),
      );
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        Routes.settings,
      );
      expect(groupTile(SettingsGroup.tasks), findsOneWidget);
    });
  });

  group('Gruppenseiten', () {
    final verification = find.byKey(
      const ValueKey('setting-tasks.verification_default'),
    );
    final jokers = find.byKey(const ValueKey('setting-tasks.jokers_per_month'));

    testWidgets('the licenses page opens from Basic, with the project notice', (
      t,
    ) async {
      await open(t, Routes.settingsHelp, store: MemorySettingsViewStore());

      await t.tap(find.text(_de.settingsLicenses));
      await t.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('WuselWall'), findsWidgets);
      expect(
        find.textContaining('Apache License, Version 2.0'),
        findsOneWidget,
      );
    });

    testWidgets('Basic shows the main settings of a group only', (t) async {
      await open(t, Routes.settingsTasks, store: MemorySettingsViewStore());

      expect(jokers, findsOneWidget);
      expect(verification, findsNothing);
      expect(find.byKey(const ValueKey('settings-more-hint')), findsOneWidget);
    });

    testWidgets('Basic shows the region in the Family group', (t) async {
      await open(t, Routes.settingsFamily, store: MemorySettingsViewStore());

      expect(
        find.byKey(const ValueKey('setting-household.region')),
        findsOneWidget,
      );
    });

    testWidgets('the chip is the one way to Advanced; the hint names it', (
      t,
    ) async {
      final store = MemorySettingsViewStore();
      await open(t, Routes.settingsTasks, store: store);

      final hint = find.byKey(const ValueKey('settings-more-hint'));
      expect(hint, findsOneWidget);
      // One line of text, no second switch beside the chip.
      expect(
        find.descendant(of: hint, matching: find.byType(ButtonStyleButton)),
        findsNothing,
      );

      await t.tap(find.byKey(const ValueKey('settings-view')));
      await t.pumpAndSettle();

      expect(store.view, SettingsView.advanced);
      expect(verification, findsOneWidget);
      expect(hint, findsNothing);
    });
  });
}
