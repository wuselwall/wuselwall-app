import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:wuselwall/core/wusel/wusel_look.dart';

/// Wusel's seven poses (specs/25 "Poses"). There is no sad one: the warmest range a
/// character can have is calm, curious, happy, proud and sleepy, and sleepy is not sad.
enum WuselPose {
  /// Present and calm: breathes, blinks.
  idle,

  /// A greeting: the kid home, the wall's morning.
  wave,

  /// The last chore of the day, a birthday.
  cheer,

  /// A badge earned, a reward redeemed: holds up a gold star.
  proud,

  /// Empty states: rises from the lower edge and looks at the call to action.
  peek,

  /// Waiting or offline (kid and kiosk only).
  think,

  /// The wall at night.
  sleep;

  /// How long the pose moves before it settles on [rest] and stops drawing frames.
  /// Wusel moves for a moment, then rests: an always-on wall must not animate all day.
  Duration get active => switch (this) {
    idle => const Duration(seconds: 8),
    wave => const Duration(milliseconds: 2600),
    cheer => const Duration(milliseconds: 2000),
    proud => const Duration(milliseconds: 1600),
    peek => const Duration(milliseconds: 900),
    think => const Duration(seconds: 6),
    sleep => const Duration(seconds: 6),
  };

  /// Whether the eyes blink now and then while the pose rests.
  bool get blinks => switch (this) {
    sleep => false,
    _ => true,
  };

  /// How often a resting pose wakes for a short moment of its own: the sleeping "z".
  Duration? get pulseEvery =>
      this == sleep ? const Duration(seconds: 20) : null;

  /// What the pose settles on after it has moved: a wave or a cheer calms down again.
  WuselLook get rest => at(active);

  /// The pose's characteristic look, held still: all there is under reduced motion,
  /// where a cheer must still read as a cheer (specs/25, "Accessibility").
  WuselLook get still => switch (this) {
    idle || peek || proud || think => rest,
    wave => const WuselLook(armRight: 2.3, armLeft: 0.25),
    cheer => const WuselLook(
      eyes: WuselEyes.happy,
      mouth: WuselMouth.open,
      tuftLift: 1,
      armLeft: 2.5,
      armRight: 2.5,
      feet: true,
    ),
    sleep => rest.copyWith(sleepZ: 0.8),
  };

  /// The look [t] after the pose began. After [active] this is [rest].
  WuselLook at(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    final end = active.inMicroseconds / 1e6;
    final settled = t >= end;
    switch (this) {
      case idle:
        return WuselLook(
          squash: settled ? 0 : 0.02 * math.sin(2 * math.pi * t / 3.2),
          tuftSway: settled ? 0 : 0.05 * math.sin(2 * math.pi * t / 2.4),
        );
      case wave:
        // Three waves of the right arm, then the arm goes down.
        final waving = t < 2.1;
        final lean = waving ? -0.04 : 0.0;
        return WuselLook(
          armRight: settled
              ? null
              : waving
              ? 2.3 + 0.35 * math.sin(2 * math.pi * t / 0.7)
              : 2.3 * (1 - _ease((t - 2.1) / 0.5)),
          armLeft: settled ? null : 0.25,
          squash: lean,
          tuftSway: settled ? 0 : 0.08 * math.sin(2 * math.pi * t / 0.7),
        );
      case cheer:
        // Anticipate, jump, land, settle: squash and stretch about the feet.
        double squash;
        double lift;
        if (t < 0.15) {
          final p = t / 0.15;
          squash = -0.1 * p;
          lift = 0;
        } else if (t < 0.6) {
          final p = (t - 0.15) / 0.45;
          squash = -0.1 + 0.16 * math.sin(math.pi * p);
          lift = -12 * math.sin(math.pi * p);
        } else if (t < 0.85) {
          final p = (t - 0.6) / 0.25;
          squash = -0.08 * math.sin(math.pi * p);
          lift = 0;
        } else {
          squash = 0;
          lift = 0;
        }
        final up = t < 1.4;
        return WuselLook(
          eyes: settled ? WuselEyes.round : WuselEyes.happy,
          mouth: settled ? WuselMouth.w : WuselMouth.open,
          squash: squash,
          lift: lift,
          tuftLift: up ? 1 : 1 - _ease((t - 1.4) / 0.6),
          armLeft: settled
              ? null
              : (up ? 2.5 : 2.5 * (1 - _ease((t - 1.4) / 0.6))),
          armRight: settled
              ? null
              : (up ? 2.5 : 2.5 * (1 - _ease((t - 1.4) / 0.6))),
          feet: !settled,
          confetti: settled ? 0 : _ease(t / 1.2),
        );
      case proud:
        return WuselLook(
          armRight: 2.4 * _ease(math.min(1, t / 0.4)),
          prop: WuselProp.star,
          propGlint: settled
              ? 0
              : math.max(0, math.sin(math.pi * (t - 0.4) / 0.8)),
          tuftLift: 0.3,
        );
      case peek:
        return const WuselLook(gaze: Offset(1, 3));
      case think:
        return WuselLook(
          gaze: const Offset(3, -4),
          armRight: -1.6,
          thinkDots: settled ? 1 : (t % 1.5) / 1.5,
        );
      case sleep:
        return WuselLook(
          eyes: WuselEyes.closed,
          eyeOpen: 0,
          mouth: WuselMouth.sleepy,
          tuftLift: -1,
          lift: 4,
          squash: settled
              ? -0.02
              : -0.02 + 0.02 * math.sin(2 * math.pi * t / 4.5),
          sleepZ: settled ? 0 : math.sin(math.pi * t / end),
        );
    }
  }

  /// The pose's own moment while it rests, [pulseEvery]: the "z" drifting by.
  WuselLook pulse(Duration elapsed) {
    final t = (elapsed.inMicroseconds / 1e6) / 3;
    return rest.copyWith(sleepZ: t >= 1 ? 0 : math.sin(math.pi * t));
  }

  static double _ease(double t) {
    final x = t.clamp(0.0, 1.0);
    return 1 - math.pow(1 - x, 3).toDouble();
  }
}
