import 'package:wuselwall/core/l10n/l10n.dart';

/// The content icons an event can carry (specs/27, `event.icon_key`): Fluent Emoji
/// pictures rendered by scripts/emoji-pictures.mjs, set `events`.
const eventIconKeys = [
  'cake',
  'game_die',
  'pizza',
  'cinema',
  'croissant',
  'book',
  'hiking',
  'beach', //
  'plane', 'zoo', 'tent', 'football', 'music', 'gift', 'balloon', 'backpack', //
  'swim', 'ferris', 'house', 'star',
];

/// The picture of [key]; null for none or an icon this app does not know.
String? eventIconAsset(String? key) =>
    key != null && eventIconKeys.contains(key)
    ? 'assets/emoji/events/$key.png'
    : null;

/// What the icon shows, for the chooser's tooltip and screen readers.
String eventIconName(AppLocalizations l10n, String key) => switch (key) {
  'cake' => l10n.eventIcon_cake,
  'game_die' => l10n.eventIcon_game_die,
  'pizza' => l10n.eventIcon_pizza,
  'cinema' => l10n.eventIcon_cinema,
  'croissant' => l10n.eventIcon_croissant,
  'book' => l10n.eventIcon_book,
  'hiking' => l10n.eventIcon_hiking,
  'beach' => l10n.eventIcon_beach,
  'plane' => l10n.eventIcon_plane,
  'zoo' => l10n.eventIcon_zoo,
  'tent' => l10n.eventIcon_tent,
  'football' => l10n.eventIcon_football,
  'music' => l10n.eventIcon_music,
  'gift' => l10n.eventIcon_gift,
  'balloon' => l10n.eventIcon_balloon,
  'backpack' => l10n.eventIcon_backpack,
  'swim' => l10n.eventIcon_swim,
  'ferris' => l10n.eventIcon_ferris,
  'house' => l10n.eventIcon_house,
  _ => l10n.eventIcon_star,
};
