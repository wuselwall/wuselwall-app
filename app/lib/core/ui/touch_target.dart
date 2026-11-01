import 'package:flutter/material.dart';

/// At least a 48 px tall touch target (kMinInteractiveDimension), for tappable rows
/// and custom tiles the theme's padded tap target size does not reach; the candidate
/// qualification checks every control for it (specs/accessibility-and-ui-qualification).
class TouchTarget extends StatelessWidget {
  const TouchTarget({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
    child: child,
  );
}
