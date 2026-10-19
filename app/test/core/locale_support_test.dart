import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/app_locale.dart';

void main() {
  test('locales are ordered de/en/fr/es with German fallback', () {
    expect(supportedLocales.map((l) => l.languageCode), [
      'de',
      'en',
      'fr',
      'es',
    ]);
    for (final code in ['de', 'en', 'fr', 'es']) {
      expect(
        basicLocaleListResolution([Locale(code, 'CA')], supportedLocales),
        Locale(code),
      );
    }
    expect(
      basicLocaleListResolution(const [
        Locale('it'),
        Locale('es', 'MX'),
      ], supportedLocales),
      const Locale('es'),
    );
    expect(
      basicLocaleListResolution(const [Locale('it')], supportedLocales),
      const Locale('de'),
    );
    expect(
      basicLocaleListResolution(const [], supportedLocales),
      const Locale('de'),
    );
  });

  test(
    'iOS declares every app language and preserves German development region',
    () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final languages = RegExp(
        r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist)!.group(1)!;
      expect(
        RegExp(r'<string>(.*?)</string>')
            .allMatches(languages)
            .map((m) => m.group(1)),
        supportedLocales.map((l) => l.languageCode),
      );
      final project = File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();
      expect(project, contains('developmentRegion = de;'));
      final regions = RegExp(r'knownRegions = \((.*?)\);', dotAll: true)
          .firstMatch(project)!
          .group(1)!
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty && v != 'Base');
      expect(regions, supportedLocales.map((l) => l.languageCode));
      final variants = RegExp(
        r'isa = PBXVariantGroup;\s*children = \((.*?)\);\s*name = InfoPlist.strings;',
        dotAll: true,
      ).firstMatch(project)!.group(1)!;
      for (final locale in supportedLocales) {
        final code = locale.languageCode;
        expect(project, contains('path = $code.lproj/InfoPlist.strings;'));
        expect(variants, contains('/* $code */'));
      }
    },
  );
}
