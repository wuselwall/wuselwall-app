import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/account/domain/sign_in_freshness.dart';

/// An unsigned access token with the given claims, as the app reads them.
String tokenWith(Map<String, Object?> claims) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(claims)}.sig';
}

void main() {
  final now = DateTime.utc(2026, 10, 15, 10);
  final unix = now.millisecondsSinceEpoch ~/ 1000;

  group('a recent sign-in (specs/20 J6)', () {
    test('a sign-in within five minutes counts', () {
      final token = tokenWith({
        'amr': [
          {'method': 'otp', 'timestamp': unix - 60},
        ],
      });
      expect(signedInRecently(token, now: now), isTrue);
    });

    test('an older sign-in does not, even when refreshed', () {
      final token = tokenWith({
        'amr': [
          {'method': 'password', 'timestamp': unix - 3600},
        ],
      });
      expect(signedInRecently(token, now: now), isFalse);
    });

    test('one fresh method among older ones is enough', () {
      final token = tokenWith({
        'amr': [
          {'method': 'password', 'timestamp': unix - 3600},
          {'method': 'oauth', 'timestamp': unix - 30},
        ],
      });
      expect(signedInRecently(token, now: now), isTrue);
    });

    test('a token without amr, or a malformed one, is not recent', () {
      expect(signedInRecently(tokenWith({'sub': 'x'}), now: now), isFalse);
      expect(signedInRecently('not-a-token', now: now), isFalse);
      expect(signedInRecently('a.%%%.c', now: now), isFalse);
    });

    test('the window can be given', () {
      final token = tokenWith({
        'amr': [
          {'method': 'otp', 'timestamp': unix - 120},
        ],
      });
      expect(
        signedInRecently(token, now: now, within: const Duration(minutes: 1)),
        isFalse,
      );
    });
  });
}
