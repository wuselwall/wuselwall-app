import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

    test(
      'a refusal by the Before User Created hook keeps its message as code',
      () {
        // GoTrue answers a hook's error with code `unknown` and the message as text.
        final failure = mapError(
          const AuthApiException(
            'setup_key_required',
            statusCode: '403',
            code: 'unknown',
          ),
        );
        expect(failure, isA<AuthFailure>());
        expect(failure.code, 'setup_key_required');
        // Ordinary messages are not mistaken for codes.
        expect(
          mapError(const AuthApiException('Invalid login', statusCode: '400'))
              .code,
          isNull,
        );
      },
    );

    test('uses the hint as the stable domain code', () {
      final failure = mapError(
        PostgrestException(message: 'm', code: 'P0001', hint: 'task_done'),
      );
      expect(failure.code, 'task_done');
    });

    test(
      'Auth fetch/CORS failures are connectivity errors, not expired sessions',
      () {
        expect(
          mapError(AuthRetryableFetchException(message: 'Failed to fetch')),
          isA<NetworkFailure>(),
        );
        expect(
          mapError(
            AuthUnknownException(
              message: 'Failed to fetch',
              originalError: http.ClientException('XMLHttpRequest error'),
            ),
          ),
          isA<NetworkFailure>(),
        );
      },
    );

    test('auth exceptions become AuthFailure', () {
      expect(mapError(const AuthException('nope')), isA<AuthFailure>());
    });

    test('a redirect error keeps Supabase\'s specific code', () {
      // getSessionFromUrl puts `error` in code and `error_code` in statusCode.
      final failure = mapError(
        const AuthException(
          'Signups not allowed',
          code: 'access_denied',
          statusCode: 'signup_disabled',
        ),
      );
      expect(failure.code, 'signup_disabled');
      expect(
        mapError(
          const AuthException('x', code: 'otp_expired', statusCode: '403'),
        ).code,
        'otp_expired',
      );
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
