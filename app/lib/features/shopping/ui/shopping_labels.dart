import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// Display name of a category: seeded ones are localised by key, custom ones keep
/// their own name.
/// A category's name: the one the family gave it, else the seeded key's translation.
String categoryLabel(AppLocalizations l10n, ShoppingCategory c) =>
    c.name ?? seededCategoryLabel(l10n, c.key) ?? l10n.shoppingCat_other;

/// The translated name of a seeded category [key], or null for a key this app does not
/// know (a custom category, or a newer server's).
String? seededCategoryLabel(AppLocalizations l10n, String? key) =>
    switch (key) {
      'produce' => l10n.shoppingCat_produce,
      'bakery' => l10n.shoppingCat_bakery,
      'dairy' => l10n.shoppingCat_dairy,
      'meat_fish' => l10n.shoppingCat_meat_fish,
      'pantry' => l10n.shoppingCat_pantry,
      'snacks' => l10n.shoppingCat_snacks,
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
      _ => null,
    };

/// The category's icon: a tile's fallback when the item has no icon_key the app knows.
/// A self-hosted set, never product photos (NFR-9).
IconData categoryIcon(ShoppingCategory? c) => switch (c?.key) {
  'produce' => Icons.eco_outlined,
  'bakery' => Icons.bakery_dining_outlined,
  'dairy' => Icons.egg_alt_outlined,
  'meat_fish' => Icons.set_meal_outlined,
  'pantry' => Icons.inventory_2_outlined,
  'snacks' => Icons.cookie_outlined,
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

/// The bundled pictures for the `icon_key` the server gives a catalogue item from its
/// name (app.catalog_icon_for): Fluent Emoji Flat (MIT), rendered by
/// scripts/emoji-pictures.mjs. A key this app does not know yet (a newer server) shows
/// the category icon instead.
const shoppingIconKeys = <String>{
  'milk',
  'cheese',
  'butter',
  'egg',
  'bowl',
  'bread',
  'baguette',
  'pretzel',
  'croissant',
  'apple',
  'pear',
  'banana',
  'orange',
  'lemon',
  'grapes',
  'strawberry',
  'tomato',
  'cucumber',
  'carrot',
  'potato',
  'onion',
  'garlic',
  'bell_pepper',
  'chili',
  'broccoli',
  'lettuce',
  'mushroom',
  'avocado',
  'corn',
  'peas',
  'beans',
  'pasta',
  'rice',
  'salt',
  'honey',
  'oil',
  'nuts',
  'chocolate',
  'candy',
  'cookie',
  'cake',
  'ice_cream',
  'pizza',
  'fries',
  'chicken',
  'meat',
  'sausage',
  'bacon',
  'fish',
  'coffee',
  'tea',
  'juice',
  'water',
  'soda',
  'beer',
  'wine',
  'tin',
  'toilet_paper',
  'soap',
  'toothbrush',
  'lotion',
  'sponge',
  'baby_bottle',
  'trash',
  'battery',
  'light_bulb',
  'plaster',
  'pill',
};

/// The asset of [key]'s picture, or null when there is none.
String? shoppingIconAsset(String? key) =>
    key != null && shoppingIconKeys.contains(key)
    ? 'assets/emoji/shopping/$key.png'
    : null;
