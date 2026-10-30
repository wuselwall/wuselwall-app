import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wuselwall/core/ui/motion.dart';

/// A number that counts to its new value when it changes: 600 ms, `easeOutCubic`, in
/// tabular figures so the digits do not jiggle (specs/17 "Motion": the points arrive
/// with a count). The first value, one that replaces a value still loading ([loaded]
/// false before), and every change under reduced motion appear at once.
///
/// Draws only the number; the caller supplies the semantics of the final value, since
/// a screen reader must not read the count in between.
class AnimatedCount extends StatefulWidget {
  const AnimatedCount({
    required this.value,
    this.style,
    this.format,
    this.loaded = true,
    super.key,
  });

  final int value;
  final TextStyle? style;

  /// How a shown value is written; plain digits by default.
  final String Function(int value)? format;

  /// False while [value] is a placeholder: the first real value then lands at once.
  final bool loaded;

  static const duration = Duration(milliseconds: 600);

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _count = AnimationController(
    vsync: this,
    duration: AnimatedCount.duration,
    value: 1,
  );
  late final Animation<double> _eased = CurvedAnimation(
    parent: _count,
    curve: Curves.easeOutCubic,
  );
  late int _from = widget.value;
  late int _to = widget.value;

  int get _shown => (_from + (_to - _from) * _eased.value).round();

  @override
  void didUpdateWidget(AnimatedCount old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    _from = _shown;
    _to = widget.value;
    if (!old.loaded || !motionAllowed(context)) {
      _count.value = 1;
    } else {
      unawaited(_count.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _eased,
      builder: (context, _) => Text(
        widget.format?.call(_shown) ?? '$_shown',
        maxLines: 1,
        style: (widget.style ?? const TextStyle()).copyWith(
          fontFeatures: [
            ...?widget.style?.fontFeatures?.where(
              (f) => f != const FontFeature.tabularFigures(),
            ),
            const FontFeature.tabularFigures(),
          ],
        ),
      ),
    ),
  );
}
