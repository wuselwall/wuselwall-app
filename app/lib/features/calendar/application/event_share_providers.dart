import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// Whether this device may send an event to people outside the household (specs/05
/// "Sharing one event"): a guardian on their own personal device. Nothing reaches the
/// server, so this is the only check.
final canShareEventProvider = Provider<bool>((ref) {
  final device = ref.watch(deviceProvider).value;
  if (device?.deviceClass != DeviceClass.personal) return false;
  final acting = ref.watch(actingProfileProvider);
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  return members.any((m) => m.id == acting && m.isGuardian);
});

bool _zonesLoaded = false;

/// The IANA zone [name] from the bundled database, or null when it is unknown.
tz.Location? eventZone(String? name) {
  if (name == null) return null;
  if (!_zonesLoaded) {
    tzdata.initializeTimeZones();
    _zonesLoaded = true;
  }
  try {
    return tz.getLocation(name);
  } on tz.LocationNotFoundException {
    return null;
  }
}
