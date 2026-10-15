/// Local notifications the app schedules on this phone (specs/09 "Realtime and
/// notifications", Q47). A self-hosted server cannot reach the store app, so the app
/// schedules what it already knows; nothing leaves the device.
abstract class NotificationScheduler {
  /// Whether this platform can show local notifications at all. False on the web.
  bool get available;

  /// Prepares the platform and names the reminders channel (shown in the OS settings).
  Future<void> init({required String channelName});

  /// Asks the OS for permission to show notifications. Only ever called after a tap.
  Future<bool> requestPermission();

  Future<bool> permissionGranted();

  /// Shows a notification at [when] (local time). Replaces nothing: the caller cancels
  /// first, so each reschedule starts from an empty set.
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  });

  /// Removes every scheduled notification of the app.
  Future<void> cancelAll();
}

/// For the web, tests and the demo: records nothing, shows nothing.
class NoopNotificationScheduler implements NotificationScheduler {
  const NoopNotificationScheduler();

  @override
  bool get available => false;

  @override
  Future<void> init({required String channelName}) async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> permissionGranted() async => false;

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
