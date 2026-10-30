import 'package:flutter_test/flutter_test.dart';

/// Fail on the first framework error, rather than rebuilding an invalid layout
/// thousands of times while pumpAndSettle waits for its ten-minute timeout.
Future<void> settleQualification(WidgetTester tester) async {
  for (var frame = 0; frame < 120; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    final error = tester.takeException();
    if (error != null) {
      throw TestFailure('Qualification framework/layout error: $error');
    }
    if (!tester.binding.hasScheduledFrame) return;
  }
  throw TestFailure('Qualification fixture did not settle within 120 frames');
}
