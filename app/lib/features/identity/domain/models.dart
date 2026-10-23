import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';
import 'package:wuselwall/app/theme/ui_register.dart';

enum DeviceClass {
  personal,
  shared,
  kiosk;

  static DeviceClass parse(String value) =>
      DeviceClass.values.firstWhere((c) => c.name == value);

  /// Shared and kiosk devices have no fixed profile: people tap to become someone.
  bool get isTapToSwitch => this != personal;
}

enum Role {
  guardian,
  member;

  static Role parse(String value) =>
      Role.values.firstWhere((r) => r.name == value);
}

/// The calling device, as returned by `api.current_device()`.
class DeviceInfo {
  const DeviceInfo({
    required this.deviceId,
    required this.householdId,
    required this.label,
    required this.deviceClass,
    required this.register,
    required this.profileId,
    required this.revoked,
    required this.guardianVerifiedUntil,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    deviceId: json['device_id'] as String,
    householdId: json['household_id'] as String,
    label: json['label'] as String,
    deviceClass: DeviceClass.parse(json['class'] as String),
    register: UiRegister.values.byName(json['register'] as String),
    profileId: json['profile_id'] as String?,
    revoked: json['revoked'] as bool,
    guardianVerifiedUntil: json['guardian_verified_until'] == null
        ? null
        : DateTime.parse(json['guardian_verified_until'] as String),
  );

  final String deviceId;
  final String householdId;
  final String label;
  final DeviceClass deviceClass;
  final UiRegister register;

  /// The bound profile; only personal devices have one.
  final String? profileId;
  final bool revoked;
  final DateTime? guardianVerifiedUntil;
}

class Member {
  const Member({
    required this.id,
    required this.displayName,
    required this.color,
    required this.role,
    required this.active,
    this.isChild = false,
    this.sortOrder = 0,
    this.hasAccount = true,
    this.avatarKey,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    color: parseHexColor(json['color'] as String),
    role: Role.parse(json['role'] as String),
    active: json['active'] as bool,
    isChild: json['kind'] == 'child',
    sortOrder: json['sort_order'] as int? ?? 0,
    // Older servers do not say; an unknown person is treated as one with an account.
    hasAccount: json['has_account'] as bool? ?? true,
    avatarKey: json['avatar_key'] as String?,
  );

  final String id;
  final String displayName;
  final Color color;
  final Role role;
  final bool active;

  /// `profile.kind` (ADR-014): role says what someone may do, kind whether they are a
  /// child — the kid register, starter chores and the Stundenplan use it.
  final bool isChild;

  /// Whether the person has signed in (an invitation is open only for one without).
  final bool hasAccount;

  /// The household's member order (`profile.sort_order`).
  final int sortOrder;

  /// The picture shown instead of the initial (`profile.avatar_key`); null is the initial.
  final String? avatarKey;

  bool get isGuardian => role == Role.guardian;

  String get initial =>
      displayName.isEmpty ? '?' : displayName.characters.first.toUpperCase();
}

class DeviceEntry {
  const DeviceEntry({
    required this.id,
    required this.label,
    required this.deviceClass,
    required this.register,
    required this.revoked,
    required this.lastSeenAt,
  });

  factory DeviceEntry.fromJson(Map<String, dynamic> json) => DeviceEntry(
    id: json['id'] as String,
    label: json['label'] as String,
    deviceClass: DeviceClass.parse(json['class'] as String),
    register: UiRegister.values.byName(json['register'] as String),
    revoked: json['revoked_at'] != null,
    lastSeenAt: json['last_seen_at'] == null
        ? null
        : DateTime.parse(json['last_seen_at'] as String),
  );

  final String id;
  final String label;
  final DeviceClass deviceClass;
  final UiRegister register;
  final bool revoked;
  final DateTime? lastSeenAt;
}

class EnrolmentCode {
  const EnrolmentCode({required this.code, required this.expiresAt});

  factory EnrolmentCode.fromJson(Map<String, dynamic> json) => EnrolmentCode(
    code: json['code'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );

  final String code;
  final DateTime expiresAt;
}

/// Outcome of a PIN attempt. A wrong PIN is an expected result, not an error.
sealed class PinResult {
  const PinResult();
}

final class PinVerified extends PinResult {
  const PinVerified(this.verifiedUntil);
  final DateTime verifiedUntil;
}

final class PinWrong extends PinResult {
  const PinWrong(this.attemptsLeft);
  final int attemptsLeft;
}

final class PinBackoff extends PinResult {
  const PinBackoff(this.retryAt);
  final DateTime? retryAt;
}

final class PinLocked extends PinResult {
  const PinLocked();
}

Color parseHexColor(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

String toHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Where the signed-in user stands on the second factor.
enum MfaState {
  /// No factor is required (none enrolled, or not a guardian).
  none,

  /// A TOTP factor exists but this session has not proven it yet (aal1 → aal2).
  challengeRequired,

  /// The session is aal2.
  satisfied,
}

class TotpEnrolment {
  const TotpEnrolment({
    required this.factorId,
    required this.uri,
    required this.secret,
  });

  final String factorId;

  /// `otpauth://` URI — rendered as a QR code on our side.
  final String uri;
  final String secret;
}

/// A guardian account that has signed in but has no device on this session yet.
class GuardianProfile {
  const GuardianProfile({required this.profileId, required this.displayName});

  factory GuardianProfile.fromJson(Map<String, dynamic> json) =>
      GuardianProfile(
        profileId: json['profile_id'] as String,
        displayName: json['display_name'] as String,
      );

  final String profileId;
  final String displayName;
}

/// The family's own row (`api.household`): what a guardian edits on the family page.
class HouseholdInfo {
  const HouseholdInfo({
    required this.id,
    required this.name,
    required this.timezone,
    required this.locale,
  });

  factory HouseholdInfo.fromJson(Map<String, dynamic> json) => HouseholdInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    timezone: json['timezone'] as String,
    locale: json['locale'] as String,
  );

  final String id;
  final String name;
  final String timezone;
  final String locale;
}
