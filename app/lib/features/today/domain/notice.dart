/// What a notice on the adult Today tab tells (specs/20 J2 and J4).
enum NoticeKind {
  /// An invited adult joined the household (shown to guardians).
  join('join'),

  /// The account signed in on another device (shown on its other personal devices).
  signIn('signin'),

  /// A guardian reset someone's second factor (shown to that person and the other
  /// guardians; security review 2026-11-01, F3).
  mfaReset('mfa_reset'),

  /// A guardian issued a password reset code for someone (shown likewise).
  passwordResetIssued('password_reset_issued');

  const NoticeKind(this.wire);

  final String wire;

  /// Null for a kind this app does not know yet (a newer server): it is not shown.
  static NoticeKind? parse(String? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }
}

/// One notice. The server derives it from the audit log and the device list; [key]
/// identifies it for dismissal, and [name] is the joiner's name, the new device's label or,
/// for a reset, the guardian who did it; [profileId] is then the person it was done for.
class AppNotice {
  const AppNotice({
    required this.key,
    required this.kind,
    required this.name,
    required this.at,
    this.profileId,
  });

  final String key;
  final NoticeKind kind;
  final String name;
  final DateTime at;
  final String? profileId;

  /// Null for a notice this app cannot show (unknown kind, or a row without a key).
  static AppNotice? fromJson(Map<String, dynamic> json) {
    final kind = NoticeKind.parse(json['kind'] as String?);
    final key = json['key'] as String?;
    if (kind == null || key == null) return null;
    return AppNotice(
      key: key,
      kind: kind,
      name: (json['name'] as String?) ?? '',
      profileId: json['profile_id'] as String?,
      at:
          DateTime.tryParse(json['at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}
