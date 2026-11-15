import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';

Map<String, dynamic> _object(Object? json) =>
    Map<String, dynamic>.from(json! as Map);

/// The opt-in services (ADR-023, specs/30 "Services"): the catalogue and the household's
/// choice, and the answers of the `services` Edge Function. Only the family's server
/// contacts a provider; the app asks the server.
///
/// A call fails with `service_off` (409, no enabled provider offers the capability),
/// `service_key_missing` (409), `service_limit` (429), `service_failed` (502) or
/// `invalid_request` (400): the failure's `code` is that string. [actor] is the acting
/// profile on a shared device (`actor_profile_id`), null on a personal one.
class ServicesRepository {
  const ServicesRepository(this._api);

  final ApiClient _api;

  /// The providers the server knows, with what each receives (any member).
  Future<Result<List<ServiceProviderInfo>>> catalogue() => _api.function(
    'services',
    body: {'action': 'catalogue'},
    parse: (json) => [
      for (final row in (_object(json)['providers'] as List?) ?? const [])
        ServiceProviderInfo.fromJson(_object(row)),
    ],
    cacheKey: 'service-catalogue',
  );

  /// What the household did with each provider (`api.service_providers`, no secret).
  Future<Result<List<ServiceProviderState>>> providers() => _api.select(
    'service_providers',
    parse: ServiceProviderState.fromJson,
    build: (q) => q.order('position', ascending: true),
    cacheKey: 'service-providers',
  );

  /// Changes how the household uses [provider]; only the given parts change. A guardian
  /// only. [key]: a string stores the key, `''` removes it, null keeps it. The server
  /// never returns a key.
  Future<Result<void>> setProvider({
    required String? actor,
    required String provider,
    bool? enabled,
    List<ServiceCapability>? capabilities,
    int? position,
    String? key,
  }) => _api.rpc(
    'service_provider_set',
    params: {
      'p_actor': actor,
      'p_provider': provider,
      'p_config': {
        'enabled': ?enabled,
        if (capabilities != null)
          'capabilities': [for (final c in capabilities) c.wire],
        'position': ?position,
        'key': ?key,
      },
    },
    parse: (_) {},
  );

  /// One small real call with the stored key (a guardian).
  Future<Result<ServiceTestResult>> test({
    required String provider,
    String? actor,
  }) => _call(
    {'action': 'test', 'provider': provider},
    actor,
    ServiceTestResult.fromJson,
  );

  /// Finds places by name; [lang] is the language of the names (`de`, `en`, `fr`, `es`).
  Future<Result<GeocodeResult>> geocode({
    required String q,
    String? lang,
    String? actor,
  }) => _call(
    {'action': 'geocode', 'q': q, 'lang': ?lang},
    actor,
    GeocodeResult.fromJson,
  );

  /// The forecast at a place. Stored for offline reading under its coordinates.
  Future<Result<Forecast>> forecast({
    required double lat,
    required double lon,
    String? actor,
  }) => _call(
    {'action': 'forecast', 'lat': lat, 'lon': lon},
    actor,
    Forecast.fromJson,
    cacheKey: 'service-forecast:${_at(lat, lon)}',
  );

  /// What is typical at a place, month by month.
  Future<Result<Climate>> climate({
    required double lat,
    required double lon,
    String? actor,
  }) => _call(
    {'action': 'climate', 'lat': lat, 'lon': lon},
    actor,
    Climate.fromJson,
    cacheKey: 'service-climate:${_at(lat, lon)}',
  );

  /// Driving distance and time between two places.
  Future<Result<RouteInfo>> route({
    required ({double lat, double lon}) from,
    required ({double lat, double lon}) to,
    String? actor,
  }) => _call(
    {
      'action': 'route',
      'from': {'lat': from.lat, 'lon': from.lon},
      'to': {'lat': to.lat, 'lon': to.lon},
    },
    actor,
    RouteInfo.fromJson,
    cacheKey: 'service-route:${_at(from.lat, from.lon)}:${_at(to.lat, to.lon)}',
  );

  /// A map picture of a place, fetched by the server.
  Future<Result<MapPicture>> map({
    required double lat,
    required double lon,
    int? zoom,
    required int width,
    required int height,
    String? actor,
  }) => _call(
    {
      'action': 'map',
      'lat': lat,
      'lon': lon,
      'zoom': ?zoom,
      'width': width,
      'height': height,
    },
    actor,
    MapPicture.fromJson,
  );

  Future<Result<T>> _call<T>(
    Map<String, dynamic> body,
    String? actor,
    T Function(Map<String, dynamic> json) parse, {
    String? cacheKey,
  }) => _api.function(
    'services',
    body: {...body, 'actor_profile_id': ?actor},
    parse: (json) => parse(_object(json)),
    cacheKey: cacheKey,
  );
}

String _at(double lat, double lon) =>
    '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';

final servicesRepositoryProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(ref.watch(apiClientProvider)),
);
