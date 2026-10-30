import 'dart:math' as math;
import 'dart:ui' show Offset, lerpDouble;

/// One hop of a trip (specs/25 "The motion"): a flight on a gravity arc from [from],
/// which is fixed at take-off, to a target that is read again on every frame, so a
/// list scrolling under Wusel is followed and Wusel still lands where it aimed.
///
/// Positions are the centre of Wusel's square, in the stage's coordinates; [height] is
/// how far the arc rises above the straight line, at its middle.
class WuselHopPath {
  const WuselHopPath({
    required this.from,
    required this.height,
    required this.seconds,
  });

  final Offset from;
  final double height;
  final double seconds;

  /// Where Wusel is at [p] (0 take-off, 1 landing) on the way to [to].
  Offset at(double p, Offset to) {
    final q = p.clamp(0.0, 1.0);
    return Offset.lerp(from, to, q)! + Offset(0, -4 * height * q * (1 - q));
  }

  /// Wusel's speed at [p] in units per second, for the rig's stretch and lean.
  Offset velocity(double p, Offset to) {
    final q = p.clamp(0.0, 1.0);
    return Offset(
      (to.dx - from.dx) / seconds,
      ((to.dy - from.dy) - 4 * height * (1 - 2 * q)) / seconds,
    );
  }
}

/// How Wusel gets from one place to another: hops of at most five of its sizes, so a
/// long way is several hops and never one long glide, but few enough that Wusel does
/// not touch down on everything it crosses.
abstract final class WuselHops {
  /// The longest hop, in Wusel sizes.
  static const maxLength = 5.0;

  /// The crouch before the first hop, and the shorter one between hops.
  static const firstCrouch = 0.12;
  static const nextCrouch = 0.06;

  /// How many hops the way from [a] to [b] takes for a Wusel of [size].
  static int count(Offset a, Offset b, double size) {
    final d = (b - a).distance;
    if (d < size * 0.25) return 1;
    return math.max(1, (d / (size * maxLength)).ceil());
  }

  /// How long one hop of [length] flies: a short hop is quick, a long one floats a
  /// little longer, as a thrown ball does.
  static double flightSeconds(double length, double size) {
    final rel = (length / (size * maxLength)).clamp(0.0, 1.0);
    return lerpDouble(0.3, 0.46, math.sqrt(rel))!;
  }

  /// How high the arc of a hop of [length] rises: at least half a Wusel, so even a
  /// short hop reads as a jump.
  static double arcHeight(double length, double size) =>
      math.max(size * 0.5, length * 0.32);
}

/// The ease the size and the crouch use: quick out, gentle in.
double wuselEase(double t) {
  final x = t.clamp(0.0, 1.0);
  return 1 - math.pow(1 - x, 3).toDouble();
}
