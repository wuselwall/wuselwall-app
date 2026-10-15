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

  test('no ARB message contains an emoji', () {
    // The web app would fetch an emoji font from Google (NFR-9), and emoji look
    // different on every platform: use the pictures in assets/emoji instead.
    final emoji = RegExp(
      r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B50}]',
      unicode: true,
    );
    for (final file in ['l10n/app_en.arb', 'l10n/app_de.arb']) {
      final hits = emoji
          .allMatches(File(file).readAsStringSync())
          .map((m) => m.group(0))
          .toList();
      expect(hits, isEmpty, reason: '$file contains emoji: $hits');
    }
  });
}
