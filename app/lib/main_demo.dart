// Entry point for the user documentation's screenshots, never part of a release:
//   flutter build web -t lib/main_demo.dart
// The app runs on in-memory data (lib/demo). The scenario comes from the URL:
//   ?scenario=setup | newfamily | adult | kid | kiosk   (default adult)
//   ?scenario=noschool   adult, with no school yet
//   ?scenario=server   the store app's first question: which server (ADR-018)
//   &still=1           nothing moves and Wusel's words are fixed, for screenshots
// Language and light/dark follow the browser, as on a real device.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/bootstrap.dart';
import 'package:wuselwall/app/licenses.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/demo/demo_notifications.dart';
import 'package:wuselwall/demo/demo_overrides.dart';
import 'package:wuselwall/features/setup/ui/server_choice_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final scenario = Uri.base.queryParameters['scenario'] ?? 'adult';
  // Screenshots hold still: no animation, and Wusel always says the same (motion.dart).
  StillMode.enabled = Uri.base.queryParameters['still'] == '1';

  if (scenario == 'server') {
    runApp(
      BootstrapShell(
        child: ServerChoicePage(
          canScan: true,
          onAddress: (_) async => ServerProblem.unreachable,
          onDemo: () {},
        ),
      ),
    );
    return;
  }

  runApp(
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
}
