import 'package:flutter/widgets.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';

/// The label of a region as a household reads it: "Kanton Zürich (ZH)" for a canton and
/// "Uster (Gemeinde), Kanton Zürich (ZH)" below one. A code that is not cached shows as it is.
String regionLabel(
  AppLocalizations l10n,
  RegionIndex index,
  String code,
  String language,
) {
  final region = index[code];
  if (region == null) return code;
  final name = region.displayName(language);
  final top = index.top(code);
  if (region.parentCode == null || top == null) {
    return regionHeading(l10n, region, language);
  }
  return l10n.regionNameDeeper(
    name,
    region.category,
    regionHeading(l10n, top, language),
  );
}

/// Swiss cantons use the app's language instead of the source's first category
/// translation. Keep the abbreviation visible wherever the selected canton is named.
String regionHeading(AppLocalizations l10n, Region region, String language) {
  final isCanton = region.country == 'CH' && region.level == 1;
  final name = regionNameTop(
    l10n,
    isCanton ? l10n.regionCategoryCanton : region.category,
    region.displayName(language),
  );
  final abbreviation = region.shortName.trim();
  return isCanton && abbreviation.isNotEmpty
      ? l10n.regionNameWithAbbreviation(name, abbreviation)
      : name;
}

/// Combines a category and name. An empty category leaves the name alone.
String regionNameTop(AppLocalizations l10n, String category, String name) =>
    category.trim().isEmpty ? name : l10n.regionNameTop(category, name);

/// The name of a country, in the language of the app.
String regionCountryName(AppLocalizations l10n, String country) =>
    switch (country) {
      'DE' => l10n.regionCountryDE,
      'AT' => l10n.regionCountryAT,
      'CH' => l10n.regionCountryCH,
      'LI' => l10n.regionCountryLI,
      _ => l10n.regionCountryOther,
    };

/// The language code of the current locale (`de`, `en`).
String languageOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode;
