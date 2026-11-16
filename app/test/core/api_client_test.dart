import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/error_mapper.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/supabase/api_client.dart';

void main() {
  group('Edge Function failures reach the error mapper', () {
    test('no response at all is a network failure', () {
      final failure = mapError(
        functionError('occurrences', const FunctionException(status: 0)),
      );
      expect(failure, isA<NetworkFailure>());
    });

    test('401 and 403 are the auth and permission failures', () {
      expect(
        mapError(
          functionError('occurrences', const FunctionException(status: 401)),
        ),
        isA<AuthFailure>(),
      );
      expect(
        mapError(
          functionError('occurrences', const FunctionException(status: 403)),
        ),
        isA<PermissionFailure>(),
      );
    });

    test('a reply with a SQLSTATE and a hint keeps the stable domain code', () {
      final failure = mapError(
        functionError(
          'occurrences',
          const FunctionException(
            status: 400,
            details: {'code': '22023', 'hint': 'rrule_invalid'},
          ),
        ),
      );
      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'rrule_invalid');
    });

    test('an error word of the function becomes the failure code', () {
      final off = mapError(
        functionError(
          'services',
          const FunctionException(
            status: 409,
            details: {'error': 'service_off'},
          ),
        ),
      );
      expect(off.code, 'service_off');
      final limit = mapError(
        functionError(
          'services',
          const FunctionException(
            status: 429,
            details: {'error': 'service_limit'},
          ),
        ),
      );
      expect(limit.code, 'service_limit');
      // A hint still wins over the word.
      final hinted = mapError(
        functionError(
          'trips',
          const FunctionException(
            status: 403,
            details: {'code': '42501', 'hint': 'adults_only', 'error': 'x_y'},
          ),
        ),
      );
      expect(hinted, isA<PermissionFailure>());
      expect(hinted.code, 'adults_only');
    });

    test('a function the server does not have is not found', () {
      final failure = mapError(
        functionError(
          'household-export',
          const FunctionException(
            status: 404,
            details: {
              'code': 'NOT_FOUND',
              'message': 'Requested function was not found',
            },
          ),
        ),
      );
      expect(failure, isA<NotFoundFailure>());
    });

    test('a bare 400 is a validation failure without a domain code', () {
      final failure = mapError(
        functionError('occurrences', const FunctionException(status: 400)),
      );
      expect(failure, isA<ValidationFailure>());
    });
  });
}
