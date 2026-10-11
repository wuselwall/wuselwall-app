import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passkeys/authenticator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// Everything identity-related that touches the backend: sign-in, setup, enrolment,
/// members, devices and the guardian PIN. Holds no rules — the `api` functions do.
class IdentityRepository {
  const IdentityRepository(this._api, this._auth);

  final ApiClient _api;
  final GoTrueClient _auth;

  /// The calling device, or null when the session has no device (not enrolled).
  Future<Result<DeviceInfo?>> currentDevice() => _api.rpc(
    'current_device',
    parse: (json) =>
        json == null ? null : DeviceInfo.fromJson(json as Map<String, dynamic>),
  );

  Future<Result<List<Member>>> members() => _api.select(
    'members',
    parse: Member.fromJson,
    build: (q) => q.order('display_name'),
  );

  Future<Result<List<DeviceEntry>>> devices() => _api.select(
    'devices',
    parse: DeviceEntry.fromJson,
    build: (q) => q.order('created_at'),
  );

  Future<Result<void>> signIn(String email, String password) =>
      Result.guard(() async {
        await _auth.signInWithPassword(email: email.trim(), password: password);
      });

  Future<void> signOut() => _auth.signOut();

  /// Creates the household and its first guardian, then signs that guardian in.
  Future<Result<void>> setupHousehold({
    required String token,
    required String householdName,
    required String displayName,
    required String email,
    required String password,
    required String pin,
    required String colorHex,
  }) async {
    final created = await _api.rpc<void>(
      'setup_household',
      params: {
        'p_token': token.trim(),
        'p_household_name': householdName.trim(),
        'p_email': email.trim(),
        'p_password': password,
        'p_display_name': displayName.trim(),
        'p_color': colorHex,
        'p_pin': pin,
      },
      parse: (_) {},
    );
    if (created is Err<void>) return created;
    return signIn(email, password);
  }

  /// Consumes a one-time code and signs this device in with the throwaway credentials
  /// the backend returns. Only the resulting session is kept.
  ///
  /// The backend answers a bad or throttled attempt with `{ok:false, reason}` rather
  /// than raising, so the attempt log survives; it is turned into a [Failure] here.
  Future<Result<void>> enrolDevice(String code) async {
    final creds = await _api.rpc<({String email, String password})>(
      'enrol_device',
      params: {'p_code': code},
      parse: (json) {
        final map = json! as Map<String, dynamic>;
        if (map['ok'] != true) {
          throw switch (map['reason']) {
            'rate_limited' => const PermissionFailure(code: 'rate_limited'),
            _ => const ValidationFailure(code: 'code_invalid'),
          };
        }
        return (
          email: map['email'] as String,
          password: map['password'] as String,
        );
      },
    );
    return switch (creds) {
      Ok(:final value) => signIn(value.email, value.password),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<EnrolmentCode>> createEnrolmentCode({
    required String? actor,
    required String label,
    required DeviceClass deviceClass,
    required UiRegister register,
  }) => _api.rpc(
    'devices_create_enrolment_code',
    params: {
      'p_actor': actor,
      'p_label': label.trim(),
      'p_class': deviceClass.name,
      'p_register': register.name,
    },
    parse: (json) => EnrolmentCode.fromJson(json! as Map<String, dynamic>),
  );

  Future<Result<void>> revokeDevice({
    required String? actor,
    required String deviceId,
  }) => _api.rpc(
    'devices_revoke',
    params: {'p_actor': actor, 'p_device': deviceId},
    parse: (_) {},
  );

  Future<Result<void>> addMember({
    required String? actor,
    required String name,
    required String colorHex,
  }) => _api.rpc(
    'members_add',
    params: {
      'p_actor': actor,
      'p_display_name': name.trim(),
      'p_color': colorHex,
    },
    parse: (_) {},
  );

  // ---------------------------------------------------------------- per-phone devices

  /// A signed-in guardian account, or null (device-owned users have no profile).
  Future<Result<GuardianProfile?>> myProfile() => _api.rpc(
    'my_profile',
    parse: (json) => json == null
        ? null
        : GuardianProfile.fromJson(json as Map<String, dynamic>),
  );

  /// Registers this session as a personal device, then refreshes the session so the new
  /// token carries the device claims.
  Future<Result<DeviceInfo>> registerPersonalDevice(String label) async {
    final registered = await _api.rpc<DeviceInfo>(
      'register_personal_device',
      params: {'p_label': label.trim()},
      parse: (json) => DeviceInfo.fromJson(json! as Map<String, dynamic>),
    );
    if (registered is Ok<DeviceInfo>) {
      final refreshed = await Result.guard(_auth.refreshSession);
      if (refreshed is Err) return Err((refreshed as Err).failure);
    }
    return registered;
  }

  /// Marks a personal phone as signed out (tidy device list), then signs out.
  Future<void> signOutDevice() async {
    await _api.rpc<void>('device_sign_out', parse: (_) {});
    await _auth.signOut();
  }

  // ---------------------------------------------------------------- second factor (TOTP)

  MfaState mfaState() {
    final aal = _auth.mfa.getAuthenticatorAssuranceLevel();
    if (aal.currentLevel == AuthenticatorAssuranceLevels.aal2) {
      return MfaState.satisfied;
    }
    return aal.nextLevel == AuthenticatorAssuranceLevels.aal2
        ? MfaState.challengeRequired
        : MfaState.none;
  }

  /// The verified TOTP factor's id, or null.
  Future<Result<String?>> totpFactorId() => Result.guard(() async {
    final factors = await _auth.mfa.listFactors();
    return factors.totp.firstOrNull?.id;
  });

  Future<Result<TotpEnrolment>> totpEnrol() => Result.guard(() async {
    final r = await _auth.mfa.enroll(
      issuer: 'WuselWall',
      friendlyName: 'WuselWall ${DateTime.now().millisecondsSinceEpoch}',
    );
    final totp = r.totp!;
    return TotpEnrolment(factorId: r.id, uri: totp.uri, secret: totp.secret);
  });

  /// Proves a code for [factorId] — completes enrolment, or lifts the session to aal2.
  Future<Result<void>> totpVerify(String factorId, String code) => Result.guard(
    () async {
      await _auth.mfa.challengeAndVerify(factorId: factorId, code: code.trim());
    },
  );

  /// Sign-in step two: verify against the user's existing verified factor.
  Future<Result<void>> totpChallenge(String code) async {
    final id = await totpFactorId();
    return switch (id) {
      Ok(:final value) when value != null => totpVerify(value, code),
      Ok() => const Err(AuthFailure(code: 'invalid_credentials')),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<void>> totpDisable(String factorId) => Result.guard(() async {
    await _auth.mfa.unenroll(factorId);
  });

  // ---------------------------------------------------------------- passkeys (beta)
  // Needs platform setup that waits for the production domain (associated domains,
  // Digital Asset Links); see specs/16-setup-plan.md.

  Future<Result<void>> registerPasskey(String friendlyName) =>
      Result.guard(() async {
        await _auth.registerPasskey(
          PasskeyAuthenticator(),
          friendlyName: friendlyName,
        );
      });

  Future<Result<void>> signInWithPasskey() => Result.guard(() async {
    await _auth.signInWithPasskey(PasskeyAuthenticator());
  });

  /// Sets a new guardian PIN and clears a lockout. Only a guardian's own phone may.
  Future<Result<void>> setPin({required String pin}) => _api.rpc(
    'guardian_set_pin',
    params: {'p_actor': null, 'p_new_pin': pin},
    parse: (_) {},
  );

  Future<Result<PinResult>> verifyPin({
    required String profileId,
    required String pin,
  }) => _api.rpc(
    'guardian_verify_pin',
    params: {'p_profile': profileId, 'p_pin': pin},
    parse: (json) {
      final map = json! as Map<String, dynamic>;
      if (map['ok'] == true) {
        return PinVerified(DateTime.parse(map['verified_until'] as String));
      }
      return switch (map['reason']) {
        'pin_locked' => const PinLocked(),
        'pin_backoff' => PinBackoff(
          map['retry_at'] == null
              ? null
              : DateTime.parse(map['retry_at'] as String),
        ),
        _ => PinWrong((map['attempts_left'] as int?) ?? 0),
      };
    },
  );
}

final identityRepositoryProvider = Provider<IdentityRepository>(
  (ref) => IdentityRepository(
    ref.watch(apiClientProvider),
    ref.watch(supabaseClientProvider).auth,
  ),
);
