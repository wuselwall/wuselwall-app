import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/wusel/wusel_look.dart';
import 'package:wuselwall/core/wusel/wusel_rig.dart';
import 'package:wuselwall/core/wusel/wusel_tilt.dart';
import 'package:wuselwall/core/wusel/wusel_travel.dart';

const _frame = 1 / 60;

/// Runs [rig] for [seconds] at 60 frames a second with [velocity].
void _run(
  WuselRig rig,
  double seconds, {
  Offset velocity = Offset.zero,
  Offset gaze = Offset.zero,
}) {
  for (var t = 0.0; t < seconds; t += _frame) {
    rig.step(_frame, velocity: velocity, gaze: gaze);
  }
}

void main() {
  group('the rig (specs/25 "The motion")', () {
    test('at rest it draws exactly the pose', () {
      final rig = WuselRig();
      const base = WuselLook(armRight: 2.3, tuftSway: 0.1);
      _run(rig, 1);
      expect(rig.atRest, isTrue);
      expect(rig.apply(base), base);
    });

    test(
      'a landing squashes and flops the tufts, and every spring comes to rest',
      () {
        final rig = WuselRig()..land();
        rig.step(_frame);
        final landed = rig.apply(const WuselLook());
        expect(landed.squash, lessThan(0));
        expect(landed.tuftLift, lessThan(0));
        expect(rig.atRest, isFalse);
        // Well within the margin a resting pose allows before it stops drawing.
        _run(rig, 0.9);
        expect(rig.atRest, isTrue);
        rig.snap();
        expect(rig.apply(const WuselLook()), const WuselLook());
      },
    );

    test('the tufts lag behind a sideways start and flick after a stop', () {
      final rig = WuselRig();
      _run(rig, 0.2);
      // Off to the right: the tufts are left behind, to the left.
      rig.step(_frame, velocity: const Offset(6, 0));
      _run(rig, 0.05, velocity: const Offset(6, 0));
      expect(rig.tuftLag.value, lessThan(0));
      // Leaning into the movement.
      expect(rig.lean.value, greaterThan(0));
      // A sudden stop: they swing on to the right.
      var maxLag = 0.0;
      for (var t = 0.0; t < 0.4; t += _frame) {
        rig.step(_frame);
        if (rig.tuftLag.value > maxLag) maxLag = rig.tuftLag.value;
      }
      expect(maxLag, greaterThan(0));
      _run(rig, 1.2);
      expect(rig.atRest, isTrue);
    });

    test('the eyes travel to a gaze and hold it', () {
      final rig = WuselRig();
      _run(rig, 0.4, gaze: const Offset(3, -1));
      expect(rig.atRest, isTrue);
      rig.snap();
      expect(
        rig.apply(const WuselLook()).gaze,
        const Offset(2, -2) + const Offset(3, -1),
      );
    });

    test('a slow frame does not make a stiff spring explode', () {
      final rig = WuselRig()..land(strength: 2);
      rig.step(0.25);
      final look = rig.apply(const WuselLook());
      expect(look.squash.abs(), lessThanOrEqualTo(0.18));
      expect(rig.squash.value.isFinite, isTrue);
    });

    test('gazeToward keeps the pupil inside the white', () {
      final g = gazeToward(
        Offset.zero,
        const Offset(500, 0),
        poseGaze: const Offset(2, -2),
      );
      final pupil = const Offset(2, -2) + g;
      expect(pupil.distance, closeTo(3.5, 1e-9));
      expect(pupil.dx, greaterThan(0));
    });
  });

  group('a hop', () {
    test('takes off from where it was and lands on the target', () {
      const path = WuselHopPath(
        from: Offset(100, 500),
        height: 60,
        seconds: 0.4,
      );
      const to = Offset(400, 300);
      expect(path.at(0, to), const Offset(100, 500));
      expect(path.at(1, to), to);
      // The middle of the arc is above the straight line.
      final middle = path.at(0.5, to);
      expect(middle.dy, lessThan(400 - 59));
    });

    test('follows a target that moves under it', () {
      const path = WuselHopPath(from: Offset(0, 0), height: 40, seconds: 0.4);
      // The list scrolled by 120 during the flight: Wusel still lands on the card.
      expect(path.at(1, const Offset(200, -120)), const Offset(200, -120));
    });

    test('rises on take-off and falls on landing', () {
      const path = WuselHopPath(from: Offset(0, 0), height: 40, seconds: 0.4);
      const to = Offset(200, 0);
      expect(path.velocity(0, to).dy, lessThan(0));
      expect(path.velocity(1, to).dy, greaterThan(0));
      expect(path.velocity(0.5, to).dy, closeTo(0, 1e-9));
    });

    test('a long way is several hops of at most four sizes', () {
      expect(WuselHops.count(Offset.zero, const Offset(100, 0), 64), 1);
      expect(WuselHops.count(Offset.zero, const Offset(1000, 0), 64), 4);
      for (final d in [10.0, 200.0, 1200.0]) {
        final n = WuselHops.count(Offset.zero, Offset(d, 0), 64);
        expect(d / n, lessThanOrEqualTo(64 * WuselHops.maxLength));
      }
    });

    test('even a short hop rises half a Wusel', () {
      expect(WuselHops.arcHeight(10, 88), 44);
    });
  });

  group('the tilt in the hand', () {
    test('upright in portrait there is no tilt', () {
      final r = tiltFrom(0, 9.81);
      expect(r.tilt, closeTo(0, 1e-9));
      expect(r.down, ScreenDown.portrait);
    });

    test('the right side lower is a positive tilt, in every orientation', () {
      // Portrait, tipped to the right.
      expect(tiltFrom(-4, 8.9).tilt, greaterThan(0.3));
      // Landscape, turned clockwise (the device's top points right): tipping the
      // screen's right side down lowers the device's top.
      final clockwise = tiltFrom(-8.9, -4);
      expect(clockwise.down, ScreenDown.landscapeRight);
      expect(clockwise.tilt, greaterThan(0.3));
      // Landscape, turned anticlockwise.
      final anticlockwise = tiltFrom(8.9, 4);
      expect(anticlockwise.down, ScreenDown.landscapeLeft);
      expect(anticlockwise.tilt, greaterThan(0.3));
    });

    test('lying almost flat keeps the orientation it had', () {
      final r = tiltFrom(-1, 0.5, previous: ScreenDown.landscapeRight);
      expect(r.down, ScreenDown.landscapeRight);
    });
  });
}
