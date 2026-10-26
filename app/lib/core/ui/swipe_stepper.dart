import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wuselwall/core/ui/motion.dart';

/// Swiping left or right steps through a sequence: the calendar's days, the meal weeks,
/// a timetable's days (specs/09 "Gestures").
///
/// The swipe is only a shortcut. The screen keeps its own previous and next buttons:
/// they are the way with a mouse, and with VoiceOver or TalkBack, which keep swipes for
/// themselves. Only touch and stylus swipe, so a mouse drag on the web still selects
/// text or drags a meal; there the arrow keys step instead, while no control holds the
/// keyboard focus. A swipe that starts in the system's gesture area at the screen's
/// edge (Android's back gesture) is left to the system.
///
/// The content follows the finger and the next one slides in after it; under reduced
/// motion it changes at once. A null [onPrevious] or [onNext] is the end of the
/// sequence: the content resists, and a light tick says so.
class SwipeStepper extends StatefulWidget {
  const SwipeStepper({
    required this.child,
    this.onPrevious,
    this.onNext,
    this.arrowKeys = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Whether ← and → step too. Off where the screen has arrow keys of its own.
  final bool arrowKeys;

  /// A swipe of this share of the width steps, however slowly it ends.
  static const distance = 0.25;

  /// A flick this fast (logical px/s) steps, however short it is.
  static const velocity = 300.0;

  @override
  State<SwipeStepper> createState() => _SwipeStepperState();
}

class _SwipeStepperState extends State<SwipeStepper>
    with SingleTickerProviderStateMixin {
  late final _offset = AnimationController.unbounded(vsync: this);
  bool _tracking = false;
  bool _motion = true;

  /// How far this drag has gone, whether or not the content follows it.
  double _dragged = 0;

  @override
  void initState() {
    super.initState();
    if (widget.arrowKeys) HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didUpdateWidget(SwipeStepper old) {
    super.didUpdateWidget(old);
    if (old.arrowKeys != widget.arrowKeys) {
      widget.arrowKeys
          ? HardwareKeyboard.instance.addHandler(_onKey)
          : HardwareKeyboard.instance.removeHandler(_onKey);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _offset.dispose();
    super.dispose();
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  /// The step a horizontal movement [dx] points to: towards the reading direction's
  /// end is next.
  VoidCallback? _stepFor(double dx) =>
      (dx < 0) != _rtl ? widget.onNext : widget.onPrevious;

  bool _onKey(KeyEvent event) {
    if (!mounted || event is KeyUpEvent) return false;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return false;
    }
    // Not under a dialog, a sheet or a pushed page, and never while a control (a
    // text field, a focused button) has the arrows for itself.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus is! FocusScopeNode) return false;
    final step = _stepFor(key == LogicalKeyboardKey.arrowRight ? -1 : 1);
    if (step == null) return false;
    step();
    return true;
  }

  void _start(DragStartDetails d) {
    final size = MediaQuery.sizeOf(context);
    final edge = MediaQuery.systemGestureInsetsOf(context);
    final x = d.globalPosition.dx;
    _tracking = x >= edge.left && x <= size.width - edge.right;
    if (!_tracking) return;
    _motion = motionAllowed(context);
    _dragged = 0;
    _offset.stop();
  }

  void _update(DragUpdateDetails d) {
    if (!_tracking) return;
    final dx = d.primaryDelta ?? 0;
    _dragged += dx;
    if (!_motion) return;
    final next = _offset.value + dx;
    // At an end of the sequence the content follows a third of the way only.
    _offset.value = _stepFor(next) == null ? _offset.value + dx / 3 : next;
  }

  Future<void> _end(DragEndDetails d) async {
    if (!_tracking) return;
    _tracking = false;
    final width = context.size?.width ?? 1;
    final v = d.primaryVelocity ?? 0;
    final moved = _dragged;
    // The direction is the flick's when there is one, else the distance dragged.
    final dx = v.abs() >= SwipeStepper.velocity ? v : moved;
    final far =
        v.abs() >= SwipeStepper.velocity ||
        moved.abs() >= width * SwipeStepper.distance;
    final step = far && dx != 0 ? _stepFor(dx) : null;
    if (far && dx != 0 && step == null) unawaited(HapticFeedback.lightImpact());
    if (step == null) {
      await _settle(0);
      return;
    }
    if (!_motion) {
      step();
      return;
    }
    final out = dx.sign * width;
    await _offset.animateTo(
      out,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeIn,
    );
    if (!mounted) return;
    step();
    // The new content comes in from the other side.
    _offset.value = -out * 0.3;
    await _settle(0);
  }

  Future<void> _settle(double to) => _offset.animateTo(
    to,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) => GestureDetector(
    // Screen readers step with the screen's buttons; scroll actions here would also
    // merge the content's labels into one node.
    excludeFromSemantics: true,
    supportedDevices: const {
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
    },
    onHorizontalDragStart: _start,
    onHorizontalDragUpdate: _update,
    onHorizontalDragEnd: (d) => unawaited(_end(d)),
    onHorizontalDragCancel: () {
      _tracking = false;
      unawaited(_settle(0));
    },
    child: ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _offset,
          builder: (context, child) {
            // Always the same two wrappers, so the content keeps its state (its
            // scroll position) while it moves.
            final x = _offset.value;
            final width = constraints.maxWidth;
            final fade = width.isFinite && width > 0
                ? 1 - (x.abs() / width).clamp(0.0, 0.6)
                : 1.0;
            return Opacity(
              opacity: fade,
              child: Transform.translate(offset: Offset(x, 0), child: child),
            );
          },
          child: widget.child,
        ),
      ),
    ),
  );
}
