import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_import_sheet.dart';
import 'package:wuselwall/features/trips/ui/trip_page.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_trips.dart';
import '../support/fakes.dart';

final _de = AppLocalizationsDe();

Uint8List _file(List<List<String>> events) => Uint8List.fromList(
  utf8.encode(
    [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      for (final lines in events) ...['BEGIN:VEVENT', ...lines, 'END:VEVENT'],
      'END:VCALENDAR',
      '',
    ].join('\r\n'),
  ),
);

const _flight = [
  'UID:flight@example.org',
  'SUMMARY:Flug Zürich - Olbia',
  'DTSTART;TZID=Europe/Zurich:20261127T104000',
  'DTEND;TZID=Europe/Zurich:20261127T123000',
];
const _hotel = [
  'UID:hotel@example.org',
  'SUMMARY:Hotel Mare',
  'DTSTART;VALUE=DATE:20261127',
  'DTEND;VALUE=DATE:20261206',
  'LOCATION:Via Roma 3\\, Olbia',
];
const _cancelled = [
  'UID:gone@example.org',
  'SUMMARY:Abgesagt',
  'STATUS:CANCELLED',
  'DTSTART:20261201T090000Z',
];

final _sardinia = Trip(
  id: 't1',
  title: 'Sardinien',
  iconKey: 'beach',
  stage: TripStage.fixed,
  startsOn: DateTime(2026, 11, 27),
  endsOn: DateTime(2026, 12, 6),
);

final _ski = Trip(
  id: 't2',
  title: 'Skiwoche',
  stage: TripStage.planned,
  startsOn: DateTime(2027, 2, 20),
  endsOn: DateTime(2027, 2, 27),
);

final _idea = const Trip(id: 't3', title: 'Nordsee');

Future<FakeTripsRepository> _open(
  WidgetTester t,
  Uint8List bytes, {
  List<Trip>? trips,
  Size size = const Size(390, 1000),
}) async {
  final repo = FakeTripsRepository(trips: trips ?? [_sardinia, _ski, _idea]);
  final container = await pumpApp(
    t,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device()),
      trips: repo,
      now: DateTime(2026, 11, 11, 9, 30),
    ),
    size: size,
  );
  await openTab(t, 'Kalender');
  unawaited(
    container.read(routerProvider).push(Routes.eventImport, extra: bytes),
  );
  await t.pumpAndSettle();
  return repo;
}

final _toTrip = find.byKey(const ValueKey('import-event-to-trip'));
final _confirm = find.byKey(const ValueKey('trip-import-confirm'));

/// specs/30 "A booking's calendar file".
void main() {
  group('a file with one event', () {
    testWidgets('keeps the import and offers the trip beside it', (t) async {
      await _open(t, _file([_flight]));
      expect(find.byKey(const ValueKey('import-event-save')), findsOneWidget);
      expect(_toTrip, findsOneWidget);
      expect(find.text(_de.tripImportAction), findsOneWidget);
    });

    testWidgets('has no trip button when there is no upcoming trip', (t) async {
      await _open(t, _file([_flight]), trips: [_idea]);
      expect(find.byKey(const ValueKey('import-event-save')), findsOneWidget);
      expect(_toTrip, findsNothing);
    });
  });

  group('a file with several events', () {
    testWidgets('is offered to a trip instead of only refused', (t) async {
      await _open(t, _file([_flight, _hotel]));
      expect(find.text(_de.tripImportSeveral), findsOneWidget);
      expect(find.text(_de.eventImportSeveral), findsNothing);
      expect(_toTrip, findsOneWidget);
      expect(find.byKey(const ValueKey('import-event-save')), findsNothing);
    });

    testWidgets('is still refused when the family has no trip to offer', (
      t,
    ) async {
      await _open(t, _file([_flight, _hotel]), trips: [_idea]);
      expect(find.text(_de.eventImportSeveral), findsOneWidget);
      expect(_toTrip, findsNothing);
    });

    testWidgets('lists the upcoming trips, then what would be added', (
      t,
    ) async {
      await _open(t, _file([_flight, _hotel, _cancelled]));
      await t.tap(_toTrip);
      await t.pumpAndSettle();
      // Planned and fixed trips with dates; an idea is not on the list.
      expect(find.text(_de.tripImportTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-import-t1')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-import-t2')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-import-t3')), findsNothing);

      await t.tap(find.byKey(const ValueKey('trip-import-t1')));
      await t.pumpAndSettle();
      expect(find.text(_de.tripImportEntries(2)), findsOneWidget);
      expect(find.text('Flug Zürich - Olbia'), findsOneWidget);
      expect(find.text('Hotel Mare'), findsOneWidget);
      // The guessed kind with its time, and the cancelled event counted.
      expect(
        find.textContaining('10:40 · ${_de.tripModeFlight}'),
        findsOneWidget,
      );
      expect(find.textContaining(_de.tripKindStay), findsOneWidget);
      expect(find.text(_de.tripImportSkipped(1)), findsOneWidget);
      expect(find.byIcon(Icons.flight_outlined), findsOneWidget);
      expect(find.byIcon(Icons.hotel_outlined), findsOneWidget);
    });

    testWidgets('adds the entries to the chosen trip and opens it', (t) async {
      final repo = await _open(t, _file([_flight, _hotel]));
      await t.tap(_toTrip);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('trip-import-t1')));
      await t.pumpAndSettle();
      expect(repo.imports, isEmpty);

      await t.tap(_confirm);
      await t.pumpAndSettle();
      final sent = repo.imports.single;
      expect(sent.tripId, 't1');
      expect(sent.entries.map((e) => e.title), [
        'Flug Zürich - Olbia',
        'Hotel Mare',
      ]);
      expect(sent.entries.map((e) => e.sourceUid), [
        'flight@example.org',
        'hotel@example.org',
      ]);
      expect(sent.entries.first.kind, EntryKind.transport);
      expect(sent.entries.first.mode, TransportMode.flight);
      expect(sent.entries.first.state, EntryState.booked);
      expect(sent.entries.last.kind, EntryKind.stay);
      expect(sent.entries.last.address, 'Via Roma 3, Olbia');
      expect(find.text(_de.tripImportDone(2, 0)), findsOneWidget);
      expect(find.byType(TripPage), findsOneWidget);
    });

    testWidgets('the same file again updates instead of doubling', (t) async {
      final repo = await _open(t, _file([_flight, _hotel]));
      repo.entryList.add(
        const TripEntry(
          id: 'old',
          tripId: 't1',
          kind: EntryKind.stay,
          title: 'Hotel alt',
          sourceUid: 'hotel@example.org',
        ),
      );
      await t.tap(_toTrip);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('trip-import-t1')));
      await t.pumpAndSettle();
      await t.tap(_confirm);
      await t.pumpAndSettle();
      expect(find.text(_de.tripImportDone(1, 1)), findsOneWidget);
      expect(repo.entryList.where((e) => e.tripId == 't1'), hasLength(2));
    });

    testWidgets('one upcoming trip needs no choosing', (t) async {
      await _open(t, _file([_flight, _hotel]), trips: [_sardinia, _idea]);
      await t.tap(_toTrip);
      await t.pumpAndSettle();
      expect(find.text(_de.tripImportEntries(2)), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-import-t1')), findsNothing);
      expect(_confirm, findsOneWidget);
    });

    testWidgets('a failed write keeps the sheet and says so', (t) async {
      final repo = await _open(
        t,
        _file([_flight, _hotel]),
        trips: [_sardinia, _idea],
      );
      await t.tap(_toTrip);
      await t.pumpAndSettle();
      repo.failure = const NetworkFailure();
      await t.tap(_confirm);
      await t.pumpAndSettle();
      expect(find.byType(TripImportSheet), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(repo.imports, isEmpty);
    });

    for (final size in const [Size(360, 800), Size(1000, 800)]) {
      testWidgets('lays out at ${size.width.round()} px', (t) async {
        await _open(t, _file([_flight, _hotel]), size: size);
        await t.tap(_toTrip);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('trip-import-t1')));
        await t.pumpAndSettle();
        expect(_confirm, findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  });
}
