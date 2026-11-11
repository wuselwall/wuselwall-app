import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/event_ics.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/household_export_providers.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fakes.dart';

final _de = AppLocalizationsDe();
final _now = DateTime.utc(2026, 11, 11, 8);

CalendarEvent _event({
  String title = 'Spieleabend',
  String? description = 'Lotta bringt Kuchen mit',
  String? location = 'Bei uns, Dorfstrasse 3',
  String? rrule,
  List<DateTime> exdates = const [],
  EventStatus status = EventStatus.confirmed,
}) => CalendarEvent(
  id: 'e1',
  title: title,
  description: description,
  location: location,
  kind: EventKind.appointment,
  isAllDay: false,
  // 19:00–22:00 in Zurich, winter time.
  startsAt: DateTime.utc(2026, 11, 14, 18),
  endsAt: DateTime.utc(2026, 11, 14, 21),
  timezone: 'Europe/Zurich',
  rrule: rrule,
  exdates: exdates,
  status: status,
  uid: 'e1@wuselwall.app',
  sequence: 3,
  attendeeIds: const [guardianId],
);

/// The unfolded content lines of [ics].
List<String> _lines(String ics) =>
    ics.replaceAll('\r\n ', '').trimRight().split('\r\n');

void main() {
  late tz.Location zurich;

  setUpAll(() {
    tzdata.initializeTimeZones();
    zurich = tz.getLocation('Europe/Zurich');
  });

  group('renderSharedEvent', () {
    test('writes one event in its own zone, without people or the note', () {
      final ics = renderSharedEvent(event: _event(), now: _now, zone: zurich);
      final lines = _lines(ics);

      expect(lines.first, 'BEGIN:VCALENDAR');
      expect(lines.last, 'END:VCALENDAR');
      expect(lines, contains('METHOD:PUBLISH'));
      expect(lines.where((l) => l == 'BEGIN:VEVENT'), hasLength(1));
      expect(lines, contains('DTSTART;TZID=Europe/Zurich:20261114T190000'));
      expect(lines, contains('DTEND;TZID=Europe/Zurich:20261114T220000'));
      expect(lines, contains('UID:e1@wuselwall.app'));
      expect(lines, contains('SEQUENCE:3'));
      expect(lines, contains('DTSTAMP:20261111T080000Z'));
      expect(lines, contains('SUMMARY:Spieleabend'));
      expect(lines, contains(r'LOCATION:Bei uns\, Dorfstrasse 3'));
      expect(lines, contains('STATUS:CONFIRMED'));
      // No return channel, nobody named, nothing the family did not choose to send.
      for (final name in ['ORGANIZER', 'ATTENDEE', 'DESCRIPTION', 'VALARM']) {
        expect(ics, isNot(contains(name)), reason: name);
      }
      expect(ics, isNot(contains(guardianId)));
      expect(ics, isNot(contains('X-WR-CALNAME')));
    });

    test('the zone block covers the event year with its real transitions', () {
      final lines = _lines(
        renderSharedEvent(event: _event(), now: _now, zone: zurich),
      );
      final from = lines.indexOf('BEGIN:VTIMEZONE');
      final to = lines.indexOf('END:VTIMEZONE');
      final block = lines.sublist(from, to);
      expect(block, contains('TZID:Europe/Zurich'));
      // 2026: winter at the start, summer on 29 March, winter on 25 October.
      expect(block.where((l) => l == 'BEGIN:STANDARD'), hasLength(2));
      expect(block.where((l) => l == 'BEGIN:DAYLIGHT'), hasLength(1));
      expect(block, contains('DTSTART:20260329T020000'));
      expect(block, contains('DTSTART:20261025T030000'));
      expect(block, contains('TZOFFSETTO:+0200'));
      expect(to, lessThan(lines.indexOf('BEGIN:VEVENT')));
    });

    test('the note and a reminder come along only when asked', () {
      final lines = _lines(
        renderSharedEvent(
          event: _event(),
          now: _now,
          zone: zurich,
          includeNote: true,
          reminder: ShareReminder.dayBefore,
        ),
      );
      expect(lines, contains('DESCRIPTION:Lotta bringt Kuchen mit'));
      final alarm = lines.sublist(
        lines.indexOf('BEGIN:VALARM'),
        lines.indexOf('END:VALARM'),
      );
      expect(alarm, contains('ACTION:DISPLAY'));
      expect(alarm, contains('TRIGGER:-P1D'));
      expect(alarm, contains('DESCRIPTION:Spieleabend'));
    });

    test('a series keeps its rule and its cancelled dates', () {
      final lines = _lines(
        renderSharedEvent(
          event: _event(
            rrule: 'FREQ=MONTHLY;BYDAY=2SA',
            exdates: [DateTime(2026, 12, 12)],
          ),
          now: _now,
          zone: zurich,
        ),
      );
      expect(lines, contains('RRULE:FREQ=MONTHLY;BYDAY=2SA'));
      expect(lines, contains('EXDATE;TZID=Europe/Zurich:20261212T190000'));
      // Three years of transitions: the rule is open-ended.
      expect(lines, contains('DTSTART:20280326T020000'));
    });

    test('one date of a series is an event of its own', () {
      final at = DateTime.utc(2026, 12, 12, 18);
      final occurrence = Occurrence(
        id: 'e1:2026-12-12',
        eventId: 'e1',
        recurrenceId: at,
        calendarId: 'c1',
        title: 'Spieleabend bei Meiers',
        location: 'Bei Meiers',
        kind: EventKind.appointment,
        status: EventStatus.tentative,
        importance: Importance.normal,
        allDay: false,
        // Moved by an hour for this date.
        start: at.add(const Duration(hours: 1)),
        end: at.add(const Duration(hours: 4)),
        localStartDate: DateTime(2026, 12, 12),
        localEndDate: DateTime(2026, 12, 12),
        isRecurring: true,
        isOverride: true,
      );
      final lines = _lines(
        renderSharedEvent(
          event: _event(rrule: 'FREQ=MONTHLY;BYDAY=2SA'),
          now: _now,
          zone: zurich,
          occurrence: occurrence,
        ),
      );
      expect(lines, contains('DTSTART;TZID=Europe/Zurich:20261212T200000'));
      expect(lines, contains('UID:20261212T180000Z-e1@wuselwall.app'));
      expect(lines, contains('SUMMARY:Spieleabend bei Meiers'));
      expect(lines, contains('LOCATION:Bei Meiers'));
      expect(lines, contains('STATUS:TENTATIVE'));
      expect(lines.where((l) => l.startsWith('RRULE')), isEmpty);
    });

    test('an all-day event ends the day after, reminded at nine', () {
      final lines = _lines(
        renderSharedEvent(
          event: CalendarEvent(
            id: 'e2',
            title: 'Wanderung',
            kind: EventKind.appointment,
            isAllDay: true,
            startDate: DateTime(2026, 12, 31),
            endDate: DateTime(2027, 1, 1),
            timezone: 'Europe/Zurich',
            uid: 'e2@wuselwall.app',
          ),
          now: _now,
          zone: zurich,
          reminder: ShareReminder.dayBefore,
        ),
      );
      expect(lines, contains('DTSTART;VALUE=DATE:20261231'));
      expect(lines, contains('DTEND;VALUE=DATE:20270102'));
      expect(lines, contains('TRIGGER:-PT15H'));
      expect(lines, isNot(contains('BEGIN:VTIMEZONE')));
    });

    test('without a known zone the time is written in UTC', () {
      final lines = _lines(renderSharedEvent(event: _event(), now: _now));
      expect(lines, contains('DTSTART:20261114T180000Z'));
      expect(lines, contains('DTEND:20261114T210000Z'));
      expect(lines, isNot(contains('BEGIN:VTIMEZONE')));
    });

    test('text is escaped and long lines are folded at 75 octets', () {
      final title = 'Spiele; Abend, ${'ä' * 60}';
      final ics = renderSharedEvent(
        event: _event(title: title, description: 'eins\nzwei'),
        now: _now,
        zone: zurich,
        includeNote: true,
      );
      for (final line in ics.trimRight().split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      final lines = _lines(ics);
      expect(lines, contains('SUMMARY:Spiele\\; Abend\\, ${'ä' * 60}'));
      expect(lines, contains(r'DESCRIPTION:eins\nzwei'));
    });
  });

  test('the file is named after the title', () {
    expect(sharedEventFileName('Spieleabend'), 'Spieleabend.ics');
    expect(sharedEventFileName(' Zoo / Ausflug! '), 'Zoo-Ausflug.ics');
    expect(sharedEventFileName('Grüße 🎲'), 'Grüße.ics');
    expect(sharedEventFileName('…'), 'event.ics');
    expect(sharedEventFileName('a' * 80), '${'a' * 40}.ics');
  });

  group('the editor', () {
    const shareButton = ValueKey('event-share');

    Future<List<({String fileName, Uint8List bytes, String mimeType})>> open(
      WidgetTester t, {
      DeviceInfo? on,
      CalendarEvent? event,
    }) async {
      final shares = <({String fileName, Uint8List bytes, String mimeType})>[];
      final container = await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: on ?? device()),
            now: DateTime(2026, 11, 11, 9, 30),
          ),
          shareExportProvider.overrideWithValue(({
            required String fileName,
            required Uint8List bytes,
            required String mimeType,
            Rect? origin,
          }) async {
            shares.add((fileName: fileName, bytes: bytes, mimeType: mimeType));
          }),
        ],
        calendar: FakeCalendarRepository(const [], {'e1': event ?? _event()}),
      );
      await openTab(t, 'Kalender');
      unawaited(
        container
            .read(routerProvider)
            .push(Routes.eventEdit, extra: const EventEditArgs(eventId: 'e1')),
      );
      await t.pumpAndSettle();
      return shares;
    }

    testWidgets('shows what leaves, then hands over one calendar file', (
      t,
    ) async {
      final shares = await open(t);
      await t.tap(find.byKey(shareButton));
      await t.pumpAndSettle();

      final preview = find.byKey(const ValueKey('share-event-preview'));
      Finder inPreview(String text) =>
          find.descendant(of: preview, matching: find.textContaining(text));
      expect(inPreview('Spieleabend'), findsOneWidget);
      expect(inPreview('19:00'), findsOneWidget);
      expect(inPreview('Dorfstrasse 3'), findsOneWidget);
      // The note stays at home until it is switched on.
      expect(inPreview('Kuchen'), findsNothing);
      expect(find.text(_de.eventShareNotSent), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('share-event-note')));
      await t.pumpAndSettle();
      expect(inPreview('Kuchen'), findsOneWidget);
      await t.tap(
        find.byKey(const ValueKey('share-event-reminder-hourBefore')),
      );
      await t.pumpAndSettle();
      final send = find.byKey(const ValueKey('share-event-send'));
      await t.ensureVisible(send);
      await t.tap(send);
      await t.pumpAndSettle();

      final share = shares.single;
      expect(share.fileName, 'Spieleabend.ics');
      expect(share.mimeType, 'text/calendar');
      final lines = _lines(utf8.decode(share.bytes));
      expect(lines, contains('DTSTART;TZID=Europe/Zurich:20261114T190000'));
      expect(lines, contains('DESCRIPTION:Lotta bringt Kuchen mit'));
      expect(lines, contains('TRIGGER:-PT1H'));
      // The sheet has closed.
      expect(send, findsNothing);
    });

    testWidgets('a shared device offers no sharing', (t) async {
      await open(t, on: device(deviceClass: DeviceClass.shared));
      expect(find.byKey(shareButton), findsNothing);
    });

    testWidgets('a presence entry offers no sharing', (t) async {
      await open(
        t,
        event: CalendarEvent(
          id: 'e1',
          title: 'Büro',
          kind: EventKind.presence,
          presenceState: PresenceState.working,
          isAllDay: false,
          startsAt: DateTime.utc(2026, 11, 14, 7),
          endsAt: DateTime.utc(2026, 11, 14, 16),
          timezone: 'Europe/Zurich',
        ),
      );
      expect(find.byKey(shareButton), findsNothing);
    });
  });
}
