import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/files/opened_file.dart';
import 'package:wuselwall/features/calendar/application/event_import_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/event_ics.dart';
import 'package:wuselwall/features/calendar/domain/ics_import.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fakes.dart';

final _de = AppLocalizationsDe();

Uint8List _file(List<String> eventLines, {bool calendar = true}) =>
    Uint8List.fromList(
      utf8.encode(
        [
          if (calendar) 'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'BEGIN:VEVENT',
          ...eventLines,
          'END:VEVENT',
          if (calendar) 'END:VCALENDAR',
          '',
        ].join('\r\n'),
      ),
    );

const _spieleabend = [
  'UID:e1@wuselwall.app',
  'SEQUENCE:2',
  'SUMMARY:Spieleabend',
  'DTSTART;TZID=Europe/Zurich:20261114T190000',
  'DTEND;TZID=Europe/Zurich:20261114T220000',
  r'LOCATION:Bei Meiers\, Dorfstrasse 3',
];

void main() {
  late tz.Location berlin;

  setUpAll(() {
    tzdata.initializeTimeZones();
    berlin = tz.getLocation('Europe/Berlin');
  });

  tz.Location? zoneOf(String name) {
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      return null;
    }
  }

  ImportedEvent parse(Uint8List bytes) =>
      parseSharedEvent(bytes, zoneOf: zoneOf, familyZone: berlin);

  Matcher refuses(IcsImportProblem problem) => throwsA(
    isA<IcsImportException>().having((e) => e.problem, 'problem', problem),
  );

  group('parseSharedEvent', () {
    test('reads what the app itself sends', () {
      final sent = renderSharedEvent(
        event: CalendarEvent(
          id: 'e1',
          title: 'Spiele; Abend, mit Meiers',
          description: 'eins\nzwei',
          location: 'Dorfstrasse 3',
          kind: EventKind.appointment,
          isAllDay: false,
          startsAt: DateTime.utc(2026, 11, 14, 18),
          endsAt: DateTime.utc(2026, 11, 14, 21),
          timezone: 'Europe/Zurich',
          rrule: 'FREQ=MONTHLY;BYDAY=2SA',
          exdates: [DateTime(2026, 12, 12)],
          status: EventStatus.tentative,
          uid: 'e1@wuselwall.app',
          sequence: 4,
        ),
        now: DateTime.utc(2026, 11, 11),
        zone: tz.getLocation('Europe/Zurich'),
        includeNote: true,
        reminder: ShareReminder.dayBefore,
      );
      final e = parse(Uint8List.fromList(utf8.encode(sent)));
      expect(e.title, 'Spiele; Abend, mit Meiers');
      expect(e.description, 'eins\nzwei');
      expect(e.location, 'Dorfstrasse 3');
      expect(e.isAllDay, isFalse);
      expect(e.startsAt, DateTime.utc(2026, 11, 14, 18));
      expect(e.endsAt, DateTime.utc(2026, 11, 14, 21));
      expect(e.timezone, 'Europe/Zurich');
      expect(e.rrule, 'FREQ=MONTHLY;BYDAY=2SA');
      expect(e.exdates, [DateTime(2026, 12, 12)]);
      expect(e.uid, 'e1@wuselwall.app');
      expect(e.sequence, 4);
      expect(e.tentative, isTrue);
      expect(e.repeatDropped, isFalse);
    });

    test('an all-day event ends the day before DTEND', () {
      final e = parse(
        _file([
          'UID:a',
          'SUMMARY:Wanderung',
          'DTSTART;VALUE=DATE:20261231',
          'DTEND;VALUE=DATE:20270102',
        ]),
      );
      expect(e.isAllDay, isTrue);
      expect(e.startDate, DateTime(2026, 12, 31));
      expect(e.endDate, DateTime(2027, 1, 1));
      expect(e.startsAt, isNull);
    });

    test('UTC, floating and Outlook times become instants', () {
      DateTime? start(String line) =>
          parse(_file(['UID:a', 'SUMMARY:x', line])).startsAt;
      expect(start('DTSTART:20261114T180000Z'), DateTime.utc(2026, 11, 14, 18));
      // No zone: the family's (Berlin, winter).
      expect(start('DTSTART:20261114T190000'), DateTime.utc(2026, 11, 14, 18));
      expect(
        start('DTSTART;TZID="W. Europe Standard Time":20260714T190000'),
        DateTime.utc(2026, 7, 14, 17),
      );
      expect(
        start('DTSTART;TZID=America/New_York:20261114T190000'),
        DateTime.utc(2026, 11, 15),
      );
      // A zone nobody knows is read as the family's, and not kept.
      final odd = parse(
        _file([
          'UID:a',
          'SUMMARY:x',
          'DTSTART;TZID=Mars/Olympus:20261114T190000',
        ]),
      );
      expect(odd.startsAt, DateTime.utc(2026, 11, 14, 18));
      expect(odd.timezone, isNull);
    });

    test('a missing end is an hour, a duration is added', () {
      final open = parse(
        _file(['UID:a', 'SUMMARY:x', 'DTSTART:20261114T180000Z']),
      );
      expect(open.endsAt, DateTime.utc(2026, 11, 14, 19));
      final lasting = parse(
        _file([
          'UID:a',
          'SUMMARY:x',
          'DTSTART:20261114T180000Z',
          'DURATION:PT2H30M',
        ]),
      );
      expect(lasting.endsAt, DateTime.utc(2026, 11, 14, 20, 30));
      final backwards = parse(
        _file([
          'UID:a',
          'SUMMARY:x',
          'DTSTART:20261114T180000Z',
          'DTEND:20261114T170000Z',
        ]),
      );
      expect(backwards.endsAt, DateTime.utc(2026, 11, 14, 19));
    });

    test('a rule the calendar cannot store is dropped and said', () {
      for (final rule in [
        'FREQ=HOURLY',
        'FREQ=WEEKLY;BYHOUR=9',
        'FREQ=DAILY;COUNT=3;UNTIL=20270101',
        'INTERVAL=2',
        'FREQ=DAILY;FREQ=WEEKLY',
      ]) {
        final e = parse(
          _file([
            'UID:a',
            'SUMMARY:x',
            'DTSTART:20261114T180000Z',
            'RRULE:$rule',
            'EXDATE:20261121T180000Z',
          ]),
        );
        expect(e.rrule, isNull, reason: rule);
        expect(e.repeatDropped, isTrue, reason: rule);
        expect(e.exdates, isEmpty, reason: rule);
      }
      final google = parse(
        _file([
          'UID:a',
          'SUMMARY:x',
          'DTSTART:20261114T180000Z',
          'RRULE:FREQ=WEEKLY;WKST=MO;UNTIL=20270101T000000Z;BYDAY=SA',
        ]),
      );
      expect(
        google.rrule,
        'FREQ=WEEKLY;WKST=MO;UNTIL=20270101T000000Z;BYDAY=SA',
      );
    });

    test('folded lines, alarms and foreign properties', () {
      final e = parse(
        _file([
          'UID:a',
          'SUMMARY:Ein sehr langer ',
          ' Titel',
          'DTSTART:20261114T180000Z',
          'ORGANIZER;CN=Jemand:mailto:jemand@example.org',
          'ATTENDEE:mailto:wir@example.org',
          'ATTACH:https://example.org/x',
          'BEGIN:VALARM',
          'ACTION:DISPLAY',
          'DESCRIPTION:Nicht die Notiz',
          'TRIGGER:-PT1H',
          'END:VALARM',
        ]),
      );
      expect(e.title, 'Ein sehr langer Titel');
      // The alarm's text is not the event's note.
      expect(e.description, isNull);
    });

    test('text is cut to what the server stores and cleaned', () {
      final e = parse(
        _file([
          'UID:${'u' * 600}',
          'SUMMARY:${'ä' * 300}',
          'LOCATION:Zeile eins\\nZeile zwei\u0007',
          'DESCRIPTION:${'x' * 5000}',
          'SEQUENCE:-4',
          'DTSTART:20261114T180000Z',
        ]),
      );
      expect(e.title.runes.length, 200);
      expect(e.location, 'Zeile eins Zeile zwei');
      expect(e.description!.length, 4000);
      // Too long to be kept as an origin: the event is simply a new one.
      expect(e.uid, isNull);
      expect(e.sequence, 0);
    });

    test(
      'a series with its moved dates is one event, a calendar is refused',
      () {
        final series = Uint8List.fromList(
          utf8.encode(
            [
              'BEGIN:VCALENDAR',
              'BEGIN:VEVENT',
              'UID:s',
              'RECURRENCE-ID:20261121T180000Z',
              'SUMMARY:Verschoben',
              'DTSTART:20261121T190000Z',
              'END:VEVENT',
              'BEGIN:VEVENT',
              'UID:s',
              'SUMMARY:Serie',
              'DTSTART:20261114T180000Z',
              'RRULE:FREQ=WEEKLY',
              'END:VEVENT',
              'END:VCALENDAR',
            ].join('\n'),
          ),
        );
        final e = parse(series);
        expect(e.title, 'Serie');
        expect(e.rrule, 'FREQ=WEEKLY');

        final two = Uint8List.fromList(
          utf8.encode(
            [
              'BEGIN:VCALENDAR',
              for (final uid in ['a', 'b']) ...[
                'BEGIN:VEVENT',
                'UID:$uid',
                'SUMMARY:x',
                'DTSTART:20261114T180000Z',
                'END:VEVENT',
              ],
              'END:VCALENDAR',
            ].join('\r\n'),
          ),
        );
        expect(() => parse(two), refuses(IcsImportProblem.severalEvents));
      },
    );

    test('what is no event is refused', () {
      expect(
        () => parse(Uint8List.fromList(utf8.encode('Hallo'))),
        refuses(IcsImportProblem.notAnEvent),
      );
      expect(
        () => parse(_file(_spieleabend, calendar: false)),
        refuses(IcsImportProblem.notAnEvent),
      );
      expect(
        () => parse(_file(['UID:a', 'SUMMARY:x'])),
        refuses(IcsImportProblem.notAnEvent),
      );
      expect(
        () => parse(_file(['UID:a', 'SUMMARY:x', 'DTSTART:gestern'])),
        refuses(IcsImportProblem.notAnEvent),
      );
      expect(
        () => parse(Uint8List(icsImportMaxBytes + 1)),
        refuses(IcsImportProblem.tooLarge),
      );
      expect(
        () => parse(_file([..._spieleabend, 'STATUS:CANCELLED'])),
        refuses(IcsImportProblem.cancelled),
      );
    });

    test('the event becomes the family\'s own', () {
      final event = parse(_file(_spieleabend)).toEvent(
        fallbackTitle: 'Termin',
        attendeeIds: const [guardianId],
        id: 'copy',
      );
      expect(event.id, 'copy');
      expect(event.kind, EventKind.appointment);
      expect(event.title, 'Spieleabend');
      expect(event.location, 'Bei Meiers, Dorfstrasse 3');
      expect(event.attendeeIds, [guardianId]);
      // The file's UID is the origin, never the row's own uid.
      expect(event.toJson().containsKey('uid'), isFalse);
    });
  });

  group('the import page', () {
    Future<({ProviderContainer container, FakeCalendarRepository calendar})>
    open(
      WidgetTester t,
      Uint8List bytes, {
      DeviceInfo? on,
      FakeCalendarRepository? calendar,
    }) async {
      final cal = calendar ?? FakeCalendarRepository();
      final container = await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: on ?? device()),
            now: DateTime(2026, 11, 11, 9, 30),
          ),
        ],
        calendar: cal,
      );
      await openTab(t, 'Kalender');
      unawaited(
        container.read(routerProvider).push(Routes.eventImport, extra: bytes),
      );
      await t.pumpAndSettle();
      return (container: container, calendar: cal);
    }

    final preview = find.byKey(const ValueKey('import-event-preview'));
    final save = find.byKey(const ValueKey('import-event-save'));
    Finder inPreview(String text) =>
        find.descendant(of: preview, matching: find.textContaining(text));

    testWidgets('shows the event and adds it only when asked', (t) async {
      final (:container, :calendar) = await open(t, _file(_spieleabend));
      expect(find.text(_de.eventImportIntro), findsOneWidget);
      expect(inPreview('Spieleabend'), findsOneWidget);
      expect(inPreview('Dorfstrasse 3'), findsOneWidget);
      expect(calendar.imported, isEmpty);
      expect(calendar.saved, isEmpty);

      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();

      final got = calendar.imported.single;
      expect(got.uid, 'e1@wuselwall.app');
      expect(got.sequence, 2);
      expect(got.event.id, isNull);
      expect(got.event.title, 'Spieleabend');
      expect(got.event.startsAt, DateTime.utc(2026, 11, 14, 18));
      expect(got.event.timezone, 'Europe/Zurich');
      // Nobody chosen: the whole family.
      expect(got.event.attendeeIds, isEmpty);
      expect(find.text(_de.eventImportAdded), findsOneWidget);
      expect(preview, findsNothing);
      container.dispose();
    });

    testWidgets('a copy the family already took is updated, with its people', (
      t,
    ) async {
      final calendar = FakeCalendarRepository(const [], {
        'copy': CalendarEvent(
          id: 'copy',
          title: 'Spieleabend alt',
          kind: EventKind.appointment,
          isAllDay: false,
          startsAt: DateTime.utc(2026, 11, 14, 17),
          endsAt: DateTime.utc(2026, 11, 14, 20),
          attendeeIds: const [guardianId],
        ),
      });
      calendar.copies['e1@wuselwall.app'] = const ImportedCopy(
        eventId: 'copy',
        own: false,
        sequence: 1,
      );
      await open(t, _file(_spieleabend), calendar: calendar);
      expect(find.text(_de.eventImportExisting), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, _de.eventImportUpdate),
        findsOneWidget,
      );

      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      final got = calendar.imported.single;
      expect(got.event.id, 'copy');
      expect(got.event.title, 'Spieleabend');
      expect(got.event.attendeeIds, [guardianId]);
      expect(find.text(_de.eventImportUpdated), findsOneWidget);
    });

    testWidgets('the family\'s own event is not added again', (t) async {
      final calendar = FakeCalendarRepository();
      calendar.copies['e1@wuselwall.app'] = const ImportedCopy(
        eventId: 'e1',
        own: true,
      );
      await open(t, _file(_spieleabend), calendar: calendar);
      expect(find.text(_de.eventImportOwn), findsOneWidget);
      expect(save, findsNothing);
      expect(find.byKey(const ValueKey('import-event-open')), findsOneWidget);
    });

    testWidgets('a file that is no event says why and offers nothing', (
      t,
    ) async {
      final (:container, :calendar) = await open(
        t,
        Uint8List.fromList(utf8.encode('Hallo')),
      );
      expect(find.text(_de.eventImportNotAnEvent), findsOneWidget);
      expect(save, findsNothing);
      expect(calendar.imported, isEmpty);
      container.dispose();
    });

    testWidgets('a shared device is turned away', (t) async {
      final (:container, :calendar) = await open(
        t,
        _file(_spieleabend),
        on: device(deviceClass: DeviceClass.shared),
      );
      expect(find.text(_de.eventImportParentsOnly), findsOneWidget);
      expect(save, findsNothing);
      expect(calendar.imported, isEmpty);
      container.dispose();
    });
  });

  group('ways in', () {
    testWidgets('Neuer Termin offers a file to a parent', (t) async {
      final calendar = FakeCalendarRepository();
      await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            now: DateTime(2026, 11, 11, 9, 30),
          ),
          calendarFilePickerProvider.overrideWithValue(
            () async => _file(_spieleabend),
          ),
        ],
        calendar: calendar,
      );
      await openTab(t, 'Kalender');
      await t.tap(
        find.widgetWithText(FloatingActionButton, _de.calendarNewEvent),
      );
      await t.pumpAndSettle();
      final tile = find.byKey(const ValueKey('event-template-file'));
      await t.ensureVisible(tile);
      await t.tap(tile);
      await t.pumpAndSettle();
      expect(find.text(_de.eventImportTitle), findsOneWidget);
      expect(find.textContaining('Spieleabend'), findsOneWidget);
    });

    testWidgets('a file the device opens the app with reaches the page', (
      t,
    ) async {
      final asked = <String>[];
      addTearDown(() => openedFile.value = null);
      await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            now: DateTime(2026, 11, 11, 9, 30),
          ),
          openedFileReaderProvider.overrideWithValue((
            link, {
            required maxBytes,
          }) async {
            asked.add(link);
            return _file(_spieleabend);
          }),
        ],
      );
      openedFile.value = 'content://com.example.provider/files/42';
      await t.pumpAndSettle();
      expect(asked, ['content://com.example.provider/files/42']);
      expect(openedFile.value, isNull);
      expect(find.text(_de.eventImportTitle), findsOneWidget);
      expect(find.textContaining('Spieleabend'), findsOneWidget);
    });

    test('only files on the device count as opened files', () {
      expect(isFileLink('content://x/1'), isTrue);
      expect(isFileLink('file:///private/Inbox/a.ics'), isTrue);
      expect(isFileLink('https://wuselwall.app/i/abc'), isFalse);
      expect(isFileLink('wuselwall://setup'), isFalse);
      expect(isFileLink('nonsense'), isFalse);
    });
  });
}
