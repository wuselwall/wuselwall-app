import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// Display name of a category: seeded ones are localised by key, custom ones keep
/// their own name.
String categoryLabel(AppLocalizations l10n, ShoppingCategory c) =>
    switch (c.key) {
      'produce' => l10n.shoppingCat_produce,
      'bakery' => l10n.shoppingCat_bakery,
      'dairy' => l10n.shoppingCat_dairy,
      'meat_fish' => l10n.shoppingCat_meat_fish,
      'pantry' => l10n.shoppingCat_pantry,
      'frozen' => l10n.shoppingCat_frozen,
      'drinks' => l10n.shoppingCat_drinks,
      'household' => l10n.shoppingCat_household,
      'other' => l10n.shoppingCat_other,
      'care' => l10n.shoppingCat_care,
      'baby' => l10n.shoppingCat_baby,
      'cleaning' => l10n.shoppingCat_cleaning,
      'health' => l10n.shoppingCat_health,
      'tools' => l10n.shoppingCat_tools,
      'screws' => l10n.shoppingCat_screws,
      'electrical' => l10n.shoppingCat_electrical,
      'garden' => l10n.shoppingCat_garden,
      _ => c.name ?? l10n.shoppingCat_other,
    };

/// The tile icon follows the item's category: a self-hosted set, never product photos
/// (NFR-9).
IconData categoryIcon(ShoppingCategory? c) => switch (c?.key) {
  'produce' => Icons.eco_outlined,
  'bakery' => Icons.bakery_dining_outlined,
  'dairy' => Icons.egg_alt_outlined,
  'meat_fish' => Icons.set_meal_outlined,
  'pantry' => Icons.inventory_2_outlined,
  'frozen' => Icons.ac_unit,
  'drinks' => Icons.local_drink_outlined,
  'household' => Icons.home_outlined,
  'care' => Icons.soap_outlined,
  'baby' => Icons.child_friendly_outlined,
  'cleaning' => Icons.cleaning_services_outlined,
  'health' => Icons.medical_services_outlined,
  'tools' => Icons.hardware_outlined,
  'screws' => Icons.build_outlined,
  'electrical' => Icons.electrical_services_outlined,
  'garden' => Icons.yard_outlined,
  _ => Icons.shopping_basket_outlined,
};
