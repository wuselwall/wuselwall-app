import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:wuselwall/core/ui/motion.dart';

/// A short burst of confetti over the whole screen (specs/26 "Celebrations"), in the
/// family's colours plus points gold. Shown in the app's overlay, it ignores touches
/// and removes itself after [duration]. Nothing happens when motion is not allowed:
/// the moment's text and Wusel's still pose carry it then.
void showConfetti(
  BuildContext context, {
  required List<Color> colors,
  Offset? origin,
  int count = 40,
  Duration duration = const Duration(milliseconds: 1400),
}) {
  if (!motionAllowed(context) || colors.isEmpty) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: ConfettiBurst(
        colors: colors,
        origin: origin,
        count: count,
        duration: duration,
        onDone: () => entry.remove(),
      ),
    ),
  );
  overlay.insert(entry);
}

/// One burst of confetti filling its parent, for a screen that places the burst
/// itself: the kid's birthday puts it behind Wusel (specs/26 "Celebrations"). The
/// caller asks [motionAllowed] first; [showConfetti] does that for the overlay.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    required this.colors,
    this.origin,
    this.count = 40,
    this.duration = const Duration(milliseconds: 1400),
    this.onDone,
    super.key,
  });

  final List<Color> colors;

  /// Where the pieces start; a little above the middle when null.
  final Offset? origin;
  final int count;
  final Duration duration;

  /// Called once the last piece has faded.
  final VoidCallback? onDone;

  @override
  State<ConfettiBurst> createState() => _ConfettiState();
}

class _ConfettiState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final List<_Piece> _pieces = _scatter(math.Random());

  List<_Piece> _scatter(math.Random r) => [
    if (widget.colors.isNotEmpty)
      for (var i = 0; i < widget.count; i++)
        _Piece(
          color: widget.colors[i % widget.colors.length],
          // Up and out, like a popper: an angle around straight up, a speed, a spin.
          angle: -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 0.9,
          speed: 0.55 + r.nextDouble() * 0.6,
          spin: (r.nextDouble() - 0.5) * 14,
          size: 6 + r.nextDouble() * 6,
          round: r.nextBool(),
        ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(
      _controller.forward().whenComplete(() {
        if (mounted) widget.onDone?.call();
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _ConfettiPainter(
        animation: _controller,
        pieces: _pieces,
        origin: widget.origin,
      ),
    ),
  );
}

class _Piece {
  const _Piece({
    required this.color,
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.round,
  });

  final Color color;
  final double angle;
  final double speed;
  final double spin;
  final double size;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.animation,
    required this.pieces,
    required this.origin,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Piece> pieces;
  final Offset? origin;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final from = origin ?? Offset(size.width / 2, size.height * 0.45);
    // Distances relative to the screen, so a phone and the wall look alike.
    final reach = size.shortestSide * 0.9;
    final gravity = size.shortestSide * 1.4;
    final fade = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    for (final p in pieces) {
      final v = p.speed * reach;
      final x = from.dx + math.cos(p.angle) * v * t;
      final y = from.dy + math.sin(p.angle) * v * t + gravity * t * t * 0.5;
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2.4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 0.55,
              height: p.size,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
