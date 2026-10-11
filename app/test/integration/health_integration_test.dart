@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/system/data/system_repository.dart';

/// Needs a running backend:
/// `flutter test test/integration --dart-define-from-file=env/dev.json`
/// Skipped when no backend is configured, so plain `flutter test` stays hermetic.
void main() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final configured = url.isNotEmpty && key.isNotEmpty;

  setUpAll(() => HttpOverrides.global = null); // flutter_test blocks real HTTP

  test(
    'api.health() round-trips through ApiClient and the repository',
    () async {
      final client = SupabaseClient(
        url,
        key,
        postgrestOptions: const PostgrestClientOptions(schema: 'api'),
      );
      addTearDown(client.dispose);

      final repo = SystemRepository(ApiClient(client));
      final result = await repo.health();

      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull!.isOk, isTrue);
      expect(result.valueOrNull!.dbVersion, isNotEmpty);
    },
    skip: configured ? false : 'no backend configured (SUPABASE_URL)',
  );

  test(
    'tables outside the api schema are unreachable and map to a Failure',
    () async {
      final client = SupabaseClient(
        url,
        key,
        postgrestOptions: const PostgrestClientOptions(schema: 'api'),
      );
      addTearDown(client.dispose);

      final result = await ApiClient(client)
          .select<Object>('profiles', parse: (row) => row);
      expect(result.isOk, isFalse);
    },
    skip: configured ? false : 'no backend configured (SUPABASE_URL)',
  );
}
