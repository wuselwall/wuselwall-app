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

  // App Store Connect refuses a build whose plugins reach for protected data without a
  // purpose string (ITMS-90683), and says so only by mail after the upload.
  test('iOS purpose strings cover the plugins and every language', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final declared = RegExp(
      r'<key>(NS\w+UsageDescription)</key>\s*<string>([^<]+)</string>',
    ).allMatches(plist).map((m) => m.group(1)!).toSet();
    const needed = {
      'camera': ['NSCameraUsageDescription'],
      'image_picker': [
        'NSCameraUsageDescription',
        'NSPhotoLibraryUsageDescription',
      ],
      'sensors_plus': ['NSMotionUsageDescription'],
    };
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final MapEntry(key: plugin, value: keys) in needed.entries) {
      expect(pubspec, contains(RegExp('^  $plugin:', multiLine: true)));
      expect(declared, containsAll(keys), reason: plugin);
    }
    for (final locale in supportedLocales) {
      final code = locale.languageCode;
      final strings = File('ios/Runner/$code.lproj/InfoPlist.strings')
          .readAsStringSync();
      final translated = RegExp(
        r'^"(NS\w+UsageDescription)" = ".+";$',
        multiLine: true,
      ).allMatches(strings).map((m) => m.group(1)!).toSet();
      expect(translated, declared, reason: code);
    }
  });
}
