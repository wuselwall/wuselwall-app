import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lays the kiosk's content out on a fixed design canvas and scales it to the panel.
///
/// The canvas is always [designWidth] wide and as tall as the panel's aspect ratio
/// needs (never below 720), so the week board looks the same on every screen and never
/// scrolls or reflows: everything on it is sized in canvas units.
class KioskCanvas extends StatelessWidget {
  const KioskCanvas({required this.child, super.key});

  /// Also the reason there is no narrow-screen layout: the canvas is never narrower
  /// than this, so the weekend never has to collapse (specs/09 degradation rule 4).
  static const designWidth = 1280.0;
  static const minHeight = 720.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.max(
        minHeight,
        designWidth * constraints.maxHeight / constraints.maxWidth,
      );
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(width: designWidth, height: height, child: child),
      );
    },
  );
}
