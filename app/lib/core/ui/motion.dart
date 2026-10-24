import 'package:flutter/widgets.dart';

/// Whether this screen may move (specs/26 "Motion"). Every celebration, Wusel's poses
/// and the springs ask here, never the platform directly.
///
/// Two settings say no: Android's "Remove animations", which Flutter reports as
/// [MediaQueryData.disableAnimations], and iOS's Reduce Motion, which does not set that
/// flag and is only exposed as `AccessibilityFeatures.reduceMotion` (Q55, checked
/// against the SDK in step 11). Below a [MotionScope] the caller rebuilds when either
/// changes; without one, Reduce Motion is read once per build.
bool motionAllowed(BuildContext context) {
  if (StillMode.enabled) return false;
  if (MediaQuery.disableAnimationsOf(context)) return false;
  final scope = context.dependOnInheritedWidgetOfExactType<_ReduceMotion>();
  if (scope != null) return !scope.reduce;
  final view = View.maybeOf(context);
  final features = view?.platformDispatcher.accessibilityFeatures;
  return !(features?.reduceMotion ?? false);
}

/// Follows iOS's Reduce Motion while the app runs, so whatever asked [motionAllowed]
/// rebuilds when it is switched. MediaQuery carries no aspect for it, so nothing else
/// would notice the change. Placed once above the app's routes.
class MotionScope extends StatefulWidget {
  const MotionScope({required this.child, super.key});

  final Widget child;

  @override
  State<MotionScope> createState() => _MotionScopeState();
}

class _MotionScopeState extends State<MotionScope> with WidgetsBindingObserver {
  late bool _reduce = _read();

  bool _read() => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .reduceMotion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAccessibilityFeatures() {
    final reduce = _read();
    if (reduce != _reduce) setState(() => _reduce = reduce);
  }

  @override
  Widget build(BuildContext context) =>
      _ReduceMotion(reduce: _reduce, child: widget.child);
}

class _ReduceMotion extends InheritedWidget {
  const _ReduceMotion({required this.reduce, required super.child});

  final bool reduce;

  @override
  bool updateShouldNotify(_ReduceMotion old) => old.reduce != reduce;
}

/// Holds the whole app still for screenshots (the docs' and the store's): nothing moves,
/// Wusel shows each pose's still look and never blinks, no confetti, and Wusel always
/// says the first variant of a line, so two runs give the same picture. The demo build
/// switches it on with `?still=1` (lib/main_demo.dart); a release never does.
abstract final class StillMode {
  static bool enabled = false;
}
