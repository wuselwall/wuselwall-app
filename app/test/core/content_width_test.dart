import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/features/today/ui/today_page.dart';

import '../support/fakes.dart';

void main() {
  for (final (width, expected) in [(390.0, 390.0), (1440.0, 960.0)]) {
    testWidgets('at $width a page is $expected wide, centred', (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ContentWidth(child: SizedBox.expand(key: ValueKey('page'))),
        ),
      );
      final page = t.getRect(find.byKey(const ValueKey('page')));
      expect(page.width, expected);
      expect(page.height, 900);
      expect(page.center.dx, width / 2);
    });
  }

  testWidgets('the adult Today page stops at the content width on a laptop', (
    t,
  ) async {
    await pumpApp(
      t,
      size: const Size(1440, 900),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );
    final page = t.getRect(find.byType(TodayPage));
    expect(page.width, adultMaxContentWidth);
    expect(page.center.dx, 720);
  });
}
