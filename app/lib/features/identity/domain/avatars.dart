/// The pictures a member may pick instead of their initial (`profile.avatar_key`): the
/// `avatars` set of the bundled Fluent Emoji pictures (scripts/emoji-pictures.mjs). In the
/// order the picker offers them.
const avatarKeys = <String>[
  'cat',
  'dog',
  'fox',
  'lion',
  'tiger',
  'panda',
  'koala',
  'rabbit',
  'bear',
  'frog',
  'unicorn',
  'owl',
  'penguin',
  'dolphin',
  'butterfly',
  'dino',
  'rocket',
  'football',
];

/// The asset for a stored key, or null for the initial and for a key this build does not
/// know (a newer server may know more pictures than an older app).
String? avatarAsset(String? key) => key != null && avatarKeys.contains(key)
    ? 'assets/emoji/avatars/$key.png'
    : null;
