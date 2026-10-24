import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/ui/motion.dart';

void main() {
  testWidgets('switching Reduce Motion rebuilds whoever asked', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final seen = <bool>[];
    await tester.pumpWidget(
      MotionScope(
        child: Builder(
          builder: (context) {
            seen.add(motionAllowed(context));
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen, [true]);

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    expect(seen, [true, false]);

    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    expect(seen, [true, false, true]);
  });

  testWidgets('Remove animations says no as well', (tester) async {
    late bool allowed;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MotionScope(
          child: Builder(
            builder: (context) {
              allowed = motionAllowed(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(allowed, isFalse);
  });
}
