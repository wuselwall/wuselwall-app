import 'dart:convert';
import 'dart:math' as math;

import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_clock.dart';
import 'package:wuselwall/demo/demo_trips.dart';
import 'package:wuselwall/features/services/data/services_repository.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';

/// The opt-in services of the demo family (ADR-022): the catalogue of the seven first
/// providers, with `open-meteo` switched on for climate, forecast and place search, as a
/// guardian would have done. Answers are made up from the coordinates; nothing contacts
/// a provider. Switching a provider on or off and storing a key work in memory.
class DemoServicesRepository implements ServicesRepository {
  DemoServicesRepository({DateTime Function()? clock})
    : _clock = clock ?? DemoClock.now;

  final DateTime Function() _clock;

  static const _catalogue = <ServiceProviderInfo>[
    ServiceProviderInfo(
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
      attribution: 'Weather data by Open-Meteo.com',
    ),
    ServiceProviderInfo(
      id: 'met-no',
      name: 'MET Norway',
      homepage: 'https://www.met.no',
      needsKey: false,
      cost: ServiceCost.free,
      capabilities: [ServiceCapability.forecast],
      receives: [ServiceReceives.coordinates],
      attribution: 'Data from MET Norway',
    ),
    ServiceProviderInfo(
      id: 'nominatim',
      name: 'Nominatim (OpenStreetMap)',
      homepage: 'https://nominatim.org',
      needsKey: false,
      cost: ServiceCost.free,
      capabilities: [ServiceCapability.geocode],
      receives: [ServiceReceives.searchText],
      attribution: '© OpenStreetMap contributors',
    ),
    ServiceProviderInfo(
      id: 'openweathermap',
      name: 'OpenWeather',
      homepage: 'https://openweathermap.org',
      keyUrl: 'https://home.openweathermap.org/api_keys',
      needsKey: true,
      cost: ServiceCost.freeKey,
      capabilities: [ServiceCapability.forecast, ServiceCapability.geocode],
      receives: [ServiceReceives.coordinates, ServiceReceives.searchText],
      attribution: 'Weather data by OpenWeather',
    ),
    ServiceProviderInfo(
      id: 'meteostat',
      name: 'Meteostat',
      homepage: 'https://meteostat.net',
      keyUrl: 'https://dev.meteostat.net',
      needsKey: true,
      cost: ServiceCost.freeKey,
      capabilities: [ServiceCapability.climate],
      receives: [ServiceReceives.coordinates],
      attribution: 'Climate data by Meteostat',
    ),
    ServiceProviderInfo(
      id: 'openrouteservice',
      name: 'openrouteservice',
      homepage: 'https://openrouteservice.org',
      keyUrl: 'https://openrouteservice.org/dev/#/signup',
      needsKey: true,
      cost: ServiceCost.freeKey,
      capabilities: [ServiceCapability.route, ServiceCapability.geocode],
      receives: [
        ServiceReceives.coordinates,
        ServiceReceives.homeCoordinates,
        ServiceReceives.searchText,
      ],
      attribution:
          '© openrouteservice.org by HeiGIT | Map data © OpenStreetMap',
    ),
    ServiceProviderInfo(
      id: 'google',
      name: 'Google Maps Platform',
      homepage: 'https://developers.google.com/maps',
      keyUrl: 'https://console.cloud.google.com/apis/credentials',
      needsKey: true,
      cost: ServiceCost.paidKey,
      capabilities: [
        ServiceCapability.geocode,
        ServiceCapability.route,
        ServiceCapability.map,
      ],
      receives: [
        ServiceReceives.coordinates,
        ServiceReceives.homeCoordinates,
        ServiceReceives.searchText,
      ],
      attribution: 'Map data © Google',
    ),
  ];

  late final List<ServiceProviderState> _states = [
    ServiceProviderState(
      provider: 'open-meteo',
      enabled: true,
      capabilities: const [
        ServiceCapability.climate,
        ServiceCapability.forecast,
        ServiceCapability.geocode,
      ],
      lastOkAt: _clock().subtract(const Duration(hours: 5)),
      callsToday: 4,
    ),
  ];

  @override
  Future<Result<List<ServiceProviderInfo>>> catalogue() async =>
      const Ok(_catalogue);

  @override
  Future<Result<List<ServiceProviderState>>> providers() async =>
      Ok([..._states]);

  @override
  Future<Result<void>> setProvider({
    required String? actor,
    required String provider,
    bool? enabled,
    List<ServiceCapability>? capabilities,
    int? position,
    String? key,
  }) async {
    final info = _catalogue.where((p) => p.id == provider).firstOrNull;
    if (info == null) {
      return const Err(ValidationFailure(code: 'service_invalid'));
    }
    final i = _states.indexWhere((s) => s.provider == provider);
    final old = i >= 0 ? _states[i] : null;
    final hasKey = key == null ? old?.hasKey ?? false : key.isNotEmpty;
    final next = ServiceProviderState(
      provider: provider,
      enabled: enabled ?? old?.enabled ?? false,
      capabilities: capabilities ?? old?.capabilities ?? const [],
      position: position ?? old?.position ?? _states.length,
      hasKey: hasKey,
      keyHint: !hasKey
          ? null
          : key == null || key.isEmpty
          ? old?.keyHint
          : '…${key.substring(key.length > 4 ? key.length - 4 : 0)}',
      lastOkAt: old?.lastOkAt,
      callsToday: old?.callsToday ?? 0,
    );
    i >= 0 ? _states[i] = next : _states.add(next);
    return const Ok(null);
  }

  @override
  Future<Result<ServiceTestResult>> test({
    required String provider,
    String? actor,
  }) async {
    final state = _states.where((s) => s.provider == provider).firstOrNull;
    final info = _catalogue.where((p) => p.id == provider).firstOrNull;
    if (info == null) {
      return const Err(ValidationFailure(code: 'service_invalid'));
    }
    if (info.needsKey && !(state?.hasKey ?? false)) {
      return const Ok(ServiceTestResult(ok: false, error: 'unauthorized'));
    }
    return const Ok(ServiceTestResult(ok: true));
  }

  bool _offered(ServiceCapability c) => _states.any(
    (s) =>
        s.enabled &&
        s.capabilities.contains(c) &&
        (!_catalogue.firstWhere((p) => p.id == s.provider).needsKey ||
            s.hasKey),
  );

  Result<T> _off<T>() => const Err(ConflictFailure(code: 'service_off'));

  static const _places = <(String, String, String?, double, double)>[
    ('Olbia', 'IT', 'Sardegna', 40.92, 9.5),
    ('Palma', 'ES', 'Illes Balears', 39.57, 2.65),
    ('Siena', 'IT', 'Toscana', 43.32, 11.33),
    ('Lisboa', 'PT', null, 38.72, -9.14),
    ('Sylt', 'DE', 'Schleswig-Holstein', 54.9, 8.3),
    ('Davos', 'CH', 'Graubünden', 46.8, 9.84),
  ];

  @override
  Future<Result<GeocodeResult>> geocode({
    required String q,
    String? lang,
    String? actor,
  }) async {
    if (!_offered(ServiceCapability.geocode)) return _off();
    final needle = q.trim().toLowerCase();
    return Ok(
      GeocodeResult(
        places: [
          for (final (name, country, admin, lat, lon) in _places)
            if (needle.isNotEmpty && name.toLowerCase().contains(needle))
              GeoPlace(
                name: name,
                country: country,
                admin: admin,
                lat: lat,
                lon: lon,
              ),
        ],
        provider: 'open-meteo',
        attribution: 'Weather data by Open-Meteo.com',
      ),
    );
  }

  /// Mean day temperature of [month] at [lat]: warm in the south, cold in the north, and
  /// a cosine through the year (mirrored south of the equator).
  double _tmax(double lat, int month) {
    final mean = 33 - lat.abs() * 0.35;
    final amp = 1 + lat.abs() * 0.23;
    final phase = lat >= 0 ? 7.5 : 1.5;
    return mean + amp * math.cos((month - phase) / 12 * 2 * math.pi);
  }

  @override
  Future<Result<Forecast>> forecast({
    required double lat,
    required double lon,
    String? actor,
  }) async {
    if (!_offered(ServiceCapability.forecast)) return _off();
    final today = dayOf(_clock());
    const codes = [
      WeatherCode.clear,
      WeatherCode.clear,
      WeatherCode.partly,
      WeatherCode.clear,
      WeatherCode.cloudy,
      WeatherCode.rain,
      WeatherCode.partly,
    ];
    return Ok(
      Forecast(
        days: [
          for (var i = 0; i < 16; i++)
            ForecastDay(
              date: addDays(today, i),
              tmax: double.parse(
                (_tmax(lat, addDays(today, i).month) + (i % 4) - 1.5)
                    .toStringAsFixed(1),
              ),
              tmin: double.parse(
                (_tmax(lat, addDays(today, i).month) - 9 + (i % 3) * 0.5)
                    .toStringAsFixed(1),
              ),
              precipMm: codes[i % 7] == WeatherCode.rain ? 4.2 : 0,
              precipProb: codes[i % 7] == WeatherCode.rain ? 70 : 10,
              code: codes[i % 7],
            ),
        ],
        provider: 'open-meteo',
        attribution: 'Weather data by Open-Meteo.com',
      ),
    );
  }

  @override
  Future<Result<Climate>> climate({
    required double lat,
    required double lon,
    String? actor,
  }) async {
    if (!_offered(ServiceCapability.climate)) return _off();
    return Ok(
      Climate(
        months: [
          for (var m = 1; m <= 12; m++)
            ClimateMonth(
              month: m,
              tmax: double.parse(_tmax(lat, m).toStringAsFixed(1)),
              tmin: double.parse((_tmax(lat, m) - 9).toStringAsFixed(1)),
              rainDays: 2 + (m + 3) % 6.0,
              sunHours: double.parse(
                (6 + 3 * math.cos((m - 7) / 12 * 2 * math.pi)).toStringAsFixed(
                  1,
                ),
              ),
              sea: lat.abs() < 46
                  ? double.parse(
                      (18 + 6 * math.cos((m - 8) / 12 * 2 * math.pi))
                          .toStringAsFixed(1),
                    )
                  : null,
            ),
        ],
        provider: 'open-meteo',
        attribution: 'Weather data by Open-Meteo.com',
      ),
    );
  }

  @override
  Future<Result<RouteInfo>> route({
    required ({double lat, double lon}) from,
    required ({double lat, double lon}) to,
    String? actor,
  }) async {
    if (!_offered(ServiceCapability.route)) return _off();
    final km = demoDistanceKm(from.lat, from.lon, to.lat, to.lon) * 1.3;
    return Ok(
      RouteInfo(
        km: km.roundToDouble(),
        minutes: (km / 85 * 60).round(),
        provider: 'openrouteservice',
        attribution: '© openrouteservice.org',
      ),
    );
  }

  /// A 1×1 transparent PNG: the demo has no map to show.
  static final _blank = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  Future<Result<MapPicture>> map({
    required double lat,
    required double lon,
    int? zoom,
    required int width,
    required int height,
    String? actor,
  }) async {
    if (!_offered(ServiceCapability.map)) return _off();
    return Ok(MapPicture(bytes: _blank, mime: 'image/png', provider: 'google'));
  }
}
