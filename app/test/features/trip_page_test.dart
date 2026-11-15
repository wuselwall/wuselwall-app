import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/trips/domain/packing_starters.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_compare_page.dart';
import 'package:wuselwall/features/trips/ui/trip_entry_page.dart';
import 'package:wuselwall/features/trips/ui/trip_pack_view.dart';
import 'package:wuselwall/features/trips/ui/trip_windows_page.dart';
import 'package:wuselwall/features/trips/ui/trips_page.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';
import 'package:wuselwall/l10n/generated/app_localizations_en.dart';
import 'package:wuselwall/l10n/generated/app_localizations_es.dart';
import 'package:wuselwall/l10n/generated/app_localizations_fr.dart';

import '../support/fake_trips.dart';
import '../support/fakes.dart';

// One trip (specs/30): its header and stage, the plan with its days and options, the
// packing list and the to-dos. Test data only.

final _de = AppLocalizationsDe();

/// A Sunday; the app's clock stands here.
final _now = DateTime(2026, 11, 15, 10, 30);

final _sardinia = Trip(
  id: 'sar',
  title: 'Sardinien',
  stage: TripStage.fixed,
  destinationName: 'Olbia',
  lat: 40.92,
  lon: 9.5,
  startsOn: DateTime(2026, 12, 1),
  endsOn: DateTime(2026, 12, 6),
  currency: 'CHF',
);

final _planned = Trip(
  id: 'plan',
  title: 'Skiwoche',
  stage: TripStage.planned,
  startsOn: DateTime(2026, 12, 26),
  endsOn: DateTime(2027, 1, 2),
  currency: 'CHF',
);

const _idea = Trip(id: 'idea', title: 'Nordsee', currency: 'CHF');

TripEntry _entry(
  String id,
  EntryKind kind,
  String title, {
  EntryState state = EntryState.chosen,
  int? price,
  DateTime? from,
  TimeOfDay? fromTime,
  DateTime? to,
  TimeOfDay? toTime,
  int position = 0,
  TransportMode? mode,
  String? fromPlace,
  String? toPlace,
  String? address,
  String? phone,
  String? url,
  String tripId = 'sar',
}) => TripEntry(
  id: id,
  tripId: tripId,
  kind: kind,
  title: title,
  state: state,
  priceCents: price,
  startsOn: from,
  startsTime: fromTime,
  endsOn: to,
  endsTime: toTime,
  position: position,
  mode: mode,
  fromPlace: fromPlace,
  toPlace: toPlace,
  address: address,
  phone: phone,
  url: url,
);

final _flight = _entry(
  'e-flight',
  EntryKind.transport,
  'Flug nach Olbia',
  price: 20000,
  from: DateTime(2026, 12, 1),
  fromTime: const TimeOfDay(hour: 10, minute: 40),
  to: DateTime(2026, 12, 1),
  toTime: const TimeOfDay(hour: 12, minute: 15),
  mode: TransportMode.flight,
  fromPlace: 'ZRH',
  toPlace: 'OLB',
);
final _hotel = _entry(
  'e-hotel',
  EntryKind.stay,
  'Hotel Mare',
  state: EntryState.booked,
  price: 34000,
  from: DateTime(2026, 12, 1),
  to: DateTime(2026, 12, 4),
  position: 1,
  address: 'Via Roma 1',
  phone: '+39 0789 1',
  url: 'https://hotel.example',
);
final _back = _entry(
  'e-back',
  EntryKind.transport,
  'Rückflug',
  price: 18000,
  from: DateTime(2026, 12, 6),
  fromTime: const TimeOfDay(hour: 18, minute: 0),
  position: 2,
  mode: TransportMode.flight,
);
final _insurance = _entry(
  'e-ins',
  EntryKind.note,
  'Reiseversicherung',
  price: 5000,
  position: 3,
);
final _flat = _entry(
  'o-flat',
  EntryKind.stay,
  'Ferienwohnung',
  state: EntryState.option,
  price: 70000,
  position: 4,
);
final _camping = _entry(
  'o-camp',
  EntryKind.stay,
  'Camping',
  state: EntryState.option,
  price: 40000,
  position: 5,
);

TripCheck _check(
  String id,
  String title, {
  CheckKind kind = CheckKind.pack,
  String? person,
  int? days,
  bool done = false,
  String tripId = 'sar',
}) => TripCheck(
  id: id,
  tripId: tripId,
  kind: kind,
  title: title,
  profileId: person,
  dueDaysBefore: days,
  doneAt: done ? DateTime(2026, 11, 14) : null,
);

const _openMeteo = ServiceProviderInfo(
  id: 'open-meteo',
  name: 'Open-Meteo',
  homepage: 'https://open-meteo.com',
  needsKey: false,
  cost: ServiceCost.free,
  capabilities: [
    ServiceCapability.climate,
    ServiceCapability.forecast,
    ServiceCapability.route,
    ServiceCapability.map,
  ],
  receives: [ServiceReceives.coordinates],
  attribution: 'Open-Meteo',
);

FakeServicesRepository _services({
  Forecast? forecast,
  Climate? climate,
  RouteInfo? route,
  MapPicture? map,
}) => FakeServicesRepository(
  catalogueList: const [_openMeteo],
  states: const [
    ServiceProviderState(
      provider: 'open-meteo',
      enabled: true,
      capabilities: [
        ServiceCapability.climate,
        ServiceCapability.forecast,
        ServiceCapability.route,
        ServiceCapability.map,
      ],
    ),
  ],
  forecastResult: forecast,
  climateResult: climate,
  routeResult: route,
  mapResult: map,
);

Future<ProviderContainer> _open(
  WidgetTester t,
  String tripId, {
  required FakeTripsRepository trips,
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
  container.read(routerProvider).go(Routes.tripPath(tripId));
  await t.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> _tab(WidgetTester t, String label) =>
    _tap(t, find.widgetWithText(Tab, label));

Future<void> _menu(WidgetTester t, String label) async {
  await _tap(t, find.byKey(const ValueKey('trip-menu')));
  await t.pumpAndSettle();
  await _tap(t, find.text(label));
  await t.pumpAndSettle();
}

void main() {
  group('the header and the stage', () {
    testWidgets('an idea without dates offers two ways to choose them', (
      t,
    ) async {
      final trips = FakeTripsRepository(trips: [_idea]);
      await _open(t, 'idea', trips: trips);
      expect(find.text(_de.tripListNoDates), findsOneWidget);
      expect(find.text(_de.tripStageIdea), findsOneWidget);
      expect(find.text(_de.tripPageWholeFamily), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-fix')), findsNothing);

      await _tap(t, find.byKey(const ValueKey('trip-find-window')));
      await t.pumpAndSettle();
      final page = t.widget<TripWindowsPage>(find.byType(TripWindowsPage));
      expect(page.tripId, 'idea');
    });

    testWidgets('entering dates makes an idea planned', (t) async {
      final trips = FakeTripsRepository(trips: [_idea]);
      await _open(t, 'idea', trips: trips, size: const Size(1000, 800));
      await _tap(t, find.byKey(const ValueKey('trip-enter-dates')));
      await t.pumpAndSettle();
      await t.tap(
        find
            .descendant(
              of: find.byType(DateRangePickerDialog),
              matching: find.text('20'),
            )
            .first,
      );
      await t.pumpAndSettle();
      await t.pumpAndSettle();
      await t.tap(
        find
            .descendant(
              of: find.byType(DateRangePickerDialog),
              matching: find.text('25'),
            )
            .first,
      );
      await t.pumpAndSettle();
      await t.pumpAndSettle();
      final save = MaterialLocalizations.of(
        t.element(find.byType(Scaffold).last),
      ).saveButtonLabel;
      await t.tap(find.text(save));
      await t.pumpAndSettle();
      await t.pumpAndSettle();
      final saved = trips.savedTrips.single;
      expect(saved.startsOn, DateTime(2026, 11, 20));
      expect(saved.endsOn, DateTime(2026, 11, 25));
      expect(saved.stage, TripStage.planned);
      // The page now shows the dates and the step that fits.
      expect(find.byKey(const ValueKey('trip-fix')), findsOneWidget);
    });

    testWidgets('a planned trip is decided with "Das machen wir"', (t) async {
      final trips = FakeTripsRepository(trips: [_planned]);
      await _open(t, 'plan', trips: trips);
      expect(find.text(_de.tripPageCalPlanned), findsOneWidget);
      expect(find.text(_de.tripListInDays(41)), findsOneWidget);
      await _tap(t, find.byKey(const ValueKey('trip-fix')));
      await t.pumpAndSettle();
      expect(trips.savedTrips.single.stage, TripStage.fixed);
      expect(find.text(_de.tripPageDecided), findsOneWidget);
      expect(find.text(_de.tripPageCalFixed), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-fix')), findsNothing);
    });

    testWidgets('a decided trip has a quiet way back to planned', (t) async {
      final trips = FakeTripsRepository(trips: [_sardinia]);
      await _open(t, 'sar', trips: trips);
      expect(find.text(_de.tripPageDecided), findsOneWidget);
      await _tap(t, find.byKey(const ValueKey('trip-unfix')));
      await t.pumpAndSettle();
      expect(trips.savedTrips.single.stage, TripStage.planned);
    });

    testWidgets('who travels is named, and the menu goes back to idea', (
      t,
    ) async {
      final trips = FakeTripsRepository(
        trips: [
          _sardinia.copyWith(memberIds: [guardianId]),
        ],
      );
      await _open(t, 'sar', trips: trips);
      expect(find.text('Papa'), findsOneWidget);
      expect(find.text(_de.tripPageWholeFamily), findsNothing);
      await _menu(t, _de.tripPageBackToIdea);
      expect(trips.savedTrips.single.stage, TripStage.idea);
      // The dates are kept, so the idea can be pencilled in again.
      expect(trips.savedTrips.single.hasDates, isTrue);
      expect(find.byKey(const ValueKey('trip-pencil')), findsOneWidget);
    });

    testWidgets('the menu edits the trip, currency included', (t) async {
      final trips = FakeTripsRepository(trips: [_sardinia]);
      await _open(t, 'sar', trips: trips);
      await _menu(t, _de.tripPageEdit);
      expect(find.byKey(const ValueKey('trip-edit-currency')), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('trip-edit-title')),
        'Sardinien 2026',
      );
      await t.enterText(find.byKey(const ValueKey('trip-edit-currency')), 'eu');
      await _tap(t, find.byKey(const ValueKey('trip-edit-save')));
      // Three letters, or the sheet stays.
      expect(find.text(_de.tripEditCurrencyInvalid), findsOneWidget);
      expect(trips.savedTrips, isEmpty);
      await t.enterText(
        find.byKey(const ValueKey('trip-edit-currency')),
        'eur',
      );
      await _tap(t, find.byKey(const ValueKey('trip-edit-save')));
      final saved = trips.savedTrips.single;
      expect(saved.title, 'Sardinien 2026');
      expect(saved.currency, 'EUR');
      expect(saved.id, 'sar');
      expect(saved.stage, TripStage.fixed);
      expect(saved.lat, 40.92);
    });

    testWidgets('deleting asks first and then returns to the list', (t) async {
      final trips = FakeTripsRepository(trips: [_sardinia]);
      await _open(t, 'sar', trips: trips);
      await _menu(t, _de.tripPageDelete);
      expect(find.text(_de.tripPageDeleteConfirm('Sardinien')), findsOneWidget);
      await _tap(t, find.text(_de.cancel));
      await t.pumpAndSettle();
      expect(trips.deletedTrips, isEmpty);

      await _menu(t, _de.tripPageDelete);
      await _tap(t, find.byKey(const ValueKey('trip-delete-confirm')));
      await t.pumpAndSettle();
      expect(trips.deletedTrips, ['sar']);
      expect(find.byType(TripsPage), findsOneWidget);
    });

    testWidgets('a trip that is gone says so and leads back', (t) async {
      await _open(t, 'nope', trips: FakeTripsRepository(trips: [_idea]));
      expect(find.text(_de.tripPageNotFound), findsOneWidget);
      await _tap(t, find.text(_de.tripPageToList));
      await t.pumpAndSettle();
      expect(find.byType(TripsPage), findsOneWidget);
    });
  });

  group('the plan', () {
    FakeTripsRepository seeded() => FakeTripsRepository(
      trips: [_sardinia],
      entries: [_flight, _hotel, _back, _insurance, _flat, _camping],
    );

    testWidgets('the days with their entries, roles and nights', (t) async {
      await _open(t, 'sar', trips: seeded());
      for (var day = 1; day <= 6; day++) {
        expect(find.byKey(ValueKey('trip-day-$day')), findsOneWidget);
      }
      expect(find.textContaining('Tag 1 ·'), findsOneWidget);
      expect(find.textContaining('Tag 6 ·'), findsOneWidget);
      // The flight is only there on day 1, with its times.
      expect(find.textContaining('10:40–12:15'), findsOneWidget);
      expect(find.text('ZRH → OLB'), findsOneWidget);
      // Check-in and check-out of the hotel; the return flight with its time.
      expect(find.textContaining(_de.tripPlanRoleCheckIn), findsOneWidget);
      expect(find.textContaining(_de.tripPlanRoleCheckOut), findsOneWidget);
      expect(find.textContaining('18:00'), findsOneWidget);
      // The three nights of the stay in the day footers.
      expect(
        find.text(_de.tripPlanStayTonight('Hotel Mare')),
        findsNWidgets(3),
      );
      // A booked entry says so.
      expect(find.text(_de.tripStateBooked), findsWidgets);
      // Chosen without a date, and the sum.
      expect(find.text(_de.tripPlanUndated), findsOneWidget);
      expect(find.text('Reiseversicherung'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('trip-info-sum'))).data,
        contains('770'),
      );
    });

    testWidgets('the sum says "at least" while a price is missing', (t) async {
      final trips = FakeTripsRepository(
        trips: [_sardinia],
        entries: [
          _flight,
          _entry('e-x', EntryKind.stay, 'Ohne Preis', position: 9),
        ],
      );
      await _open(t, 'sar', trips: trips);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('trip-info-sum'))).data,
        contains('mindestens'),
      );
    });

    testWidgets('the options by kind, with count and price range', (t) async {
      await _open(t, 'sar', trips: seeded());
      final stays = find.byKey(const ValueKey('trip-options-stay'));
      await t.ensureVisible(stays);
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: stays,
          matching: find.textContaining(_de.tripPlanOptionCount(2)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: stays, matching: find.textContaining('400')),
        findsWidgets,
      );
      expect(find.text('Ferienwohnung'), findsOneWidget);
      // A kind without options is offered as a way to add one.
      expect(find.byKey(const ValueKey('trip-add-rental')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-add-stay')), findsNothing);
    });

    testWidgets('compare, add and open lead to the other pages', (t) async {
      final container = await _open(t, 'sar', trips: seeded());
      await _tap(t, find.byKey(const ValueKey('trip-compare-stay')));
      final compare = t.widget<TripComparePage>(find.byType(TripComparePage));
      expect(compare.tripId, 'sar');
      expect(compare.kind, EntryKind.stay);

      container.read(routerProvider).go(Routes.tripPath('sar'));
      await t.pumpAndSettle();
      await _tap(t, find.byKey(const ValueKey('trip-add-option-stay')));
      var entry = t.widget<TripEntryPage>(find.byType(TripEntryPage));
      expect(entry.args!.isNew, isTrue);
      expect(entry.args!.entry.kind, EntryKind.stay);
      expect(entry.args!.entry.tripId, 'sar');

      container.read(routerProvider).go(Routes.tripPath('sar'));
      await t.pumpAndSettle();
      await _tap(t, find.byKey(const ValueKey('trip-add-rental')));
      entry = t.widget<TripEntryPage>(find.byType(TripEntryPage));
      expect(entry.args!.entry.kind, EntryKind.rental);

      container.read(routerProvider).go(Routes.tripPath('sar'));
      await t.pumpAndSettle();
      await _tap(t, find.byKey(const ValueKey('trip-entry-o-camp')));
      entry = t.widget<TripEntryPage>(find.byType(TripEntryPage));
      expect(entry.args!.isNew, isFalse);
      expect(entry.args!.entry.id, 'o-camp');
    });

    testWidgets('link, phone and address are there for the phone to open', (
      t,
    ) async {
      await _open(t, 'sar', trips: seeded());
      expect(find.byTooltip(_de.tripPlanOpenLink), findsWidgets);
      expect(find.byTooltip(_de.tripPlanCall), findsWidgets);
      expect(find.byTooltip(_de.tripPlanOpenMap), findsWidgets);
    });

    testWidgets('today is marked while the trip runs', (t) async {
      final running = _sardinia.copyWith(
        startsOn: DateTime(2026, 11, 13),
        endsOn: DateTime(2026, 11, 20),
      );
      await _open(t, 'sar', trips: FakeTripsRepository(trips: [running]));
      expect(find.text(_de.tripPlanToday), findsOneWidget);
      expect(find.text(_de.tripListDayOf(3, 8)), findsOneWidget);
    });

    testWidgets('a trip without dates lists the options and asks for dates', (
      t,
    ) async {
      final trips = FakeTripsRepository(
        trips: [_idea],
        entries: [
          _entry(
            'o1',
            EntryKind.stay,
            'Strandhaus',
            state: EntryState.option,
            tripId: 'idea',
          ),
        ],
      );
      await _open(t, 'idea', trips: trips);
      expect(find.text(_de.tripPlanNoDatesHint), findsOneWidget);
      expect(find.text('Strandhaus'), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-day-1')), findsNothing);
    });

    testWidgets('an empty plan offers every kind to start with', (t) async {
      await _open(t, 'sar', trips: FakeTripsRepository(trips: [_sardinia]));
      for (final kind in EntryKind.values) {
        expect(find.byKey(ValueKey('trip-add-${kind.wire}')), findsOneWidget);
      }
    });

    testWidgets('no service on: no forecast, no spinner, no error', (t) async {
      await _open(
        t,
        'sar',
        trips: FakeTripsRepository(trips: [_sardinia]),
        services: FakeServicesRepository(),
      );
      expect(find.byKey(const ValueKey('trip-info')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a service that cannot answer leaves its part out', (t) async {
      await _open(
        t,
        'sar',
        trips: FakeTripsRepository(trips: [_sardinia]),
        services: _services(),
      );
      expect(find.byKey(const ValueKey('trip-info')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('the forecast shows during the trip, with its attribution', (
      t,
    ) async {
      final running = _sardinia.copyWith(
        startsOn: DateTime(2026, 11, 14),
        endsOn: DateTime(2026, 11, 18),
      );
      await _open(
        t,
        'sar',
        trips: FakeTripsRepository(trips: [running]),
        services: _services(
          forecast: Forecast(
            days: [
              for (var d = 14; d <= 18; d++)
                ForecastDay(
                  date: DateTime(2026, 11, d),
                  tmax: 21.4,
                  tmin: 12.2,
                  precipMm: 0,
                  code: WeatherCode.clear,
                ),
            ],
            attribution: 'Wetterdaten von Open-Meteo',
          ),
        ),
      );
      expect(find.text(_de.tripInfoForecast), findsOneWidget);
      expect(find.text('21° / 12°'), findsNWidgets(5));
      expect(find.text('Wetterdaten von Open-Meteo'), findsOneWidget);
    });

    testWidgets('before the trip: what is typical, the drive and the map', (
      t,
    ) async {
      // A 1x1 picture, so the map has something to draw.
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
      );
      final trips = FakeTripsRepository(
        trips: [_sardinia],
        homePlace: const TripHome(name: 'Zürich', lat: 47.37, lon: 8.54),
      );
      await _open(
        t,
        'sar',
        trips: trips,
        services: _services(
          climate: const Climate(
            months: [
              ClimateMonth(
                month: 12,
                tmax: 15.4,
                tmin: 8.2,
                rainDays: 6,
                sea: 17.5,
              ),
            ],
            attribution: 'Klimadaten: Open-Meteo',
          ),
          route: const RouteInfo(
            km: 1234,
            minutes: 150,
            attribution: 'Route: OSM',
          ),
          map: MapPicture(
            bytes: png,
            mime: 'image/png',
            attribution: 'Karte: OSM',
          ),
        ),
      );
      expect(find.text(_de.tripInfoClimate), findsOneWidget);
      expect(find.textContaining('15° / 8°'), findsOneWidget);
      expect(find.textContaining('6 Regentage'), findsOneWidget);
      expect(find.textContaining('Meer 18°'), findsOneWidget);
      expect(find.textContaining('2 h 30 min'), findsOneWidget);
      expect(find.text('Klimadaten: Open-Meteo'), findsOneWidget);
      expect(find.text('Route: OSM'), findsOneWidget);
      expect(find.text('Karte: OSM'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('packing', () {
    FakeTripsRepository seeded({List<TripCheck>? checks}) =>
        FakeTripsRepository(
          trips: [
            _sardinia,
            const Trip(id: 'old', title: 'Herbst 2025', currency: 'CHF'),
          ],
          checks:
              checks ??
              [
                _check('c1', 'Sonnencreme'),
                _check('c2', 'Pass', person: guardianId),
                _check('c3', 'Kuscheltier', person: kidId, done: true),
              ],
        );

    Future<void> openPack(WidgetTester t, FakeTripsRepository trips) async {
      await _open(t, 'sar', trips: trips);
      await _tab(t, _de.tripPageTabPack);
    }

    testWidgets('the list per person and for everyone, with progress', (
      t,
    ) async {
      await openPack(t, seeded());
      expect(find.text(_de.tripPackForAll), findsOneWidget);
      expect(find.text('Papa'), findsWidgets);
      expect(find.text('Anna'), findsWidgets);
      expect(find.text(_de.tripPackProgress(1, 3)), findsWidgets);
      expect(find.text('Sonnencreme'), findsOneWidget);
    });

    testWidgets('ticking and unticking go to the server', (t) async {
      final trips = seeded();
      await openPack(t, trips);
      await _tap(t, find.byKey(const ValueKey('trip-check-c1')));
      await t.pumpAndSettle();
      await _tap(t, find.byKey(const ValueKey('trip-check-c3')));
      await t.pumpAndSettle();
      expect(trips.ticks.map((e) => (e.id, e.done)), [
        ('c1', true),
        ('c3', false),
      ]);
    });

    testWidgets('an item is added to a person or to everyone', (t) async {
      final trips = seeded();
      await openPack(t, trips);
      final family = find.descendant(
        of: find.byKey(const ValueKey('trip-pack-family')),
        matching: find.byType(TextField),
      );
      await t.enterText(family, ' Badetuch ');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      final papa = find.descendant(
        of: find.byKey(const ValueKey('trip-pack-$guardianId')),
        matching: find.byType(TextField),
      );
      await t.enterText(papa, 'Lesebrille');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(trips.savedChecks, hasLength(2));
      expect(trips.savedChecks.first.title, 'Badetuch');
      expect(trips.savedChecks.first.profileId, isNull);
      expect(trips.savedChecks.first.kind, CheckKind.pack);
      expect(trips.savedChecks.first.tripId, 'sar');
      expect(trips.savedChecks.last.title, 'Lesebrille');
      expect(trips.savedChecks.last.profileId, guardianId);
    });

    testWidgets('an item is renamed or removed from its menu', (t) async {
      final trips = seeded();
      await openPack(t, trips);
      await _tap(t, find.byKey(const ValueKey('trip-check-menu-c1')));
      await t.pumpAndSettle();
      await _tap(t, find.text(_de.tripPackRename));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).last, 'Sonnenmilch');
      await _tap(t, find.text(_de.save));
      await t.pumpAndSettle();
      expect(trips.savedChecks.single.title, 'Sonnenmilch');
      expect(trips.savedChecks.single.id, 'c1');

      await _tap(t, find.byKey(const ValueKey('trip-check-menu-c2')));
      await t.pumpAndSettle();
      await _tap(t, find.text(_de.tripPackRemove));
      await t.pumpAndSettle();
      expect(trips.deletedChecks, ['c2']);
    });

    testWidgets('the starter list adds one item per traveller where needed', (
      t,
    ) async {
      final trips = seeded(checks: const []);
      await openPack(t, trips);
      expect(find.text(_de.tripPackEmpty), findsOneWidget);
      await _tap(t, find.byKey(const ValueKey('trip-pack-suggest')));
      await _tap(t, find.byKey(const ValueKey('trip-suggest-add')));
      final added = trips.addedChecks.single;
      expect(added.tripId, 'sar');
      final titles = [for (final c in added.checks) c.title];
      expect(titles, contains('Sonnencreme'));
      // Papa and Anna each need a passport; only the child has the cuddly toy.
      expect(titles.where((s) => s == 'Pass oder Ausweis'), hasLength(2));
      final toys = added.checks.where((c) => c.title == 'Kuscheltier');
      expect(toys.map((c) => c.profileId), [kidId]);
      expect(find.text(_de.tripPackAdded(added.checks.length)), findsOneWidget);
    });

    testWidgets('groups can be left out of the starter list', (t) async {
      final trips = seeded(checks: const []);
      await openPack(t, trips);
      await _tap(t, find.byKey(const ValueKey('trip-pack-suggest')));
      await _tap(t, find.byKey(const ValueKey('trip-suggest-beach')));
      await _tap(t, find.byKey(const ValueKey('trip-suggest-kids')));
      await _tap(t, find.byKey(const ValueKey('trip-suggest-add')));
      final titles = [for (final c in trips.addedChecks.single.checks) c.title];
      expect(titles, isNot(contains('Sonnenbrille')));
      expect(titles, isNot(contains('Kuscheltier')));
      expect(titles, contains('Sonnencreme'));
    });

    testWidgets('"Wie letztes Mal" copies the list of another trip', (t) async {
      final trips = seeded(
        checks: [
          _check('o1', 'Zelt', tripId: 'old'),
          _check('c1', 'Sonnencreme'),
        ],
      );
      await openPack(t, trips);
      await _tap(t, find.byKey(const ValueKey('trip-pack-last-time')));
      await t.pumpAndSettle();
      await _tap(t, find.byKey(const ValueKey('trip-copy-from-old')));
      await t.pumpAndSettle();
      expect(trips.copiedChecks.single.from, 'old');
      expect(trips.copiedChecks.single.to, 'sar');
    });

    testWidgets('"Wie letztes Mal" says so when no other list exists', (
      t,
    ) async {
      final trips = seeded(checks: [_check('c1', 'Sonnencreme')]);
      await openPack(t, trips);
      await _tap(t, find.byKey(const ValueKey('trip-pack-last-time')));
      await t.pumpAndSettle();
      expect(find.text(_de.tripPackLastTimeNone), findsOneWidget);
      expect(trips.copiedChecks, isEmpty);
    });

    testWidgets('a long list does not need the helpers', (t) async {
      final trips = seeded(
        checks: [for (var i = 0; i < 12; i++) _check('c$i', 'Ding $i')],
      );
      await openPack(t, trips);
      expect(find.byKey(const ValueKey('trip-pack-suggest')), findsNothing);
      expect(find.byKey(const ValueKey('trip-pack-last-time')), findsNothing);
    });

    test('every starter has a title in every language', () {
      final all = [
        AppLocalizationsDe(),
        AppLocalizationsEn(),
        AppLocalizationsFr(),
        AppLocalizationsEs(),
      ];
      for (final l10n in all) {
        for (final s in packingStarters) {
          final title = packStarterTitle(l10n, s);
          expect(title, isNot(s.id), reason: '${l10n.localeName} ${s.id}');
          expect(title.trim(), isNotEmpty);
        }
        for (final g in PackingGroup.values) {
          expect(packGroupTitle(l10n, g).trim(), isNotEmpty);
        }
      }
      expect(packingStarters, hasLength(27));
    });
  });

  group('preparing', () {
    FakeTripsRepository seeded(Trip trip) => FakeTripsRepository(
      trips: [trip],
      checks: [
        _check(
          'd1',
          'Pässe prüfen',
          kind: CheckKind.todo,
          days: 30,
          tripId: trip.id,
        ),
        _check(
          'd2',
          'Katze: Nachbarn fragen',
          kind: CheckKind.todo,
          days: 3,
          tripId: trip.id,
        ),
        _check(
          'd3',
          'Hotel anrufen',
          kind: CheckKind.todo,
          done: true,
          tripId: trip.id,
        ),
      ],
    );

    testWidgets('the days before become dates; a past one is said calmly', (
      t,
    ) async {
      await _open(t, 'sar', trips: seeded(_sardinia));
      await _tab(t, _de.tripPageTabPrepare);
      // 30 days before 1 Dec is 1 Nov: before today (15 Nov), so it was due.
      expect(find.textContaining('Eigentlich bis'), findsOneWidget);
      // 3 days before is 28 Nov: still ahead.
      expect(find.textContaining('Bis 28'), findsOneWidget);
      expect(find.text(_de.tripTodoDone), findsOneWidget);
      expect(find.text(_de.tripPackProgress(1, 3)), findsOneWidget);
      // No alarm colour on the late one: it is plain secondary text.
      final late = t.widget<Text>(find.textContaining('Eigentlich bis'));
      final scheme = Theme.of(t.element(find.byType(Scaffold).last))
          .colorScheme;
      expect(late.style?.color, isNot(scheme.error));
    });

    testWidgets('without dates the days stay "N days before"', (t) async {
      await _open(t, 'idea', trips: seeded(_idea));
      await _tab(t, _de.tripPageTabPrepare);
      expect(find.text(_de.tripTodoDaysBefore(30)), findsOneWidget);
      expect(find.text(_de.tripTodoDaysBefore(3)), findsOneWidget);
    });

    testWidgets('a to-do is added with its days', (t) async {
      final trips = seeded(_sardinia);
      await _open(t, 'sar', trips: trips);
      await _tab(t, _de.tripPageTabPrepare);
      await _tap(t, find.byKey(const ValueKey('trip-todo-add')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('trip-todo-title')),
        'Post umleiten',
      );
      await t.enterText(find.byKey(const ValueKey('trip-todo-days')), '14');
      await _tap(t, find.byKey(const ValueKey('trip-todo-save')));
      await t.pumpAndSettle();
      final saved = trips.savedChecks.single;
      expect(saved.kind, CheckKind.todo);
      expect(saved.title, 'Post umleiten');
      expect(saved.dueDaysBefore, 14);
      expect(saved.tripId, 'sar');
    });

    testWidgets('a to-do is ticked, changed and removed', (t) async {
      final trips = seeded(_sardinia);
      await _open(t, 'sar', trips: trips);
      await _tab(t, _de.tripPageTabPrepare);
      await _tap(t, find.byKey(const ValueKey('trip-check-d2')));
      await t.pumpAndSettle();
      expect(trips.ticks.single, (id: 'd2', done: true));

      await _tap(t, find.byKey(const ValueKey('trip-check-menu-d1')));
      await t.pumpAndSettle();
      await _tap(t, find.text(_de.tripTodoEdit));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('trip-todo-title')),
        'Reisepässe prüfen',
      );
      await t.enterText(find.byKey(const ValueKey('trip-todo-days')), '');
      await _tap(t, find.byKey(const ValueKey('trip-todo-save')));
      await t.pumpAndSettle();
      expect(trips.savedChecks.single.title, 'Reisepässe prüfen');
      expect(trips.savedChecks.single.dueDaysBefore, isNull);

      await _tap(t, find.byKey(const ValueKey('trip-check-menu-d3')));
      await t.pumpAndSettle();
      await _tap(t, find.text(_de.tripPackRemove));
      await t.pumpAndSettle();
      expect(trips.deletedChecks, ['d3']);
    });

    testWidgets('no to-dos yet invites to the first one', (t) async {
      await _open(t, 'sar', trips: FakeTripsRepository(trips: [_sardinia]));
      await _tab(t, _de.tripPageTabPrepare);
      expect(find.text(_de.tripTodoEmpty), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-todo-add')), findsOneWidget);
    });
  });

  group('layout', () {
    for (final size in const [Size(360, 800), Size(1000, 800)]) {
      testWidgets('every tab fits at ${size.width.toInt()} wide', (t) async {
        final trips = FakeTripsRepository(
          trips: [_sardinia],
          entries: [_flight, _hotel, _back, _insurance, _flat, _camping],
          checks: [
            _check('c1', 'Sonnencreme'),
            _check('c2', 'Pass', person: guardianId),
            _check('d1', 'Pässe prüfen', kind: CheckKind.todo, days: 30),
          ],
        );
        await _open(t, 'sar', trips: trips, size: size);
        await _tab(t, _de.tripPageTabPack);
        await _tab(t, _de.tripPageTabPrepare);
        await _tab(t, _de.tripPageTabPlan);
        expect(find.byKey(const ValueKey('trip-header')), findsOneWidget);
      });
    }

    testWidgets('large text still fits', (t) async {
      final trips = FakeTripsRepository(
        trips: [_sardinia],
        entries: [_flight, _hotel],
      );
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(t, 'sar', trips: trips);
      // The header is tall at this size: the tabs come with a scroll.
      await t.scrollUntilVisible(
        find.widgetWithText(Tab, _de.tripPageTabPack),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await _tab(t, _de.tripPageTabPack);
      await _tab(t, _de.tripPageTabPrepare);
    });
  });

  testWidgets('without the trips on offer the page says so', (t) async {
    await _open(
      t,
      'sar',
      trips: FakeTripsRepository(trips: [_sardinia]),
      extra: [tripsSupportedProvider.overrideWith((ref) => false)],
    );
    expect(find.text(_de.tripPageUnavailable), findsOneWidget);
  });
}
