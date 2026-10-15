import 'package:flutter/widgets.dart';

/// A bundled Fluent Emoji picture (MIT; scripts/emoji-pictures.mjs) in place of an emoji
/// character: drawn as text, an emoji makes the web app fetch an emoji font from Google
/// (NFR-9), and it looks different on every platform.
class EmojiPicture extends StatelessWidget {
  const EmojiPicture(
    this.asset, {
    required this.size,
    this.semanticLabel,
    super.key,
  });

  final String asset;
  final double size;

  /// Read by screen readers; null when the text next to the picture already says it.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    semanticLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
  );
}

/// Pictures shown next to text: a streak, a celebration, a reward without its own icon.
const emojiFire = 'assets/emoji/extras/fire.png';
const emojiParty = 'assets/emoji/extras/party.png';
const emojiGift = 'assets/emoji/extras/gift.png';
