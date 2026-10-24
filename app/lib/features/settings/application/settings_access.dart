import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// What the person at this device may open under Einstellungen (specs/09, "Settings on a
/// shared device").
enum SettingsAccess {
  /// Everything: a personal phone, or a guardian at a shared or kiosk device. Household
  /// and device changes still go through `ensureGuardian` (the PIN step-up).
  full,

  /// Only their own settings: a child, or an adult who is not a guardian, at a shared or
  /// kiosk device.
  own,

  /// Nothing: a shared or kiosk device with nobody acting.
  none,
}

/// The access of whoever is acting now. Attribution on a tap-to-switch device is
/// cooperative, so this decides what the app offers; the server enforces the rest.
final settingsAccessProvider = Provider<SettingsAccess>((ref) {
  final device = ref.watch(deviceProvider).value;
  if (device == null || !device.deviceClass.isTapToSwitch) {
    return SettingsAccess.full;
  }
  final acting = ref.watch(actingProfileProvider);
  if (acting == null) return SettingsAccess.none;
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final me = members.where((m) => m.id == acting).firstOrNull;
  return me != null && me.isGuardian ? SettingsAccess.full : SettingsAccess.own;
});

/// Whether the settings gear is drawn. A family tablet with nobody selected has none; the
/// kitchen wall keeps it and asks who is asking when it is tapped.
final settingsGearVisibleProvider = Provider<bool>((ref) {
  final device = ref.watch(deviceProvider).value;
  return !(device?.deviceClass == DeviceClass.shared &&
      ref.watch(actingProfileProvider) == null);
});
