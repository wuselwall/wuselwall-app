import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lays the kiosk's content out on a design canvas and scales it to the panel.
///
/// The canvas is at least [designWidth] × [minHeight], the reference viewport of
/// specs/09, and grows along the one side the panel's aspect ratio needs: a 16:9 panel
/// gets a 1422 × 800 canvas, a 16:10 one exactly 1280 × 800. So the board keeps the same
/// rows at every aspect ratio (a wider panel only widens the columns) and never scrolls
/// or reflows: everything on it is sized in canvas units. The tap-through details are
/// drawn on one too (`board_detail.dart`), so they share the board's scale.
class KioskCanvas extends StatelessWidget {
  const KioskCanvas({required this.child, super.key});

  /// Also the reason there is no narrow-screen layout: the canvas is never narrower
  /// than this, so the weekend never has to collapse (specs/09 degradation rule 4).
  static const designWidth = 1280.0;

  /// The canvas is never lower than this either: the height the board's rows are
  /// planned for, so a wide panel does not squeeze the appointments or the meals.
  static const minHeight = 800.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final aspect = constraints.maxWidth / constraints.maxHeight;
      final width = math.max(designWidth, minHeight * aspect);
      final height = math.max(minHeight, designWidth / aspect);
      // The panel's whole area, tightly: a FittedBox under loose constraints (a
      // Scaffold body is loose) takes its child's own size whenever that fits, so a
      // 1920×1080 panel would show the 1280 canvas unscaled in its top-left corner.
      // Tight, it scales the canvas up as well as down.
      final scale = math.min(
        constraints.maxWidth / width,
        constraints.maxHeight / height,
      );
      // Inside, the screen is the canvas: its size, and the system's insets in
      // canvas units, so a layout that asks MediaQuery (the acting profile bar in a
      // detail) measures what it is drawn on.
      final media = MediaQuery.of(context);
      EdgeInsets toCanvas(EdgeInsets e) => scale > 0 ? e / scale : e;
      return SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: width,
            height: height,
            child: MediaQuery(
              data: media.copyWith(
                size: Size(width, height),
                padding: toCanvas(media.padding),
                viewPadding: toCanvas(media.viewPadding),
                viewInsets: toCanvas(media.viewInsets),
              ),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
