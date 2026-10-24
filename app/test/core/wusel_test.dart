import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/core/wusel/wusel_look.dart';
import 'package:wuselwall/core/wusel/wusel_painter.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

final _colors = WuselColors.of(Shade.light, const []);

WuselLook _look(WidgetTester tester) =>
    (tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(Wusel),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as WuselPainter)
        .look;

/// Whether Wusel closes its eyes at some point in the next [span], sampled every
/// 50 ms (a blink takes 180).
Future<bool> _blinksWithin(WidgetTester tester, Duration span) async {
  var blinked = false;
  for (var t = Duration.zero; t < span; t += const Duration(milliseconds: 50)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (_look(tester).eyeOpen < 0.9) blinked = true;
  }
  return blinked;
}

void main() {
  tearDown(() => StillMode.enabled = false);

  testWidgets('in still mode Wusel draws no frames and keeps no timers', (
    tester,
  ) async {
    StillMode.enabled = true;
    await tester.pumpWidget(
      _host(Wusel(colors: _colors, pose: WuselPose.cheer, size: 96)),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(Wusel),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as WuselPainter;
    // The cheer's still look, not the calm one it settles on after moving.
    expect(painter.look, WuselPose.cheer.still);
    await tester.pump(const Duration(seconds: 30));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a lively pose moves for a moment, then stops drawing frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(Wusel(colors: _colors, pose: WuselPose.wave, size: 96)),
    );
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(
      WuselPose.wave.active + const Duration(milliseconds: 400),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    // Unmounting cancels the blink timer: nothing is left pending.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a still Wusel draws its still look and no frames', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(Wusel(colors: _colors, pose: WuselPose.cheer, still: true)),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(_look(tester), WuselPose.cheer.still);
    await tester.pump(const Duration(seconds: 30));
    expect(tester.binding.hasScheduledFrame, isFalse);

    // Moving again plays the pose.
    await tester.pumpWidget(
      _host(Wusel(colors: _colors, pose: WuselPose.cheer)),
    );
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('on the wall the blinking stops a minute after the last moment', (
    tester,
  ) async {
    Widget wusel(int moment) => _host(
      Wusel(
        colors: _colors,
        moment: moment,
        restAfter: const Duration(seconds: 60),
      ),
    );
    const settle = Duration(seconds: 9);
    await tester.pumpWidget(wusel(0));
    await tester.pump(settle);
    // Within the minute it blinks every 3 to 7 seconds.
    expect(await _blinksWithin(tester, const Duration(seconds: 20)), isTrue);
    await tester.pump(const Duration(seconds: 40));
    await tester.pump(const Duration(seconds: 1));
    // Then it rests for good.
    expect(await _blinksWithin(tester, const Duration(minutes: 3)), isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);

    // A new moment wakes it up again.
    await tester.pumpWidget(wusel(1));
    await tester.pump(settle);
    expect(await _blinksWithin(tester, const Duration(seconds: 20)), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('elsewhere Wusel keeps blinking', (tester) async {
    await tester.pumpWidget(_host(Wusel(colors: _colors)));
    await tester.pump(const Duration(minutes: 2));
    expect(await _blinksWithin(tester, const Duration(seconds: 20)), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('below 32 px Wusel is not drawn', (tester) async {
    await tester.pumpWidget(_host(Wusel(colors: _colors, size: 24)));
    expect(
      find.descendant(
        of: find.byType(Wusel),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  test('every pose has a still look, and no pose is sad', () {
    for (final pose in WuselPose.values) {
      final still = pose.still;
      // Sleepy is not sad: the only closed eyes are the sleeping ones.
      if (still.eyes == WuselEyes.closed) expect(pose, WuselPose.sleep);
    }
    expect(WuselPose.values.map((p) => p.name), isNot(contains('sad')));
  });
}
