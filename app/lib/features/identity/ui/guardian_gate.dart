import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/pin_pad.dart';

/// Guarantees the next guardian-only call will be accepted, asking for the PIN if
/// needed. Returns false if the user is not a guardian or cancels.
///
/// The server decides in the end (`app.require_guardian`); this only avoids sending a
/// request that is certain to be refused.
Future<bool> ensureGuardian(BuildContext context, WidgetRef ref) async {
  final device = ref.read(deviceProvider).value;
  final actingId = ref.read(actingProfileProvider);
  if (device == null) return false;

  final members = await ref.read(membersProvider.future);
  if (!context.mounted) return false;
  final acting = members.where((m) => m.id == actingId).firstOrNull;
  if (acting == null || !acting.isGuardian) {
    context.showMessage(context.l10n.errGuardianRequired);
    return false;
  }
  if (device.deviceClass == DeviceClass.personal) return true;
  if (ref.read(guardianVerifiedProvider.notifier).isActive) return true;

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => PinPadDialog(guardian: acting),
  );
  return ok ?? false;
}
