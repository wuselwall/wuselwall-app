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
  'swim', 'ferris', 'house', 'broom', 'cleaner', //
  // Health and care.
  'doctor', 'dentist', 'haircut', 'vet', //
  // Sports and hobbies.
  'bicycle', 'ski', 'dance', 'riding', 'tennis', 'guitar', //
  // Home and errands.
  'laundry', 'garden', 'car', 'work', 'shopping', //
  'star',
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
  'broom' => l10n.eventIcon_broom,
  'cleaner' => l10n.eventIcon_cleaner,
  'doctor' => l10n.eventIcon_doctor,
  'dentist' => l10n.eventIcon_dentist,
  'haircut' => l10n.eventIcon_haircut,
  'vet' => l10n.eventIcon_vet,
  'bicycle' => l10n.eventIcon_bicycle,
  'ski' => l10n.eventIcon_ski,
  'dance' => l10n.eventIcon_dance,
  'riding' => l10n.eventIcon_riding,
  'tennis' => l10n.eventIcon_tennis,
  'guitar' => l10n.eventIcon_guitar,
  'laundry' => l10n.eventIcon_laundry,
  'garden' => l10n.eventIcon_garden,
  'car' => l10n.eventIcon_car,
  'work' => l10n.eventIcon_work,
  'shopping' => l10n.eventIcon_shopping,
  _ => l10n.eventIcon_star,
};
