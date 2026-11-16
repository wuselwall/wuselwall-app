import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/demo/demo_services.dart';
import 'package:wuselwall/demo/demo_trips.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/services/application/service_actions.dart';
import 'package:wuselwall/features/services/application/service_providers.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/application/trip_service_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/domain/trip_plan.dart';

import '../support/fake_trips.dart';
import '../support/fakes.dart';

final _now = DateTime(2027, 7, 12, 9);

Trip _trip({
  String id = 't1',
  TripStage stage = TripStage.fixed,
  double? lat = 40.92,
}) => Trip(
  id: id,
  title: 'Sardinien',
  stage: stage,
  lat: lat,
  lon: lat == null ? null : 9.5,
  startsOn: stage == TripStage.idea ? null : DateTime(2027, 7, 10),
  endsOn: stage == TripStage.idea ? null : DateTime(2027, 7, 19),
  currency: 'CHF',
);

const _openMeteo = ServiceProviderInfo(
  id: 'open-meteo',
  name: 'Open-Meteo',
  homepage: 'https://open-meteo.com',
  needsKey: false,
  cost: ServiceCost.free,
  capabilities: [ServiceCapability.climate, ServiceCapability.forecast],
  receives: [ServiceReceives.coordinates],
  attribution: 'Open-Meteo',
);

const _google = ServiceProviderInfo(
  id: 'google',
  name: 'Google',
  homepage: 'https://x',
  needsKey: true,
  cost: ServiceCost.paidKey,
  capabilities: [ServiceCapability.route, ServiceCapability.map],
  receives: [ServiceReceives.homeCoordinates],
  attribution: 'G',
);

Future<ProviderContainer> _container({
  FakeTripsRepository? trips,
  FakeServicesRepository? services,
  DeviceInfo? device,
  DateTime? now,
}) async {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device ?? deviceOf()),
      trips: trips,
      services: services,
      now: now ?? _now,
    ),
  );
  addTearDown(container.dispose);
  await container.read(sessionStateProvider.future);
  return container;
}

DeviceInfo deviceOf({UiRegister register = UiRegister.adult}) =>
    device(register: register);

void main() {
  group('the trips of the household', () {
    test('are filtered per trip and planned from its entries', () async {
      final trips = FakeTripsRepository(
        trips: [
          _trip(),
          _trip(id: 't2', stage: TripStage.idea),
        ],
        entries: [
          TripEntry(
            id: 'e1',
            tripId: 't1',
            kind: EntryKind.stay,
            title: 'Hotel',
            state: EntryState.booked,
            startsOn: DateTime(2027, 7, 10),
            endsOn: DateTime(2027, 7, 19),
          ),
          const TripEntry(
            id: 'e2',
            tripId: 't2',
            kind: EntryKind.stay,
            title: 'Other',
          ),
        ],
        combos: const [TripCombo(id: 'c1', tripId: 't1', name: 'A')],
        checks: const [
          TripCheck(id: 'k1', tripId: 't2', kind: CheckKind.pack, title: 'x'),
        ],
      );
      final c = await _container(trips: trips);
      expect((await c.read(tripsProvider.future)).length, 2);
      expect((await c.read(tripProvider('t1').future))!.title, 'Sardinien');
      expect(await c.read(tripProvider('nope').future), isNull);
      expect((await c.read(tripEntriesProvider('t1').future)).single.id, 'e1');
      expect((await c.read(tripCombosProvider('t1').future)).single.id, 'c1');
      expect(await c.read(tripChecksProvider('t1').future), isEmpty);
      final plan = (await c.read(tripPlanProvider('t1').future))!;
      expect(plan.days, hasLength(10));
      expect(plan.stayTonight(DateTime(2027, 7, 12))!.id, 'e1');
      expect(await c.read(tripPlanProvider('nope').future), isNull);
    });

    test('a failure is an error for the page, not an empty list', () async {
      final trips = FakeTripsRepository(failure: const NetworkFailure());
      final c = await _container(trips: trips);
      c.listen(tripsProvider, (_, _) {});
      await expectLater(
        c.read(tripsProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test(
      'upcoming trips are the planned and fixed ones that are not over',
      () async {
        final trips = FakeTripsRepository(
          trips: [
            _trip(id: 'idea', stage: TripStage.idea),
            _trip(id: 'now'),
            Trip(
              id: 'past',
              title: 'Past',
              stage: TripStage.fixed,
              startsOn: DateTime(2027, 1, 1),
              endsOn: DateTime(2027, 1, 5),
            ),
            Trip(
              id: 'later',
              title: 'Later',
              stage: TripStage.planned,
              startsOn: DateTime(2027, 9, 1),
              endsOn: DateTime(2027, 9, 5),
            ),
          ],
        );
        final c = await _container(trips: trips);
        await c.read(tripsProvider.future);
        expect(c.read(upcomingTripsProvider).map((t) => t.id), [
          'now',
          'later',
        ]);
      },
    );
  });

  group('the trip card of Today', () {
    FakeTripsRepository seeded() => FakeTripsRepository(
      trips: [_trip()],
      entries: [
        TripEntry(
          id: 'boat',
          tripId: 't1',
          kind: EntryKind.activity,
          title: 'Boot',
          state: EntryState.booked,
          startsOn: DateTime(2027, 7, 12),
          startsTime: const TimeOfDay(hour: 10, minute: 0),
        ),
      ],
    );

    test('shows the running trip to an adult', () async {
      final c = await _container(trips: seeded());
      await c.read(tripsProvider.future);
      await c.read(allTripEntriesProvider.future);
      final today = c.read(tripTodayProvider)!;
      expect(today.dayNumber, 3);
      expect(today.todayItems.single.entry.id, 'boat');
    });

    test(
      'shows nothing on a child\'s device, the wall or an old server',
      () async {
        for (final register in [UiRegister.kid, UiRegister.kiosk]) {
          final c = await _container(
            trips: seeded(),
            device: deviceOf(register: register),
          );
          await c.read(tripsProvider.future);
          expect(c.read(tripTodayProvider), isNull, reason: '$register');
        }
      },
    );

    test('shows nothing while the trips have not loaded', () async {
      final c = await _container(trips: seeded());
      expect(c.read(tripTodayProvider), isNull);
    });
  });

  group('the actions', () {
    test('write as the acting profile and refresh the lists', () async {
      final trips = FakeTripsRepository(trips: [_trip(stage: TripStage.idea)]);
      final c = await _container(trips: trips);
      expect((await c.read(tripsProvider.future)).single.hasDates, isFalse);
      final saved = await c
          .read(tripActionsProvider)
          .setDates(
            _trip(stage: TripStage.idea),
            DateTime(2027, 7, 10),
            DateTime(2027, 7, 19),
          );
      expect(saved.isOk, isTrue);
      expect(trips.savedTrips.single.stage, TripStage.planned);
      expect(trips.actors.single, guardianId);
      final again = await c.read(tripsProvider.future);
      expect(again.single.hasDates, isTrue);
      expect(again.single.stage, TripStage.planned);
    });

    test('taking the dates away makes it an idea again', () async {
      final trips = FakeTripsRepository(
        trips: [_trip(stage: TripStage.planned)],
      );
      final c = await _container(trips: trips);
      await c
          .read(tripActionsProvider)
          .setDates(_trip(stage: TripStage.planned), null, null);
      final t = trips.savedTrips.single;
      expect(t.stage, TripStage.idea);
      expect(t.hasDates, isFalse);
    });

    test('a refused write is a failure and refreshes nothing', () async {
      final trips = FakeTripsRepository()
        ..failure = const PermissionFailure(code: 'adults_only');
      final c = await _container(trips: trips);
      final r = await c.read(tripActionsProvider).deleteEntry('e1');
      expect(r.failureOrNull!.code, 'adults_only');
      expect(trips.deletedEntries, isEmpty);
    });

    test('entries, combinations and checks go through one call each', () async {
      final trips = FakeTripsRepository(trips: [_trip()]);
      final c = await _container(trips: trips);
      final a = c.read(tripActionsProvider);
      const entry = TripEntry(
        id: 'e1',
        tripId: 't1',
        kind: EntryKind.stay,
        title: 'Hotel',
      );
      await a.saveEntry(entry);
      await a.setEntryState(entry, EntryState.chosen);
      await a.copyEntry('e1');
      await a.saveCombo(
        const TripCombo(id: 'c1', tripId: 't1', name: 'A', entryIds: ['e1']),
      );
      await a.chooseCombo('c1', setDates: true);
      await a.tickCheck('k1', done: true);
      await a.setHome(const TripHome(name: 'Zürich', lat: 47.37, lon: 8.54));
      expect(trips.savedEntries.map((e) => e.state), [
        EntryState.option,
        EntryState.chosen,
      ]);
      expect(trips.copiedEntries, ['e1']);
      expect(trips.chosenCombos.single.setDates, isTrue);
      expect(trips.ticks.single, (id: 'k1', done: true));
      expect((await c.read(tripHomeProvider.future))!.name, 'Zürich');
      expect(TripActions.newId(), isNot(TripActions.newId()));
    });
  });

  group('the services', () {
    FakeServicesRepository seeded({bool google = false}) =>
        FakeServicesRepository(
          catalogueList: const [_openMeteo, _google],
          states: [
            const ServiceProviderState(
              provider: 'open-meteo',
              enabled: true,
              capabilities: [ServiceCapability.forecast],
            ),
            if (google)
              const ServiceProviderState(
                provider: 'google',
                enabled: true,
                capabilities: [ServiceCapability.route],
                hasKey: false,
              ),
          ],
          forecastResult: Forecast(
            days: [
              for (var d = 8; d <= 25; d++)
                ForecastDay(
                  date: DateTime(2027, 7, d),
                  tmax: 30,
                  tmin: 20,
                  precipMm: 0,
                  code: WeatherCode.clear,
                ),
            ],
            provider: 'open-meteo',
            attribution: 'a',
          ),
          climateResult: const Climate(months: []),
        );

    test(
      'an offered capability needs an enabled provider that is set for it',
      () async {
        final c = await _container(services: seeded(google: true));
        await c.read(serviceSetupProvider.future);
        expect(
          c.read(serviceOffersProvider(ServiceCapability.forecast)),
          isTrue,
        );
        // Enabled but not set for climate.
        expect(
          c.read(serviceOffersProvider(ServiceCapability.climate)),
          isFalse,
        );
        // Google needs a key it does not have.
        expect(c.read(serviceOffersProvider(ServiceCapability.route)), isFalse);
        expect(c.read(serviceOffersProvider(ServiceCapability.map)), isFalse);
      },
    );

    test('the settings list puts the enabled ones first', () async {
      final c = await _container(services: seeded());
      final list = await c.read(serviceSetupProvider.future);
      expect(list.map((v) => v.info.id), ['open-meteo', 'google']);
      expect(list.first.enabled, isTrue);
      expect(list.last.enabled, isFalse);
      expect(list.last.state, isNull);
    });

    test('nothing is offered to a child\'s device', () async {
      final c = await _container(
        services: seeded(),
        device: deviceOf(register: UiRegister.kid),
      );
      await c.read(serviceSetupProvider.future);
      expect(
        c.read(serviceOffersProvider(ServiceCapability.forecast)),
        isFalse,
      );
    });

    test(
      'the forecast of a trip is read from seven days before until its end',
      () async {
        final services = seeded();
        final trips = FakeTripsRepository(trips: [_trip()]);
        final c = await _container(trips: trips, services: services);
        await c.read(serviceSetupProvider.future);
        final f = (await c.read(tripForecastProvider('t1').future))!;
        expect(f.days.first.date, DateTime(2027, 7, 10));
        expect(f.days.last.date, DateTime(2027, 7, 19));
        expect(services.forecasts.single, (lat: 40.92, lon: 9.5));

        final early = await _container(
          trips: trips,
          services: seeded(),
          now: DateTime(2027, 7, 1),
        );
        await early.read(serviceSetupProvider.future);
        expect(await early.read(tripForecastProvider('t1').future), isNull);

        final late = await _container(
          trips: trips,
          services: seeded(),
          now: DateTime(2027, 7, 20),
        );
        await late.read(serviceSetupProvider.future);
        expect(await late.read(tripForecastProvider('t1').future), isNull);
      },
    );

    test('a trip without coordinates asks no service', () async {
      final services = seeded();
      final c = await _container(
        trips: FakeTripsRepository(trips: [_trip(lat: null)]),
        services: services,
      );
      await c.read(serviceSetupProvider.future);
      expect(await c.read(tripForecastProvider('t1').future), isNull);
      expect(services.forecasts, isEmpty);
    });

    test('a capability that is off is null, never an error', () async {
      final services = seeded();
      final c = await _container(
        trips: FakeTripsRepository(trips: [_trip()]),
        services: services,
      );
      await c.read(serviceSetupProvider.future);
      expect(await c.read(tripClimateProvider('t1').future), isNull);
      expect(await c.read(tripRouteProvider('t1').future), isNull);
      expect(await c.read(tripMapProvider('t1').future), isNull);
      expect(services.climates, isEmpty);
    });

    test('a failing service is null too', () async {
      final services = seeded()..forecastResult = null;
      final c = await _container(
        trips: FakeTripsRepository(trips: [_trip()]),
        services: services,
      );
      await c.read(serviceSetupProvider.future);
      expect(await c.read(tripForecastProvider('t1').future), isNull);
      expect(services.forecasts, hasLength(1));
    });

    test('a guardian\'s changes refresh the states', () async {
      final services = seeded();
      final c = await _container(services: services);
      expect((await c.read(serviceStatesProvider.future)), hasLength(1));
      final r = await c
          .read(serviceActionsProvider)
          .setProvider(
            'google',
            enabled: true,
            capabilities: [ServiceCapability.route],
            key: 'abcd1234',
          );
      expect(r.isOk, isTrue);
      expect(services.setCalls.single.key, 'abcd1234');
      final states = await c.read(serviceStatesProvider.future);
      expect(states, hasLength(2));
      expect(states.last.hasKey, isTrue);
    });

    test('a guardian is told apart from an adult', () async {
      final c = await _container();
      await c.read(membersProvider.future);
      expect(c.read(actingGuardianProvider), isTrue);
    });
  });

  group('the demo', () {
    test(
      'has the family\'s trips and lets the screenshots change them',
      () async {
        final repo = DemoTripsRepository(clock: () => DateTime(2027, 7, 1, 8));
        final trips = (await repo.trips()).unwrap();
        expect(trips.where((t) => t.stage == TripStage.idea), hasLength(3));
        final fixed = trips.singleWhere((t) => t.stage == TripStage.fixed);
        expect(fixed.title, 'Sardinien');
        expect(fixed.startsOn, DateTime(2027, 7, 13));
        expect(fixed.days, 10);
        final entries = (await repo.entries()).unwrap();
        expect(
          entries.where((e) => e.mode == TransportMode.flight),
          isNotEmpty,
        );
        expect(entries.where((e) => e.kind == EntryKind.stay), hasLength(3));
        expect(entries.where((e) => e.kind == EntryKind.rental), hasLength(2));
        expect((await repo.combos()).unwrap(), hasLength(2));
        expect((await repo.checks()).unwrap().any((c) => c.done), isTrue);
        expect((await repo.home()).unwrap(), isNotNull);

        final id = (await repo.saveEntry(
          actor: null,
          entry: const TripEntry(
            id: 'new',
            tripId: 'trip-sardinia',
            kind: EntryKind.activity,
            title: 'Eis',
            priceCents: 500,
          ),
        )).unwrap();
        expect(id, 'new');
        final saved = (await repo.entries()).unwrap().singleWhere(
          (e) => e.id == 'new',
        );
        expect(saved.priceCheckedOn, DateTime(2027, 7, 1));
        await repo.deleteEntry(actor: null, id: 'e-stay-3');
        final combos = (await repo.combos()).unwrap();
        expect(combos.first.entryIds, isNot(contains('e-stay-3')));

        final choice = (await repo.chooseCombo(
          actor: null,
          id: 'c-1',
        )).unwrap();
        expect(choice.chosen, greaterThan(0));
        expect(
          (await repo.entries())
              .unwrap()
              .where((e) => e.id == 'e-fl-1')
              .single
              .state,
          EntryState.option,
        );
      },
    );

    test('has windows and a discovery that follow the filters', () async {
      final repo = DemoTripsRepository(clock: () => DateTime(2027, 7, 1, 8));
      final windows = (await repo.windows(const TripWindowsArgs(minDays: 7)))
          .unwrap();
      expect(windows.every((w) => w.days >= 7), isTrue);
      expect(windows, isNotEmpty);
      final warm = (await repo.discover(
        actor: null,
        args: TripDiscoverArgs(
          from: DateTime(2027, 7, 10),
          to: DateTime(2027, 7, 24),
          filters: const DiscoverFilters(tempMin: 28, dry: true, tags: ['sea']),
        ),
      )).unwrap();
      final fits = warm.places.where((p) => p.fits == DiscoverFit.yes).toList();
      expect(fits, isNotEmpty);
      expect(fits.every((p) => p.tags.contains('sea')), isTrue);
      expect(fits.every((p) => p.climate!.tmax >= 28), isTrue);
      // Places that fit come first, then the nearer ones.
      expect(warm.places.first.fits, DiscoverFit.yes);
      expect(warm.attribution, isNotNull);
    });

    test('the demo services start with open-meteo on', () async {
      final repo = DemoServicesRepository(clock: () => DateTime(2027, 7, 1));
      expect((await repo.catalogue()).unwrap(), hasLength(7));
      final states = (await repo.providers()).unwrap();
      expect(states.single.provider, 'open-meteo');
      expect(
        (await repo.forecast(lat: 40.9, lon: 9.5)).unwrap().days,
        isNotEmpty,
      );
      expect(
        (await repo.climate(lat: 40.9, lon: 9.5)).unwrap().months,
        hasLength(12),
      );
      expect(
        (await repo.map(
          lat: 1,
          lon: 2,
          width: 10,
          height: 10,
        )).failureOrNull?.code,
        'service_off',
      );
      await repo.setProvider(
        actor: null,
        provider: 'google',
        enabled: true,
        capabilities: [ServiceCapability.map],
        key: 'abcd1234',
      );
      expect(
        (await repo.map(lat: 1, lon: 2, width: 10, height: 10)).unwrap().bytes,
        isNotEmpty,
      );
    });
  });

  test('a plan item of a same-day flight is single', () {
    final item = PlanItem(
      TripEntry(
        id: 'f',
        tripId: 't',
        kind: EntryKind.transport,
        title: 'f',
        startsOn: DateTime(2027, 7, 10),
        startsTime: const TimeOfDay(hour: 7, minute: 0),
      ),
      PlanRole.single,
    );
    expect(item.time, const TimeOfDay(hour: 7, minute: 0));
  });
}
