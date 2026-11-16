import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_discover_page.dart';
import 'package:wuselwall/features/trips/ui/trip_page.dart';
import 'package:wuselwall/features/trips/ui/trip_windows_page.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_trips.dart';
import '../support/fakes.dart';

// Reisen (specs/30): the running and coming trips, the ideas, the past ones folded, and
// "Neue Idee". Test data only.

final _de = AppLocalizationsDe();

/// A Sunday; the app's clock stands here.
final _now = DateTime(2026, 11, 15, 10, 30);

Trip _trip(
  String id,
  String title, {
  TripStage stage = TripStage.idea,
  DateTime? from,
  DateTime? to,
  String? destination,
  String? icon,
}) => Trip(
  id: id,
  title: title,
  stage: stage,
  startsOn: from,
  endsOn: to,
  destinationName: destination,
  iconKey: icon,
  currency: 'CHF',
);

final _running = _trip(
  'run',
  'Nordsee',
  stage: TripStage.fixed,
  from: DateTime(2026, 11, 13),
  to: DateTime(2026, 11, 22),
  destination: 'Sylt',
  icon: 'beach',
);
final _coming = _trip(
  'ski',
  'Skiwoche',
  stage: TripStage.planned,
  from: DateTime(2026, 12, 26),
  to: DateTime(2027, 1, 2),
);
final _idea = _trip('idea', 'Sardinien', destination: 'Olbia');
final _past = _trip(
  'old',
  'Herbstferien',
  stage: TripStage.fixed,
  from: DateTime(2026, 10, 3),
  to: DateTime(2026, 10, 11),
);

Future<ProviderContainer> _open(
  WidgetTester t, {
  FakeTripsRepository? trips,
  FakeServicesRepository? services,
  Size size = const Size(360, 800),
  List<Override> extra = const [],
}) async {
  final container = await pumpApp(
    t,
    size: size,
    overrides: [
      ...baseOverrides(
        identity: FakeIdentityRepository(current: device()),
        trips: trips,
        services: services,
        now: _now,
      ),
      ...extra,
    ],
  );
  container.read(routerProvider).go(Routes.trips);
  await t.pumpAndSettle();
  return container;
}

/// Taps something inside the sheet, scrolling it into view first.
Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('the three groups, soonest first, with how near each is', (
    t,
  ) async {
    await _open(
      t,
      trips: FakeTripsRepository(trips: [_idea, _coming, _past, _running]),
    );
    expect(find.text(_de.tripsTitle), findsOneWidget);
    expect(find.text(_de.tripListUpcoming), findsOneWidget);
    expect(find.text(_de.tripListIdeas), findsOneWidget);
    // Running first, then the coming one.
    final run = t.getTopLeft(find.byKey(const ValueKey('trip-card-run'))).dy;
    final ski = t.getTopLeft(find.byKey(const ValueKey('trip-card-ski'))).dy;
    expect(run, lessThan(ski));
    expect(find.text(_de.tripListDayOf(3, 10)), findsOneWidget);
    expect(find.text(_de.tripListInDays(41)), findsOneWidget);
    expect(find.text('Sylt'), findsOneWidget);
    expect(find.text(_de.tripStageFixed), findsOneWidget);
    expect(find.text(_de.tripStagePlanned), findsOneWidget);
    expect(find.text(_de.tripStageIdea), findsOneWidget);
    expect(find.text(_de.tripListNoDates), findsOneWidget);
  });

  testWidgets('past trips are folded until asked for', (t) async {
    await _open(t, trips: FakeTripsRepository(trips: [_running, _past]));
    expect(find.text(_de.tripListPast(1)), findsOneWidget);
    expect(find.text('Herbstferien'), findsNothing);
    await t.tap(find.text(_de.tripListPast(1)));
    await t.pumpAndSettle();
    expect(find.text('Herbstferien'), findsOneWidget);
  });

  testWidgets('a card opens the trip', (t) async {
    await _open(t, trips: FakeTripsRepository(trips: [_idea]));
    await t.tap(find.byKey(const ValueKey('trip-card-idea')));
    await t.pumpAndSettle();
    expect(find.byType(TripPage), findsOneWidget);
    expect(find.text('Sardinien'), findsWidgets);
  });

  testWidgets('"Zeitfenster" leads to the windows', (t) async {
    await _open(t, trips: FakeTripsRepository(trips: [_idea]));
    await t.tap(find.byKey(const ValueKey('trip-windows')));
    await t.pumpAndSettle();
    expect(find.byType(TripWindowsPage), findsOneWidget);
  });

  testWidgets('"Wohin?" leads to discovery', (t) async {
    await _open(t, trips: FakeTripsRepository(trips: [_idea]));
    await t.tap(find.byKey(const ValueKey('trip-discover')));
    await t.pumpAndSettle();
    expect(find.byType(TripDiscoverPage), findsOneWidget);
  });

  testWidgets('"Neue Idee" asks for a name and saves an idea', (t) async {
    final trips = FakeTripsRepository();
    await _open(t, trips: trips);
    // Nothing yet: the empty state invites to the first idea.
    expect(find.text(_de.tripListEmptyTitle), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('trip-new')));
    await t.pumpAndSettle();
    // A name is required.
    await _tap(t, find.byKey(const ValueKey('trip-edit-save')));
    expect(find.text(_de.tripEditNameRequired), findsOneWidget);
    expect(trips.savedTrips, isEmpty);

    await t.enterText(
      find.byKey(const ValueKey('trip-edit-title')),
      ' Ostsee ',
    );
    await _tap(t, find.byKey(const ValueKey('trip-icon-beach')));
    await t.enterText(
      find.byKey(const ValueKey('trip-edit-destination')),
      'Rügen',
    );
    await _tap(t, find.byKey(const ValueKey('trip-edit-save')));

    expect(trips.savedTrips, hasLength(1));
    final saved = trips.savedTrips.single;
    expect(saved.title, 'Ostsee');
    expect(saved.stage, TripStage.idea);
    expect(saved.iconKey, 'beach');
    expect(saved.destinationName, 'Rügen');
    expect(saved.memberIds, isEmpty);
    expect(saved.id, isNotEmpty);
    // A new trip leaves the currency to the server.
    expect(saved.toJson().containsKey('currency'), isFalse);
    // The sheet is closed and the idea is in the list.
    expect(find.byKey(const ValueKey('trip-edit-title')), findsNothing);
    expect(find.text('Ostsee'), findsOneWidget);
  });

  testWidgets('a new idea can name who travels', (t) async {
    final trips = FakeTripsRepository();
    await _open(t, trips: trips);
    await t.tap(find.byKey(const ValueKey('trip-new')));
    await t.pumpAndSettle();
    expect(find.text(_de.tripEditWholeFamily), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('trip-edit-title')), 'Wandern');
    await t.ensureVisible(
      find.byKey(const ValueKey('trip-member-$guardianId')),
    );
    await t.tap(find.byKey(const ValueKey('trip-member-$guardianId')));
    await t.pumpAndSettle();
    expect(find.text(_de.tripEditWholeFamily), findsNothing);
    await _tap(t, find.byKey(const ValueKey('trip-edit-save')));
    expect(trips.savedTrips.single.memberIds, [guardianId]);
  });

  testWidgets('the place search is offered only with a geocoding service', (
    t,
  ) async {
    await _open(t, trips: FakeTripsRepository());
    await t.tap(find.byKey(const ValueKey('trip-new')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-find-place')), findsNothing);
  });

  testWidgets('a found place is stored with its coordinates', (t) async {
    final trips = FakeTripsRepository();
    final services = FakeServicesRepository(
      catalogueList: const [
        ServiceProviderInfo(
          id: 'nominatim',
          name: 'Nominatim',
          homepage: 'https://x',
          needsKey: false,
          cost: ServiceCost.free,
          capabilities: [ServiceCapability.geocode],
          receives: [ServiceReceives.searchText],
          attribution: 'OSM',
        ),
      ],
      states: const [
        ServiceProviderState(
          provider: 'nominatim',
          enabled: true,
          capabilities: [ServiceCapability.geocode],
        ),
      ],
      geocodeResult: const GeocodeResult(
        places: [
          GeoPlace(
            name: 'Olbia',
            country: 'IT',
            admin: 'Sardinien',
            lat: 40.92,
            lon: 9.5,
          ),
        ],
        attribution: 'Daten von OpenStreetMap',
      ),
    );
    await _open(t, trips: trips, services: services);
    await t.tap(find.byKey(const ValueKey('trip-new')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('trip-edit-title')), 'Sommer');
    await t.enterText(
      find.byKey(const ValueKey('trip-edit-destination')),
      'Olb',
    );
    await _tap(t, find.byKey(const ValueKey('trip-find-place')));
    expect(services.geocoded.single.q, 'Olb');
    expect(find.text('Daten von OpenStreetMap'), findsOneWidget);
    await _tap(t, find.byKey(const ValueKey('trip-place-40.92-9.5')));
    expect(find.text(_de.tripEditPlaceFound), findsOneWidget);
    await _tap(t, find.byKey(const ValueKey('trip-edit-save')));
    final saved = trips.savedTrips.single;
    expect(saved.destinationName, 'Olbia');
    expect(saved.country, 'IT');
    expect(saved.lat, 40.92);
    expect(saved.lon, 9.5);
  });

  testWidgets('a failed save says so in the sheet and keeps it open', (
    t,
  ) async {
    final trips = FakeTripsRepository();
    await _open(t, trips: trips);
    await t.tap(find.byKey(const ValueKey('trip-new')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('trip-edit-title')), 'Sommer');
    trips.failure = const NetworkFailure();
    await _tap(t, find.byKey(const ValueKey('trip-edit-save')));
    expect(find.byKey(const ValueKey('trip-edit-title')), findsOneWidget);
    expect(find.textContaining('Verbindung'), findsOneWidget);
  });

  testWidgets('without the trips on offer the page says so', (t) async {
    await _open(
      t,
      trips: FakeTripsRepository(trips: [_idea]),
      extra: [tripsSupportedProvider.overrideWith((ref) => false)],
    );
    expect(find.text(_de.tripPageUnavailable), findsOneWidget);
    expect(find.byKey(const ValueKey('trip-new')), findsNothing);
  });

  testWidgets('a failing server shows the error with a retry', (t) async {
    final trips = FakeTripsRepository(
      trips: [_idea],
      failure: const NetworkFailure(),
    );
    await _open(t, trips: trips);
    expect(find.text(_de.retry), findsOneWidget);
    trips.failure = null;
    await t.tap(find.text(_de.retry));
    await t.pumpAndSettle();
    expect(find.text('Sardinien'), findsOneWidget);
  });

  testWidgets('a wide screen lays the cards in two columns without overflow', (
    t,
  ) async {
    await _open(
      t,
      size: const Size(1000, 800),
      trips: FakeTripsRepository(trips: [_running, _coming, _idea, _past]),
    );
    final run = t.getTopLeft(find.byKey(const ValueKey('trip-card-run')));
    final ski = t.getTopLeft(find.byKey(const ValueKey('trip-card-ski')));
    expect(run.dy, ski.dy);
    expect(run.dx, lessThan(ski.dx));
  });
}
