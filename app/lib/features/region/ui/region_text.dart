import 'package:flutter/widgets.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/region/domain/region_models.dart';

/// The label of a region as a household reads it: "Kanton Zürich" for a canton and
/// "Uster (Gemeinde), Kanton Zürich" below one. A code that is not cached shows as it is.
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
    return regionNameTop(l10n, region.category, name);
  }
  return l10n.regionNameDeeper(
    name,
    region.category,
    regionNameTop(l10n, top.category, top.displayName(language)),
  );
}

/// "Kanton Zürich": the level-1 label. An empty category leaves the name alone.
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
