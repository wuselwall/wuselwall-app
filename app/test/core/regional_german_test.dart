import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/app.dart' show localizationsDelegates;
import 'package:wuselwall/core/l10n/app_locale.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

// Regional German (specs/09): the family's country decides how German is written,
// and a person's own choice beats it.

void main() {
  Locale effective({
    Locale? chosen,
    List<Locale> device = const [Locale('de', 'DE')],
    String? country,
  }) => effectiveAppLocale(
    chosen: chosen,
    device: device,
    familyCountry: country,
  );

  test("German follows the family's country", () {
    expect(effective(country: 'CH'), const Locale('de', 'CH'));
    expect(effective(country: 'LI'), const Locale('de', 'CH'));
    expect(effective(country: 'AT'), const Locale('de', 'AT'));
    expect(effective(country: 'DE'), const Locale('de'));
  });

  test("without a family country, the device's region decides", () {
    expect(
      effective(device: const [Locale('de', 'CH')]),
      const Locale('de', 'CH'),
    );
    expect(effective(device: const [Locale('de')]), const Locale('de'));
    // A device in a language the app lacks falls back to German of Germany.
    expect(effective(device: const [Locale('it', 'CH')]), const Locale('de'));
  });

  test("a person's own variant beats the family's country", () {
    expect(
      effective(chosen: const Locale('de', 'DE'), country: 'CH'),
      const Locale('de'),
    );
    expect(
      effective(chosen: const Locale('de', 'AT'), country: 'CH'),
      const Locale('de', 'AT'),
    );
    // Plain German, chosen before there were variants, follows the family.
    expect(
      effective(chosen: const Locale('de'), country: 'CH'),
      const Locale('de', 'CH'),
    );
  });

  test('other languages have no variant', () {
    expect(
      effective(device: const [Locale('fr', 'CH')], country: 'CH'),
      const Locale('fr'),
    );
    expect(
      effective(chosen: const Locale('en'), country: 'AT'),
      const Locale('en'),
    );
  });

  test('each variant has its own words', () {
    final de = lookupAppLocalizations(const Locale('de'));
    final ch = lookupAppLocalizations(const Locale('de', 'CH'));
    final at = lookupAppLocalizations(const Locale('de', 'AT'));
    expect(de.tasksTitle, 'Aufgaben');
    expect(ch.tasksTitle, 'Ämtli');
    expect(at.tasksTitle, 'Aufgaben');
    expect(ch.close, 'Schliessen');
    expect(at.close, 'Schließen');
    expect(de.eventStarterSportsEvent, 'Sportveranstaltung');
    expect(ch.eventStarterSportsEvent, 'Sportanlass');
    expect(at.mealsSlotSnack, 'Jause');
    expect(ch.mealsSlotSnack, 'Zvieri');
  });

  for (final (locale, month) in [
    (const Locale('de', 'AT'), 'Jänner 2026'),
    (const Locale('de', 'CH'), 'Januar 2026'),
    (const Locale('de'), 'Januar 2026'),
  ]) {
    testWidgets('dates in $locale say $month', (t) async {
      String? shown;
      await t.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: appLocales,
          localizationsDelegates: localizationsDelegates,
          home: Builder(
            builder: (context) {
              shown = DateFormat.yMMMM(
                Localizations.localeOf(context).toLanguageTag(),
              ).format(DateTime(2026, 1, 5));
              return const SizedBox();
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(shown, month);
    });
  }
}
