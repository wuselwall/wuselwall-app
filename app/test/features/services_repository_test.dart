import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/services/data/services_repository.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';

import 'trips_repository_test.dart' show Sent;

({ServicesRepository repo, List<Sent> sent}) fixture(
  (int, Object?) Function(Sent request) answer,
) {
  final sent = <Sent>[];
  final client = MockClient((req) async {
    final s = Sent(
      req.method,
      req.url,
      req.body.isEmpty ? null : jsonDecode(req.body),
    );
    sent.add(s);
    final (status, json) = answer(s);
    return http.Response(
      jsonEncode(json),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: req,
    );
  });
  return (
    repo: ServicesRepository(
      ApiClient(
        SupabaseClient(
          'http://localhost:54321',
          'anon-key',
          httpClient: client,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ),
    ),
    sent: sent,
  );
}

void main() {
  test('the catalogue is read from the services function', () async {
    final f = fixture(
      (r) => (
        200,
        {
          'providers': [
            {
              'id': 'open-meteo',
              'name': 'Open-Meteo',
              'homepage': 'https://open-meteo.com',
              'key_url': null,
              'needs_key': false,
              'cost': 'free',
              'capabilities': ['climate', 'forecast', 'geocode'],
              'receives': ['coordinates', 'search_text'],
              'attribution': 'Weather data by Open-Meteo.com',
            },
            {
              'id': 'google',
              'name': 'Google',
              'homepage': 'https://developers.google.com/maps',
              'key_url': 'https://console.cloud.google.com',
              'needs_key': true,
              'cost': 'paid_key',
              'capabilities': ['geocode', 'route', 'map', 'unknown-one'],
              'receives': ['home_coordinates', 'something-new'],
              'attribution': 'x',
            },
          ],
        },
      ),
    );
    final list = (await f.repo.catalogue()).unwrap();
    expect(f.sent.single.path, '/functions/v1/services');
    expect(f.sent.single.params, {'action': 'catalogue'});
    expect(list.first.capabilities, [
      ServiceCapability.climate,
      ServiceCapability.forecast,
      ServiceCapability.geocode,
    ]);
    expect(list.first.receives, [
      ServiceReceives.coordinates,
      ServiceReceives.searchText,
    ]);
    expect(list.first.cost, ServiceCost.free);
    expect(list.last.cost, ServiceCost.paidKey);
    expect(list.last.needsKey, isTrue);
    // A capability this app does not know is ignored, not an error.
    expect(list.last.capabilities, hasLength(3));
    expect(list.last.receives, [ServiceReceives.homeCoordinates]);
    expect(list.last.offers(ServiceCapability.map), isTrue);
  });

  test('the household\'s choice comes from the api view', () async {
    final f = fixture(
      (r) => (
        200,
        [
          {
            'provider': 'open-meteo',
            'enabled': true,
            'capabilities': ['forecast'],
            'position': 0,
            'has_key': false,
            'key_hint': null,
            'last_ok_at': '2026-11-15T08:00:00Z',
            'last_error': null,
            'calls_day': '2026-11-15',
            'calls_today': 3,
          },
        ],
      ),
    );
    final states = (await f.repo.providers()).unwrap();
    expect(f.sent.single.path, '/rest/v1/service_providers');
    expect(states.single.enabled, isTrue);
    expect(states.single.capabilities, [ServiceCapability.forecast]);
    expect(states.single.callsToday, 3);
  });

  group('setProvider', () {
    test('sends only what is given', () async {
      final f = fixture((r) => (204, null));
      await f.repo.setProvider(actor: 'a', provider: 'google', enabled: true);
      expect(f.sent.single.path, '/rest/v1/rpc/service_provider_set');
      expect(f.sent.single.params, {
        'p_actor': 'a',
        'p_provider': 'google',
        'p_config': {'enabled': true},
      });
    });

    test('a key is stored, an empty one removes it, none keeps it', () async {
      final f = fixture((r) => (204, null));
      await f.repo.setProvider(
        actor: null,
        provider: 'google',
        capabilities: [ServiceCapability.geocode, ServiceCapability.route],
        position: 2,
        key: 'secret',
      );
      await f.repo.setProvider(actor: null, provider: 'google', key: '');
      await f.repo.setProvider(actor: null, provider: 'google', enabled: false);
      expect(f.sent[0].params['p_config'], {
        'capabilities': ['geocode', 'route'],
        'position': 2,
        'key': 'secret',
      });
      expect(f.sent[1].params['p_config'], {'key': ''});
      expect((f.sent[2].params['p_config'] as Map).containsKey('key'), isFalse);
    });

    test('the key is not part of any answer', () async {
      final f = fixture((r) => (204, null));
      final r = await f.repo.setProvider(
        actor: null,
        provider: 'google',
        key: 'secret',
      );
      expect(r.isOk, isTrue);
      expect(r.toString(), isNot(contains('secret')));
    });

    test('a refusal keeps its hint', () async {
      final f = fixture(
        (r) => (
          403,
          {'code': '42501', 'message': 'guardian', 'hint': 'guardian_required'},
        ),
      );
      final r = await f.repo.setProvider(
        actor: null,
        provider: 'google',
        enabled: true,
      );
      expect(r.failureOrNull, isA<PermissionFailure>());
      expect(r.failureOrNull!.code, 'guardian_required');
    });
  });

  group('the questions', () {
    test('test', () async {
      final f = fixture((r) => (200, {'ok': false, 'error': 'unauthorized'}));
      final r = (await f.repo.test(provider: 'google', actor: 'a')).unwrap();
      expect(r.ok, isFalse);
      expect(r.error, 'unauthorized');
      expect(f.sent.single.params, {
        'action': 'test',
        'provider': 'google',
        'actor_profile_id': 'a',
      });
    });

    test('geocode', () async {
      final f = fixture(
        (r) => (
          200,
          {
            'places': [
              {
                'name': 'Olbia',
                'country': 'IT',
                'admin': 'Sardegna',
                'lat': 40.92,
                'lon': 9.5,
              },
            ],
            'provider': 'nominatim',
            'attribution': '© OpenStreetMap contributors',
          },
        ),
      );
      final r = (await f.repo.geocode(q: 'Olbia', lang: 'de')).unwrap();
      expect(r.places.single.admin, 'Sardegna');
      expect(r.attribution, '© OpenStreetMap contributors');
      expect(f.sent.single.params, {
        'action': 'geocode',
        'q': 'Olbia',
        'lang': 'de',
      });
    });

    test('forecast', () async {
      final f = fixture(
        (r) => (
          200,
          {
            'days': [
              {
                'date': '2027-07-10',
                'tmax': 31.2,
                'tmin': 21,
                'precip_mm': 0,
                'precip_prob': 5,
                'code': 'clear',
              },
              {
                'date': '2027-07-11',
                'tmax': 28,
                'tmin': 20,
                'precip_mm': 4.5,
                'code': 'storm',
              },
            ],
            'provider': 'open-meteo',
            'attribution': 'Weather data by Open-Meteo.com',
          },
        ),
      );
      final r = (await f.repo.forecast(lat: 40.92, lon: 9.5)).unwrap();
      expect(r.days.first.date, DateTime(2027, 7, 10));
      expect(r.days.first.code, WeatherCode.clear);
      expect(r.days.last.code, WeatherCode.storm);
      expect(r.days.last.precipProb, isNull);
      expect(
        r.between(DateTime(2027, 7, 11), DateTime(2027, 7, 20)).single.tmax,
        28,
      );
      expect(f.sent.single.params, {
        'action': 'forecast',
        'lat': 40.92,
        'lon': 9.5,
      });
    });

    test('climate, and the months of a trip', () async {
      final f = fixture(
        (r) => (
          200,
          {
            'months': [
              for (var m = 1; m <= 12; m++)
                {'month': m, 'tmax': 10.0 + m, 'tmin': 5.0 + m},
            ],
            'provider': 'open-meteo',
          },
        ),
      );
      final r = (await f.repo.climate(lat: 40.92, lon: 9.5)).unwrap();
      expect(r.months, hasLength(12));
      expect(
        r
            .monthsFor(DateTime(2027, 7, 28), DateTime(2027, 8, 6))
            .map((m) => m.month),
        [7, 8],
      );
      expect(
        r
            .monthsFor(DateTime(2027, 12, 20), DateTime(2028, 1, 3))
            .map((m) => m.month),
        [12, 1],
      );
      expect(f.sent.single.params['action'], 'climate');
    });

    test('route', () async {
      final f = fixture((r) => (200, {'km': 812.4, 'minutes': 596}));
      final r = (await f.repo.route(
        from: (lat: 47.37, lon: 8.54),
        to: (lat: 40.92, lon: 9.5),
      )).unwrap();
      expect((r.km, r.minutes), (812.4, 596));
      expect(f.sent.single.params, {
        'action': 'route',
        'from': {'lat': 47.37, 'lon': 8.54},
        'to': {'lat': 40.92, 'lon': 9.5},
      });
    });

    test('map decodes the picture', () async {
      final f = fixture(
        (r) => (
          200,
          {
            'image_base64': base64Encode([1, 2, 3, 4]),
            'mime': 'image/png',
            'provider': 'google',
            'attribution': 'Map data © Google',
          },
        ),
      );
      final r = (await f.repo.map(
        lat: 40.92,
        lon: 9.5,
        zoom: 9,
        width: 640,
        height: 360,
      )).unwrap();
      expect(r.bytes, [1, 2, 3, 4]);
      expect(r.mime, 'image/png');
      expect(f.sent.single.params, {
        'action': 'map',
        'lat': 40.92,
        'lon': 9.5,
        'zoom': 9,
        'width': 640,
        'height': 360,
      });
    });
  });

  group('the function\'s errors become failures with their word as code', () {
    for (final (status, code) in const [
      (409, 'service_off'),
      (409, 'service_key_missing'),
      (429, 'service_limit'),
      (502, 'service_failed'),
      (400, 'invalid_request'),
    ]) {
      test('$status $code', () async {
        final f = fixture((r) => (status, {'error': code}));
        final r = await f.repo.forecast(lat: 1, lon: 2);
        expect(r.failureOrNull, isNotNull);
        expect(r.failureOrNull!.code, code);
      });
    }

    test('a database refusal passes through with its hint', () async {
      final f = fixture(
        (r) => (
          403,
          {
            'error': 'adults_only',
            'code': '42501',
            'hint': 'adults_only',
            'message': 'x',
          },
        ),
      );
      final r = await f.repo.geocode(q: 'x');
      expect(r.failureOrNull, isA<PermissionFailure>());
      expect(r.failureOrNull!.code, 'adults_only');
    });

    test('an unreachable function is a network failure', () async {
      final repo = ServicesRepository(
        ApiClient(
          SupabaseClient(
            'http://localhost:54321',
            'anon-key',
            httpClient: MockClient(
              (_) async => throw http.ClientException('x'),
            ),
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        ),
      );
      final r = await repo.climate(lat: 1, lon: 2);
      expect(r.failureOrNull, isA<NetworkFailure>());
    });
  });
}
