import 'package:wuselwall/core/notifications/notification_scheduler.dart';
import 'package:wuselwall/features/reminders/data/reminder_dismissal_store.dart';

/// One notification the fake was asked to show.
typedef ScheduledNotice = ({int id, DateTime when, String title, String body});

/// In-memory local notifications. [active] is what the phone would have pending; a
/// `cancelAll` clears it, as the real plugin does.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({
    this.available = true,
    this.granted = true,
    this.grantOnRequest = true,
  });

  @override
  final bool available;

  /// The OS permission as it stands; the tests flip it.
  bool granted;

  /// What the OS answers to the next request.
  bool grantOnRequest;

  final active = <ScheduledNotice>[];
  int cancelAllCalls = 0;
  int requests = 0;
  final channelNames = <String>[];

  @override
  Future<void> init({required String channelName}) async {
    channelNames.add(channelName);
  }

  @override
  Future<bool> requestPermission() async {
    requests++;
    granted = grantOnRequest;
    return granted;
  }

  @override
  Future<bool> permissionGranted() async => granted;

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    active.add((id: id, when: when, title: title, body: body));
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    active.clear();
  }
}

/// The dismissal of the Today row, in memory (secure storage has no platform in tests).
class MemoryReminderDismissalStore implements ReminderDismissalStore {
  MemoryReminderDismissalStore({this.isDismissed = false});

  bool isDismissed;

  @override
  Future<bool> dismissed() async => isDismissed;

  @override
  Future<void> dismiss() async => isDismissed = true;
}
