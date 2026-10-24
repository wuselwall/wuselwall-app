import 'package:flutter/widgets.dart';

/// Whether this screen may move (specs/26 "Motion"). Every celebration, Wusel's poses
/// and the springs ask here, never the platform directly.
///
/// Two settings say no: Android's "Remove animations", which Flutter reports as
/// [MediaQueryData.disableAnimations], and iOS's Reduce Motion, which does not set that
/// flag and is only exposed as `AccessibilityFeatures.reduceMotion` (Q55, checked
/// against the SDK in step 11).
bool motionAllowed(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return false;
  final view = View.maybeOf(context);
  final features = view?.platformDispatcher.accessibilityFeatures;
  return !(features?.reduceMotion ?? false);
}
