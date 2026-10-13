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

    test('a bare 400 is a validation failure without a domain code', () {
      final failure = mapError(
        functionError('occurrences', const FunctionException(status: 400)),
      );
      expect(failure, isA<ValidationFailure>());
    });
  });
}
