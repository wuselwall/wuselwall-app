import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/settings/ui/household_settings_page.dart';
import 'package:wuselwall/features/settings/ui/setting_labels.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

import '../support/fakes.dart';

Map<String, dynamic> _row({
  required String key,
  required String scope,
  required String type,
  Object? value,
  Map<String, dynamic> constraints = const {},
  bool isDefault = true,
  String? profileId,
  String? deviceId,
}) => {
  'key': key,
  'scope': scope,
  'type': type,
  'constraints': constraints,
  'self_service': false,
  'default_value': value,
  'value': value,
  'is_default': isDefault,
  'profile_id': profileId,
  'device_id': deviceId,
};

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

void main() {
  group('SettingEntry.fromJson', () {
    test('parses every value encoding of the catalogue', () {
      final boolean = SettingEntry.fromJson(
        _row(
          key: 'tasks.verification_default',
          scope: 'household',
          type: 'boolean',
          value: true,
          isDefault: false,
        ),
      );
      expect(boolean.type, SettingType.boolean);
      expect(boolean.value, true);
      expect(boolean.isDefault, isFalse);
      expect(boolean.profileId, isNull);

      final integer = SettingEntry.fromJson(
        _row(
          key: 'tasks.points.duty_default',
          scope: 'household',
          type: 'integer',
          value: 1,
          constraints: {'min': 0, 'max': 3},
        ),
      );
      expect(integer.type, SettingType.integer);
      expect(integer.min, 0);
      expect(integer.max, 3);
      expect(integer.nullable, isFalse);

      final time = SettingEntry.fromJson(
        _row(
          key: 'meals.care_lunch_cutoff',
          scope: 'household',
          type: 'time',
          value: '14:00',
        ),
      );
      expect(time.type, SettingType.time);
      expect(time.value, '14:00');

      final enumeration = SettingEntry.fromJson(
        _row(
          key: 'calendar.key_default',
          scope: 'household',
          type: 'enum',
          value: 'whole_family',
          constraints: {
            'values': ['whole_family', 'all', 'none'],
          },
        ),
      );
      expect(enumeration.type, SettingType.enumeration);
      expect(enumeration.enumValues, ['whole_family', 'all', 'none']);

      final weekday = SettingEntry.fromJson(
        _row(
          key: 'board.rollover',
          scope: 'household',
          type: 'weekday_time',
          value: {'weekday': 6, 'time': '12:00'},
        ),
      );
      expect(weekday.type, SettingType.weekdayTime);
      expect((weekday.value! as Map)['weekday'], 6);

      final range = SettingEntry.fromJson(
        _row(
          key: 'device.night_hours',
          scope: 'device',
          type: 'time_range',
          value: {'from': '21:00', 'to': '06:00'},
        ),
      );
      expect(range.type, SettingType.timeRange);
      expect(range.scope, SettingScope.device);

      final times = SettingEntry.fromJson(
        _row(
          key: 'board.day_parts',
          scope: 'household',
          type: 'times',
          value: ['12:00', '17:00'],
        ),
      );
      expect(times.type, SettingType.times);
      expect(times.value, ['12:00', '17:00']);
    });

    test('a nullable integer that is off has a null value and is nullable', () {
      final off = SettingEntry.fromJson(
        _row(
          key: 'notify.event_reminder',
          scope: 'member',
          type: 'integer',
          value: null,
          constraints: {'min': 5, 'max': 120, 'nullable': true},
        ),
      );
      expect(off.value, isNull);
      expect(off.nullable, isTrue);
      expect(off.min, 5);
      expect(off.max, 120);
    });

    test('unknown wire names are rejected', () {
      expect(() => SettingType.parse('colour'), throwsFormatException);
      expect(() => SettingScope.parse('school'), throwsFormatException);
    });
  });

  group('resolveSetting', () {
    final rows = [
      SettingEntry.fromJson(
        _row(
          key: 'tasks.jokers_per_month',
          scope: 'household',
          type: 'integer',
          value: 1,
          constraints: {'min': 0, 'max': 5},
        ),
      ),
      SettingEntry.fromJson(
        _row(
          key: 'tasks.jokers_per_month',
          scope: 'household',
          type: 'integer',
          value: 3,
          isDefault: false,
          constraints: {'min': 0, 'max': 5},
          profileId: 'p-kid',
        ),
      ),
      SettingEntry.fromJson(
        _row(
          key: 'device.idle_revert_seconds',
          scope: 'device',
          type: 'integer',
          value: 90,
          isDefault: false,
          constraints: {'min': 30, 'max': 300},
          deviceId: 'd-kitchen',
        ),
      ),
      SettingEntry.fromJson(
        _row(
          key: 'device.idle_revert_seconds',
          scope: 'device',
          type: 'integer',
          value: 60,
          constraints: {'min': 30, 'max': 300},
        ),
      ),
    ];

    test('a member override beats the household row', () {
      final kid = resolveSetting(
        rows,
        'tasks.jokers_per_month',
        profileId: 'p-kid',
      );
      expect(kid?.value, 3);
      expect(kid?.isDefault, isFalse);
    });

    test('everyone else gets the household row', () {
      final papa = resolveSetting(
        rows,
        'tasks.jokers_per_month',
        profileId: 'p-papa',
      );
      expect(papa?.value, 1);
      expect(papa?.isDefault, isTrue);
      expect(resolveSetting(rows, 'tasks.jokers_per_month')?.value, 1);
    });

    test('a device override applies to that device only', () {
      expect(
        resolveSetting(
          rows,
          'device.idle_revert_seconds',
          deviceId: 'd-kitchen',
        )?.value,
        90,
      );
      expect(
        resolveSetting(
          rows,
          'device.idle_revert_seconds',
          deviceId: 'd-tablet',
        )?.value,
        60,
      );
    });

    test('an unknown key resolves to null', () {
      expect(resolveSetting(rows, 'no.such.key'), isNull);
    });
  });

  group('HouseholdSettingsPage', () {
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

    Future<FakeHouseholdSettingsRepository> pumpPage(
      WidgetTester tester, {
      required List<SettingEntry> rows,
      Locale locale = const Locale('en'),
    }) async {
      final repo = FakeHouseholdSettingsRepository(rows);
      final container = await pumpApp(
        tester,
        locale: locale,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            settingsView: SettingsView.advanced,
          ),
          householdSettingsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      container.read(routerProvider).go(Routes.householdSettings);
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('shows every section header, scrolling as needed', (
      tester,
    ) async {
      await pumpPage(tester, rows: rowsWithOneCustomised());
      final scrollable = find.byType(Scrollable).last;
      for (final title in const [
        'Household and members',
        'Tasks',
        'Calendar and school',
        'Meals',
        'Kitchen display',
        'This device',
        'My settings',
      ]) {
        await tester.scrollUntilVisible(
          find.text(title),
          300,
          scrollable: scrollable,
        );
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('a server without the rituals shows no empty headings', (
      tester,
    ) async {
      // The previous server release: no rituals, no occasions.
      await pumpPage(
        tester,
        rows: [
          for (final e in rowsWithOneCustomised())
            if (!e.key.startsWith('rituals.') &&
                !e.key.startsWith('ambience.') &&
                !e.key.startsWith('meals.wishes'))
              e,
        ],
      );
      final scrollable = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text('My settings'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Rituals'), findsNothing);
      expect(find.text('Seasons and occasions'), findsNothing);
    });

    testWidgets("the rituals lead to the family's own table questions", (
      tester,
    ) async {
      await pumpPage(tester, rows: rowsWithOneCustomised());
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('family-questions')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Our questions'), findsOneWidget);
    });

    testWidgets('settings nothing reads yet are not offered', (tester) async {
      await pumpPage(tester, rows: rowsWithOneCustomised());
      final scrollable = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text('My settings'),
        300,
        scrollable: scrollable,
      );
      for (final key in unusedSettingKeys) {
        final title = settingText(
          lookupAppLocalizations(const Locale('en')),
          key,
        ).title;
        expect(find.text(title), findsNothing, reason: key);
      }
    });

    testWidgets('a boolean switch writes its key and value', (tester) async {
      final repo = await pumpPage(tester, rows: rowsWithOneCustomised());
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
      final repo = await pumpPage(tester, rows: rowsWithOneCustomised());
      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l10n.settingIsCustom), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.settingReset));
      await tester.pumpAndSettle();

      expect(repo.resets.single.key, 'tasks.points.duty_default');
      expect(repo.resets.single.profileId, isNull);
      expect(repo.resets.single.deviceId, isNull);
    });

    testWidgets('builds in German', (tester) async {
      await pumpPage(
        tester,
        rows: rowsWithOneCustomised(),
        locale: const Locale('de'),
      );
      expect(find.text('Haushalt einstellen'), findsOneWidget);
      expect(find.text('angepasst'), findsOneWidget);
    });
  });

  group('SettingEntry.fromRows', () {
    test('skips a type or scope this app does not know', () {
      final entries = SettingEntry.fromRows([
        _row(
          key: 'future.kind',
          scope: 'household',
          type: 'colour',
          value: 'red',
        ),
        _row(
          key: 'future.scope',
          scope: 'school',
          type: 'boolean',
          value: true,
        ),
        _row(
          key: 'household.region',
          scope: 'household',
          type: 'region',
          value: null,
        ),
        _row(
          key: 'board.rollover',
          scope: 'household',
          type: 'boolean',
          value: false,
        ),
      ]);
      expect(entries.map((e) => e.key), ['household.region', 'board.rollover']);
      expect(entries.first.type, SettingType.region);
      expect(entries.first.nullable, isFalse);
    });
  });
}
