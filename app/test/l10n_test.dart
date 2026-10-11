import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CLAUDE.md: every user-facing string exists in English and German, always.
void main() {
  test('app_en.arb and app_de.arb define exactly the same messages', () {
    Set<String> keys(String file) =>
        (jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>).keys
            .where((k) => !k.startsWith('@'))
            .toSet();

    expect(keys('l10n/app_de.arb'), keys('l10n/app_en.arb'));
  });
}
