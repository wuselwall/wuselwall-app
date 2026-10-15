import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/notifications/notification_scheduler.dart';

/// The no-op by default; `main.dart` installs the plugin on Android and iOS.
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => const NoopNotificationScheduler(),
);
