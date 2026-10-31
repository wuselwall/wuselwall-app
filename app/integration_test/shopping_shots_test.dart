// Screenshots of the shopping list on a real device or emulator, on the in-memory demo
// household (no server), for a pull request or a review:
//
//   SHOTS_OUT=build/shots flutter drive --driver=test_driver/shots_driver.dart \
//     --target=integration_test/shopping_shots_test.dart -d emulator-5554 \
//     --dart-define=SHOTS_PREFIX=pixel8
//
// Language and light/dark follow the device, as in the demo. The driver
// (test_driver/shots_driver.dart) writes `$SHOTS_PREFIX-<shot>.png`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/demo/demo_notifications.dart';
import 'package:wuselwall/demo/demo_overrides.dart';

const _prefix = String.fromEnvironment('SHOTS_PREFIX', defaultValue: 'device');

/// Pumps until nothing moves, but gives up after [seconds] — a lively screen (Wusel)
/// would otherwise never settle.
Future<void> _settle(WidgetTester tester, [double seconds = 2]) async {
  final end = DateTime.now().add(
    Duration(milliseconds: (seconds * 1000).round()),
  );
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  await _settle(tester, 1);
  await binding.takeScreenshot('$_prefix-$name');
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: 'no widget with key $key');
  await tester.tap(finder);
  await _settle(tester, 1);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot(WidgetTester tester, String scenario) async {
    StillMode.enabled = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...demoOverrides(scenario: scenario),
          notificationSchedulerProvider.overrideWithValue(
            const DemoNotificationScheduler(),
          ),
        ],
        child: const WuselWallApp(),
      ),
    );
    await _settle(tester, 3);
    await binding.convertFlutterSurfaceToImage();
    await _settle(tester, 1);
  }

  testWidgets('shopping list, adult', (tester) async {
    await boot(tester, 'adult');
    // The adult home opens on the calendar; the shopping destination has its own icon.
    await tester.tap(find.byIcon(Icons.shopping_basket).first);
    await _settle(tester, 2);
    await _shot(binding, tester, 'shopping-plan');

    // "Einkaufen gehen" opens the trip, a page of its own without the navigation.
    await _tapKey(tester, 'shopping-start');
    await _shot(binding, tester, 'shopping-shop');

    await _tapKey(tester, 'shopping-add-in-store');
    await _shot(binding, tester, 'shopping-shop-add');
    // Close the sheet.
    await tester.tapAt(const Offset(10, 10));
    await _settle(tester, 1);

    await _tapKey(tester, 'shopping-mode-plan');
    await _shot(binding, tester, 'shopping-plan-again');

    // A tap on the first plain row opens the item sheet.
    final row = find
        .byWidgetPredicate(
          (w) =>
              w is ListTile &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('shopping-item-'),
        )
        .first;
    await tester.tap(row);
    await _settle(tester, 1);
    await _shot(binding, tester, 'shopping-item-sheet');
  });
}
