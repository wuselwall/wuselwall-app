import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

const _device = 'd-wall';

Member _member({required bool child}) => Member(
  id: child ? 'p-child' : 'p-adult',
  displayName: child ? 'Lotta' : 'Sabine',
  color: const Color(0xFF2D6A4F),
  role: child ? Role.member : Role.guardian,
  active: true,
  isChild: child,
);

SettingEntry _entry(
  String key,
  Object? value, {
  String? profile,
  String? dev,
}) => SettingEntry(
  key: key,
  scope: profile != null
      ? SettingScope.member
      : dev != null
      ? SettingScope.device
      : SettingScope.household,
  type: SettingType.enumeration,
  constraints: const {},
  selfService: true,
  defaultValue: null,
  value: value,
  isDefault: false,
  profileId: profile,
  deviceId: dev,
);

/// What Wusel does for [acting] on a device of [register], with `member.wusel` and
/// `device.wusel` as given; null leaves a key out, as an older server does.
WuselPresence _resolve({
  required UiRegister register,
  Member? acting,
  String? member,
  String? device,
}) => resolveLighterDay(
  entries: [
    if (member != null && acting != null)
      _entry('member.wusel', member, profile: acting.id),
    if (device != null) _entry('device.wusel', device, dev: _device),
  ],
  register: register,
  deviceId: _device,
  acting: acting,
).wusel;

void main() {
  final adult = _member(child: false);
  final child = _member(child: true);
  const lively = WuselPresence.lively;
  const quiet = WuselPresence.quiet;
  const off = WuselPresence.off;

  group('a member who chose', () {
    // An explicit choice wins everywhere, over any device value.
    for (final register in UiRegister.values) {
      for (final person in [adult, child]) {
        for (final device in ['lively', 'quiet', 'off', null]) {
          for (final (value, expected) in [
            ('lively', lively),
            ('quiet', quiet),
            ('off', off),
          ]) {
            test(
              '${register.name}, ${person.displayName} chose $value, '
              'device $device',
              () => expect(
                _resolve(
                  register: register,
                  acting: person,
                  member: value,
                  device: device,
                ),
                expected,
              ),
            );
          }
        }
      }
    }
  });

  group('auto on the wall follows the device', () {
    for (final person in [adult, child, null]) {
      for (final (device, expected) in [
        ('lively', lively),
        ('quiet', quiet),
        ('off', off),
        (null, lively),
      ]) {
        test('${person?.displayName ?? 'nobody'} chosen, device $device', () {
          expect(
            _resolve(
              register: UiRegister.kiosk,
              acting: person,
              member: person == null ? null : 'auto',
              device: device,
            ),
            expected,
          );
        });
      }
    }

    test('an adult tapping their avatar keeps the corner Wusel', () {
      expect(
        _resolve(
          register: UiRegister.kiosk,
          acting: adult,
          member: 'auto',
          device: 'lively',
        ),
        lively,
      );
    });

    test(
      'a child on auto does not bring back a Wusel the wall switched off',
      () {
        expect(
          _resolve(
            register: UiRegister.kiosk,
            acting: child,
            member: 'auto',
            device: 'off',
          ),
          off,
        );
      },
    );
  });

  group(
    'auto on a phone and the kid register: children lively, adults quiet',
    () {
      for (final register in [UiRegister.adult, UiRegister.kid]) {
        for (final device in ['lively', 'quiet', 'off', null]) {
          test('${register.name}, device $device', () {
            expect(
              _resolve(
                register: register,
                acting: child,
                member: 'auto',
                device: device,
              ),
              lively,
            );
            expect(
              _resolve(
                register: register,
                acting: adult,
                member: 'auto',
                device: device,
              ),
              quiet,
            );
          });
        }
      }
    },
  );

  group('an older server without the keys', () {
    test('the wall is lively', () {
      expect(_resolve(register: UiRegister.kiosk), lively);
      expect(_resolve(register: UiRegister.kiosk, acting: adult), lively);
    });

    test('a phone is quiet for an adult and lively for a child', () {
      expect(_resolve(register: UiRegister.adult, acting: adult), quiet);
      expect(_resolve(register: UiRegister.adult, acting: child), lively);
    });

    test('the kid register is lively', () {
      expect(_resolve(register: UiRegister.kid, acting: child), lively);
      expect(_resolve(register: UiRegister.kid), lively);
    });
  });
}
