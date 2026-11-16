import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_discover_page.dart';

import '../support/fake_trips.dart';
import '../support/fakes.dart';

final _range = DateTimeRange(
  start: DateTime(2027, 7, 3),
  end: DateTime(2027, 7, 11),
);

const _olbia = DiscoverPlace(
  key: 'olbia',
  name: 'Sardinien',
  country: 'IT',
  lat: 40.92,
  lon: 9.5,
  tags: ['sea', 'island'],
  km: 953,
  effort: TravelEffort.short,
  climate: DiscoverClimate(
    tmax: 29.4,
    tmin: 19.6,
    rainDays: 2.2,
    sunHours: 10.4,
    sea: 24.3,
  ),
  fits: DiscoverFit.yes,
);

const _davos = DiscoverPlace(
  key: 'davos',
  name: 'Davos',
  country: 'CH',
  lat: 46.8,
  lon: 9.84,
  tags: ['mountains'],
);

const _ownIdea = DiscoverPlace(
  tripId: 't9',
  name: 'Nordsee',
  country: 'DE',
  lat: 54.0,
  lon: 8.0,
  tags: ['sea', 'north'],
);

final _openMeteo = ServiceProviderInfo.fromJson(const {
  'id': 'open-meteo',
  'name': 'Open-Meteo',
  'homepage': 'https://open-meteo.com',
  'needs_key': false,
  'cost': 'free',
  'capabilities': ['climate', 'geocode'],
  'receives': ['coordinates'],
});

FakeServicesRepository _withClimate() => FakeServicesRepository(
  catalogueList: [_openMeteo],
  states: const [
    ServiceProviderState(
      provider: 'open-meteo',
      enabled: true,
      capabilities: [ServiceCapability.climate],
    ),
  ],
);

const _home = TripHome(name: 'Zürich', lat: 47.37, lon: 8.54);

Future<ProviderContainer> _open(
  WidgetTester tester,
  FakeTripsRepository trips, {
  FakeServicesRepository? services,
  DateTimeRange? range,
  Size size = const Size(390, 1200),

  /// False where time must not run on: settling would wait out the page's retries.
  bool settle = true,
}) async {
  final container = await pumpApp(
    tester,
    locale: const Locale('en'),
    size: size,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device()),
      trips: trips,
      services: services,
    ),
  );
  container
      .read(routerProvider)
      .go(Routes.tripDiscover, extra: range ?? _range);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  return container;
}

/// Opens the folded wishes.
Future<void> _wishes(WidgetTester tester) async {
  await tester.tap(find.text('Wishes'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the places with distance, climate and the sources', (
    tester,
  ) async {
    final trips = FakeTripsRepository(
      discovered: const DiscoverResult(
        places: [_olbia, _davos, _ownIdea],
        provider: 'open-meteo',
        attribution: 'Weather data by Open-Meteo.com',
      ),
    );
    await _open(tester, trips);

    expect(find.text('Where to?'), findsOneWidget);
    expect(find.text('Sardinien · IT'), findsOneWidget);
    expect(find.text('about 950 km · a short flight'), findsOneWidget);
    expect(find.text('29° by day, 20° at night'), findsOneWidget);
    expect(find.text('2 rain days'), findsOneWidget);
    expect(find.text('Sea 24°'), findsOneWidget);
    expect(find.text('No climate values yet'), findsNWidgets(2));
    expect(find.text('Your idea'), findsOneWidget);
    expect(find.text('Weather data by Open-Meteo.com'), findsOneWidget);
    expect(
      find.textContaining('not a forecast', findRichText: true),
      findsOneWidget,
    );
    final asked = trips.discoverRequests.last;
    expect(asked.from, DateTime(2027, 7, 3));
    expect(asked.to, DateTime(2027, 7, 11));
    expect(asked.lang, 'en');
    expect(asked.filters.isEmpty, isTrue);
  });

  testWidgets('without a weather service the climate wishes explain why', (
    tester,
  ) async {
    await _open(tester, FakeTripsRepository());
    await _wishes(tester);

    expect(find.textContaining('With a weather service'), findsOneWidget);
    expect(
      find.text('Distances need a home place. A parent can set one.'),
      findsOneWidget,
    );
    final dry = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Little rain'),
    );
    expect(dry.onSelected, isNull);
    final warm = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '28 °C'),
    );
    expect(warm.onSelected, isNull);
    final far = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'a short flight'),
    );
    expect(far.onSelected, isNull);
  });

  testWidgets('the wishes go into the request', (tester) async {
    final trips = FakeTripsRepository(homePlace: _home);
    await _open(tester, trips, services: _withClimate());
    await _wishes(tester);

    expect(find.textContaining('With a weather service'), findsNothing);
    await _tap(tester, find.widgetWithText(ChoiceChip, '28 °C'));
    await _tap(tester, find.widgetWithText(FilterChip, 'Little rain'));
    await _tap(tester, find.widgetWithText(ChoiceChip, '20 °C'));
    await _tap(tester, find.widgetWithText(ChoiceChip, 'a long drive'));
    await _tap(tester, find.widgetWithText(FilterChip, 'Mountains'));

    final f = trips.discoverRequests.last.filters;
    expect(f.tempMin, 28);
    expect(f.dry, isTrue);
    expect(f.seaMin, 20);
    expect(f.effort, TravelEffort.car);
    // Wanting warm water means a place by the sea.
    expect(f.tags, containsAll(['sea', 'mountains']));

    // Dropping the sea drops its temperature.
    await _tap(tester, find.widgetWithText(FilterChip, 'Sea'));
    expect(trips.discoverRequests.last.filters.seaMin, isNull);
    expect(trips.discoverRequests.last.filters.tags, ['mountains']);

    await _tap(tester, find.widgetWithText(ChoiceChip, 'any').first);
    expect(trips.discoverRequests.last.filters.tempMin, isNull);
  });

  testWidgets('keeps a place as an idea and offers to open it', (tester) async {
    final trips = FakeTripsRepository(
      discovered: const DiscoverResult(places: [_olbia]),
    );
    await _open(tester, trips);

    await _tap(tester, find.text('Keep as idea'));

    final saved = trips.savedTrips.single;
    expect(saved.title, 'Sardinien');
    expect(saved.stage, TripStage.idea);
    expect(saved.destinationKey, 'olbia');
    expect(saved.country, 'IT');
    expect(saved.lat, 40.92);
    expect(saved.hasDates, isFalse);
    expect(find.text('Kept as an idea: Sardinien'), findsOneWidget);
    expect(find.text('Open'), findsWidgets);
  });

  testWidgets('an idea of the family opens its trip', (tester) async {
    final trips = FakeTripsRepository(
      trips: const [Trip(id: 't9', title: 'Nordsee')],
      discovered: const DiscoverResult(places: [_ownIdea]),
    );
    await _open(tester, trips);

    expect(find.text('Keep as idea'), findsNothing);
    await _tap(tester, find.widgetWithText(TextButton, 'Open'));
    expect(find.text('Where to?'), findsNothing);
  });

  testWidgets('asks again while climates are pending, then gives up', (
    tester,
  ) async {
    final trips = FakeTripsRepository(
      discovered: const DiscoverResult(places: [_davos], pending: 5),
    );
    await _open(tester, trips, settle: false);

    expect(
      find.text('Climate values are being loaded: 5 places to go'),
      findsOneWidget,
    );
    final first = trips.discoverRequests.length;

    // Progress: fewer pending, and the page keeps showing the list meanwhile.
    trips.discovered = const DiscoverResult(places: [_davos], pending: 3);
    await tester.pump(discoverPendingRetry);
    await tester.pump();
    await tester.pump();
    expect(trips.discoverRequests.length, first + 1);
    expect(find.text('Davos · CH'), findsOneWidget);
    expect(
      find.text('Climate values are being loaded: 3 places to go'),
      findsOneWidget,
    );

    // No progress for five minutes: it stops and says so.
    for (var i = 0; i < 12; i++) {
      await tester.pump(discoverPendingRetry);
      await tester.pump();
      await tester.pump();
    }
    expect(
      find.textContaining('More values will follow later'),
      findsOneWidget,
    );
    final after = trips.discoverRequests.length;
    await tester.pump(discoverPendingRetry * 3);
    expect(trips.discoverRequests.length, after);
  });

  testWidgets('no result says to loosen the wishes', (tester) async {
    await _open(tester, FakeTripsRepository());
    expect(find.textContaining('No place fits'), findsOneWidget);
  });

  testWidgets('without a range it starts with the next school holidays', (
    tester,
  ) async {
    final trips = FakeTripsRepository(
      windowList: [
        TripWindow(
          from: DateTime(2027, 4, 3),
          to: DateTime(2027, 4, 11),
          days: 9,
          kind: WindowKind.holidays,
          leaveDays: 5,
        ),
      ],
    );
    final container = await pumpApp(
      tester,
      locale: const Locale('en'),
      size: const Size(390, 1200),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
        trips: trips,
      ),
    );
    container.read(routerProvider).go(Routes.tripDiscover);
    await tester.pumpAndSettle();

    expect(trips.discoverRequests.last.from, DateTime(2027, 4, 3));
    expect(trips.discoverRequests.last.to, DateTime(2027, 4, 11));
  });

  testWidgets('without a range and without holidays: the month after next', (
    tester,
  ) async {
    final trips = FakeTripsRepository();
    final container = await pumpApp(
      tester,
      locale: const Locale('en'),
      size: const Size(390, 1200),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
        trips: trips,
      ),
    );
    container.read(routerProvider).go(Routes.tripDiscover);
    await tester.pumpAndSettle();

    final today = testNow();
    final asked = trips.discoverRequests.last;
    expect(asked.from, DateTime(today.year, today.month + 2));
    expect(asked.to, DateTime(today.year, today.month + 3, 0));
  });

  testWidgets('a child device does not offer it', (tester) async {
    final container = ProviderContainer(
      overrides: baseOverrides(
        identity: FakeIdentityRepository(
          current: device(register: UiRegister.kid),
        ),
      ),
    );
    addTearDown(container.dispose);
    await container.read(sessionStateProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripDiscoverPage(range: _range),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trips are not available here.'), findsOneWidget);
  });

  for (final size in const [Size(360, 800), Size(1000, 800)]) {
    testWidgets('lays out at $size without overflow', (tester) async {
      await _open(
        tester,
        FakeTripsRepository(
          homePlace: _home,
          discovered: const DiscoverResult(
            places: [_olbia, _davos, _ownIdea],
            attribution: 'Weather data by Open-Meteo.com',
          ),
        ),
        services: _withClimate(),
        size: size,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Sardinien · IT'), findsOneWidget);
    });
  }
}
