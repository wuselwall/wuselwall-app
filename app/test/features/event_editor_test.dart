import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fakes.dart';

final _de = AppLocalizationsDe();

/// Mo..So as the German chips write them.
String _wd(int isoWeekday) =>
    DateFormat.E('de')
        .format(DateTime(2024, 1, 1 + isoWeekday - 1))
        .replaceAll('.', '');

/// Hour the editor starts a new event on: the next full hour of the real clock.
int get _defaultHour => (DateTime.now().hour + 1).clamp(0, 23);

final _day = DateTime(2026, 10, 14); // a Wednesday, so the weekly default is Mi

class _SettingsFake implements HouseholdSettingsRepository {
  _SettingsFake(this.rows);

  final List<SettingEntry> rows;

  @override
  Future<Result<List<SettingEntry>>> all() async => Ok(List.of(rows));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

SettingEntry _keyDefault(String value) => SettingEntry(
  key: 'calendar.key_default',
  scope: SettingScope.household,
  type: SettingType.enumeration,
  constraints: const {},
  selfService: false,
  defaultValue: 'whole_family',
  value: value,
  isDefault: value == 'whole_family',
);

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

/// The app on the calendar tab, with [settings] as the household's settings.
Future<ProviderContainer> _app(
  WidgetTester t, {
  FakeCalendarRepository? calendar,
  List<SettingEntry> settings = const [],
}) async {
  final container = await pumpApp(
    t,
    overrides: [
      ...baseOverrides(identity: FakeIdentityRepository(current: device())),
      householdSettingsRepositoryProvider.overrideWithValue(
        _SettingsFake(settings),
      ),
    ],
    calendar: calendar,
  );
  await openTab(t, 'Kalender');
  return container;
}

/// Opens the editor on [route] the way the app does, through the router.
Future<void> _open(
  WidgetTester t, {
  FakeCalendarRepository? calendar,
  EventEditArgs? args,
  String route = Routes.eventNew,
  List<SettingEntry> settings = const [],
}) async {
  final container = await _app(t, calendar: calendar, settings: settings);
  // The push completes when the editor pops, so it is not awaited.
  unawaited(container.read(routerProvider).push(route, extra: args));
  await t.pumpAndSettle();
}

Future<void> _title(WidgetTester t, String text) async {
  await t.enterText(find.byType(TextField).first, text);
  await t.pump();
}

Future<void> _save(WidgetTester t) =>
    _tap(t, find.widgetWithText(FilledButton, _de.save));

CalendarEvent _fixture({
  required String id,
  String title = 'Turnen',
  DateTime? startsAt,
  DateTime? endsAt,
  String? rrule,
}) {
  final start = startsAt ?? DateTime(2026, 10, 14, 15);
  return CalendarEvent(
    id: id,
    title: title,
    kind: EventKind.appointment,
    isAllDay: false,
    startsAt: start,
    endsAt: endsAt ?? start.add(const Duration(hours: 1)),
    rrule: rrule,
    attendeeIds: const [guardianId],
  );
}

void main() {
  group('new event', () {
    testWidgets('a timed event saves its start, end, attendee and kind', (
      t,
    ) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Zahnarzt');
      await _save(t);

      expect(cal.saved, hasLength(1));
      final json = cal.saved.single.toJson();
      final start = DateTime(2026, 10, 14, _defaultHour);
      expect(json['title'], 'Zahnarzt');
      expect(json['is_all_day'], false);
      expect(json['starts_at'], start.toUtc().toIso8601String());
      expect(
        json['ends_at'],
        start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
      );
      expect(json['start_date'], isNull);
      expect(json['kind'], 'appointment');
      expect(json['attendee_ids'], [guardianId]);
      expect(json['rrule'], isNull);
      expect(cal.savedActors, [guardianId]);
    });

    testWidgets('importance follows calendar.key_default: whole family', (
      t,
    ) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Essen');
      // Only Papa: not the whole family, so not on the kitchen display.
      await _save(t);
      expect(cal.saved.single.importance, Importance.normal);
    });

    testWidgets('whole family selected means the kitchen display by default', (
      t,
    ) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Familienessen');
      await _tap(t, find.widgetWithText(FilterChip, 'Anna'));
      await _save(t);
      expect(cal.saved.single.importance, Importance.key);
      expect(cal.saved.single.attendeeIds, [guardianId, kidId]);
    });

    testWidgets('key_default none keeps the switch off, even for everyone', (
      t,
    ) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
        settings: [_keyDefault('none')],
      );
      await _title(t, 'Ruhig');
      await _tap(t, find.widgetWithText(FilterChip, 'Anna'));
      await _save(t);
      expect(cal.saved.single.importance, Importance.normal);
    });

    testWidgets('an all-day event saves start_date and end_date', (t) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Geburtstag');
      await _tap(t, find.widgetWithText(SwitchListTile, _de.eventAllDay));
      await _save(t);

      final json = cal.saved.single.toJson();
      expect(json['is_all_day'], true);
      expect(json['start_date'], '2026-10-14');
      expect(json['end_date'], '2026-10-14');
      expect(json['starts_at'], isNull);
      expect(json['ends_at'], isNull);
    });

    testWidgets('an empty title is refused and nothing is saved', (t) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _save(t);
      expect(find.text(_de.eventTitleRequired), findsOneWidget);
      expect(cal.saved, isEmpty);
    });

    testWidgets('a presence event needs a state, then sends presence_state', (
      t,
    ) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Homeoffice');
      await _tap(t, find.text(_de.eventKindPresence));
      await _save(t);
      expect(find.text(_de.eventPresenceStateRequired), findsOneWidget);
      expect(cal.saved, isEmpty);

      await _tap(t, find.bySemanticsLabel(_de.presenceHomeOffice).first);
      expect(find.text(_de.eventPresenceStateRequired), findsNothing);
      await _save(t);
      final json = cal.saved.single.toJson();
      expect(json['kind'], 'presence');
      expect(json['presence_state'], 'home_office');
    });
  });

  group('repeat', () {
    testWidgets('weekly on Mo and Mi is FREQ=WEEKLY;BYDAY=MO,WE', (t) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Dienst');
      await _tap(t, find.text(_de.eventRepeatWeekly));
      await _tap(t, find.widgetWithText(FilterChip, _wd(1)));
      await _save(t);
      expect(cal.saved.single.rrule, 'FREQ=WEEKLY;BYDAY=MO,WE');
    });

    testWidgets('every 2 weeks adds INTERVAL=2', (t) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Turnen');
      await _tap(t, find.text(_de.eventRepeatBiweekly));
      await _save(t);
      expect(cal.saved.single.rrule, 'FREQ=WEEKLY;INTERVAL=2;BYDAY=WE');
    });

    testWidgets('monthly on the last Friday is BYDAY=-1FR', (t) async {
      final cal = FakeCalendarRepository();
      // 30 October 2026 is the last Friday of its month.
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: DateTime(2026, 10, 30)),
      );
      await _title(t, 'Putztag');
      await _tap(t, find.text(_de.eventRepeatMonthly));
      await _tap(
        t,
        find.text(
          _de.eventRepeatMonthlyLast(
            DateFormat.EEEE('de').format(DateTime(2026, 10, 30)),
          ),
        ),
      );
      await _save(t);
      expect(cal.saved.single.rrule, 'FREQ=MONTHLY;BYDAY=-1FR');
    });

    testWidgets('monthly on the second Wednesday is BYDAY=2WE', (t) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Kurs');
      await _tap(t, find.text(_de.eventRepeatMonthly));
      await _tap(t, find.text(_de.eventRepeatMonthlyNth(2, 'Mittwoch')));
      await _save(t);
      expect(cal.saved.single.rrule, 'FREQ=MONTHLY;BYDAY=2WE');
    });

    testWidgets('ends after a count: COUNT=11 after one more', (t) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Kurs');
      await _tap(t, find.text(_de.eventRepeatWeekly));
      await _tap(t, find.text(_de.eventRepeatCount(10)));
      await _tap(t, find.byIcon(Icons.add));
      await _save(t);
      expect(cal.saved.single.rrule, 'FREQ=WEEKLY;BYDAY=WE;COUNT=11');
    });

    testWidgets('ends on a date: UNTIL=YYYYMMDD', (t) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Kurs');
      await _tap(t, find.text(_de.eventRepeatWeekly));
      await _tap(t, find.text(_de.eventRepeatUntil));
      // The button shows the chosen end date; it opens a date picker.
      await _tap(
        t,
        find
            .widgetWithText(
              OutlinedButton,
              DateFormat.MMMMEEEEd('de').format(_day),
            )
            .first,
      );
      await _tap(t, find.text('20'));
      await _tap(t, find.text('OK'));
      await _save(t);
      expect(cal.saved.single.rrule, 'FREQ=WEEKLY;BYDAY=WE;UNTIL=20261020');
    });

    testWidgets('Dienstplan: three tapped days go to rdates, no rrule', (
      t,
    ) async {
      final cal = FakeCalendarRepository();
      await _open(
        t,
        calendar: cal,
        args: EventEditArgs(date: _day),
      );
      await _title(t, 'Schicht');
      await _tap(t, find.text(_de.eventRepeatSpecificDays));
      for (final d in ['20', '21', '22']) {
        await _tap(t, find.text(d));
      }
      await _save(t);
      final json = cal.saved.single.toJson();
      expect(json['rrule'], isNull);
      expect(json['rdates'], ['2026-10-20', '2026-10-21', '2026-10-22']);
    });
  });

  group('existing events', () {
    testWidgets('FREQ=WEEKLY;INTERVAL=2;BYDAY=TU parses to every 2 weeks, Di', (
      t,
    ) async {
      final cal = FakeCalendarRepository(const [], {
        'e-rule': _fixture(
          id: 'e-rule',
          rrule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU',
        ),
      });
      await _open(
        t,
        calendar: cal,
        route: Routes.eventEdit,
        args: const EventEditArgs(eventId: 'e-rule'),
      );
      expect(
        t
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, _de.eventRepeatBiweekly),
            )
            .selected,
        isTrue,
      );
      expect(
        t.widget<FilterChip>(find.widgetWithText(FilterChip, _wd(2))).selected,
        isTrue,
      );
    });

    testWidgets('an unsupported rule shows Eigene Regel and is kept', (
      t,
    ) async {
      const rule = 'FREQ=WEEKLY;BYSETPOS=1;BYDAY=TU';
      final cal = FakeCalendarRepository(const [], {
        'e-custom': _fixture(id: 'e-custom', rrule: rule),
      });
      await _open(
        t,
        calendar: cal,
        route: Routes.eventEdit,
        args: const EventEditArgs(eventId: 'e-custom'),
      );
      expect(find.text(_de.eventCustomRule), findsOneWidget);
      await _save(t);
      expect(cal.saved.single.rrule, rule);
    });

    testWidgets('an end before the start is refused', (t) async {
      final cal = FakeCalendarRepository(const [], {
        'e-bad': _fixture(
          id: 'e-bad',
          startsAt: DateTime(2026, 10, 14, 15),
          endsAt: DateTime(2026, 10, 14, 14),
        ),
      });
      await _open(
        t,
        calendar: cal,
        route: Routes.eventEdit,
        args: const EventEditArgs(eventId: 'e-bad'),
      );
      await _save(t);
      expect(find.text(_de.eventEndBeforeStart), findsOneWidget);
      expect(cal.saved, isEmpty);
    });

    testWidgets('a series occurrence: Nur dieser Termin saves an override', (
      t,
    ) async {
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final recurrenceId = DateTime(monday.year, monday.month, monday.day, 15);
      final series = _fixture(
        id: 'e-series',
        startsAt: recurrenceId,
        rrule:
            'FREQ=WEEKLY;BYDAY=${['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'][monday.weekday - 1]}',
      );
      final occurrence = Occurrence(
        id: 'e-series|${isoDate(monday)}',
        eventId: 'e-series',
        recurrenceId: recurrenceId,
        calendarId: 'cal',
        title: 'Turnen',
        kind: EventKind.appointment,
        status: EventStatus.confirmed,
        importance: Importance.normal,
        allDay: false,
        start: recurrenceId,
        end: recurrenceId.add(const Duration(hours: 1)),
        localStartDate: monday,
        localEndDate: monday,
        localStarts: const TimeOfDay(hour: 15, minute: 0),
        localEnds: const TimeOfDay(hour: 16, minute: 0),
        attendeeIds: const [guardianId],
        isRecurring: true,
      );
      final cal = FakeCalendarRepository([occurrence], {'e-series': series});
      await _app(t, calendar: cal);
      await _tap(t, find.text('Turnen'));

      await _title(t, 'Turnen heute');
      await _save(t);
      await _tap(t, find.text(_de.eventScopeThis));

      expect(cal.saved, isEmpty);
      expect(cal.overrides.single.eventId, 'e-series');
      expect(cal.overrides.single.recurrenceId, recurrenceId);
      expect(cal.overrides.single.cancelled, isFalse);
      expect(cal.overrides.single.patch['title'], 'Turnen heute');
    });

    testWidgets('deleting one occurrence with Nur dieser cancels it', (
      t,
    ) async {
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final recurrenceId = DateTime(monday.year, monday.month, monday.day, 15);
      final occurrence = Occurrence(
        id: 'e-series|${isoDate(monday)}',
        eventId: 'e-series',
        recurrenceId: recurrenceId,
        calendarId: 'cal',
        title: 'Turnen',
        kind: EventKind.appointment,
        status: EventStatus.confirmed,
        importance: Importance.normal,
        allDay: false,
        start: recurrenceId,
        end: recurrenceId.add(const Duration(hours: 1)),
        localStartDate: monday,
        localEndDate: monday,
        localStarts: const TimeOfDay(hour: 15, minute: 0),
        localEnds: const TimeOfDay(hour: 16, minute: 0),
        attendeeIds: const [guardianId],
        isRecurring: true,
      );
      final cal = FakeCalendarRepository(
        [occurrence],
        {
          'e-series': _fixture(
            id: 'e-series',
            startsAt: recurrenceId,
            rrule: 'FREQ=WEEKLY',
          ),
        },
      );
      await _app(t, calendar: cal);
      await _tap(t, find.text('Turnen'));

      await _tap(t, find.byTooltip(_de.delete));
      await _tap(t, find.text(_de.eventScopeThis));

      expect(cal.deleted, isEmpty);
      expect(cal.overrides.single.cancelled, isTrue);
      expect(cal.overrides.single.recurrenceId, recurrenceId);
    });
  });
}
