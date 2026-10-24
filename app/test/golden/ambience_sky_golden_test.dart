// Goldens of the sky (specs/26 "Day phases"): morning, the day with its two clouds,
// the evening, the evening sun halfway down in the hour before night, and the night
// sky, in light and dark. Only shapes, no text, so they are stable on the Linux runners.
// Update with: flutter test --update-goldens test/golden/ambience_sky_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';
import 'package:wuselwall/features/wusel/ui/ambience_sky.dart';

const _size = Size(320, 72);

const _skies = [
  Ambience(phase: SkyPhase.morning),
  Ambience(phase: SkyPhase.day),
  Ambience(phase: SkyPhase.evening),
  Ambience(phase: SkyPhase.evening, sunset: 0.5),
];

Widget _sky(Ambience ambience, Shade shade) => SizedBox.fromSize(
  size: _size,
  child: ClipRect(
    child: CustomPaint(
      painter: SkyPainter(ambience: ambience, shade: shade),
    ),
  ),
);

Widget _sheet(List<Widget> skies) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: Column(mainAxisSize: MainAxisSize.min, spacing: 4, children: skies),
  ),
);

void main() {
  for (final shade in [Shade.light, Shade.dark]) {
    testWidgets('the phases of the day, ${shade.name}', (tester) async {
      tester.view.physicalSize = Size(
        _size.width,
        _skies.length * _size.height + (_skies.length - 1) * 4,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_sheet([for (final a in _skies) _sky(a, shade)]));
      await expectLater(
        find.byType(Column),
        matchesGoldenFile('goldens/ambience_sky_${shade.name}.png'),
      );
    });
  }

  testWidgets('the night sky', (tester) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _sheet([_sky(const Ambience(phase: SkyPhase.night), Shade.night)]),
    );
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/ambience_sky_night.png'),
    );
  });
}
