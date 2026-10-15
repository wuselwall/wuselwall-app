import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// The one-time introduction a newly connected shared device shows (specs/20 J3): the kiosk
/// checklist on a wall display, the welcome on a kids' tablet. Shown once per device.
enum FirstRun { kiosk, kidWelcome }

/// Remembers which devices have seen their introduction. Local to the device, because the
/// question is the device's own. Every failure reads as "seen": a missing storage must never
/// keep a wall display on a checklist.
abstract class FirstRunStore {
  Future<bool> isSeen(String deviceId);
  Future<void> markSeen(String deviceId);
}

class SecureFirstRunStore implements FirstRunStore {
  const SecureFirstRunStore();

  static const _storage = FlutterSecureStorage();

  static String _key(String deviceId) => 'first_run_seen:$deviceId';

  @override
  Future<bool> isSeen(String deviceId) async {
    try {
      return await _storage.read(key: _key(deviceId)) == 'true';
    } on Object {
      return true;
    }
  }

  @override
  Future<void> markSeen(String deviceId) async {
    try {
      await _storage.write(key: _key(deviceId), value: 'true');
    } on Object {
      // Shown again next time at worst.
    }
  }
}

final firstRunStoreProvider = Provider<FirstRunStore>(
  (ref) => const SecureFirstRunStore(),
);

/// The introduction this device still owes, or null (a personal phone, or already seen).
final pendingFirstRunProvider = FutureProvider<FirstRun?>((ref) async {
  final device = ref.watch(deviceProvider).value;
  if (device == null) return null;
  final kind = switch (device.deviceClass) {
    DeviceClass.kiosk => FirstRun.kiosk,
    DeviceClass.shared when device.register == UiRegister.kid =>
      FirstRun.kidWelcome,
    _ => null,
  };
  if (kind == null) return null;
  final seen = await ref.watch(firstRunStoreProvider).isSeen(device.deviceId);
  return seen ? null : kind;
});
