import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/ui/settings_view_switch.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

import '../support/fakes.dart';
import 'settings_groups_test.dart' show FakeHouseholdSettingsRepository;

/// Settings on a family tablet and on the kitchen wall (specs/09, "Settings on a shared
/// device"): who sees the gear, who may open what, and what happens when the acting
/// person goes away.
const _mamaId = 'p-mama';

/// An adult who is not a guardian.
const _mama = Member(
  id: _mamaId,
  displayName: 'Mama',
  color: Color(0xFF5C6BC0),
  role: Role.member,
  active: true,
);

/// The app of the running test: unmounted at its end, because the Personal page's Wusel
/// previews start the board's timers and Flutter checks for pending timers first.
ProviderContainer? _running;

void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    final container = _running;
    if (container != null) await unmountApp(tester, container);
    _running = null;
  });
}

final _en = lookupAppLocalizations(const Locale('en'));

String _path(ProviderContainer c) => c
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .last
    .matchedLocation;

Finder get _gear => find.byTooltip(_en.settingsTitle);

Finder _tile(SettingsGroup g) =>
    find.byKey(ValueKey('settings-group-${g.name}'));

Finder _setting(String key) => find.byKey(ValueKey('setting-$key'));

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required DeviceClass deviceClass,
  required UiRegister register,
  String? acting,
  SettingsView view = SettingsView.basic,
}) async {
  final container = await pumpApp(
    tester,
    locale: const Locale('en'),
    overrides: [
      ...baseOverrides(
        identity: FakeIdentityRepository(
          current: device(deviceClass: deviceClass, register: register),
          members: [...testMembers, _mama],
        ),
        settingsView: view,
      ),
      householdSettingsRepositoryProvider.overrideWithValue(
        FakeHouseholdSettingsRepository(demoSettingCatalogue()),
      ),
    ],
  );
  _running = container;
  if (acting != null) {
    container.read(actingProfileProvider.notifier).select(acting);
    await tester.pumpAndSettle();
  }
  return container;
}

Future<void> _go(
  WidgetTester tester,
  ProviderContainer container,
  String route,
) async {
  container.read(routerProvider).go(route);
  await tester.pumpAndSettle();
}

/// Only the three personal settings, nothing of the rest of Einstellungen.
void _expectOwnPageOnly(String name) {
  expect(find.text(_en.settingsOwnTitle(name)), findsOneWidget);
  expect(_setting('member.wusel'), findsOneWidget);
  expect(_setting('member.wusel_outfit'), findsOneWidget);
  expect(_setting('member.completion_sound'), findsOneWidget);
  expect(find.byType(SettingsViewSwitch), findsNothing);
  expect(find.text(_en.signOutDevice), findsNothing);
  expect(find.byKey(const ValueKey('settings-reminders')), findsNothing);
  expect(find.byKey(const ValueKey('settings-show-all')), findsNothing);
  for (final g in SettingsGroup.values) {
    expect(_tile(g), findsNothing, reason: g.name);
  }
  // Nothing outside the member's own scope: no household, board or device rows.
  expect(_setting('tasks.jokers_per_month'), findsNothing);
  expect(_setting('device.sky'), findsNothing);
  expect(find.byType(ListTile), findsNothing);
}

void main() {
  group('a family tablet with nobody selected', () {
    _test('has no gear in the kid register', (tester) async {
      final c = await _pump(
        tester,
        deviceClass: DeviceClass.shared,
        register: UiRegister.kid,
      );
      expect(_gear, findsNothing);
      await _go(tester, c, Routes.settings);
      expect(_path(c), Routes.home);
    });

    _test('has no gear in the adult register', (tester) async {
      final c = await _pump(
        tester,
        deviceClass: DeviceClass.shared,
        register: UiRegister.adult,
      );
      expect(_gear, findsNothing);
      await _go(tester, c, Routes.settings);
      expect(_path(c), Routes.home);
    });

    _test('every settings route leads home', (tester) async {
      final c = await _pump(
        tester,
        deviceClass: DeviceClass.shared,
        register: UiRegister.adult,
      );
      for (final route in [
        Routes.settingsPersonal,
        Routes.settingsTasks,
        Routes.settingsDevices,
        Routes.settingsMembers,
        Routes.reminders,
        '${Routes.devicePair}?kind=kid_tablet',
      ]) {
        await _go(tester, c, route);
        expect(_path(c), Routes.home, reason: route);
      }
    });

    _test('gets the gear once someone is picked', (tester) async {
      final c = await _pump(
        tester,
        deviceClass: DeviceClass.shared,
        register: UiRegister.adult,
      );
      expect(_gear, findsNothing);
      c.read(actingProfileProvider.notifier).select(guardianId);
      await tester.pumpAndSettle();
      expect(_gear, findsOneWidget);
    });
  });

  for (final (label, who, name) in [
    ('a child', kidId, 'Anna'),
    ('an adult who is not a guardian', _mamaId, 'Mama'),
  ]) {
    group('$label on a family tablet', () {
      _test('opens their own settings only', (tester) async {
        final c = await _pump(
          tester,
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
          acting: who,
        );
        await tester.tap(_gear);
        await tester.pumpAndSettle();
        expect(_path(c), Routes.settings);
        _expectOwnPageOnly(name);
      });

      _test('sees the same in the Advanced view', (tester) async {
        final c = await _pump(
          tester,
          deviceClass: DeviceClass.shared,
          register: UiRegister.adult,
          acting: who,
          view: SettingsView.advanced,
        );
        await _go(tester, c, Routes.settings);
        _expectOwnPageOnly(name);
      });

      _test('is sent back from every other settings route', (tester) async {
        final c = await _pump(
          tester,
          deviceClass: DeviceClass.shared,
          register: UiRegister.adult,
          acting: who,
        );
        for (final route in [
          Routes.settingsTasks,
          Routes.settingsDevices,
          Routes.settingsFamily,
          Routes.settingsMembers,
          Routes.familyProfile,
          Routes.baselines,
          Routes.devicePair,
        ]) {
          await _go(tester, c, route);
          expect(_path(c), Routes.settings, reason: route);
          _expectOwnPageOnly(name);
        }
        await _go(tester, c, Routes.settingsPersonal);
        expect(_path(c), Routes.settingsPersonal);
        _expectOwnPageOnly(name);
      });

      _test('Back leaves settings for home', (tester) async {
        final c = await _pump(
          tester,
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
          acting: who,
        );
        await tester.tap(_gear);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(_path(c), Routes.home);
      });
    });
  }

  group('a guardian on a family tablet', () {
    _test('has the full top page', (tester) async {
      final c = await _pump(
        tester,
        deviceClass: DeviceClass.shared,
        register: UiRegister.adult,
        acting: guardianId,
        view: SettingsView.advanced,
      );
      await tester.tap(_gear);
      await tester.pumpAndSettle();
      expect(_path(c), Routes.settings);
      expect(find.byType(SettingsViewSwitch), findsOneWidget);
      for (final g in const [
        SettingsGroup.personal,
        SettingsGroup.family,
        SettingsGroup.tasks,
        SettingsGroup.devices,
      ]) {
        await tester.ensureVisible(_tile(g));
        expect(_tile(g), findsOneWidget, reason: g.name);
      }
      await tester.tap(_tile(SettingsGroup.tasks));
      await tester.pumpAndSettle();
      expect(_path(c), Routes.settingsTasks);
    });
  });

  group('the kitchen wall with nobody selected', () {
    Future<ProviderContainer> wall(WidgetTester tester) => _pump(
      tester,
      deviceClass: DeviceClass.kiosk,
      register: UiRegister.kiosk,
    );

    _test('keeps the gear and asks who you are first', (tester) async {
      final c = await wall(tester);
      expect(_gear, findsOneWidget);
      await tester.tap(_gear);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('who-are-you')), findsOneWidget);
      expect(find.text(_en.actingWho), findsOneWidget);
      for (final id in [guardianId, kidId, _mamaId]) {
        expect(find.byKey(ValueKey('who-pick-$id')), findsOneWidget);
      }
      expect(_path(c), Routes.home);
      expect(c.read(actingProfileProvider), isNull);
    });

    _test('a guardian picked opens the full settings', (tester) async {
      final c = await wall(tester);
      await tester.tap(_gear);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('who-pick-$guardianId')));
      await tester.pumpAndSettle();
      expect(c.read(actingProfileProvider), guardianId);
      expect(_path(c), Routes.settings);
      expect(_tile(SettingsGroup.family), findsOneWidget);
      expect(find.byType(SettingsViewSwitch), findsOneWidget);
    });

    _test('a child picked opens their own page', (tester) async {
      final c = await wall(tester);
      await tester.tap(_gear);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('who-pick-$kidId')));
      await tester.pumpAndSettle();
      expect(c.read(actingProfileProvider), kidId);
      expect(_path(c), Routes.settings);
      _expectOwnPageOnly('Anna');
    });

    _test('Cancel opens nothing', (tester) async {
      final c = await wall(tester);
      await tester.tap(_gear);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('who-are-you-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('who-are-you')), findsNothing);
      expect(_path(c), Routes.home);
      expect(c.read(actingProfileProvider), isNull);
    });

    _test('someone already selected goes straight in', (tester) async {
      await _pump(
        tester,
        deviceClass: DeviceClass.kiosk,
        register: UiRegister.kiosk,
        acting: kidId,
      );
      await tester.tap(_gear);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('who-are-you')), findsNothing);
      _expectOwnPageOnly('Anna');
    });

    _test('settings pages go back to nobody after 60 s idle', (tester) async {
      final c = await _pump(
        tester,
        deviceClass: DeviceClass.kiosk,
        register: UiRegister.kiosk,
        acting: guardianId,
      );
      await _go(tester, c, Routes.settingsTasks);
      expect(_path(c), Routes.settingsTasks);
      await tester.pump(const Duration(seconds: 30));
      // A touch on the settings page counts as activity.
      await tester.tapAt(const Offset(500, 800));
      await tester.pump(const Duration(seconds: 45));
      expect(_path(c), Routes.settingsTasks);
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();
      expect(c.read(actingProfileProvider), isNull);
      expect(_path(c), Routes.home);
    });
  });

  group('when the acting person goes away', () {
    _test('a guardian deep in settings is taken home', (tester) async {
      final c = await _pump(
        tester,
        deviceClass: DeviceClass.shared,
        register: UiRegister.adult,
        acting: guardianId,
      );
      await _go(tester, c, Routes.settingsTasks);
      expect(_path(c), Routes.settingsTasks);
      c.read(actingProfileProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(_path(c), Routes.home);
      expect(_gear, findsNothing);
    });

    _test('a child on their page is taken home', (tester) async {
      final c = await _pump(
        tester,
        deviceClass: DeviceClass.shared,
        register: UiRegister.kid,
        acting: kidId,
      );
      await tester.tap(_gear);
      await tester.pumpAndSettle();
      _expectOwnPageOnly('Anna');
      c.read(actingProfileProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(_path(c), Routes.home);
      expect(find.text(_en.settingsOwnTitle('Anna')), findsNothing);
    });

    _test('switching from a guardian to a child narrows the page', (
      tester,
    ) async {
      final c = await _pump(
        tester,
        deviceClass: DeviceClass.shared,
        register: UiRegister.adult,
        acting: guardianId,
      );
      await _go(tester, c, Routes.settingsTasks);
      c.read(actingProfileProvider.notifier).select(kidId);
      await tester.pumpAndSettle();
      expect(_path(c), Routes.settings);
      _expectOwnPageOnly('Anna');
    });
  });

  group('a personal phone', () {
    _test('is unchanged: gear, full pages, no member picker', (tester) async {
      final c = await _pump(
        tester,
        deviceClass: DeviceClass.personal,
        register: UiRegister.adult,
        view: SettingsView.advanced,
      );
      await tester.tap(_gear);
      await tester.pumpAndSettle();
      expect(_path(c), Routes.settings);
      expect(find.byKey(const ValueKey('who-are-you')), findsNothing);
      expect(find.byType(SettingsViewSwitch), findsOneWidget);
      expect(_tile(SettingsGroup.family), findsOneWidget);
      await tester.ensureVisible(find.text(_en.signOutDevice));
      expect(find.text(_en.signOutDevice), findsOneWidget);
      await _go(tester, c, Routes.settingsTasks);
      expect(_path(c), Routes.settingsTasks);
      await _go(tester, c, Routes.settingsPersonal);
      expect(_path(c), Routes.settingsPersonal);
      expect(find.byType(SettingsViewSwitch), findsOneWidget);
    });
  });
}
