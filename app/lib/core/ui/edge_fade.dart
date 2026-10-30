import 'package:flutter/material.dart';

/// A sideways scrolling row (chips, tabs, tiles) that fades out at an edge while more
/// lies beyond it, so a cut chip reads as "scroll for more" rather than as a broken
/// label (round-3 review K). The fade follows the row's own scroll position: none at
/// the start until the row has moved, none at the end once it is reached; a row that
/// fits does not fade.
///
/// Wrap the scrollable itself (a horizontal `ListView`, `SingleChildScrollView` or a
/// scrollable `TabBar`); notifications from nested scrollables are ignored.
class EdgeFade extends StatefulWidget {
  const EdgeFade({required this.child, this.extent = 32, super.key});

  final Widget child;

  /// How wide the fade is, in logical pixels.
  final double extent;

  @override
  State<EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<EdgeFade> {
  bool _before = false;
  bool _after = false;

  /// Whether the row fades at its start (it has scrolled) and at its end (more lies
  /// beyond it).
  @visibleForTesting
  ({bool start, bool end}) get fades => (start: _before, end: _after);

  bool _update(ScrollMetrics m) {
    if (m.axis != Axis.horizontal) return false;
    // Half a pixel of slack, so rounding never leaves a faint fade at an end.
    final before = m.extentBefore > 0.5;
    final after = m.extentAfter > 0.5;
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Visual left and right: in a right-to-left row the start is on the right.
    final left = rtl ? _after : _before;
    final right = rtl ? _before : _after;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => n.depth == 0 && _update(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => n.depth == 0 && _update(n.metrics),
        // Always the mask, also when nothing fades: swapping it in and out would
        // rebuild the row and lose its scroll position.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            final f = bounds.width <= 0
                ? 0.0
                : (widget.extent / bounds.width).clamp(0.0, 0.5);
            // A mask, not a colour on screen: only the alpha counts, opaque
            // keeps the row, transparent fades it out.
            return LinearGradient(
              colors: [
                if (left) Colors.transparent,
                Colors.white,
                Colors.white,
                if (right) Colors.transparent,
              ],
              stops: [
                if (left) 0,
                left ? f : 0,
                right ? 1 - f : 1,
                if (right) 1,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
