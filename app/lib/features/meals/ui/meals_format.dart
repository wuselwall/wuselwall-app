import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';

/// Quantities as the meals screens write them: "500 g", "1,5 l", "2 Zwiebeln" (the unit
/// is text, so it reads in the household's words). Whole numbers lose their decimals.
extension MealsFormat on BuildContext {
  String quantityText(double? quantity, String? unit) {
    final tag = Localizations.localeOf(this).toLanguageTag();
    final number = quantity == null
        ? ''
        : NumberFormat('#,##0.#', tag).format(quantity);
    return [number, unit ?? ''].where((s) => s.isNotEmpty).join(' ');
  }

  /// "Mittagessen", "Abendessen", … for the four slots of a day.
  String planSlotLabel(PlanSlot slot) => switch (slot) {
    PlanSlot.breakfast => l10n.mealsSlotBreakfast,
    PlanSlot.lunch => l10n.mealsSlotLunch,
    PlanSlot.dinner => l10n.mealsSlotDinner,
    PlanSlot.snack => l10n.mealsSlotSnack,
  };

  /// A quantity typed in a form field: "1,5" and "1.5" both read as 1.5. Empty or
  /// unreadable input is null, so the ingredient keeps only its name.
  static double? parseQuantity(String text) {
    final v = text.trim().replaceAll(',', '.');
    if (v.isEmpty) return null;
    final n = double.tryParse(v);
    return n == null || n <= 0 ? null : n;
  }
}
