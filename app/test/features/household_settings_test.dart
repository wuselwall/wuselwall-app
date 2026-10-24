import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

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
