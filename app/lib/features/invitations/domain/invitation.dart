import 'package:wuselwall/features/identity/domain/pairing.dart';

/// Invitations (specs/20, J2). What a guardian makes, what the invitee sees and what the
/// server answers. Holds no rules: `api.invitation_*` decides, this only reads and writes.

const inviteHost = 'wuselwall.app';

final _tokenPattern = RegExp(r'^[0-9a-f]{32}$');
final _codePattern = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$');

/// The link a guardian shares: the token travels in the fragment, so the landing page on
/// the website never receives it (specs/20, "Universal links and the landing pages").
String inviteLink(String token) => 'https://$inviteHost/i/#$token';

/// Reads a secret out of typed or scanned text: the 8-symbol code (any case, with or without
/// the hyphen), the token, or an invitation link `…/i/#<token>[@host]`. The `@host` part names
/// the household's server and belongs to another branch, so it is dropped here. Returns the
/// normalised secret, or null when [raw] holds neither.
String? parseInvitation(String raw) {
  final text = raw.trim();
  final uri = Uri.tryParse(text);
  final String candidate;
  if (uri != null && uri.hasScheme) {
    if (uri.host != inviteHost || !uri.path.startsWith('/i')) return null;
    candidate = uri.fragment.split('@').first;
  } else {
    candidate = text;
  }
  final s = candidate.replaceAll(RegExp(r'[\s-]'), '');
  if (s.length == 32 && _tokenPattern.hasMatch(s.toLowerCase())) {
    return s.toLowerCase();
  }
  final code = s.toUpperCase();
  return _codePattern.hasMatch(code) ? code : null;
}

/// The role an invitation gives. `guardian` (Erziehungsberechtigt) or `member` (Mitglied).
enum InvitationRole {
  guardian,
  member;

  static InvitationRole parse(String? wire) =>
      wire == 'member' ? InvitationRole.member : InvitationRole.guardian;

  String get wire => name;
}

/// What `invitation_preview` reveals to anyone holding the secret.
class InvitationPreview {
  const InvitationPreview({
    required this.householdName,
    required this.profileName,
    required this.role,
    required this.expiresAt,
    this.inviterFirstName,
  });

  factory InvitationPreview.fromJson(Map<String, dynamic> json) =>
      InvitationPreview(
        householdName: json['household_name'] as String,
        inviterFirstName: json['inviter_first_name'] as String?,
        profileName: json['profile_name'] as String,
        role: InvitationRole.parse(json['role'] as String?),
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  final String householdName;
  final String? inviterFirstName;
  final String profileName;
  final InvitationRole role;
  final DateTime expiresAt;
}

/// The answer to a preview: a valid invitation, or the reason it is not one
/// (`invalid`, `expired` or `rate_limited`).
sealed class PreviewOutcome {
  const PreviewOutcome();
}

final class PreviewValid extends PreviewOutcome {
  const PreviewValid(this.preview);
  final InvitationPreview preview;
}

final class PreviewRefused extends PreviewOutcome {
  const PreviewRefused(this.reason);
  final String reason;
}

/// The answer to an accept: joined (the household's ids), or refused for a reason the person
/// can act on (`invalid`, `expired`, `rate_limited`). Account state arrives as a failure.
sealed class AcceptOutcome {
  const AcceptOutcome();
}

final class Accepted extends AcceptOutcome {
  const Accepted({
    required this.householdId,
    required this.profileId,
    required this.deviceId,
  });
  final String householdId;
  final String profileId;
  final String deviceId;
}

final class AcceptRefused extends AcceptOutcome {
  const AcceptRefused(this.reason);
  final String reason;
}

/// An invitation a guardian has just made. The token and the code are shown once.
class CreatedInvitation {
  const CreatedInvitation({
    required this.id,
    required this.profileId,
    required this.token,
    required this.code,
    required this.expiresAt,
  });

  factory CreatedInvitation.fromJson(Map<String, dynamic> json) =>
      CreatedInvitation(
        id: json['id'] as String,
        profileId: json['profile_id'] as String,
        token: json['token'] as String,
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  final String id;
  final String profileId;
  final String token;
  final String code;
  final DateTime expiresAt;

  String get link => inviteLink(token);

  /// K7QM-3XRP, the way it is read out and written down.
  String get displayCode => formatPairingCode(code);
}

/// An open invitation of the household, as the members list shows it.
class OpenInvitation {
  const OpenInvitation({
    required this.id,
    required this.profileId,
    required this.profileName,
    required this.role,
    required this.expiresAt,
    this.email,
    this.acceptedAt,
    this.revokedAt,
  });

  factory OpenInvitation.fromJson(Map<String, dynamic> json) => OpenInvitation(
    id: json['id'] as String,
    profileId: json['profile_id'] as String,
    profileName: json['profile_name'] as String,
    role: InvitationRole.parse(json['role'] as String?),
    email: json['email'] as String?,
    expiresAt: DateTime.parse(json['expires_at'] as String),
    acceptedAt: _date(json['accepted_at']),
    revokedAt: _date(json['revoked_at']),
  );

  final String id;
  final String profileId;
  final String profileName;
  final InvitationRole role;
  final String? email;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;

  /// Not accepted, not withdrawn and not yet expired.
  bool get isOpen =>
      acceptedAt == null &&
      revokedAt == null &&
      expiresAt.isAfter(DateTime.now());

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

/// An invitation that names this account's confirmed email (`my_account`'s
/// `pending_invitations`): the H0 screen, and the join confirmation without a code.
class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.householdName,
    required this.profileName,
    required this.role,
    this.inviterFirstName,
    this.profileColor,
  });

  factory PendingInvitation.fromJson(Map<String, dynamic> json) =>
      PendingInvitation(
        id: json['id'] as String,
        householdName: json['household_name'] as String,
        inviterFirstName: json['inviter_first_name'] as String?,
        profileName: json['profile_name'] as String,
        profileColor: json['profile_color'] as String?,
        role: InvitationRole.parse(json['role'] as String?),
      );

  final String id;
  final String householdName;
  final String? inviterFirstName;
  final String profileName;

  /// The colour the inviter chose for the person (`#RRGGBB`), when known.
  final String? profileColor;
  final InvitationRole role;
}

/// An invitation the invitee previewed and kept on this phone until they join or decline
/// (specs/20: "the code is kept until accepted or discarded"). The secret is the token or the
/// code; the rest is what the banner said, for the screens after sign-in.
class StoredInvitation {
  const StoredInvitation({
    required this.secret,
    required this.householdName,
    required this.profileName,
    required this.role,
    this.inviterFirstName,
  });

  factory StoredInvitation.fromJson(Map<String, dynamic> json) =>
      StoredInvitation(
        secret: json['secret'] as String,
        householdName: json['household_name'] as String,
        profileName: json['profile_name'] as String,
        role: InvitationRole.parse(json['role'] as String?),
        inviterFirstName: json['inviter_first_name'] as String?,
      );

  factory StoredInvitation.fromPreview(String secret, InvitationPreview p) =>
      StoredInvitation(
        secret: secret,
        householdName: p.householdName,
        profileName: p.profileName,
        role: p.role,
        inviterFirstName: p.inviterFirstName,
      );

  Map<String, dynamic> toJson() => {
    'secret': secret,
    'household_name': householdName,
    'profile_name': profileName,
    'role': role.wire,
    'inviter_first_name': inviterFirstName,
  };

  final String secret;
  final String householdName;
  final String profileName;
  final InvitationRole role;
  final String? inviterFirstName;
}
