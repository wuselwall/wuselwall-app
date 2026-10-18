import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/legal/legal_links.dart';

void main() {
  test('the privacy policy is German for German, English for English', () {
    expect(
      privacyPolicyUri(const Locale('de')).toString(),
      'https://wuselwall.app/datenschutz',
    );
    expect(
      privacyPolicyUri(const Locale('en')).toString(),
      'https://wuselwall.app/en/privacy',
    );
  });
}
