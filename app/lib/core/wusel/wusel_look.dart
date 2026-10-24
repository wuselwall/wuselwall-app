import 'dart:ui' show Offset, lerpDouble;

import 'package:flutter/foundation.dart';

/// The shape of Wusel's eyes (specs/25 "The drawing").
enum WuselEyes { round, happy, closed }

/// The shape of Wusel's mouth: the "w", a cheering open "w", or a small sleepy line.
enum WuselMouth { w, open, sleepy }

/// Something Wusel holds up (specs/25, pose `proud`).
enum WuselProp { none, star }

/// What Wusel wears (specs/25 "Outfits"). Free from the start, never earned. The keys
/// are the values of the `member.wusel_outfit` setting.
enum WuselOutfit {
  none,
  party,
  crown,
  wizard,
  wreath,
  sunglasses,
  scarf,
  headphones,
  bow;

  static WuselOutfit parse(Object? wire) => WuselOutfit.values.firstWhere(
    (o) => o.name == wire,
    orElse: () => WuselOutfit.none,
  );
}

/// Every parameter the painter draws Wusel from, on the reference drawing's 100 × 100
/// grid. A pose is a function of time that returns one of these; nothing is a separate
/// drawing, so poses blend into each other and recolour at runtime.
@immutable
class WuselLook {
  const WuselLook({
    this.eyes = WuselEyes.round,
    this.eyeOpen = 1,
    this.gaze = const Offset(2, -2),
    this.mouth = WuselMouth.w,
    this.squash = 0,
    this.lift = 0,
    this.tuftLift = 0,
    this.tuftSway = 0,
    this.armLeft,
    this.armRight,
    this.feet = false,
    this.prop = WuselProp.none,
    this.propGlint = 0,
    this.thinkDots = 0,
    this.sleepZ = 0,
    this.confetti = 0,
  });

  final WuselEyes eyes;

  /// 1 open, 0 shut: a blink is a short dip to 0 of round eyes.
  final double eyeOpen;

  /// Where the pupils look, in grid units from the eye's centre.
  final Offset gaze;

  final WuselMouth mouth;

  /// Vertical squash (negative) or stretch (positive) about the feet, e.g. −0.1.
  final double squash;

  /// Up (negative) or down (positive), in grid units.
  final double lift;

  /// −1 drooping (asleep), 0 standing, 1 flying (cheering).
  final double tuftLift;

  /// A small sideways swing of every tuft, in radians.
  final double tuftSway;

  /// The arms, as an angle from straight down in radians (positive is outward and
  /// up). Null hides the arm: Wusel has arms only in the poses that use them.
  final double? armLeft;
  final double? armRight;

  final bool feet;
  final WuselProp prop;

  /// 0–1: the glint on a held prop.
  final double propGlint;

  /// 0–1: the three thinking dots, fading in one after another.
  final double thinkDots;

  /// 0–1: the sleeping "z".
  final double sleepZ;

  /// 0–1: the little burst of confetti above Wusel when it cheers.
  final double confetti;

  WuselLook copyWith({
    WuselEyes? eyes,
    double? eyeOpen,
    Offset? gaze,
    WuselMouth? mouth,
    double? squash,
    double? lift,
    double? tuftLift,
    double? tuftSway,
    double? Function()? armLeft,
    double? Function()? armRight,
    bool? feet,
    WuselProp? prop,
    double? propGlint,
    double? thinkDots,
    double? sleepZ,
    double? confetti,
  }) => WuselLook(
    eyes: eyes ?? this.eyes,
    eyeOpen: eyeOpen ?? this.eyeOpen,
    gaze: gaze ?? this.gaze,
    mouth: mouth ?? this.mouth,
    squash: squash ?? this.squash,
    lift: lift ?? this.lift,
    tuftLift: tuftLift ?? this.tuftLift,
    tuftSway: tuftSway ?? this.tuftSway,
    armLeft: armLeft == null ? this.armLeft : armLeft(),
    armRight: armRight == null ? this.armRight : armRight(),
    feet: feet ?? this.feet,
    prop: prop ?? this.prop,
    propGlint: propGlint ?? this.propGlint,
    thinkDots: thinkDots ?? this.thinkDots,
    sleepZ: sleepZ ?? this.sleepZ,
    confetti: confetti ?? this.confetti,
  );

  /// Blends two looks. Shapes that cannot blend (eyes, mouth, feet, prop) switch at the
  /// halfway point; an arm that appears or goes swings from or to hanging down.
  static WuselLook lerp(WuselLook a, WuselLook b, double t) {
    double l(double x, double y) => lerpDouble(x, y, t)!;
    double? arm(double? x, double? y) {
      if (x == null && y == null) return null;
      if (t >= 1) return y;
      if (t <= 0) return x;
      return lerpDouble(x ?? 0, y ?? 0, t);
    }

    final late = t >= 0.5;
    return WuselLook(
      eyes: late ? b.eyes : a.eyes,
      eyeOpen: l(a.eyeOpen, b.eyeOpen),
      gaze: Offset.lerp(a.gaze, b.gaze, t)!,
      mouth: late ? b.mouth : a.mouth,
      squash: l(a.squash, b.squash),
      lift: l(a.lift, b.lift),
      tuftLift: l(a.tuftLift, b.tuftLift),
      tuftSway: l(a.tuftSway, b.tuftSway),
      armLeft: arm(a.armLeft, b.armLeft),
      armRight: arm(a.armRight, b.armRight),
      feet: late ? b.feet : a.feet,
      prop: late ? b.prop : a.prop,
      propGlint: l(a.propGlint, b.propGlint),
      thinkDots: l(a.thinkDots, b.thinkDots),
      sleepZ: l(a.sleepZ, b.sleepZ),
      confetti: l(a.confetti, b.confetti),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WuselLook &&
      other.eyes == eyes &&
      other.eyeOpen == eyeOpen &&
      other.gaze == gaze &&
      other.mouth == mouth &&
      other.squash == squash &&
      other.lift == lift &&
      other.tuftLift == tuftLift &&
      other.tuftSway == tuftSway &&
      other.armLeft == armLeft &&
      other.armRight == armRight &&
      other.feet == feet &&
      other.prop == prop &&
      other.propGlint == propGlint &&
      other.thinkDots == thinkDots &&
      other.sleepZ == sleepZ &&
      other.confetti == confetti;

  @override
  int get hashCode => Object.hash(
    eyes,
    eyeOpen,
    gaze,
    mouth,
    squash,
    lift,
    tuftLift,
    tuftSway,
    armLeft,
    armRight,
    feet,
    prop,
    propGlint,
    thinkDots,
    sleepZ,
    confetti,
  );
}
