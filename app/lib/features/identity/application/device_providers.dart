import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/household/data/household_onboarding_repository.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';

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

/// A signed-in account with no device and no profile: it may start a family (H1), or
/// wait for an invitation. It is not signed out.
final class NeedsHousehold extends SessionState {
  const NeedsHousehold(this.account, {this.hasStoredInvite = false});
  final Account account;

  /// An invitation was previewed on this phone and not yet joined or discarded: the join
  /// confirmation comes first (specs/20, J2).
  final bool hasStoredInvite;
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

  // An account with no household (or a deleted one) is not signed out: it starts or restores.
  Future<SessionState> freeAccountOrSignOut() async {
    final account = await ref
        .read(householdOnboardingRepositoryProvider)
        .account();
    return switch (account) {
      Ok(:final value) when !value.hasHousehold => NeedsHousehold(
        value,
        hasStoredInvite: await ref.read(invitationStoreProvider).read() != null,
      ),
      Ok() => dropSession(),
      Err(:final failure) => throw failure,
    };
  }

  final device = await repo.currentDevice();
  switch (device) {
    case Err(:final failure):
      if (failure is AuthFailure || failure is PermissionFailure) {
        return dropSession();
      }
      throw failure;
    case Ok(:final value) when value != null && !value.revoked:
      return Ready(value);
    // A phone revoked by leaving its family, or by the family's deletion (specs/20 J6).
    case Ok(:final value) when value != null:
      return freeAccountOrSignOut();
    case Ok():
      break;
  }

  final profile = await repo.myProfile();
  switch (profile) {
    case Ok(:final value) when value != null:
      return NeedsRegistration(value);
    case Ok():
      break;
    case Err(:final failure):
      throw failure;
  }

  return freeAccountOrSignOut();
});

/// The device behind the current session, or null while there is none.
///
/// While the session state is re-evaluated (every auth event, including the token
/// refresh `mfa.listFactors()` triggers) the last known device is kept: `whenData` on a
/// reloading value would drop it, reset every provider keyed on the device and make
/// Settings flicker in a loop.
final deviceProvider = Provider<AsyncValue<DeviceInfo?>>((ref) {
  final session = ref.watch(sessionStateProvider);
  DeviceInfo? deviceOf(SessionState s) => s is Ready ? s.device : null;
  if (session.isLoading && session.hasValue) {
    return AsyncData(deviceOf(session.requireValue));
  }
  return session.whenData(deviceOf);
});

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
