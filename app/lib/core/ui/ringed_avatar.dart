import 'package:flutter/material.dart';

/// A member's avatar inside a selectable chip. Selected, it gets a ring, so the
/// selection shows by shape as well as by the chip's fill; the chip's own check mark
/// (which would cover the avatar) is switched off with `showCheckmark: false`.
class RingedAvatar extends StatelessWidget {
  const RingedAvatar({required this.selected, required this.child, super.key});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selected) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: FittedBox(child: child),
      ),
    );
  }
}
