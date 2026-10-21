import 'package:flutter/widgets.dart';

/// Priority order shared by the app, reminders and demo. German is first because it
/// is the fallback for any device language the app does not support (specs/09).
const supportedLocales = [
  Locale('de'),
  Locale('en'),
  Locale('fr'),
  Locale('es'),
];

Locale resolveAppLocale(List<Locale> preferred) =>
    basicLocaleListResolution(preferred, supportedLocales);

/// The household's curated regional default, not the device's arbitrary region.
String householdLocaleTag(Locale locale) => switch (locale.languageCode) {
  'en' => 'en-GB',
  'fr' => 'fr-FR',
  'es' => 'es-ES',
  _ => 'de-DE',
};
