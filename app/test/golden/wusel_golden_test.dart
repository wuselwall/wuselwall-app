// Goldens of Wusel (specs/25, specs/18 layer 5): every pose in the three shades, and
// every outfit. Only shapes, no text, so they are stable on the Linux runners.
// Update with: flutter test --update-goldens test/golden/wusel_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/core/wusel/wusel.dart';

/// The reference household's four colours, in board order.
final _family = [for (final s in MemberPalette.swatches.take(4)) s.light];

/// Motion off: every pose shows its characteristic still look, as under reduced motion.
Widget _sheet(Shade shade, List<Widget> children) => MediaQuery(
  data: const MediaQueryData(disableAnimations: true),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: Palette.of(shade).bg,
      child: Center(child: Wrap(spacing: 8, runSpacing: 8, children: children)),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  // Every pose moves for at most 8 s, then rests.
  await tester.pump(const Duration(seconds: 9));
  await tester.pump();
}

void main() {
  for (final shade in Shade.values) {
    testWidgets('every pose, ${shade.name}', (tester) async {
      tester.view.physicalSize = const Size(7 * 128 + 6 * 8, 128);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _sheet(shade, [
          for (final pose in WuselPose.values)
            Wusel(
              colors: WuselColors.of(shade, _family),
              pose: pose,
              size: 128,
            ),
        ]),
      );
      await _settle(tester);
      await expectLater(
        find.byType(Wrap),
        matchesGoldenFile('goldens/wusel_poses_${shade.name}.png'),
      );
    });
  }

  testWidgets('every outfit', (tester) async {
    tester.view.physicalSize = const Size(8 * 128 + 7 * 8, 128);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _sheet(Shade.light, [
        for (final outfit in WuselOutfit.values.skip(1))
          Wusel(
            colors: WuselColors.of(Shade.light, _family),
            size: 128,
            outfit: outfit,
          ),
      ]),
    );
    await _settle(tester);
    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('goldens/wusel_outfits.png'),
    );
  });

  testWidgets('one to six tufts, the front one longer', (tester) async {
    tester.view.physicalSize = const Size(6 * 128 + 5 * 8, 128);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final six = [for (final s in MemberPalette.swatches.take(6)) s.light];
    await tester.pumpWidget(
      _sheet(Shade.light, [
        for (var n = 1; n <= 6; n++)
          Wusel(
            colors: WuselColors.of(Shade.light, six.take(n).toList()),
            size: 128,
            frontTuft: n - 1,
          ),
      ]),
    );
    await _settle(tester);
    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('goldens/wusel_tufts.png'),
    );
  });
}
