import 'package:wuselwall/core/notifications/notification_scheduler.dart';

/// The docs' screenshots show reminders as a phone shows them: available and allowed.
/// Nothing is scheduled; the web cannot show reminders.
class DemoNotificationScheduler implements NotificationScheduler {
  const DemoNotificationScheduler();

  @override
  bool get available => true;

  @override
  Future<void> init({required String channelName}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> permissionGranted() async => true;

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelAll() async {}
}
