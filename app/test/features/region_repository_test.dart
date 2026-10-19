import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/region/data/region_repository.dart';

/// `api.regions` as PostgREST serves it: offset and limit from the query, and at most
/// [maxRows] rows per answer whatever was asked (the server's `max_rows`). [onRequest]
/// counts the requests.
MockClient postgrest(
  List<Map<String, Object?>> rows, {
  required int maxRows,
  void Function()? onRequest,
}) => MockClient((req) async {
  onRequest?.call();
  expect(req.url.path, endsWith('/rest/v1/regions'));
  final q = req.url.queryParameters;
  final offset = int.parse(q['offset'] ?? '0');
  final limit = int.parse(q['limit'] ?? '$maxRows');
  final take = limit < maxRows ? limit : maxRows;
  final page = rows.skip(offset).take(take).toList();
  return http.Response(
    jsonEncode(page),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
    request: req,
  );
});

List<Map<String, Object?>> swissRegions(int count) => [
  for (var i = 0; i < count; i++)
    {
      'code': 'CH-ZH-ZH-${i.toString().padLeft(4, '0')}',
      'country': 'CH',
      'parent_code': 'CH-ZH-ZH',
      'level': 3,
      'category': 'Gemeinde',
      'short_name': 'G$i',
      'names': {'de': 'Gemeinde $i'},
    },
];

RegionRepository repository(MockClient client) => SupabaseRegionRepository(
  ApiClient(
    SupabaseClient(
      'http://localhost:54321',
      'anon-key',
      httpClient: client,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  ),
);

void main() {
  group('the region cache is read in pages', () {
    test('Switzerland has more regions than one answer holds', () async {
      // About as many as the real answer (1989 in 2026-10), above the default max_rows.
      final rows = swissRegions(1989);
      final result = await repository(postgrest(rows, maxRows: 1000))
          .regions('CH');

      final regions = result.unwrap();
      expect(regions, hasLength(1989));
      expect(regions.map((r) => r.code).toSet(), hasLength(1989));
      expect(regions.last.code, 'CH-ZH-ZH-1988');
    });

    test('a server that caps below the page size still gives everything', () {
      final rows = swissRegions(750);
      expect(
        repository(postgrest(rows, maxRows: 300))
            .regions('CH')
            .then((r) => r.unwrap().length),
        completion(750),
      );
    });

    test('a country with few regions is one page and an empty one', () async {
      var requests = 0;
      final client = postgrest(
        swissRegions(16),
        maxRows: 1000,
        onRequest: () => requests++,
      );
      final regions = (await repository(client).regions('CH')).unwrap();
      expect(regions, hasLength(16));
      expect(requests, 2);
    });

    test('a failed page is the failure, not a short list', () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode({'code': '42501', 'message': 'permission denied'}),
          403,
          headers: {'content-type': 'application/json'},
          request: req,
        ),
      );
      final result = await repository(client).regions('CH');
      expect(result.isOk, isFalse);
    });
  });
}
