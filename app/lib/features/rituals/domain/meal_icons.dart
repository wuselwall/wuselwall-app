import 'package:wuselwall/core/l10n/l10n.dart';

/// The dish pictures (specs/27 "Wunschessen"): Fluent Emoji pictures rendered by
/// scripts/emoji-pictures.mjs, set `meals`. The server picks one from a recipe's or a
/// meal's name (`app.meal_icon_for`, `icon_key` of `api.recipes`, `api.meal_history` and
/// `api.meal_wishes`); a free-text wish may carry one chosen in the picker. In the order
/// the picker offers them.
const mealIconKeys = [
  'pizza', 'pasta', 'pancakes', 'waffle', 'burger', 'fries', 'hotdog', //
  'sandwich', 'taco', 'burrito', 'kebab', 'curry', 'rice', 'noodles', 'soup', //
  'paella', 'salad', 'sushi', 'dumpling', 'chicken', 'fish', 'meat', 'egg', //
  'falafel', 'fondue', 'pie', 'cake', 'ice_cream', 'bread', 'pretzel', //
  'croissant', 'potato', 'cheese', 'porridge', 'vegetables',
];

/// The picture of [key]; null for none or a key this app does not know (a newer server).
String? mealIconAsset(String? key) => key != null && mealIconKeys.contains(key)
    ? 'assets/emoji/meals/$key.png'
    : null;

/// What the picture shows, for the chooser's tooltip and screen readers.
String mealIconName(AppLocalizations l10n, String key) => switch (key) {
  'pizza' => l10n.mealIcon_pizza,
  'pasta' => l10n.mealIcon_pasta,
  'pancakes' => l10n.mealIcon_pancakes,
  'waffle' => l10n.mealIcon_waffle,
  'burger' => l10n.mealIcon_burger,
  'fries' => l10n.mealIcon_fries,
  'hotdog' => l10n.mealIcon_hotdog,
  'sandwich' => l10n.mealIcon_sandwich,
  'taco' => l10n.mealIcon_taco,
  'burrito' => l10n.mealIcon_burrito,
  'kebab' => l10n.mealIcon_kebab,
  'curry' => l10n.mealIcon_curry,
  'rice' => l10n.mealIcon_rice,
  'noodles' => l10n.mealIcon_noodles,
  'soup' => l10n.mealIcon_soup,
  'paella' => l10n.mealIcon_paella,
  'salad' => l10n.mealIcon_salad,
  'sushi' => l10n.mealIcon_sushi,
  'dumpling' => l10n.mealIcon_dumpling,
  'chicken' => l10n.mealIcon_chicken,
  'fish' => l10n.mealIcon_fish,
  'meat' => l10n.mealIcon_meat,
  'egg' => l10n.mealIcon_egg,
  'falafel' => l10n.mealIcon_falafel,
  'fondue' => l10n.mealIcon_fondue,
  'pie' => l10n.mealIcon_pie,
  'cake' => l10n.mealIcon_cake,
  'ice_cream' => l10n.mealIcon_ice_cream,
  'bread' => l10n.mealIcon_bread,
  'pretzel' => l10n.mealIcon_pretzel,
  'croissant' => l10n.mealIcon_croissant,
  'potato' => l10n.mealIcon_potato,
  'cheese' => l10n.mealIcon_cheese,
  'porridge' => l10n.mealIcon_porridge,
  _ => l10n.mealIcon_vegetables,
};
