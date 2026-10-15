import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/core/logging/log.dart';

/// Whether this phone's "Erinnerungen einschalten" row was dismissed ("Brauchen wir
/// nicht"). Per device, so a phone that never had the row is not hidden by another's.
abstract class ReminderDismissalStore {
  Future<bool> dismissed();

  Future<void> dismiss();
}

class SecureReminderDismissalStore implements ReminderDismissalStore {
  SecureReminderDismissalStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wuselwall.reminders.card_dismissed';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> dismissed() async {
    try {
      return (await _storage.read(key: _key)) == 'true';
    } on Object catch (error, stack) {
      logError(
        'Reading the reminder dismissal failed',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  @override
  Future<void> dismiss() async {
    try {
      await _storage.write(key: _key, value: 'true');
    } on Object catch (error, stack) {
      logError(
        'Saving the reminder dismissal failed',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

final reminderDismissalStoreProvider = Provider<ReminderDismissalStore>(
  (ref) => SecureReminderDismissalStore(),
);
