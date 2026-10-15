import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// Set while the new device shows its "Verbunden mit …" greeting (P1). The router keeps the
/// pairing page up while it is set, so the greeting is not cut short by the sign-in.
class PairingHandoff extends Notifier<String?> {
  @override
  String? build() => null;

  void hold(String householdName) => state = householdName;

  void release() => state = null;
}

final pairingHandoffProvider = NotifierProvider<PairingHandoff, String?>(
  PairingHandoff.new,
);

/// Whether this phone may approve a new device: a personal device of a guardian (G1).
/// Shared and kiosk devices never may, and a child's phone is refused by the server too.
final canApprovePairingProvider = Provider<bool>((ref) {
  final device = ref.watch(deviceProvider).value;
  if (device == null || device.deviceClass != DeviceClass.personal) {
    return false;
  }
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  return members.any((m) => m.id == device.profileId && m.isGuardian);
});
