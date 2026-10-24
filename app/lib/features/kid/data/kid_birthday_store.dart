import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/core/logging/log.dart';

/// Whether this device has shown a child's birthday celebration today: the full
/// screen comes once per day per device (specs/25), not on every open of the kid home.
abstract class KidBirthdayStore {
  /// True when [profileId]'s celebration on [day] has not been shown on this device
  /// yet, and from now on counts as shown.
  Future<bool> claim(String profileId, DateTime day);
}

/// What was claimed, as `profile@yyyy-mm-dd`.
String _entry(String profileId, DateTime day) =>
    '$profileId@${day.year}-${day.month}-${day.day}';

/// The claims of this app run only: the tests and the demo.
class MemoryKidBirthdayStore implements KidBirthdayStore {
  final _claimed = <String>{};

  @override
  Future<bool> claim(String profileId, DateTime day) async =>
      _claimed.add(_entry(profileId, day));
}

/// Kept on the device with the app's other small preferences, so a restart of the
/// app on the birthday does not celebrate again. Only today's claims are kept: the
/// list never grows.
class SecureKidBirthdayStore implements KidBirthdayStore {
  SecureKidBirthdayStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wuselwall.kid.birthday_shown';

  final FlutterSecureStorage _storage;

  /// Claims of this run, so a second open does not wait for the storage.
  final _memory = MemoryKidBirthdayStore();

  @override
  Future<bool> claim(String profileId, DateTime day) async {
    if (!await _memory.claim(profileId, day)) return false;
    final entry = _entry(profileId, day);
    final suffix = '@${day.year}-${day.month}-${day.day}';
    try {
      final stored = (await _storage.read(key: _key))?.split(',') ?? const [];
      if (stored.contains(entry)) return false;
      await _storage.write(
        key: _key,
        value: [...stored.where((e) => e.endsWith(suffix)), entry].join(','),
      );
    } on Object catch (error, stack) {
      // Without the storage the celebration still comes once in this run.
      logError(
        'Saving the birthday celebration failed',
        error: error,
        stackTrace: stack,
      );
    }
    return true;
  }
}

/// Under `flutter test` the secure storage has no platform.
bool get _underTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

final kidBirthdayStoreProvider = Provider<KidBirthdayStore>(
  (ref) => _underTest ? MemoryKidBirthdayStore() : SecureKidBirthdayStore(),
);
