import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/settings/ui/setting_labels.dart';
import 'package:wuselwall/features/settings/ui/settings_group_text.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

import '../support/fakes.dart';

/// Records what the page asked for; the rows are the household's effective settings.
class FakeHouseholdSettingsRepository implements HouseholdSettingsRepository {
  FakeHouseholdSettingsRepository(this.rows);

  final List<SettingEntry> rows;
  final sets =
      <({String key, Object? value, String? profileId, String? deviceId})>[];
  final resets = <({String key, String? profileId, String? deviceId})>[];

  @override
  Future<Result<List<SettingEntry>>> all() async => Ok(List.of(rows));

  @override
  Future<Result<void>> set({
    required String? actor,
    required String key,
    required Object? value,
    String? profileId,
    String? deviceId,
  }) async {
    sets.add((
      key: key,
      value: value,
      profileId: profileId,
      deviceId: deviceId,
    ));
    return const Ok(null);
  }

  @override
  Future<Result<void>> reset({
    required String? actor,
    required String key,
    String? profileId,
    String? deviceId,
  }) async {
    resets.add((key: key, profileId: profileId, deviceId: deviceId));
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _de = lookupAppLocalizations(const Locale('de'));
final _en = lookupAppLocalizations(const Locale('en'));

/// The keys `settingText` knows, read from its source: a catalogue key with a title is
/// one the app can show, so it needs a place.
Set<String> _labelledKeys() {
  final source = File('lib/features/settings/ui/setting_labels.dart')
      .readAsStringSync();
  return {
    for (final m in RegExp(
      r"^\s*'([a-z_.]+)' => \(",
      multiLine: true,
    ).allMatches(source))
      m.group(1)!,
  };
}

SettingsEnv _env(
  List<SettingEntry> entries, {
  bool advanced = true,
  DeviceClass? deviceClass = DeviceClass.personal,
  String? acting = 'p1',
  bool notifications = true,
  bool server = false,
  bool coop = false,
}) => SettingsEnv(
  entries: entries,
  advanced: advanced,
  deviceClass: deviceClass,
  deviceId: 'd1',
  acting: acting,
  notificationsAvailable: notifications,
  hasServer: server,
  coopSupported: coop,
);

void main() {
  group('the groups place every setting once', () {
    final placed = placedSettingKeys.toList();

    test('no key sits in two places', () {
      expect(placed.toSet(), hasLength(placed.length));
    });

    test('every labelled key is placed, except those nothing reads', () {
      final labelled = _labelledKeys();
      expect(labelled, isNotEmpty);
      expect(
        labelled.difference(unusedSettingKeys).difference(placed.toSet()),
        isEmpty,
        reason: 'a labelled setting that no group shows',
      );
      expect(
        placed.toSet().difference(labelled),
        isEmpty,
        reason: 'a placed key without a title',
      );
      expect(placed.toSet().intersection(unusedSettingKeys), isEmpty);
    });

    test('every key of the demo catalogue is placed or unused', () {
      final keys = {for (final e in demoSettingCatalogue()) e.key};
      expect(
        keys.difference(unusedSettingKeys).difference(placed.toSet()),
        isEmpty,
      );
    });

    test('the Basic keys are all placed', () {
      expect(basicSettingKeys.difference(placed.toSet()), isEmpty);
    });

    test('a key of a newer server follows its prefix, else lands in Other', () {
      final entries = [
        ...demoSettingCatalogue(),
        for (final key in const ['tasks.future_flag', 'zzz.other'])
          SettingEntry.fromJson({
            'key': key,
            'scope': 'household',
            'type': 'boolean',
            'constraints': const <String, dynamic>{},
            'self_service': false,
            'default_value': false,
            'value': false,
            'is_default': true,
            'profile_id': null,
            'device_id': null,
          }),
      ];
      final env = _env(entries);
      expect(env.unplacedKeys, ['tasks.future_flag', 'zzz.other']);
      final tasks = visibleSections(SettingsGroup.tasks, env).last;
      expect(tasks.id, SettingsSectionId.other);
      expect(tasks.items.map((i) => (i as SettingKey).key), [
        'tasks.future_flag',
      ]);
      final help = visibleSections(SettingsGroup.help, env).last;
      expect(help.id, SettingsSectionId.other);
      expect(help.items.map((i) => (i as SettingKey).key), ['zzz.other']);
      // Basic does not show what it does not know.
      final basic = env.copyWith(advanced: false);
      expect(
        visibleSections(SettingsGroup.tasks, basic).map((s) => s.id),
        isNot(contains(SettingsSectionId.other)),
      );
    });
  });

  group('what a device shows', () {
    final catalogue = demoSettingCatalogue();

    test(
      'Basic keeps the Basic keys and Delete account on a personal phone',
      () {
        final env = _env(catalogue, advanced: false);
        final shown = [
          for (final g in SettingsGroup.values)
            for (final s in visibleSections(g, env)) ...s.items,
        ];
        final keys = {
          for (final i in shown)
            if (i is SettingKey) i.key,
        };
        expect(keys, basicSettingKeys);
        expect(
          shown.whereType<SettingTileItem>().map((i) => i.tile),
          contains(SettingsTile.deleteAccount),
        );
        // Account and security is whole in Basic: the password and leaving too.
        expect(
          visibleItemCount(SettingsGroup.account, env),
          visibleItemCount(SettingsGroup.account, env.copyWith(advanced: true)),
        );
      },
    );

    test('Account and Notifications are for a personal phone only', () {
      final shared = _env(catalogue, deviceClass: DeviceClass.shared);
      expect(visibleItemCount(SettingsGroup.account, shared), 0);
      expect(
        visibleSections(SettingsGroup.personal, shared).map((s) => s.id),
        isNot(contains(SettingsSectionId.notifications)),
      );
    });

    test('Personal needs someone acting', () {
      expect(
        visibleItemCount(SettingsGroup.personal, _env(catalogue, acting: null)),
        0,
      );
      expect(
        visibleGroups(_env(catalogue, acting: null)),
        isNot(contains(SettingsGroup.personal)),
      );
      expect(visibleGroups(_env(catalogue)), contains(SettingsGroup.personal));
    });

    test('Server is Advanced only, and only for a build that chose one', () {
      expect(
        visibleGroups(_env(catalogue, server: true)),
        contains(SettingsGroup.server),
      );
      expect(
        visibleGroups(_env(catalogue)),
        isNot(contains(SettingsGroup.server)),
      );
      expect(
        visibleGroups(_env(catalogue, server: true, advanced: false)),
        isNot(contains(SettingsGroup.server)),
      );
    });

    test('a group the server has no settings for has no tile', () {
      final old = [
        for (final e in catalogue)
          if (!e.key.startsWith('rituals.') &&
              !e.key.startsWith('ambience.') &&
              !e.key.startsWith('meals.wishes'))
            e,
      ];
      final groups = visibleGroups(_env(old));
      expect(groups, isNot(contains(SettingsGroup.rituals)));
      expect(groups, isNot(contains(SettingsGroup.celebrations)));
      expect(groups, contains(SettingsGroup.meals));
    });

    group('the Coop list tile', () {
      bool shown(SettingsEnv env) =>
          [
                for (final s in visibleSections(SettingsGroup.devices, env))
                  ...s.items,
              ]
              .whereType<SettingTileItem>()
              .any((i) => i.tile == SettingsTile.coopList);

      test('sits in This device on a personal phone with a WebView', () {
        final env = _env(catalogue, coop: true);
        expect(shown(env), isTrue);
        final owner = visibleSections(SettingsGroup.devices, env).where(
          (s) => s.items.whereType<SettingTileItem>().any(
            (i) => i.tile == SettingsTile.coopList,
          ),
        );
        expect(owner.map((s) => s.id), [SettingsSectionId.thisDevice]);
        // Basic keeps it too: it is a tile, not a setting.
        expect(shown(env.copyWith(advanced: false)), isTrue);
      });

      test('is not there in a build without a WebView', () {
        expect(shown(_env(catalogue)), isFalse);
        expect(shown(_env(const [])), isFalse);
      });

      test('is not there on a shared device or a wall', () {
        for (final deviceClass in [DeviceClass.shared, DeviceClass.kiosk]) {
          expect(
            shown(_env(catalogue, coop: true, deviceClass: deviceClass)),
            isFalse,
            reason: deviceClass.name,
          );
        }
      });
    });

    test('before the catalogue arrives only the groups of tiles show', () {
      expect(visibleGroups(_env(const [])), [
        SettingsGroup.personal,
        SettingsGroup.family,
        SettingsGroup.calendar,
        SettingsGroup.devices,
        SettingsGroup.account,
        SettingsGroup.help,
      ]);
    });
  });

  group('the group pages', () {
    /// The catalogue as a household that changed nothing sees it, except one customised
    /// row so that the reset action and the "customised" chip are present.
    List<SettingEntry> rowsWithOneCustomised() => [
      for (final e in demoSettingCatalogue())
        if (e.key == 'tasks.points.duty_default')
          SettingEntry.fromJson({
            'key': e.key,
            'scope': 'household',
            'type': 'integer',
            'constraints': e.constraints,
            'self_service': false,
            'default_value': 1,
            'value': 2,
            'is_default': false,
          })
        else
          e,
    ];

    late ProviderContainer container;

    Future<FakeHouseholdSettingsRepository> pumpRoute(
      WidgetTester tester,
      String route, {
      List<SettingEntry>? rows,
      Locale locale = const Locale('en'),
      SettingsView view = SettingsView.advanced,
      DeviceInfo? current,
      String? acting,
    }) async {
      final repo = FakeHouseholdSettingsRepository(
        rows ?? rowsWithOneCustomised(),
      );
      container = await pumpApp(
        tester,
        locale: locale,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: current ?? device()),
            settingsView: view,
          ),
          householdSettingsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      if (acting != null) {
        container.read(actingProfileProvider.notifier).select(acting);
      }
      container.read(routerProvider).go(route);
      await tester.pumpAndSettle();
      return repo;
    }

    Finder groupTile(SettingsGroup g) =>
        find.byKey(ValueKey('settings-group-${g.name}'));

    testWidgets('the top page lists the groups with title and subtitle', (
      tester,
    ) async {
      await pumpRoute(tester, Routes.settings);
      for (final group in const [
        SettingsGroup.personal,
        SettingsGroup.family,
        SettingsGroup.tasks,
        SettingsGroup.calendar,
        SettingsGroup.meals,
        SettingsGroup.rituals,
        SettingsGroup.celebrations,
        SettingsGroup.kitchen,
        SettingsGroup.devices,
        SettingsGroup.account,
        SettingsGroup.help,
      ]) {
        final tile = groupTile(group);
        await tester.ensureVisible(tile);
        expect(tile, findsOneWidget, reason: group.name);
        expect(
          find.descendant(of: tile, matching: find.text(group.title(_en))),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tile, matching: find.text(group.subtitle(_en))),
          findsOneWidget,
        );
      }
      expect(find.text(_en.signOutDevice), findsOneWidget);
    });

    testWidgets('a group opens its page and Back returns to the top', (
      tester,
    ) async {
      await pumpRoute(tester, Routes.settings);
      await tester.tap(groupTile(SettingsGroup.tasks));
      await tester.pumpAndSettle();
      expect(find.text(_en.settingsGroupTasksTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey('setting-tasks.verification_default')),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(groupTile(SettingsGroup.tasks), findsOneWidget);
    });

    testWidgets('a group page shows its sections as headings', (tester) async {
      await pumpRoute(tester, Routes.settingsRituals);
      for (final title in [
        _en.settingsSectionTableQuestion,
        _en.settingsSectionWeekReview,
        _en.settingsSectionCountdowns,
      ]) {
        expect(find.text(title, skipOffstage: false), findsWidgets);
      }
    });

    testWidgets("the rituals lead to the family's own table questions", (
      tester,
    ) async {
      await pumpRoute(tester, Routes.settingsRituals);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('family-questions')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Our questions'), findsOneWidget);
    });

    testWidgets('Celebrations has its two sections in Advanced', (
      tester,
    ) async {
      await pumpRoute(tester, Routes.settingsCelebrations);
      expect(find.text(_en.settingsSectionHolidays), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(_en.settingsSectionThroughYear),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(_en.settingsSectionThroughYear), findsOneWidget);
    });

    testWidgets('Calendar & school offers its connections in Advanced', (
      tester,
    ) async {
      await pumpRoute(tester, Routes.settingsCalendar);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-feeds')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.byKey(const ValueKey('settings-external-calendars')),
        findsOneWidget,
      );
    });

    testWidgets('Basic filters a page to its Basic settings', (tester) async {
      await pumpRoute(
        tester,
        Routes.settingsCalendar,
        view: SettingsView.basic,
      );
      expect(
        find.byKey(const ValueKey('setting-calendar.members_edit_own_events')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setting-calendar.key_default')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('settings-feeds')), findsNothing);
      expect(find.byKey(const ValueKey('settings-more-hint')), findsOneWidget);
    });

    testWidgets('Family holds the profile, region, members and usual week', (
      tester,
    ) async {
      await pumpRoute(tester, Routes.settingsFamily, view: SettingsView.basic);
      expect(find.byKey(const ValueKey('settings-family')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('setting-household.region')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('settings-members')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-baselines')), findsOneWidget);
    });

    testWidgets('Devices holds this device and all devices', (tester) async {
      await pumpRoute(tester, Routes.settingsDevices);
      expect(find.text(_en.settingsSectionThisDevice), findsOneWidget);
      expect(find.text(_en.languageTitle), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(_en.settingsSectionAllDevices),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(_en.settingsSectionAllDevices), findsOneWidget);
    });

    testWidgets('Personal holds Wusel, sound and the notifications', (
      tester,
    ) async {
      await pumpRoute(tester, Routes.settingsPersonal);
      expect(
        find.byKey(const ValueKey('setting-member.wusel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setting-member.completion_sound')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-reminders')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
    });

    testWidgets('a shared device with nobody acting has no settings', (
      tester,
    ) async {
      await pumpRoute(
        tester,
        Routes.settings,
        current: device(
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
        ),
      );
      expect(groupTile(SettingsGroup.personal), findsNothing);
      expect(groupTile(SettingsGroup.family), findsNothing);
    });

    testWidgets('a guardian at a shared device sees Personal and Family', (
      tester,
    ) async {
      await pumpRoute(
        tester,
        Routes.settings,
        current: device(
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
        ),
        acting: guardianId,
      );
      expect(groupTile(SettingsGroup.personal), findsOneWidget);
      expect(groupTile(SettingsGroup.family), findsOneWidget);
      // The kid home behind it greeted the acting guardian and started the board's timers.
      await unmountApp(tester, container);
    });

    testWidgets('a server without the rituals has no tile for them', (
      tester,
    ) async {
      await pumpRoute(
        tester,
        Routes.settings,
        rows: [
          for (final e in rowsWithOneCustomised())
            if (!e.key.startsWith('rituals.') &&
                !e.key.startsWith('ambience.') &&
                !e.key.startsWith('meals.wishes'))
              e,
        ],
      );
      expect(groupTile(SettingsGroup.meals), findsOneWidget);
      expect(groupTile(SettingsGroup.rituals), findsNothing);
      expect(groupTile(SettingsGroup.celebrations), findsNothing);
    });

    testWidgets('Delete account is reachable in Basic on a personal phone', (
      tester,
    ) async {
      await pumpRoute(tester, Routes.settings, view: SettingsView.basic);
      await tester.tap(groupTile(SettingsGroup.account));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-account')), findsOneWidget);
    });

    testWidgets('no Account group on a shared device', (tester) async {
      await pumpRoute(
        tester,
        Routes.settings,
        view: SettingsView.basic,
        current: device(
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
        ),
        acting: guardianId,
      );
      expect(groupTile(SettingsGroup.family), findsOneWidget);
      expect(groupTile(SettingsGroup.account), findsNothing);
      await unmountApp(tester, container);
    });

    testWidgets('settings nothing reads yet are not offered', (tester) async {
      await pumpRoute(tester, Routes.settingsDevices);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('setting-device.pixel_shift')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      for (final key in unusedSettingKeys) {
        final title = settingText(_en, key).title;
        expect(find.text(title), findsNothing, reason: key);
      }
    });

    testWidgets('a boolean switch writes its key and value', (tester) async {
      final repo = await pumpRoute(tester, Routes.settingsTasks);
      final row = find.byKey(
        const ValueKey('setting-tasks.verification_default'),
      );
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(repo.sets, hasLength(1));
      expect(repo.sets.single.key, 'tasks.verification_default');
      expect(repo.sets.single.value, true);
      expect(repo.sets.single.profileId, isNull);
      expect(repo.sets.single.deviceId, isNull);
    });

    testWidgets('a customised row shows its chip and resets', (tester) async {
      final repo = await pumpRoute(tester, Routes.settingsTasks);
      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.settingIsCustom), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.settingReset));
      await tester.pumpAndSettle();

      expect(repo.resets.single.key, 'tasks.points.duty_default');
      expect(repo.resets.single.profileId, isNull);
      expect(repo.resets.single.deviceId, isNull);
    });

    testWidgets('builds in German', (tester) async {
      await pumpRoute(tester, Routes.settings, locale: const Locale('de'));
      for (final title in const [
        'Persönlich',
        'Familie',
        'Aufgaben & Belohnungen',
        'Kalender & Schule',
        'Essen',
        'Rituale',
        'Feste & Jahreszeiten',
        'Küchenwand',
        'Geräte',
        'Konto & Sicherheit',
        'Hilfe & Info',
      ]) {
        final tile = find.widgetWithText(ListTile, title);
        await tester.ensureVisible(tile);
        expect(tile, findsOneWidget, reason: title);
      }
      expect(_de.settingsGroupServerTitle, 'Server');
    });
  });
}
