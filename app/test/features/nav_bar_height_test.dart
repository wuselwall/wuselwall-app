import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/ui/nav_labels.dart';

import '../support/fakes.dart';

/// The adult home's bottom bar (specs/09 "the bottom bar"): lower on a phone than
/// Material's 80 dp, Material's height on a wide screen, and every destination still
/// a 44 dp touch target (specs/17).
void main() {
  Future<void> pumpAdult(WidgetTester t, Size size) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      size: size,
    );
  }

  testWidgets('on a phone the bar is 64 dp plus the system inset', (t) async {
    await pumpAdult(t, const Size(390, 844));
    expect(navBarHeight(t.element(find.byType(NavigationBar))), 64);
    // No system inset in a test: the bar is its height alone.
    expect(t.getSize(find.byType(NavigationBar)).height, 64);
    for (final d in find.byType(NavigationDestination).evaluate()) {
      final size = (d.renderObject! as RenderBox).size;
      expect(size.height, greaterThanOrEqualTo(44));
      expect(size.width, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('on a phone every destination opens, its label inside the bar', (
    t,
  ) async {
    await pumpAdult(t, const Size(390, 844));
    final bar = find.byType(NavigationBar);
    final destinations = find.byType(NavigationDestination);
    final count = destinations.evaluate().length;
    // Backwards, so each tap leaves the tab it starts on.
    for (var i = count - 1; i >= 0; i--) {
      // Where a person taps: the destination, whose label is hidden until chosen.
      await t.tap(destinations.at(i));
      await t.pumpAndSettle();
      expect(t.widget<NavigationBar>(bar).selectedIndex, i);
      final label = find.descendant(
        of: destinations.at(i),
        matching: find.byType(RichText),
      );
      final box = t.getRect(bar);
      final rect = t.getRect(label.first);
      expect(
        box.top <= rect.top && rect.bottom <= box.bottom,
        isTrue,
        reason: 'label of destination $i at $rect, bar at $box',
      );
    }
  });

  testWidgets('a wide screen keeps the Material height', (t) async {
    await pumpAdult(t, const Size(1000, 1600));
    expect(navBarHeight(t.element(find.byType(NavigationBar))), isNull);
    expect(t.getSize(find.byType(NavigationBar)).height, 80);
  });
}
