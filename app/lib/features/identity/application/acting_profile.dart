import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

/// Who is acting right now (specs/08, "tap to switch").
///
/// Personal devices are fixed to their profile. Shared and kiosk devices start with
/// nobody and become whoever taps their avatar; the kiosk reverts after 60 s idle.
/// Attribution is cooperative bookkeeping, not authentication.
class ActingProfileNotifier extends Notifier<String?> {
  @override
  String? build() {
    final key = ref.watch(deviceKeyProvider);
    final isPersonal = key.deviceClass?.isTapToSwitch == false;
    return isPersonal ? key.profileId : null;
  }

  void select(String profileId) => state = profileId;

  /// Back to "nobody" — only meaningful on tap-to-switch devices.
  void clear() {
    final key = ref.read(deviceKeyProvider);
    if (key.deviceClass?.isTapToSwitch ?? false) state = null;
  }
}

final actingProfileProvider = NotifierProvider<ActingProfileNotifier, String?>(
  ActingProfileNotifier.new,
);

/// Until when the server considers this device guardian-verified (PIN step-up).
class GuardianVerifiedNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    ref.watch(deviceKeyProvider);
    return ref.read(deviceProvider).value?.guardianVerifiedUntil;
  }

  // ignore: use_setters_to_change_properties
  void set(DateTime? until) => state = until;

  bool get isActive => state?.isAfter(DateTime.now()) ?? false;
}

final guardianVerifiedProvider =
    NotifierProvider<GuardianVerifiedNotifier, DateTime?>(
      GuardianVerifiedNotifier.new,
    );
