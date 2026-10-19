import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/legal/legal_links.dart';

void main() {
  test('French and Spanish use the existing English legal page', () {
    for (final code in ['fr', 'es']) {
      expect(
        privacyPolicyUri(Locale(code)).toString(),
        'https://wuselwall.app/en/privacy',
      );
    }
  });

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
