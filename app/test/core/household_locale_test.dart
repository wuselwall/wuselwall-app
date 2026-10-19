import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/app_locale.dart';
import 'package:wuselwall/demo/demo_data.dart';

void main() {
  test(
    'the household locale tag follows the app locale for all four languages',
    () {
      expect(householdLocaleTag(const Locale('de')), 'de-DE');
      expect(householdLocaleTag(const Locale('en', 'US')), 'en-GB');
      expect(householdLocaleTag(const Locale('fr', 'CA')), 'fr-FR');
      expect(householdLocaleTag(const Locale('es', 'MX')), 'es-ES');
      // The curated regional default, not the device's arbitrary region.
      expect(
        householdLocaleTag(resolveAppLocale(const [Locale('fr', 'CA')])),
        'fr-FR',
      );
      expect(
        householdLocaleTag(resolveAppLocale(const [Locale('es', 'MX')])),
        'es-ES',
      );
      expect(
        householdLocaleTag(resolveAppLocale(const [Locale('it')])),
        'de-DE',
      );
    },
  );

  test(
    'the demo follows the resolved app locale, not only German and English',
    () {
      addTearDown(() => DemoData.useLanguageOf(const [Locale('de')]));
      final expected = {
        'de': ['Thomas', 'Julia', 'Emma', 'Paul'],
        'en': ['David', 'Sarah', 'Olivia', 'Jack'],
        'fr': ['Thomas', 'Julie', 'Emma', 'Paul'],
        'es': ['David', 'Sara', 'Olivia', 'Pablo'],
      };
      for (final entry in expected.entries) {
        DemoData.useLanguageOf([Locale(entry.key)]);
        expect(DemoData.languageCode, entry.key);
        expect(DemoData.members.map((m) => m.displayName), entry.value);
      }
      // Region variants resolve to their language; unknown devices stay German.
      DemoData.useLanguageOf(const [Locale('fr', 'CA')]);
      expect(DemoData.languageCode, 'fr');
      DemoData.useLanguageOf(const [Locale('es', 'MX'), Locale('de')]);
      expect(DemoData.languageCode, 'es');
      DemoData.useLanguageOf(const [Locale('it'), Locale('nl')]);
      expect(DemoData.languageCode, 'de');
      // The first supported language wins, as in MaterialApp.
      DemoData.useLanguageOf(const [Locale('it'), Locale('es'), Locale('en')]);
      expect(DemoData.languageCode, 'es');
    },
  );

  test('demo prose is not the German fallback in any shipped language', () {
    addTearDown(() => DemoData.useLanguageOf(const [Locale('de')]));
    const samples = <String, Map<String, String>>{
      'Supermarkt': {
        'de': 'Supermarkt',
        'en': 'Supermarket',
        'fr': 'Supermarché',
        'es': 'Supermercado',
      },
      'Milch': {'de': 'Milch', 'en': 'Milk', 'fr': 'Lait', 'es': 'Leche'},
      'Zahnpasta': {
        'de': 'Zahnpasta',
        'en': 'Toothpaste',
        'fr': 'Dentifrice',
        'es': 'Pasta de dientes',
      },
    };
    for (final language in ['de', 'en', 'fr', 'es']) {
      DemoData.useLanguageOf([Locale(language)]);
      for (final entry in samples.entries) {
        expect(
          DemoData.tr4(
            entry.value['de']!,
            entry.value['en']!,
            entry.value['fr']!,
            entry.value['es']!,
          ),
          entry.value[language],
          reason: '${entry.key} in $language',
        );
      }
    }
  });
}
