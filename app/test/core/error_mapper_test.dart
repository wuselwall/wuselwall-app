import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/error_mapper.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';

void main() {
  group('mapError', () {
    test('network exceptions become NetworkFailure', () {
      expect(mapError(const SocketException('x')), isA<NetworkFailure>());
      expect(mapError(TimeoutException('x')), isA<NetworkFailure>());
    });

    test('maps Postgres and PostgREST codes', () {
      Failure f(String code, {String? hint}) =>
          mapError(PostgrestException(message: 'm', code: code, hint: hint));

      expect(f('42501'), isA<PermissionFailure>());
      expect(f('PGRST301'), isA<AuthFailure>());
      expect(f('PGRST116'), isA<NotFoundFailure>());
      expect(f('23505'), isA<ConflictFailure>());
      expect(f('23514'), isA<ValidationFailure>());
      expect(f('P0001'), isA<ValidationFailure>());
      expect(f('XX000'), isA<UnknownFailure>());
    });

    test('uses the hint as the stable domain code', () {
      final failure = mapError(
        PostgrestException(message: 'm', code: 'P0001', hint: 'task_done'),
      );
      expect(failure.code, 'task_done');
    });

    test('auth exceptions become AuthFailure', () {
      expect(mapError(const AuthException('nope')), isA<AuthFailure>());
    });

    test('a Failure passes through unchanged', () {
      const original = PermissionFailure();
      expect(identical(mapError(original), original), isTrue);
    });
  });

  group('Result', () {
    test('guard wraps success', () async {
      final r = await Result.guard(() async => 3);
      expect(r.valueOrNull, 3);
      expect(r.map((v) => v + 1).valueOrNull, 4);
    });

    test('guard maps thrown errors', () async {
      final r = await Result.guard<int>(
        () async => throw const SocketException('x'),
      );
      expect(r.failureOrNull, isA<NetworkFailure>());
      expect(r.isOk, isFalse);
      expect(r.unwrap, throwsA(isA<NetworkFailure>()));
    });
  });
}
