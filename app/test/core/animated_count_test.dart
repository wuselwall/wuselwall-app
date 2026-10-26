import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/ui/animated_count.dart';

Widget _count(int value, {bool loaded = true}) => MaterialApp(
  home: Center(
    child: AnimatedCount(value: value, loaded: loaded),
  ),
);

String _shown(WidgetTester t) => t.widget<Text>(find.byType(Text)).data!;

void main() {
  testWidgets('the first value appears at once', (t) async {
    await t.pumpWidget(_count(14));
    expect(_shown(t), '14');
    await t.pump();
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a change counts to the new value in 600 ms', (t) async {
    await t.pumpWidget(_count(10));
    await t.pumpWidget(_count(20));
    await t.pump(const Duration(milliseconds: 100));
    final midway = int.parse(_shown(t));
    expect(midway, inExclusiveRange(10, 20));
    await t.pump(const Duration(milliseconds: 600));
    expect(_shown(t), '20');
    expect(
      t.widget<Text>(find.byType(Text)).style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('a value that was still loading lands at once', (t) async {
    await t.pumpWidget(_count(0, loaded: false));
    await t.pumpWidget(_count(37));
    expect(_shown(t), '37');
  });

  testWidgets('under reduced motion a change jumps', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.pumpWidget(_count(10));
    await t.pumpWidget(_count(20));
    expect(_shown(t), '20');
  });
}
