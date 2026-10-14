import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';
import 'package:wuselwall/features/calendar/ui/calendar_tiles.dart';
import 'package:wuselwall/features/calendar/ui/event_editor_page.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

import '../support/fake_external_calendars.dart';
import '../support/fakes.dart';

const _binId = 'ext-abfuhr';

/// Monday of the current week plus [offset] days, local midnight.
DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - (now.weekday - 1) + offset);
}

/// An imported all-day appointment (a bin day) in this week.
Occurrence _imported({
  String title = 'Restmüll',
  String calendarId = _binId,
  DateTime? day,
}) {
  final d = dateOnly(day ?? _day(1));
  return Occurrence(
    id: 'imported|$title',
    eventId: '$calendarId|$title',
    calendarId: calendarId,
    title: title,
    kind: EventKind.appointment,
    status: EventStatus.confirmed,
    importance: Importance.normal,
    allDay: true,
    start: d,
    end: DateTime(d.year, d.month, d.day + 1),
    localStartDate: d,
    localEndDate: d,
    source: OccurrenceSource.imported,
    colourHex: '#9A5300',
  );
}

ExternalCalendar _calendar({
  String id = _binId,
  String name = 'Abfuhrkalender',
  bool active = true,
  List<String> memberIds = const [],
  DateTime? lastFetchedAt,
  String? lastError,
}) => ExternalCalendar(
  id: id,
  name: name,
  url: 'https://abfuhr.example.de/k.ics',
  colourHex: '#9A5300',
  memberIds: memberIds,
  showOnBoard: true,
  active: active,
  lastFetchedAt: lastFetchedAt,
  lastError: lastError,
);

Future<ProviderContainer> _open(
  WidgetTester tester, {
  required String route,
  Object? extra,
  FakeExternalCalendarsRepository? calendars,
  FakeCalendarRepository? calendar,
  DeviceInfo? deviceInfo,
}) async {
  final container = await pumpApp(
    tester,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: deviceInfo ?? device()),
      externalCalendars: calendars,
    ),
    calendar: calendar,
  );
  container.read(routerProvider).go(route, extra: extra);
  await tester.pumpAndSettle();
  return container;
}

DeviceInfo _memberDevice() => device(profileId: kidId);

void main() {
  group('imported appointments', () {
    testWidgets('tapping one opens a read-only sheet, never the editor', (
      tester,
    ) async {
      final calendars = FakeExternalCalendarsRepository(
        calendars: [_calendar()],
      );
      await pumpApp(
        tester,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          externalCalendars: calendars,
        ),
        calendar: FakeCalendarRepository([_imported()]),
      );
      await openTab(tester, 'Kalender');

      // The tile's title is rich text (with the subscription mark), so tap the tile.
      await tester.tap(find.byType(OccurrenceTile));
      await tester.pumpAndSettle();

      expect(find.byType(EventEditorPage), findsNothing);
      expect(
        find.text('Abonnierter Kalender — Änderungen kommen von der Quelle'),
        findsOneWidget,
      );
      expect(find.text('Aus Abfuhrkalender'), findsOneWidget);
      expect(find.textContaining('Ganztägig'), findsOneWidget);
    });

    testWidgets(
      'an imported tile carries its calendar colour and a subscription mark',
      (tester) async {
        final occurrence = _imported();
        await pumpApp(
          tester,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            externalCalendars: FakeExternalCalendarsRepository(
              calendars: [_calendar()],
            ),
          ),
          calendar: FakeCalendarRepository([occurrence]),
        );
        await openTab(tester, 'Kalender');

        expect(
          find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.rss_feed),
          findsWidgets,
        );
        final tile = tester.widget<OccurrenceTile>(
          find.byType(OccurrenceTile).first,
        );
        expect(tile.occurrence.isImported, isTrue);
      },
    );
  });

  group('Abonnierte Kalender', () {
    testWidgets('the list shows the status and the friendly error', (
      tester,
    ) async {
      final now = DateTime.now();
      final calendars = FakeExternalCalendarsRepository(
        calendars: [
          _calendar(lastFetchedAt: now.subtract(const Duration(minutes: 12))),
          _calendar(
            id: 'ext-fc',
            name: 'FC Spielplan',
            memberIds: const [kidId],
            lastFetchedAt: now.subtract(const Duration(minutes: 5)),
            lastError: 'http_404',
          ),
          _calendar(id: 'ext-new-one', name: 'Neu'),
        ],
      );
      await _open(
        tester,
        route: Routes.externalCalendars,
        calendars: calendars,
      );

      expect(find.text('Abfuhrkalender'), findsOneWidget);
      expect(find.text('Ganze Familie'), findsNWidgets(2));
      expect(find.text('Aktualisiert vor 12 Min.'), findsOneWidget);
      expect(find.text('Adresse nicht gefunden (404).'), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Wird zum ersten Mal geladen …'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(3));
    });

    testWidgets('refresh now runs the on-demand fetch and shows its result', (
      tester,
    ) async {
      final calendars = FakeExternalCalendarsRepository(
        calendars: [_calendar()],
      );
      await _open(
        tester,
        route: Routes.externalCalendars,
        calendars: calendars,
      );

      await tester.tap(find.text('Jetzt aktualisieren'));
      await tester.pumpAndSettle();

      expect(calendars.refreshed, [(actor: guardianId, calendarId: _binId)]);
      expect(find.text('3 Termine geladen'), findsOneWidget);
    });

    testWidgets('a member sees the list read-only', (tester) async {
      final calendars = FakeExternalCalendarsRepository(
        calendars: [_calendar()],
      );
      await _open(
        tester,
        route: Routes.externalCalendars,
        calendars: calendars,
        deviceInfo: _memberDevice(),
      );

      expect(find.text('Abfuhrkalender'), findsOneWidget);
      expect(
        find.text('Nur Eltern können Kalender abonnieren oder ändern.'),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Jetzt aktualisieren'), findsNothing);
      expect(find.text('Bearbeiten'), findsNothing);
      expect(find.text('Löschen'), findsNothing);
    });

    testWidgets('delete asks first, then removes that calendar', (
      tester,
    ) async {
      final calendars = FakeExternalCalendarsRepository(
        calendars: [_calendar()],
      );
      await _open(
        tester,
        route: Routes.externalCalendars,
        calendars: calendars,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
      await tester.pumpAndSettle();
      expect(calendars.deleted, isEmpty, reason: 'confirmation comes first');

      await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
      await tester.pumpAndSettle();
      expect(calendars.deleted, [(actor: guardianId, id: _binId)]);
    });
  });

  group('the form', () {
    testWidgets('a new calendar saves the right JSON and fetches at once', (
      tester,
    ) async {
      final calendars = FakeExternalCalendarsRepository();
      await _open(
        tester,
        route: Routes.externalCalendarNew,
        calendars: calendars,
      );

      await tester.enterText(find.byType(TextField).at(0), 'FC Spielplan');
      await tester.enterText(
        find.byType(TextField).at(1),
        'webcal://fc.example.de/spiel.ics',
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();

      expect(calendars.saved, hasLength(1));
      expect(calendars.saved.single.actor, guardianId);
      expect(calendars.saved.single.draft.toJson(), {
        'name': 'FC Spielplan',
        'url': 'https://fc.example.de/spiel.ics',
        'colour_hex': toHex(MemberPalette.swatches.first.light),
        'member_ids': [kidId],
        'show_on_board': true,
      });
      expect(calendars.refreshed, [(actor: guardianId, calendarId: 'ext-new')]);
      expect(find.text('3 Termine geladen'), findsOneWidget);
    });

    testWidgets('an edit sends the id and keeps the rest as stored', (
      tester,
    ) async {
      final calendars = FakeExternalCalendarsRepository(
        calendars: [_calendar()],
      );
      await _open(
        tester,
        route: Routes.externalCalendarEdit,
        extra: _calendar(name: 'Abfuhr 2027'),
        calendars: calendars,
      );

      expect(find.text('Abfuhr 2027'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();

      expect(calendars.saved.single.draft.toJson(), {
        'id': _binId,
        'name': 'Abfuhr 2027',
        'url': 'https://abfuhr.example.de/k.ics',
        'colour_hex': '#9A5300',
        'member_ids': <String>[],
        'show_on_board': true,
      });
    });

    testWidgets('an address that is not https is refused before saving', (
      tester,
    ) async {
      final calendars = FakeExternalCalendarsRepository();
      await _open(
        tester,
        route: Routes.externalCalendarNew,
        calendars: calendars,
      );

      await tester.enterText(find.byType(TextField).at(0), 'Verein');
      await tester.enterText(
        find.byType(TextField).at(1),
        'ftp://verein.example.de/k.ics',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Das sieht nicht nach einer Internet-Adresse aus (https://…).',
        ),
        findsOneWidget,
      );
      expect(calendars.saved, isEmpty);
    });
  });
}
