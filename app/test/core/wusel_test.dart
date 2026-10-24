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
