import 'package:flutter/widgets.dart';

/// Priority order shared by the app, reminders and demo. German is first because it
/// is the fallback for any device language the app does not support (specs/09).
const supportedLocales = [
  Locale('de'),
  Locale('en'),
  Locale('fr'),
  Locale('es'),
];

/// German as written in Switzerland (and Liechtenstein) and in Austria (specs/09
/// "Regional German"): only the strings that differ, over the German of Germany.
const regionalLocales = [Locale('de', 'CH'), Locale('de', 'AT')];

/// Everything MaterialApp may show.
const appLocales = [...supportedLocales, ...regionalLocales];

/// What a person can pick under Einstellungen → Sprache, besides the device's language:
/// each German variant on its own, so a German family member in Switzerland keeps the
/// German of Germany.
const languageChoices = [
  Locale('de', 'DE'),
  Locale('de', 'CH'),
  Locale('de', 'AT'),
  Locale('en'),
  Locale('fr'),
  Locale('es'),
];

Locale resolveAppLocale(List<Locale> preferred) =>
    basicLocaleListResolution(preferred, supportedLocales);

/// The German of [country]: Swiss for CH and LI, Austrian for AT, otherwise the German
/// of Germany (plain `de`).
Locale germanFor(String? country) => switch (country?.toUpperCase()) {
  'CH' || 'LI' => const Locale('de', 'CH'),
  'AT' => const Locale('de', 'AT'),
  _ => const Locale('de'),
};

/// The locale the app shows (specs/09 "Regional German"):
///
/// 1. A variant chosen on this device wins (`de-DE` in a Swiss family stays German).
/// 2. Otherwise the language is the chosen one, else the first of the [device]'s
///    languages the app ships, German when it ships none.
/// 3. German then follows the family's [familyCountry] (the country of
///    `household.region`), and without one the region of the device's German.
Locale effectiveAppLocale({
  required Locale? chosen,
  required List<Locale> device,
  String? familyCountry,
}) {
  if (chosen != null && chosen.countryCode != null) {
    return chosen.languageCode == 'de'
        ? germanFor(chosen.countryCode)
        : Locale(chosen.languageCode);
  }
  final language =
      chosen?.languageCode ?? resolveAppLocale(device).languageCode;
  if (language != 'de') return Locale(language);
  final deviceGerman = device
      .where((l) => l.languageCode == 'de')
      .firstOrNull
      ?.countryCode;
  return germanFor(familyCountry ?? deviceGerman);
}

/// The household's curated regional default, not the device's arbitrary region.
String householdLocaleTag(Locale locale) => switch (locale.languageCode) {
  'en' => 'en-GB',
  'fr' => 'fr-FR',
  'es' => 'es-ES',
  _ => 'de-DE',
};
