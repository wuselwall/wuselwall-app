import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/demo/demo_services.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/services/ui/services_page.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

import '../support/fake_trips.dart';
import '../support/fakes.dart';

const _openMeteo = ServiceProviderInfo(
  id: 'open-meteo',
  name: 'Open-Meteo',
  homepage: 'https://open-meteo.com',
  needsKey: false,
  cost: ServiceCost.free,
  capabilities: [
    ServiceCapability.climate,
    ServiceCapability.forecast,
    ServiceCapability.geocode,
  ],
  receives: [ServiceReceives.coordinates, ServiceReceives.searchText],
  attribution: 'Open-Meteo',
);

const _metNo = ServiceProviderInfo(
  id: 'met-no',
  name: 'MET Norway',
  homepage: 'https://www.met.no',
  needsKey: false,
  cost: ServiceCost.free,
  capabilities: [ServiceCapability.forecast],
  receives: [ServiceReceives.coordinates],
  attribution: 'MET',
);

const _owm = ServiceProviderInfo(
  id: 'openweathermap',
  name: 'OpenWeather',
  homepage: 'https://openweathermap.org',
  keyUrl: 'https://home.openweathermap.org/api_keys',
  needsKey: true,
  cost: ServiceCost.freeKey,
  capabilities: [ServiceCapability.forecast, ServiceCapability.geocode],
  receives: [ServiceReceives.coordinates, ServiceReceives.homeCoordinates],
  attribution: 'OWM',
);

FakeServicesRepository _services({
  List<ServiceProviderState> states = const [],
  ServiceTestResult test = const ServiceTestResult(ok: true),
  GeocodeResult? geocode,
}) => FakeServicesRepository(
  catalogueList: [_openMeteo, _metNo, _owm],
  states: states,
  testResult: test,
  geocodeResult: geocode,
);

const _meteoOn = ServiceProviderState(
  provider: 'open-meteo',
  enabled: true,
  capabilities: [
    ServiceCapability.climate,
    ServiceCapability.forecast,
    ServiceCapability.geocode,
  ],
);

const _adult = Member(
  id: 'p-adult',
  displayName: 'Mama',
  color: Color(0xFF3366AA),
  role: Role.member,
  active: true,
);

Future<ProviderContainer> _open(
  WidgetTester tester, {
  FakeServicesRepository? services,
  FakeTripsRepository? trips,
  Size size = const Size(390, 2400),
  SettingsView view = SettingsView.basic,
  bool guardian = true,
}) async {
  final container = await pumpApp(
    tester,
    locale: const Locale('en'),
    size: size,
    overrides: [
      ...baseOverrides(
        identity: FakeIdentityRepository(
          current: device(profileId: guardian ? guardianId : _adult.id),
          members: [...testMembers, _adult],
        ),
        services: services ?? _services(),
        trips: trips,
        settingsView: view,
      ),
    ],
  );
  container.read(routerProvider).go(Routes.servicesSettings);
  await tester.pumpAndSettle();
  return container;
}

Finder _card(String id) => find.byKey(ValueKey('service-$id'));

Finder _in(String id, Finder inner) =>
    find.descendant(of: _card(id), matching: inner);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'says what this is and shows every provider with what it receives',
    (tester) async {
      await _open(tester);

      expect(find.text('Weather and maps'), findsOneWidget);
      expect(find.textContaining('Everything here is off'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
      expect(_in('open-meteo', find.text('Free, no key')), findsOneWidget);
      expect(_in('open-meteo', find.text('Typical climate')), findsOneWidget);
      expect(_in('open-meteo', find.text('Place search')), findsOneWidget);
      expect(
        _in(
          'open-meteo',
          find.text(
            'It receives: the coordinates of a place, the text you search',
          ),
        ),
        findsOneWidget,
      );
      expect(
        _in('openweathermap', find.text('Free with your own key')),
        findsOneWidget,
      );
      expect(_in('openweathermap', find.text('Get a key')), findsOneWidget);
      expect(find.textContaining('terms are yours to accept'), findsOneWidget);
      expect(find.text('A parent can change this.'), findsNothing);
    },
  );

  testWidgets('switching on a provider without a key lists all it offers', (
    tester,
  ) async {
    final services = _services(states: const [_meteoOn]);
    await _open(tester, services: services);

    await _tap(tester, _in('met-no', find.byType(Switch)));

    final call = services.setCalls.single;
    expect(call.provider, 'met-no');
    expect(call.enabled, isTrue);
    expect(call.capabilities, [ServiceCapability.forecast]);
    // A provider never touched is placed after the last.
    expect(call.position, 1);
    expect(call.key, isNull);

    await _tap(tester, _in('open-meteo', find.byType(Switch)));
    expect(services.setCalls.last.provider, 'open-meteo');
    expect(services.setCalls.last.enabled, isFalse);
    expect(services.setCalls.last.capabilities, isNull);
  });

  testWidgets('a provider with a key is switched on with its key in one call', (
    tester,
  ) async {
    final services = _services();
    await _open(tester, services: services);

    // No switch before there is a key; the field is empty and hidden.
    expect(_in('openweathermap', find.byType(Switch)), findsNothing);
    final field = _in('openweathermap', find.byType(TextField));
    expect(tester.widget<TextField>(field).obscureText, isTrue);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    final save = _in('openweathermap', find.byType(FilledButton));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(field, 'secret-abcd');
    await tester.pump();
    await _tap(tester, save);

    final call = services.setCalls.single;
    expect(call.provider, 'openweathermap');
    expect(call.enabled, isTrue);
    expect(call.key, 'secret-abcd');
    expect(call.capabilities, [
      ServiceCapability.forecast,
      ServiceCapability.geocode,
    ]);
    expect(
      _in('openweathermap', find.text('Key stored …secret-abcd')),
      findsOneWidget,
    );
    expect(_in('openweathermap', find.byType(Switch)), findsOneWidget);
    // Never shown again: the field is gone and nothing prints the key.
    expect(find.text('secret-abcd'), findsNothing);
  });

  testWidgets('replacing and removing a stored key', (tester) async {
    final services = _services(
      states: const [
        ServiceProviderState(
          provider: 'openweathermap',
          enabled: true,
          capabilities: [ServiceCapability.forecast],
          hasKey: true,
          keyHint: '…abcd',
        ),
      ],
    );
    await _open(tester, services: services);

    expect(
      _in('openweathermap', find.text('Key stored …abcd')),
      findsOneWidget,
    );
    await _tap(tester, _in('openweathermap', find.text('Replace')));
    await tester.enterText(
      _in('openweathermap', find.byType(TextField)),
      'new-9999',
    );
    await tester.pump();
    await _tap(tester, _in('openweathermap', find.text('Save key')));
    expect(services.setCalls.single.key, 'new-9999');
    expect(services.setCalls.single.enabled, isNull);

    await _tap(tester, _in('openweathermap', find.text('Remove')));
    expect(
      find.textContaining('Remove the key of OpenWeather?'),
      findsOneWidget,
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Remove'));
    expect(services.setCalls.last.key, '');
    expect(services.setCalls.last.enabled, isFalse);
    expect(_in('openweathermap', find.byType(Switch)), findsNothing);
  });

  testWidgets('the test button says it works or why not', (tester) async {
    final services = _services(states: const [_meteoOn]);
    await _open(tester, services: services);

    await _tap(tester, _in('open-meteo', find.text('Test')));
    expect(services.tested, ['open-meteo']);
    expect(_in('open-meteo', find.text('Works')), findsOneWidget);

    services.testResult = const ServiceTestResult(
      ok: false,
      error: 'unauthorized',
    );
    await _tap(tester, _in('open-meteo', find.text('Test')));
    expect(
      _in('open-meteo', find.text('The provider refused the key.')),
      findsOneWidget,
    );

    services.testResult = const ServiceTestResult(ok: false, error: 'http_502');
    await _tap(tester, _in('open-meteo', find.text('Test')));
    expect(
      _in('open-meteo', find.text('The provider did not work this time.')),
      findsOneWidget,
    );
  });

  testWidgets('shows the last error calmly', (tester) async {
    await _open(
      tester,
      services: _services(
        states: const [
          ServiceProviderState(
            provider: 'open-meteo',
            enabled: true,
            capabilities: [ServiceCapability.climate],
            lastError: 'quota',
          ),
        ],
      ),
    );

    expect(
      find.text('Last call: The provider’s allowance is used up for now.'),
      findsOneWidget,
    );
  });

  testWidgets('Advanced: what it is used for, the order and the calls', (
    tester,
  ) async {
    final services = _services(
      states: const [
        ServiceProviderState(
          provider: 'open-meteo',
          enabled: true,
          capabilities: [ServiceCapability.climate, ServiceCapability.forecast],
          callsToday: 4,
        ),
        ServiceProviderState(
          provider: 'met-no',
          enabled: true,
          capabilities: [ServiceCapability.forecast],
          position: 1,
        ),
      ],
    );
    await _open(tester, services: services, view: SettingsView.advanced);

    expect(find.text('4 calls today'), findsOneWidget);

    // Geocode is not used yet: tick it.
    await _tap(
      tester,
      _in('open-meteo', find.widgetWithText(CheckboxListTile, 'Place search')),
    );
    expect(services.setCalls.single.capabilities, [
      ServiceCapability.climate,
      ServiceCapability.forecast,
      ServiceCapability.geocode,
    ]);

    // Move the first provider down: positions become 0, 1 in the new order.
    services.setCalls.clear();
    await _tap(tester, _in('open-meteo', find.byTooltip('Ask later')));
    expect(services.setCalls.map((c) => (c.provider, c.position)).toList(), [
      ('met-no', 0),
      ('open-meteo', 1),
    ]);
  });

  testWidgets('Basic leaves the capabilities and the order out', (
    tester,
  ) async {
    await _open(tester, services: _services(states: const [_meteoOn]));

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byTooltip('Ask later'), findsNothing);
  });

  testWidgets('someone who is not a parent only reads', (tester) async {
    final services = _services(states: const [_meteoOn]);
    await _open(tester, services: services, guardian: false);

    expect(find.text('A parent can change this.'), findsOneWidget);
    expect(find.text('Test'), findsNothing);
    expect(find.text('Set'), findsNothing);
    expect(find.text('Save key and switch on'), findsNothing);
    expect(find.text('Needs a key first'), findsOneWidget);
    for (final s in tester.widgetList<Switch>(find.byType(Switch))) {
      expect(s.onChanged, isNull);
    }
    expect(services.setCalls, isEmpty);
  });

  testWidgets('sets the home place by typing coordinates', (tester) async {
    final trips = FakeTripsRepository();
    await _open(tester, trips: trips);

    await _tap(tester, find.text('Set'));
    expect(find.text('Save'), findsOneWidget);
    // Without a place search the dialog says to type them.
    expect(
      find.textContaining('No place search is switched on'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Name of the place'),
      'Zürich',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Latitude'),
      '47,3769',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Longitude'), '8.54');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final home = trips.homes.single!;
    expect(home.name, 'Zürich');
    expect(home.lat, closeTo(47.3769, 1e-9));
    expect(find.text('Zürich · 47.38, 8.54'), findsOneWidget);
  });

  testWidgets('finds the home place by name with a place search on', (
    tester,
  ) async {
    final trips = FakeTripsRepository();
    final services = _services(
      states: const [_meteoOn],
      geocode: const GeocodeResult(
        places: [
          GeoPlace(
            name: 'Olbia',
            country: 'IT',
            admin: 'Sardegna',
            lat: 40.92,
            lon: 9.5,
          ),
        ],
      ),
    );
    await _open(tester, services: services, trips: trips);

    await _tap(tester, find.text('Set'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Name of the place'),
      'Olb',
    );
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(services.geocoded.single.q, 'Olb');
    await tester.tap(find.text('Sardegna, IT'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final home = trips.homes.single!;
    expect((home.name, home.lat, home.lon), ('Olbia', 40.92, 9.5));
  });

  testWidgets('forgets the home place after asking', (tester) async {
    final trips = FakeTripsRepository(
      homePlace: const TripHome(name: 'Zürich', lat: 47.37, lon: 8.54),
    );
    await _open(tester, trips: trips);

    expect(find.text('Zürich · 47.37, 8.54'), findsOneWidget);
    await _tap(tester, find.text('Forget'));
    await tester.tap(find.widgetWithText(FilledButton, 'Forget'));
    await tester.pumpAndSettle();

    expect(trips.homes.single, isNull);
    expect(find.text('Not set'), findsOneWidget);
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
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ServicesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Weather and maps are not available here.'),
      findsOneWidget,
    );
  });

  for (final size in const [Size(360, 800), Size(1000, 800)]) {
    testWidgets('looks right with the demo catalogue at $size', (tester) async {
      // The seven providers of the demo, as the guide's screenshots show them.
      final demo = DemoServicesRepository();
      await _open(
        tester,
        size: size,
        view: SettingsView.advanced,
        services: FakeServicesRepository(
          catalogueList: (await demo.catalogue()).unwrap(),
          states: (await demo.providers()).unwrap(),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Open-Meteo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Google Maps Platform'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Google Maps Platform'), findsOneWidget);
    });
  }
}
