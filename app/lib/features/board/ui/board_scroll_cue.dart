import 'package:flutter/material.dart';

/// Fades the end of a scroll view out while there is more to scroll to, so a detail
/// on the wall never seems to end at its edge when it goes on (specs/09 "Touch
/// behaviour": the details are where the full labels live). Wraps the scroll view
/// itself, along its [axis]; nested scroll views of the other axis are ignored.
///
/// Nothing moves: the fade is there or not, it does not animate (specs/26 "Protecting
/// the wall").
class BoardScrollFade extends StatefulWidget {
  const BoardScrollFade({
    required this.child,
    this.axis = Axis.vertical,
    this.extent = 48,
    super.key,
  });

  final Widget child;
  final Axis axis;

  /// How far into the view the fade reaches, in logical pixels.
  final double extent;

  @override
  State<BoardScrollFade> createState() => _BoardScrollFadeState();
}

class _BoardScrollFadeState extends State<BoardScrollFade> {
  bool _more = false;

  bool _onMetrics(ScrollMetrics m) {
    if (m.axis != widget.axis) return false;
    final more = m.extentAfter > 0.5;
    if (more != _more) setState(() => _more = more);
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              final length = widget.axis == Axis.vertical
                  ? bounds.height
                  : bounds.width;
              final start = length <= 0
                  ? 0.0
                  : (1 - widget.extent / length).clamp(0.0, 1.0);
              // Opaque white keeps the content; the end fades to transparent.
              return LinearGradient(
                begin: widget.axis == Axis.vertical
                    ? Alignment.topCenter
                    : AlignmentDirectional.centerStart.resolve(
                        Directionality.of(context),
                      ),
                end: widget.axis == Axis.vertical
                    ? Alignment.bottomCenter
                    : AlignmentDirectional.centerEnd.resolve(
                        Directionality.of(context),
                      ),
                stops: [start, 1],
                colors: [
                  Colors.white,
                  _more ? Colors.white.withValues(alpha: 0) : Colors.white,
                ],
              ).createShader(bounds);
            },
            child: widget.child,
          ),
        ),
      );
}
