import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:wuselwall/core/wusel/wusel_look.dart';

/// One damped spring, in whatever unit its caller uses. Unit mass, so [stiffness] and
/// [dampingRatio] mean what they mean in `SpringDescription.withDampingRatio`.
class WuselSpring {
  WuselSpring({required this.stiffness, required double dampingRatio})
    : _damping = 2 * dampingRatio * math.sqrt(stiffness);

  final double stiffness;
  final double _damping;

  double value = 0;
  double velocity = 0;
  double target = 0;

  /// Pushes the spring away from where it is: a landing, a take-off.
  void kick(double v) => velocity += v;

  /// Advances by [dt] seconds with [force] on top of the spring's own pull (the inertia
  /// of a tuft on an accelerating body). Steps of at most 1/120 s keep a stiff spring
  /// stable on a slow frame.
  void step(double dt, {double force = 0}) {
    var left = dt;
    while (left > 0) {
      final h = math.min(left, 1 / 120);
      final a = -stiffness * (value - target) - _damping * velocity + force;
      velocity += a * h;
      value += velocity * h;
      left -= h;
    }
  }

  bool get atRest => (value - target).abs() < 0.002 && velocity.abs() < 0.02;

  /// Lands on [target] at once.
  void settle() {
    value = target;
    velocity = 0;
  }
}

/// Wusel's secondary motion (specs/25 "The motion"): what the body and the tufts do
/// because Wusel moves, on top of what a pose says. The squash and the lean come from
/// the body's speed, the tufts lag behind its acceleration and flick after a stop,
/// and the eyes travel to what Wusel looks at on a spring of their own.
///
/// Pure Dart with a fixed [step], so a test can run it frame by frame. Speeds are in
/// Wusel sizes per second, so the same rig serves a 64 px Wusel and a 160 px one.
class WuselRig {
  /// `Tokens.springBouncy` (specs/26): the body's squash and lean.
  final squash = WuselSpring(stiffness: 300, dampingRatio: 0.5);
  final lean = WuselSpring(stiffness: 300, dampingRatio: 0.6);

  /// Floppier than the body, so a tuft overshoots once before it settles.
  final tuftLag = WuselSpring(stiffness: 420, dampingRatio: 0.38);
  final tuftFlop = WuselSpring(stiffness: 420, dampingRatio: 0.38);

  /// Quick eyes: a glance arrives in about 100 ms without wobbling.
  final gazeX = WuselSpring(stiffness: 900, dampingRatio: 0.9);
  final gazeY = WuselSpring(stiffness: 900, dampingRatio: 0.9);

  /// Where the body slides on a tilted tablet, in grid units.
  final slide = WuselSpring(stiffness: 120, dampingRatio: 0.8);

  late final List<WuselSpring> _all = [
    squash,
    lean,
    tuftLag,
    tuftFlop,
    gazeX,
    gazeY,
    slide,
  ];

  Offset _lastVelocity = Offset.zero;
  bool _hasVelocity = false;

  /// How strongly the tufts answer the body's acceleration (in sizes per second²),
  /// sideways and up or down.
  static const _lagInertia = 10.0;
  static const _flopInertia = 17.0;

  /// Advances by [dt] seconds. [velocity] is the body's speed in sizes per second
  /// (screen axes: y down); the acceleration is taken from its change. [gaze] is an
  /// offset added to the pose's own gaze, in grid units; [lean], [slide] and [tufts]
  /// are resting targets on top of the movement (a tilted tablet).
  void step(
    double dt, {
    Offset velocity = Offset.zero,
    Offset gaze = Offset.zero,
    double lean = 0,
    double slide = 0,
    double tufts = 0,
  }) {
    if (dt <= 0) return;
    final accel = _hasVelocity ? (velocity - _lastVelocity) / dt : Offset.zero;
    _lastVelocity = velocity;
    _hasVelocity = true;
    // A frame-to-frame jump in speed (a take-off) is a large acceleration for one
    // frame; capped, it reads as a flick rather than a snap.
    final ax = accel.dx.clamp(-40.0, 40.0);
    final ay = accel.dy.clamp(-40.0, 40.0);

    // Stretched along a fast vertical movement, leaning into a sideways one.
    squash.target = math.min(0.12, velocity.dy.abs() * 0.035);
    this.lean.target = (velocity.dx * 0.035 + lean).clamp(-0.35, 0.35);
    this.slide.target = slide;
    tuftLag.target = tufts;
    tuftFlop.target = 0;
    gazeX.target = gaze.dx;
    gazeY.target = gaze.dy;

    squash.step(dt);
    this.lean.step(dt);
    this.slide.step(dt);
    // Inertia: the body speeds up to the right, the tufts are left behind to the left.
    tuftLag.step(dt, force: -ax * _lagInertia);
    // Speeding up upwards (ay < 0) presses the tufts down; falling lets them fly.
    tuftFlop.step(dt, force: ay * _flopInertia);
    gazeX.step(dt);
    gazeY.step(dt);
  }

  /// A landing: the body squashes and the tufts flop, then both spring back.
  void land({double strength = 1}) {
    squash.kick(-2.6 * strength);
    tuftFlop.kick(-6 * strength);
  }

  /// A take-off: a stretch, the tufts pressed down for a moment.
  void takeOff({double strength = 1, double sideways = 0}) {
    squash.kick(2 * strength);
    tuftFlop.kick(-4 * strength);
    tuftLag.kick(-sideways * 3);
  }

  /// A giggle or a poke: a quick wobble of the body and the tufts.
  void wobble({double strength = 1}) {
    squash.kick(-1.8 * strength);
    tuftLag.kick(4 * strength);
  }

  /// Whether nothing moves any more: the caller may stop drawing frames.
  bool get atRest =>
      _all.every((s) => s.atRest) && _lastVelocity == Offset.zero;

  /// Puts every spring exactly at its target, so a rig that is [atRest] draws its
  /// targets and not a remainder of the movement.
  void snap() {
    for (final s in _all) {
      s.settle();
    }
    _lastVelocity = Offset.zero;
    _hasVelocity = false;
  }

  /// Puts every spring at zero, as when Wusel stops being drawn.
  void reset() {
    for (final s in _all) {
      s
        ..target = 0
        ..settle();
    }
    _lastVelocity = Offset.zero;
    _hasVelocity = false;
  }

  /// [base] with the secondary motion on top. A rig at rest with no targets returns
  /// [base] unchanged, so a resting Wusel draws exactly its pose.
  WuselLook apply(WuselLook base) {
    if (_all.every((s) => s.value == 0)) return base;
    return base.copyWith(
      squash: (base.squash + squash.value).clamp(-0.18, 0.18),
      lean: base.lean + lean.value,
      tuftLag: base.tuftLag + tuftLag.value.clamp(-0.9, 0.9),
      tuftLift: (base.tuftLift + tuftFlop.value.clamp(-0.8, 0.8)).clamp(
        -1.0,
        1.2,
      ),
      gaze: base.gaze + Offset(gazeX.value, gazeY.value),
      slide: base.slide + slide.value,
    );
  }
}

/// Where the pupils go to look at [point] from an eye at [eye], both in the same
/// coordinates, as an offset from the pose's gaze on the 100 × 100 grid. The pupil
/// stays inside the white: at most 3.5 units from the eye's centre.
Offset gazeToward(Offset eye, Offset point, {required Offset poseGaze}) {
  final d = point - eye;
  final length = d.distance;
  if (length < 1) return -poseGaze;
  final reach = math.min(3.5, length / 20);
  return d / length * reach - poseGaze;
}
