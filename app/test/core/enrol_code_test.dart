import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/identity/domain/enrol_code.dart';

void main() {
  test('the QR payload round-trips through the parser', () {
    expect(parseEnrolmentCode(enrolmentQrPayload('ABCD2345')), 'ABCD2345');
  });

  test('bare codes are accepted, trimmed and upper-cased', () {
    expect(parseEnrolmentCode('  abcd2345 '), 'ABCD2345');
  });

  test('anything else is rejected', () {
    for (final bad in [
      '',
      'SHORT',
      'ABCD234',
      'ABCD23456',
      'ABCD 2345',
      'https://evil.example/?code=ABCD2345',
      'wuselwall://enrol',
      'wuselwall://enrol?code=nope',
    ]) {
      expect(parseEnrolmentCode(bad), isNull, reason: bad);
    }
  });
}
