import 'package:flutter/physics.dart';

/// Shared design tokens (specs/17-design-system.md). Registers scale these; they do
/// not redefine them. Colours live in `palette.dart`.
abstract final class Tokens {
  /// UI face for every register: drawn for legibility (distinct `I l 1`, `O 0`),
  /// for early readers and for the wall read from 2.5 m. Bundled, never fetched (NFR-9).
  static const String fontUi = 'AtkinsonHyperlegibleNext';

  /// Narrow face for the kiosk week board's day names, times and numbers; use it with
  /// `FontFeature.tabularFigures()`.
  static const String fontNumeric = 'BarlowSemiCondensed';

  /// Spacing scale; use these instead of literals so registers can scale layout later.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;

  /// Motion (specs/17): brief, and off when the system asks for reduced motion.
  static const Duration motionStandard = Duration(milliseconds: 150);
  static const Duration motionEmphasised = Duration(milliseconds: 250);

  /// Springs (specs/26 "Motion"): snappy for a press or a tick, bouncy for Wusel's
  /// jumps and a badge. Both are skipped, landing at once, when motion is not allowed.
  static final SpringDescription springSnappy =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 600, ratio: 0.7);
  static final SpringDescription springBouncy =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 300, ratio: 0.5);
}
