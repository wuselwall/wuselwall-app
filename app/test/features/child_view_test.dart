import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/application/child_view.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

import '../support/fakes.dart' show device;

/// What the children's limits and the simple view are built on (specs/09 "What a child
/// sees", "The simple view"): who counts as a young child, who is looking at the
/// device, and what they are offered. No widgets: providers over a fixed day.

/// Saturday 28 November 2026: a day on which no fixture birthday is today's.
final _today = DateTime(2026, 11, 28);

Member _member(
  String id, {
  bool isChild = false,
  DateTime? birthday,
  Role role = Role.member,
}) => Member(
  id: id,
  displayName: id,
  color: const Color(0xFF2E7D6B),
  role: role,
  active: true,
  isChild: isChild,
  hasAccount: !isChild,
  birthday: birthday,
);

const _papa = 'papa';
const _anna = 'anna'; // eight
const _ben = 'ben'; // thirteen
const _caro = 'caro'; // a child without a birthday

final _family = [
  _member(_papa, role: Role.guardian),
  _member(_anna, isChild: true, birthday: DateTime(2018, 3, 14)),
  _member(_ben, isChild: true, birthday: DateTime(2013, 3, 14)),
  _member(_caro, isChild: true),
];

/// The household's settings with the two switches for children; either row can be left
/// out, as an older server does.
List<SettingEntry> _settings({
  bool shopping = false,
  bool calendar = true,
  bool withCalendarRow = true,
}) => [
  for (final e in demoSettingCatalogue())
    if (e.key == kidCalendarKey && !withCalendarRow)
      ...<SettingEntry>[]
    else if (e.key == kidShoppingKey || e.key == kidCalendarKey)
      SettingEntry(
        key: e.key,
        scope: e.scope,
        type: e.type,
        constraints: e.constraints,
        selfService: e.selfService,
        defaultValue: e.defaultValue,
        value: e.key == kidShoppingKey ? shopping : calendar,
        isDefault: false,
      )
    else
      e,
];

/// A container for a device of [deviceClass] where [acting] (a member id, or nobody)
/// is at the screen. The members and the settings are loaded when it returns.
/// [settings] null leaves them loading for good, [settingsFail] makes them fail.
Future<ProviderContainer> _container({
  DeviceClass deviceClass = DeviceClass.shared,
  UiRegister register = UiRegister.adult,
  String? profileId = _papa,
  String? acting,
  List<SettingEntry>? settings,
  bool settingsFail = false,
  List<Member>? members,
}) async {
  final container = ProviderContainer(
    overrides: <Override>[
      deviceProvider.overrideWithValue(
        AsyncData(
          device(
            deviceClass: deviceClass,
            register: register,
            profileId: profileId,
          ),
        ),
      ),
      membersProvider.overrideWith((ref) async => members ?? _family),
      householdSettingsProvider.overrideWith((ref) async {
        if (settingsFail) throw StateError('settings unreadable');
        if (settings == null) return Completer<List<SettingEntry>>().future;
        return settings;
      }),
      nowProvider.overrideWithValue(DateTime(2026, 11, 28, 10, 30)),
    ],
  );
  addTearDown(container.dispose);
  // autoDispose providers stay alive while someone listens.
  container
    ..listen(membersProvider, (_, _) {})
    ..listen(householdSettingsProvider, (_, _) {});
  await container.read(membersProvider.future);
  if (settings != null) await container.read(householdSettingsProvider.future);
  if (settingsFail) {
    await expectLater(
      container.read(householdSettingsProvider.future),
      throwsStateError,
    );
  }
  if (acting != null) {
    container.read(actingProfileProvider.notifier).select(acting);
  }
  return container;
}

Occurrence _occurrence(
  String id,
  DateTime day, {
  List<String> who = const [],
  String title = 'Termin',
}) => Occurrence(
  id: id,
  eventId: 'e-$id',
  calendarId: 'c',
  title: title,
  kind: EventKind.appointment,
  status: EventStatus.confirmed,
  importance: Importance.normal,
  allDay: false,
  start: DateTime(day.year, day.month, day.day, 15),
  end: DateTime(day.year, day.month, day.day, 16),
  localStartDate: day,
  localEndDate: day,
  localStarts: const TimeOfDay(hour: 15, minute: 0),
  localEnds: const TimeOfDay(hour: 16, minute: 0),
  attendeeIds: who,
);

void main() {
  group('Member.isYoungChildOn', () {
    // The day before the twelfth birthday is the last of the simple view.
    test('a child who turns twelve tomorrow is young today', () {
      final child = _member(
        'c',
        isChild: true,
        birthday: DateTime(2014, 11, 29),
      );
      expect(child.isYoungChildOn(_today), isTrue);
    });

    test('on the twelfth birthday itself the child is not young', () {
      final child = _member(
        'c',
        isChild: true,
        birthday: DateTime(2014, 11, 28),
      );
      expect(child.isYoungChildOn(_today), isFalse);
      // And it stays so the day after.
      expect(child.isYoungChildOn(DateTime(2026, 11, 29)), isFalse);
    });

    test('a child without a birthday counts as young', () {
      expect(_member('c', isChild: true).isYoungChildOn(_today), isTrue);
    });

    test('an adult is never young, whatever their birthday says', () {
      // Kind decides, not the date: a grown-up born as recently as a five-year-old.
      final adult = _member(
        'a',
        birthday: DateTime(2021, 5, 1),
        role: Role.guardian,
      );
      expect(adult.isYoungChildOn(_today), isFalse);
      expect(_member('b').isYoungChildOn(_today), isFalse);
    });

    test('a child born on 29 February does not throw in any year', () {
      final child = _member(
        'c',
        isChild: true,
        birthday: DateTime(2016, 2, 29),
      );
      for (final day in [
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 1),
        DateTime(2028, 2, 28),
        DateTime(2028, 2, 29),
        DateTime(2028, 3, 1),
      ]) {
        expect(
          () => child.isYoungChildOn(day),
          returnsNormally,
          reason: '$day',
        );
      }
      // Twelve on the leap day itself, still eleven the day before.
      expect(child.isYoungChildOn(DateTime(2028, 2, 28)), isTrue);
      expect(child.isYoungChildOn(DateTime(2028, 2, 29)), isFalse);
    });
  });

  group('occurrencesOfChild', () {
    test(
      'keeps only the appointments the child is in, and their busy lines',
      () {
        final window = OccurrenceWindow(
          timezone: 'Europe/Berlin',
          occurrences: [
            _occurrence('mine', _today, who: [_anna], title: 'Zahnarzt'),
            _occurrence('shared', _today, who: [_papa, _anna], title: 'Kino'),
            _occurrence('theirs', _today, who: [_ben], title: 'Fussball'),
            _occurrence('adult', _today, who: [_papa], title: 'Sitzung'),
            _occurrence('nobody', _today, title: 'Ohne Teilnehmer'),
          ],
          busyUntil: {
            (profileId: _anna, date: _today): const TimeOfDay(
              hour: 16,
              minute: 0,
            ),
            (profileId: _ben, date: _today): const TimeOfDay(
              hour: 17,
              minute: 0,
            ),
            (profileId: _papa, date: _today): const TimeOfDay(
              hour: 18,
              minute: 0,
            ),
          },
          publicHolidays: {_today: 'Feiertag'},
        );

        final mine = occurrencesOfChild(window, _anna);

        expect(mine.occurrences.map((o) => o.id), ['mine', 'shared']);
        expect(mine.busyUntil.keys.map((k) => k.profileId), [_anna]);
        expect(mine.timezone, 'Europe/Berlin');
        // Holidays belong to everyone.
        expect(mine.publicHolidays, {_today: 'Feiertag'});
      },
    );
  });

  group('viewerProvider', () {
    test('a personal adult device is an adult', () async {
      final c = await _container(
        deviceClass: DeviceClass.personal,
        acting: null,
      );
      expect(c.read(viewerProvider), Viewer.adult);
    });

    test('a shared device with nobody acting is nobody', () async {
      final c = await _container();
      expect(c.read(viewerProvider), Viewer.nobody);
      expect(c.read(viewerProvider).isChild, isFalse);
    });

    test('an adult acting on a shared device is an adult', () async {
      final c = await _container(acting: _papa);
      expect(c.read(viewerProvider), Viewer.adult);
    });

    test('a child of eight acting is a young child', () async {
      final c = await _container(acting: _anna);
      expect(c.read(viewerProvider), Viewer.youngChild);
      expect(c.read(youngChildActingProvider), isTrue);
    });

    test('a child of thirteen acting is an older child', () async {
      final c = await _container(acting: _ben);
      expect(c.read(viewerProvider), Viewer.olderChild);
      expect(c.read(viewerProvider).isChild, isTrue);
      expect(c.read(youngChildActingProvider), isFalse);
    });

    test('a child without a birthday is a young child', () async {
      final c = await _container(acting: _caro);
      expect(c.read(viewerProvider), Viewer.youngChild);
    });

    test('the viewer follows whoever takes the device next', () async {
      final c = await _container(acting: _anna);
      c.read(actingProfileProvider.notifier).select(_ben);
      expect(c.read(viewerProvider), Viewer.olderChild);
      c.read(actingProfileProvider.notifier).clear();
      expect(c.read(viewerProvider), Viewer.nobody);
    });
  });

  group('uiRegisterProvider', () {
    test(
      'a young child on an adult-register tablet gets the kid register',
      () async {
        final c = await _container(acting: _anna);
        expect(c.read(deviceRegisterProvider), UiRegister.adult);
        expect(c.read(uiRegisterProvider), UiRegister.kid);
      },
    );

    test(
      'an older child on an adult-register tablet keeps the adult register',
      () async {
        final c = await _container(acting: _ben);
        expect(c.read(uiRegisterProvider), UiRegister.adult);
      },
    );

    test('nobody and an adult leave the device register alone', () async {
      final nobody = await _container();
      expect(nobody.read(uiRegisterProvider), UiRegister.adult);
      final adult = await _container(acting: _papa);
      expect(adult.read(uiRegisterProvider), UiRegister.adult);
    });

    test(
      'on the wall a young child gets the kid register, the wall stays a wall',
      () async {
        final c = await _container(
          deviceClass: DeviceClass.kiosk,
          register: UiRegister.kiosk,
          acting: _anna,
        );
        expect(c.read(uiRegisterProvider), UiRegister.kid);
        expect(c.read(deviceRegisterProvider), UiRegister.kiosk);
      },
    );

    test('on the wall an older child leaves the kiosk register', () async {
      final c = await _container(
        deviceClass: DeviceClass.kiosk,
        register: UiRegister.kiosk,
        acting: _ben,
      );
      expect(c.read(uiRegisterProvider), UiRegister.kiosk);
    });
  });

  group('what the family offers children', () {
    final all = HomeTab.values;

    test('an adult has all six tabs whatever the switches say', () async {
      final c = await _container(
        acting: _papa,
        settings: _settings(shopping: false, calendar: false),
      );
      expect(c.read(homeTabsProvider), all);
      expect(c.read(shoppingOfferedProvider), isTrue);
      expect(c.read(calendarOfferedProvider), isTrue);
    });

    test(
      'a personal adult device has all six tabs with the switches off',
      () async {
        final c = await _container(
          deviceClass: DeviceClass.personal,
          acting: null,
          settings: _settings(shopping: false, calendar: false),
        );
        expect(c.read(homeTabsProvider), all);
      },
    );

    test(
      'nobody on a shared device: no shopping, the calendar stays',
      () async {
        final c = await _container(
          settings: _settings(shopping: false, calendar: true),
        );
        final tabs = c.read(homeTabsProvider);
        expect(tabs, isNot(contains(HomeTab.shopping)));
        expect(tabs, contains(HomeTab.calendar));
        expect(c.read(shoppingOfferedProvider), isFalse);
        expect(c.read(calendarOfferedProvider), isTrue);
        // The others are untouched.
        expect(tabs, [
          HomeTab.today,
          HomeTab.calendar,
          HomeTab.schedule,
          HomeTab.tasks,
          HomeTab.meals,
        ]);
      },
    );

    test(
      'nobody on a shared device with the calendar off: no calendar tab',
      () async {
        final c = await _container(
          settings: _settings(shopping: false, calendar: false),
        );
        final tabs = c.read(homeTabsProvider);
        expect(tabs, isNot(contains(HomeTab.calendar)));
        expect(tabs, isNot(contains(HomeTab.shopping)));
        expect(c.read(calendarOfferedProvider), isFalse);
      },
    );

    test('with both switches on nobody has all six tabs', () async {
      final c = await _container(
        settings: _settings(shopping: true, calendar: true),
      );
      expect(c.read(homeTabsProvider), all);
    });

    test('an older child follows the switches too', () async {
      final c = await _container(
        acting: _ben,
        settings: _settings(shopping: true, calendar: false),
      );
      final tabs = c.read(homeTabsProvider);
      expect(tabs, contains(HomeTab.shopping));
      expect(tabs, isNot(contains(HomeTab.calendar)));
    });

    test('a server without the calendar row offers the calendar', () async {
      final c = await _container(
        settings: _settings(shopping: false, withCalendarRow: false),
      );
      expect(c.read(calendarOfferedProvider), isTrue);
      expect(c.read(homeTabsProvider), contains(HomeTab.calendar));
      // The shopping row is there and says no.
      expect(c.read(homeTabsProvider), isNot(contains(HomeTab.shopping)));
    });

    test('settings still loading offer nothing to a child', () async {
      final c = await _container(acting: _ben);
      expect(c.read(childSwitchProvider(kidShoppingKey)), isFalse);
      expect(c.read(childSwitchProvider(kidCalendarKey)), isFalse);
      expect(c.read(homeTabsProvider), [
        HomeTab.today,
        HomeTab.schedule,
        HomeTab.tasks,
        HomeTab.meals,
      ]);
      // An adult is not made to wait.
      final adult = await _container(acting: _papa);
      expect(adult.read(homeTabsProvider), all);
    });

    test('settings that cannot be read keep everything for a child', () async {
      final c = await _container(acting: _ben, settingsFail: true);
      expect(c.read(childSwitchProvider(kidShoppingKey)), isTrue);
      expect(c.read(childSwitchProvider(kidCalendarKey)), isTrue);
      expect(c.read(homeTabsProvider), all);
    });
  });

  group('childDaysProvider', () {
    test(
      'an older child with the calendar on has four days from today',
      () async {
        final c = await _container(
          acting: _ben,
          settings: _settings(calendar: true),
        );
        final days = c.read(childDaysProvider)!;
        expect(days, [
          DateTime(2026, 11, 28),
          DateTime(2026, 11, 29),
          DateTime(2026, 11, 30),
          // Across the month's end.
          DateTime(2026, 12, 1),
        ]);
      },
    );

    test('a young child has the four days as well', () async {
      final c = await _container(
        acting: _anna,
        settings: _settings(calendar: true),
      );
      expect(c.read(childDaysProvider), hasLength(childHorizonDays));
    });

    test('with the calendar off a child has today only', () async {
      final c = await _container(
        acting: _ben,
        settings: _settings(calendar: false),
      );
      expect(c.read(childDaysProvider), [_today]);
    });

    test('an adult, and nobody, have no child days', () async {
      final adult = await _container(
        acting: _papa,
        settings: _settings(calendar: true),
      );
      expect(adult.read(childDaysProvider), isNull);
      expect(adult.read(childCalendarProvider), isNull);
      final nobody = await _container(settings: _settings(calendar: true));
      expect(nobody.read(childDaysProvider), isNull);
    });

    test(
      'the child calendar belongs to the acting child, from today',
      () async {
        final c = await _container(
          acting: _ben,
          settings: _settings(calendar: true),
        );
        expect(c.read(childCalendarProvider), (id: _ben, from: _today));
      },
    );
  });
}
