import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/domain/trip_plan.dart';
import 'package:wuselwall/features/trips/ui/trip_page.dart';
import 'package:wuselwall/features/trips/ui/trip_today_card.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_trips.dart';
import '../support/fakes.dart';

final _de = AppLocalizationsDe();

Trip _trip({
  TripStage stage = TripStage.fixed,
  DateTime? startsOn,
  DateTime? endsOn,
}) => Trip(
  id: 't1',
  title: 'Sardinien',
  iconKey: 'beach',
  stage: stage,
  startsOn: startsOn ?? DateTime(2026, 11, 27),
  endsOn: endsOn ?? DateTime(2026, 12, 6),
);

TripCheck _todo(String id, String title, {bool done = false}) => TripCheck(
  id: id,
  tripId: 't1',
  kind: CheckKind.todo,
  title: title,
  dueDaysBefore: 14,
  doneAt: done ? DateTime(2026, 11, 1) : null,
);

TripCheck _pack(String id, {bool done = false}) => TripCheck(
  id: id,
  tripId: 't1',
  kind: CheckKind.pack,
  title: 'Item $id',
  doneAt: done ? DateTime(2026, 11, 1) : null,
);

final _entries = [
  TripEntry(
    id: 'stay',
    tripId: 't1',
    kind: EntryKind.stay,
    title: 'Hotel Mare',
    state: EntryState.booked,
    address: 'Via Roma 3, Olbia',
    phone: '+39 0789 1234',
    startsOn: DateTime(2026, 11, 27),
    endsOn: DateTime(2026, 12, 6),
  ),
  TripEntry(
    id: 'ferry',
    tripId: 't1',
    kind: EntryKind.transport,
    mode: TransportMode.ferry,
    title: 'Fähre nach Olbia',
    state: EntryState.booked,
    startsOn: DateTime(2026, 11, 29),
    startsTime: const TimeOfDay(hour: 21, minute: 30),
    endsOn: DateTime(2026, 11, 30),
    endsTime: const TimeOfDay(hour: 7, minute: 0),
  ),
  TripEntry(
    id: 'boat',
    tripId: 't1',
    kind: EntryKind.activity,
    title: 'Bootstour',
    state: EntryState.chosen,
    startsOn: DateTime(2026, 11, 29),
    startsTime: const TimeOfDay(hour: 10, minute: 0),
  ),
  TripEntry(
    id: 'hike',
    tripId: 't1',
    kind: EntryKind.activity,
    title: 'Wanderung',
    state: EntryState.chosen,
    startsOn: DateTime(2026, 11, 30),
    startsTime: const TimeOfDay(hour: 9, minute: 0),
  ),
];

Future<ProviderContainer> _today(
  WidgetTester t,
  FakeTripsRepository trips, {
  DateTime? now,
  Size size = const Size(390, 1200),
  DeviceInfo? on,
  AppConfig? config,
}) async {
  final container = await pumpApp(
    t,
    overrides: [
      ...baseOverrides(
        identity: FakeIdentityRepository(current: on ?? device()),
        trips: trips,
        now: now ?? DateTime(2026, 11, 15, 9),
        appConfig: config,
      ),
    ],
    size: size,
  );
  await t.tap(find.text('Heute').last);
  await t.pumpAndSettle();
  return container;
}

final _card = find.byKey(const ValueKey('trip-today-card'));

/// specs/30 "During the trip": the card on Heute.
void main() {
  group('before the trip', () {
    testWidgets('says when, what is due and how far packing is', (t) async {
      await _today(
        t,
        FakeTripsRepository(
          trips: [_trip()],
          checks: [
            _todo('a', 'Fähre buchen'),
            _todo('b', 'Sonnencreme kaufen'),
            _todo('c', 'Pass erneuern'),
            _todo('d', 'Post umleiten'),
            _todo('e', 'Schon erledigt', done: true),
            _pack('p1', done: true),
            _pack('p2'),
            _pack('p3'),
            _pack('p4'),
          ],
        ),
      );
      expect(_card, findsOneWidget);
      expect(find.text('Sardinien'), findsOneWidget);
      expect(find.text(_de.countdownInDays(12)), findsOneWidget);
      expect(find.text(_de.tripTodayTodos), findsOneWidget);
      // Three of the four due to-dos, then how many more.
      expect(find.text('Fähre buchen'), findsOneWidget);
      expect(find.text('Sonnencreme kaufen'), findsOneWidget);
      expect(find.text('Pass erneuern'), findsOneWidget);
      expect(find.text('Post umleiten'), findsNothing);
      expect(find.text('Schon erledigt'), findsNothing);
      expect(find.text(_de.tripTodayMore(1)), findsOneWidget);
      expect(find.text(_de.tripTodayPacked(1, 4)), findsOneWidget);
      final bar = t.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('trip-today-packing')),
      );
      expect(bar.value, 0.25);
      // Nothing of the running trip.
      expect(find.text(_de.tripTodayTonight), findsNothing);
    });

    testWidgets('opens the trip', (t) async {
      await _today(t, FakeTripsRepository(trips: [_trip()]));
      await t.tap(_card);
      await t.pumpAndSettle();
      expect(find.byType(TripPage), findsOneWidget);
    });

    testWidgets('has no list and no bar when there is nothing to show', (
      t,
    ) async {
      await _today(t, FakeTripsRepository(trips: [_trip()]));
      expect(_card, findsOneWidget);
      expect(find.text(_de.tripTodayTodos), findsNothing);
      expect(find.byKey(const ValueKey('trip-today-packing')), findsNothing);
    });

    testWidgets('stays away for an idea, a far trip and a past one', (t) async {
      await _today(
        t,
        FakeTripsRepository(
          trips: [
            _trip(stage: TripStage.idea),
            Trip(
              id: 'far',
              title: 'Weit weg',
              stage: TripStage.fixed,
              startsOn: DateTime(2027, 3, 1),
              endsOn: DateTime(2027, 3, 8),
            ),
            Trip(
              id: 'past',
              title: 'Vorbei',
              stage: TripStage.fixed,
              startsOn: DateTime(2026, 10, 1),
              endsOn: DateTime(2026, 10, 8),
            ),
          ],
        ),
      );
      expect(_card, findsNothing);
    });

    testWidgets('stays away on a server without trips', (t) async {
      await _today(
        t,
        FakeTripsRepository(trips: [_trip()]),
        // A server that answers, and does not list the trips.
        config: AppConfig(
          environment: 'test',
          supabaseUrl: 'https://example.org',
          supabasePublishableKey: 'demo',
          server: ServerInfo(
            supabaseUrl: Uri.parse('https://example.org'),
            publishableKey: 'demo',
            apiVersion: 1,
            minAppVersion: '1.0.0',
          ),
        ),
      );
      expect(_card, findsNothing);
    });
  });

  group('during the trip', () {
    final now = DateTime(2026, 11, 29, 8);

    Future<void> run(WidgetTester t, {Size? size}) async => _today(
      t,
      FakeTripsRepository(trips: [_trip()], entries: _entries),
      now: now,
      size: size ?? const Size(390, 1200),
    );

    testWidgets('names the day, today, tonight and tomorrow', (t) async {
      await run(t);
      expect(find.text(_de.tripTodayDayOf(3, 10)), findsOneWidget);
      // Today's items in time order, the ferry with its role word.
      expect(find.text('Bootstour'), findsOneWidget);
      expect(
        find.text('${_de.tripTodayDeparture} · Fähre nach Olbia'),
        findsOneWidget,
      );
      expect(
        t.getTopLeft(find.text('Bootstour')).dy,
        lessThan(
          t
              .getTopLeft(
                find.text('${_de.tripTodayDeparture} · Fähre nach Olbia'),
              )
              .dy,
        ),
      );
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('21:30'), findsOneWidget);
      // Where the family sleeps, with the address and the phone.
      expect(find.text(_de.tripTodayTonight), findsOneWidget);
      expect(find.text('Hotel Mare'), findsOneWidget);
      expect(find.text('Via Roma 3, Olbia'), findsOneWidget);
      expect(find.byTooltip(_de.tripTodayMap), findsOneWidget);
      expect(find.byTooltip(_de.tripTodayCall), findsOneWidget);
      // Tomorrow's first item: the ferry's arrival comes before the hike.
      expect(find.text(_de.tripTodayTomorrow), findsOneWidget);
      expect(
        find.text('${_de.tripTodayArrival} · Fähre nach Olbia'),
        findsOneWidget,
      );
      // Not the before's words.
      expect(find.text(_de.tripTodayTodos), findsNothing);
    });

    testWidgets('says so on a day without a plan', (t) async {
      await _today(t, FakeTripsRepository(trips: [_trip()]), now: now);
      expect(find.text(_de.tripTodayNothing), findsOneWidget);
      expect(find.text(_de.tripTodayTonight), findsNothing);
    });

    for (final size in const [Size(360, 800), Size(1000, 800)]) {
      testWidgets('lays out at ${size.width.round()} px', (t) async {
        await run(t, size: size);
        expect(_card, findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('the address and the phone have no action without them', (
      t,
    ) async {
      await _today(
        t,
        FakeTripsRepository(
          trips: [_trip()],
          entries: [
            TripEntry(
              id: 'stay',
              tripId: 't1',
              kind: EntryKind.stay,
              title: 'Zelt',
              state: EntryState.booked,
              startsOn: DateTime(2026, 11, 27),
              endsOn: DateTime(2026, 12, 6),
            ),
          ],
        ),
        now: now,
      );
      expect(find.text('Zelt'), findsOneWidget);
      expect(find.byTooltip(_de.tripTodayMap), findsNothing);
      expect(find.byTooltip(_de.tripTodayCall), findsNothing);
    });
  });

  group('the role words', () {
    PlanItem item(EntryKind kind, PlanRole role) => PlanItem(
      TripEntry(id: 'e', tripId: 't1', kind: kind, title: 'X'),
      role,
    );
    String? word(EntryKind kind, PlanRole role) =>
        tripTodayRole(_de, item(kind, role));

    test('follow the kind and the day of an entry', () {
      expect(word(EntryKind.stay, PlanRole.start), 'Einchecken');
      expect(word(EntryKind.stay, PlanRole.end), 'Auschecken');
      expect(word(EntryKind.rental, PlanRole.start), _de.tripTodayPickUp);
      expect(word(EntryKind.rental, PlanRole.end), _de.tripTodayReturn);
      expect(word(EntryKind.transport, PlanRole.start), 'Abfahrt');
      expect(word(EntryKind.transport, PlanRole.end), 'Ankunft');
    });

    test('an entry of one day has none', () {
      expect(word(EntryKind.transport, PlanRole.single), isNull);
      expect(word(EntryKind.activity, PlanRole.single), isNull);
      expect(word(EntryKind.stay, PlanRole.during), isNull);
    });
  });
}
