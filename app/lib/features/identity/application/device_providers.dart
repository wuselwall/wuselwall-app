import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// Where the app stands, which decides what it shows (the router just follows this).
sealed class SessionState {
  const SessionState();
}

/// Nobody signed in, or a session the backend no longer accepts.
final class SignedOut extends SessionState {
  const SignedOut();
}

/// A guardian whose session has not passed the TOTP challenge yet.
final class NeedsMfa extends SessionState {
  const NeedsMfa();
}

/// A signed-in guardian whose session is not yet registered as a device (a new phone).
final class NeedsRegistration extends SessionState {
  const NeedsRegistration(this.guardian);
  final GuardianProfile guardian;
}

final class Ready extends SessionState {
  const Ready(this.device);
  final DeviceInfo device;
}

final sessionStateProvider = FutureProvider<SessionState>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  // Re-evaluate after the second factor is proven or the session is refreshed.
  ref.watch(authStateProvider);
  if (userId == null) return const SignedOut();

  final repo = ref.watch(identityRepositoryProvider);
  if (repo.mfaState() == MfaState.challengeRequired) return const NeedsMfa();

  Future<SessionState> dropSession() async {
    await repo.signOut();
    return const SignedOut();
  }

  final device = await repo.currentDevice();
  switch (device) {
    case Err(:final failure):
      if (failure is AuthFailure || failure is PermissionFailure) {
        return dropSession();
      }
      throw failure;
    case Ok(:final value) when value != null:
      return value.revoked ? dropSession() : Ready(value);
    case Ok():
      break;
  }

  final profile = await repo.myProfile();
  return switch (profile) {
    Ok(:final value) when value != null => NeedsRegistration(value),
    Ok() => dropSession(),
    Err(:final failure) => throw failure,
  };
});

/// The device behind the current session, or null while there is none.
final deviceProvider = Provider<AsyncValue<DeviceInfo?>>(
  (ref) => ref
      .watch(sessionStateProvider)
      .whenData((s) => s is Ready ? s.device : null),
);

/// Whether this device is enrolled in a household.
final isEnrolledProvider = Provider<bool>(
  (ref) => ref.watch(deviceProvider).value != null,
);

/// The register comes from the device record; adult until a device is known.
final uiRegisterProvider = Provider<UiRegister>(
  (ref) => ref.watch(deviceProvider).value?.register ?? UiRegister.adult,
);

/// Identity of the device without the volatile parts, so dependants do not reset when
/// only `guardian_verified_until` changes.
typedef DeviceKey = ({
  String? deviceId,
  DeviceClass? deviceClass,
  String? profileId,
});

final deviceKeyProvider = Provider<DeviceKey>((ref) {
  final d = ref.watch(deviceProvider).value;
  return (
    deviceId: d?.deviceId,
    deviceClass: d?.deviceClass,
    profileId: d?.profileId,
  );
});

/// Household members (without secrets), refetched on demand.
final membersProvider = FutureProvider.autoDispose<List<Member>>((ref) async {
  ref.watch(deviceKeyProvider);
  return (await ref.watch(identityRepositoryProvider).members()).unwrap();
});

final devicesProvider = FutureProvider.autoDispose<List<DeviceEntry>>((
  ref,
) async {
  ref.watch(deviceKeyProvider);
  return (await ref.watch(identityRepositoryProvider).devices()).unwrap();
});

/// The verified TOTP factor's id (null: second factor not enabled).
final totpFactorProvider = FutureProvider.autoDispose<String?>((ref) async {
  ref.watch(deviceKeyProvider);
  return (await ref.watch(identityRepositoryProvider).totpFactorId()).unwrap();
});
