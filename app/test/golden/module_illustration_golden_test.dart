// Goldens of the module bands' pictures (specs/26 "Module bands") in light and dark,
// each on its own band at the adult app bar's height. Only shapes, no text, so they
// are stable on the Linux runners.
// Update with: flutter test --update-goldens test/golden/module_illustration_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/core/ui/module_band.dart';

const _modules = [
  AppModule.shopping,
  AppModule.tasks,
  AppModule.calendar,
  AppModule.meals,
  AppModule.schedule,
  AppModule.settings,
];

/// The painter alone, as the bar shows it: [ModuleIllustration.width] wide, 64 high.
Widget _sheet(Shade shade) => Directionality(
  textDirection: TextDirection.ltr,
  child: ColoredBox(
    color: Palette.of(shade).bg,
    child: Center(
      child: Wrap(
        spacing: 8,
        children: [
          for (final module in _modules)
            ColoredBox(
              color: ModuleBands.of(module).of(shade),
              child: SizedBox(
                width: ModuleIllustration.width,
                height: 64,
                child: ClipRect(
                  child: CustomPaint(
                    painter: ModuleIllustrationPainter(
                      module: module,
                      shade: shade,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);

void main() {
  for (final shade in [Shade.light, Shade.dark]) {
    testWidgets('every module picture on its band, ${shade.name}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(
        _modules.length * ModuleIllustration.width + (_modules.length - 1) * 8,
        64,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_sheet(shade));
      await expectLater(
        find.byType(Wrap),
        matchesGoldenFile('goldens/module_illustrations_${shade.name}.png'),
      );
    });
  }
}
