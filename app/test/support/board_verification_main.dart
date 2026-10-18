// Test-only entrypoint for reproducible system-scaling/night browser evidence.
// Not an application release entrypoint.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/licenses.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/demo/demo_notifications.dart';
import 'package:wuselwall/demo/demo_overrides.dart';

class _VerificationNight extends NightNotifier {
  @override
  bool build() => Uri.base.queryParameters['shade'] == 'night';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final q = Uri.base.queryParameters;
  final scale = double.tryParse(q['scale'] ?? '1') ?? 1;
  runApp(
    ProviderScope(
      overrides: [
        ...demoOverrides(scenario: q['scenario'] ?? 'kiosk'),
        nightProvider.overrideWith(_VerificationNight.new),
        notificationSchedulerProvider.overrideWithValue(
          const DemoNotificationScheduler(),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData.fromView(
          WidgetsBinding.instance.platformDispatcher.views.first,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: const WuselWallApp(),
      ),
    ),
  );
}
