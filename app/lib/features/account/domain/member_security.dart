/// One adult of the household, as `api.member_security` reports them to a guardian: whether
/// they have an account, and whether it has a verified authenticator (TOTP).
class MemberSecurity {
  const MemberSecurity({
    required this.profileId,
    required this.hasAccount,
    required this.hasMfa,
  });

  factory MemberSecurity.fromJson(Map<String, dynamic> json) => MemberSecurity(
    profileId: json['profile_id'] as String,
    hasAccount: json['has_account'] as bool? ?? false,
    hasMfa: json['has_mfa'] as bool? ?? false,
  );

  final String profileId;
  final bool hasAccount;
  final bool hasMfa;
}
