/// The signed-in account, as `api.my_account()` reports it. It knows nothing about the
/// household beyond whether there is one; the household's own data comes after sign-in.
class Account {
  const Account({
    required this.userId,
    required this.hasHousehold,
    required this.creation,
    this.email,
    this.householdId,
    this.profileId,
    this.fullName,
    this.givenName,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    userId: json['user_id'] as String,
    email: json['email'] as String?,
    hasHousehold: json['has_household'] as bool? ?? false,
    householdId: json['household_id'] as String?,
    profileId: json['profile_id'] as String?,
    creation: json['household_creation'] == 'open'
        ? HouseholdCreation.open
        : HouseholdCreation.code,
    fullName: json['full_name'] as String?,
    givenName: json['given_name'] as String?,
  );

  final String userId;
  final String? email;
  final bool hasHousehold;
  final String? householdId;
  final String? profileId;

  /// Whether a new family needs a founder code (`code`) or anyone may start one (`open`).
  final HouseholdCreation creation;

  /// From the identity provider (Apple, Google), when it gave one.
  final String? fullName;
  final String? givenName;

  /// The family name suggested for H1: the surname of [fullName], when there is one.
  String? get suggestedFamilyName {
    final parts = (fullName ?? '').trim().split(RegExp(r'\s+'));
    return parts.length > 1 && parts.last.isNotEmpty ? parts.last : null;
  }
}

/// `app.instance_setting` `household_creation`.
enum HouseholdCreation { open, code }

/// A row of H2: a person in the family who has no account yet.
class NewMember {
  const NewMember({required this.displayName, required this.isChild});

  final String displayName;

  /// A child is a `member` of kind child; an adult a `guardian` of kind adult.
  final bool isChild;

  Map<String, dynamic> toJson() => {
    'display_name': displayName.trim(),
    'kind': isChild ? 'child' : 'adult',
  };
}

/// What the founder chose on H1 that H2 needs after the household exists.
class OnboardingPlan {
  const OnboardingPlan({required this.seedExamples});

  /// The examples were asked for; their child-dependent chores follow H2.
  final bool seedExamples;
}
