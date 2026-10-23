import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/features/identity/domain/avatars.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// A member as a circle: their colour with the initial, or their picture on the colour's
/// tint when they chose one (`profile.avatar_key`). The name is the semantics label.
class MemberCircle extends StatelessWidget {
  const MemberCircle({
    required this.member,
    this.size = 40,
    this.selected = false,
    super.key,
  });

  final Member member;
  final double size;

  /// Draws the selection ring: the picker's current choice.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final mc = context.ww.member(member.color);
    final asset = avatarAsset(member.avatarKey);
    return Semantics(
      label: member.displayName,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: asset == null ? mc.ink : mc.tint,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : Border.all(color: mc.ink, width: asset == null ? 0 : 2),
        ),
        child: asset == null
            ? Text(
                member.initial,
                style: TextStyle(
                  fontFamily: Tokens.fontUi,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.5,
                  color: mc.onInk,
                ),
              )
            : EmojiPicture(asset, size: size * 0.62),
      ),
    );
  }
}

/// One colour of the member palette in a picker, with the selection ring.
class SwatchChoice extends StatelessWidget {
  const SwatchChoice({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.label,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
      ),
    ),
  );
}
