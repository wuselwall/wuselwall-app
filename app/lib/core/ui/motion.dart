import 'package:flutter/widgets.dart';

/// Whether this screen may move (specs/26 "Motion"). Every celebration, Wusel's poses
/// and the springs ask here, never the platform directly.
///
/// Two settings say no: Android's "Remove animations", which Flutter reports as
/// [MediaQueryData.disableAnimations], and iOS's Reduce Motion, which does not set that
/// flag and is only exposed as `AccessibilityFeatures.reduceMotion` (Q55, checked
/// against the SDK in step 11).
bool motionAllowed(BuildContext context) {
  if (StillMode.enabled) return false;
  if (MediaQuery.disableAnimationsOf(context)) return false;
  final view = View.maybeOf(context);
  final features = view?.platformDispatcher.accessibilityFeatures;
  return !(features?.reduceMotion ?? false);
}

/// Holds the whole app still for screenshots (the docs' and the store's): nothing moves,
/// Wusel shows each pose's still look and never blinks, no confetti, and Wusel always
/// says the first variant of a line, so two runs give the same picture. The demo build
/// switches it on with `?still=1` (lib/main_demo.dart); a release never does.
abstract final class StillMode {
  static bool enabled = false;
}
