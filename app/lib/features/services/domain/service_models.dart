import 'dart:convert';
import 'dart:typed_data';

import 'package:wuselwall/features/board/domain/week_board.dart' show parseDate;

/// The opt-in services (ADR-023, specs/30 "Services"): the providers a guardian can
/// switch on, and what they answer through the family's server. Shaped by the `services`
/// Edge Function's answers and `api.service_providers`.

List<String> _strings(Object? v) =>
    ((v as List?) ?? const []).cast<String>().toList(growable: false);

List<Map<String, dynamic>> _maps(Object? v) => [
  for (final row in (v as List?) ?? const <Object?>[])
    Map<String, dynamic>.from(row! as Map),
];

double? _double(Object? v) => (v as num?)?.toDouble();

/// What a provider can do.
enum ServiceCapability {
  /// What is typical in each month (discovery, and a trip's page).
  climate,

  /// The days before and during a trip.
  forecast,

  /// Finding a destination's or the home's coordinates by name.
  geocode,

  /// Driving time and distance from home.
  route,

  /// A map picture on the trip page.
  map;

  static ServiceCapability? parse(String? v) {
    for (final c in values) {
      if (c.name == v) return c;
    }
    return null;
  }

  String get wire => name;
}

/// What a provider is sent, shown before it is switched on.
enum ServiceReceives {
  /// A destination's coordinates.
  coordinates,

  /// What the family typed into a place search.
  searchText,

  /// The home place, rounded to two decimals (for a route).
  homeCoordinates;

  static ServiceReceives? parse(String? v) => switch (v) {
    'coordinates' => coordinates,
    'search_text' => searchText,
    'home_coordinates' => homeCoordinates,
    _ => null,
  };
}

/// What using a provider costs.
enum ServiceCost {
  free,

  /// Free, with a key of the family's own.
  freeKey,

  /// A key of the family's own that may cost money.
  paidKey;

  static ServiceCost parse(String? v) => switch (v) {
    'free_key' => freeKey,
    'paid_key' => paidKey,
    _ => free,
  };
}

List<ServiceCapability> _capabilities(Object? v) => [
  for (final s in _strings(v)) ?ServiceCapability.parse(s),
];

/// One row of the server's catalogue (`services` function, action `catalogue`): what a
/// provider is, whether it needs a key and what it receives. A new provider appears with
/// a server release, without an app release.
class ServiceProviderInfo {
  const ServiceProviderInfo({
    required this.id,
    required this.name,
    required this.homepage,
    required this.needsKey,
    required this.cost,
    required this.capabilities,
    required this.receives,
    required this.attribution,
    this.keyUrl,
  });

  factory ServiceProviderInfo.fromJson(Map<String, dynamic> json) =>
      ServiceProviderInfo(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        homepage: json['homepage'] as String? ?? '',
        keyUrl: json['key_url'] as String?,
        needsKey: json['needs_key'] as bool? ?? false,
        cost: ServiceCost.parse(json['cost'] as String?),
        capabilities: _capabilities(json['capabilities']),
        receives: [
          for (final s in _strings(json['receives'])) ?ServiceReceives.parse(s),
        ],
        attribution: json['attribution'] as String? ?? '',
      );

  /// `^[a-z0-9-]{2,40}$`: `open-meteo`, `met-no`, `nominatim`, `openweathermap`,
  /// `meteostat`, `openrouteservice`, `google` in the first build.
  final String id;

  /// The provider's own name; not translated.
  final String name;
  final String homepage;

  /// Where a family gets a key; null when none is needed.
  final String? keyUrl;
  final bool needsKey;
  final ServiceCost cost;
  final List<ServiceCapability> capabilities;
  final List<ServiceReceives> receives;

  /// The line the provider's terms ask to be shown with its data.
  final String attribution;

  bool offers(ServiceCapability c) => capabilities.contains(c);
}

/// A row of `api.service_providers`: what the household did with a provider. A provider
/// without a row has never been touched (off).
class ServiceProviderState {
  const ServiceProviderState({
    required this.provider,
    required this.enabled,
    required this.capabilities,
    this.position = 0,
    this.hasKey = false,
    this.keyHint,
    this.lastOkAt,
    this.lastError,
    this.callsToday = 0,
  });

  factory ServiceProviderState.fromJson(Map<String, dynamic> json) =>
      ServiceProviderState(
        provider: json['provider'] as String,
        enabled: json['enabled'] as bool? ?? false,
        capabilities: _capabilities(json['capabilities']),
        position: (json['position'] as num?)?.toInt() ?? 0,
        hasKey: json['has_key'] as bool? ?? false,
        keyHint: json['key_hint'] as String?,
        lastOkAt: json['last_ok_at'] == null
            ? null
            : DateTime.parse(json['last_ok_at'] as String),
        lastError: json['last_error'] as String?,
        callsToday: (json['calls_today'] as num?)?.toInt() ?? 0,
      );

  final String provider;
  final bool enabled;

  /// Which of the provider's capabilities the household uses it for.
  final List<ServiceCapability> capabilities;

  /// The household's order: the first enabled provider that offers a capability answers.
  final int position;

  /// A key is stored (it is never readable); [keyHint] shows its last four characters
  /// as "…abcd".
  final bool hasKey;
  final String? keyHint;
  final DateTime? lastOkAt;

  /// A short code of the last failure (`http_500`, `timeout`, `unauthorized`, `quota`,
  /// `bad_answer`); null after a success.
  final String? lastError;
  final int callsToday;
}

/// A provider as the settings page shows it: the catalogue row with what the household
/// did with it ([state] is null for one never touched).
class ServiceProviderView {
  const ServiceProviderView(this.info, this.state);

  final ServiceProviderInfo info;
  final ServiceProviderState? state;

  bool get enabled => state?.enabled ?? false;

  /// Enabled and, if it needs a key, with one stored: it can answer.
  bool get ready => enabled && (!info.needsKey || (state?.hasKey ?? false));

  /// Whether it will be asked for [c]: ready, offering it and switched on for it. A
  /// provider switched on with no capability listed serves none, so the page lists every
  /// capability it offers when a guardian enables it.
  bool servesCapability(ServiceCapability c) =>
      ready && info.offers(c) && (state?.capabilities.contains(c) ?? false);
}

/// The answer of the `test` action: one small real call with the stored key.
class ServiceTestResult {
  const ServiceTestResult({required this.ok, this.error});

  factory ServiceTestResult.fromJson(Map<String, dynamic> json) =>
      ServiceTestResult(
        ok: json['ok'] as bool? ?? false,
        error: json['error'] as String?,
      );

  final bool ok;

  /// A short code (`unauthorized`, `timeout`, ...).
  final String? error;
}

/// A place found by name (`geocode`).
class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.country,
    required this.lat,
    required this.lon,
    this.admin,
  });

  factory GeoPlace.fromJson(Map<String, dynamic> json) => GeoPlace(
    name: json['name'] as String? ?? '',
    country: json['country'] as String? ?? '',
    admin: json['admin'] as String?,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
  );

  final String name;

  /// ISO 3166-1 alpha-2, upper case; empty when unknown.
  final String country;

  /// Region or state, to tell two places of one name apart.
  final String? admin;
  final double lat;
  final double lon;
}

/// The `geocode` answer.
class GeocodeResult {
  const GeocodeResult({required this.places, this.provider, this.attribution});

  factory GeocodeResult.fromJson(Map<String, dynamic> json) => GeocodeResult(
    places: [for (final m in _maps(json['places'])) GeoPlace.fromJson(m)],
    provider: json['provider'] as String?,
    attribution: json['attribution'] as String?,
  );

  final List<GeoPlace> places;
  final String? provider;
  final String? attribution;
}

/// What a weather says.
enum WeatherCode {
  clear,
  partly,
  cloudy,
  fog,
  rain,
  snow,
  storm;

  static WeatherCode parse(String? v) {
    for (final c in values) {
      if (c.name == v) return c;
    }
    return cloudy;
  }
}

/// One day of a forecast.
class ForecastDay {
  const ForecastDay({
    required this.date,
    required this.tmax,
    required this.tmin,
    required this.precipMm,
    required this.code,
    this.precipProb,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> json) => ForecastDay(
    date: parseDate(json['date'] as String),
    tmax: (json['tmax'] as num).toDouble(),
    tmin: (json['tmin'] as num).toDouble(),
    precipMm: _double(json['precip_mm']) ?? 0,
    precipProb: _double(json['precip_prob']),
    code: WeatherCode.parse(json['code'] as String?),
  );

  /// The place's own date.
  final DateTime date;
  final double tmax;
  final double tmin;
  final double precipMm;

  /// 0–100, when the provider says.
  final double? precipProb;
  final WeatherCode code;
}

/// The `forecast` answer.
class Forecast {
  const Forecast({required this.days, this.provider, this.attribution});

  factory Forecast.fromJson(Map<String, dynamic> json) => Forecast(
    days: [for (final m in _maps(json['days'])) ForecastDay.fromJson(m)],
    provider: json['provider'] as String?,
    attribution: json['attribution'] as String?,
  );

  final List<ForecastDay> days;
  final String? provider;

  /// Shown with the numbers.
  final String? attribution;

  /// The days from [from] to [to], both included.
  List<ForecastDay> between(DateTime from, DateTime to) => [
    for (final d in days)
      if (!d.date.isBefore(from) && !d.date.isAfter(to)) d,
  ];
}

/// One month of what is typical at a place.
class ClimateMonth {
  const ClimateMonth({
    required this.month,
    required this.tmax,
    required this.tmin,
    this.rainDays,
    this.precipMm,
    this.sunHours,
    this.sea,
  });

  factory ClimateMonth.fromJson(Map<String, dynamic> json) => ClimateMonth(
    month: (json['month'] as num).toInt(),
    tmax: (json['tmax'] as num).toDouble(),
    tmin: (json['tmin'] as num).toDouble(),
    rainDays: _double(json['rain_days']),
    precipMm: _double(json['precip_mm']),
    sunHours: _double(json['sun_hours']),
    sea: _double(json['sea']),
  );

  /// 1–12.
  final int month;
  final double tmax;
  final double tmin;
  final double? rainDays;
  final double? precipMm;
  final double? sunHours;

  /// The sea temperature, where the provider has it.
  final double? sea;
}

/// The `climate` answer.
class Climate {
  const Climate({required this.months, this.provider, this.attribution});

  factory Climate.fromJson(Map<String, dynamic> json) => Climate(
    months: [for (final m in _maps(json['months'])) ClimateMonth.fromJson(m)],
    provider: json['provider'] as String?,
    attribution: json['attribution'] as String?,
  );

  final List<ClimateMonth> months;
  final String? provider;
  final String? attribution;

  /// The months a trip from [from] to [to] touches, in order (at most twelve).
  List<ClimateMonth> monthsFor(DateTime from, DateTime to) {
    final out = <ClimateMonth>[];
    var y = from.year;
    var m = from.month;
    while (y < to.year || (y == to.year && m <= to.month)) {
      for (final c in months) {
        if (c.month == m) out.add(c);
      }
      if (out.length >= 12) break;
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return out;
  }
}

/// The `route` answer: driving distance and time from home.
class RouteInfo {
  const RouteInfo({
    required this.km,
    required this.minutes,
    this.provider,
    this.attribution,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) => RouteInfo(
    km: (json['km'] as num).toDouble(),
    minutes: (json['minutes'] as num).toInt(),
    provider: json['provider'] as String?,
    attribution: json['attribution'] as String?,
  );

  final double km;
  final int minutes;
  final String? provider;
  final String? attribution;
}

/// The `map` answer: a picture the server fetched.
class MapPicture {
  const MapPicture({
    required this.bytes,
    required this.mime,
    this.provider,
    this.attribution,
  });

  factory MapPicture.fromJson(Map<String, dynamic> json) => MapPicture(
    bytes: base64Decode(json['image_base64'] as String),
    mime: json['mime'] as String? ?? 'image/png',
    provider: json['provider'] as String?,
    attribution: json['attribution'] as String?,
  );

  /// The decoded image, for `Image.memory`.
  final Uint8List bytes;
  final String mime;
  final String? provider;

  /// Shown with the picture.
  final String? attribution;
}
