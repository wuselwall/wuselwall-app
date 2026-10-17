import 'package:wuselwall/features/invitations/domain/invitation.dart';

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
    this.householdName,
    this.leaveBlocked,
    this.deletedHousehold,
    this.pendingInvitations = const [],
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
    householdName: json['household_name'] as String?,
    leaveBlocked: json['leave_blocked'] as String?,
    deletedHousehold: json['deleted_household'] is Map<String, dynamic>
        ? DeletedHousehold.fromJson(
            json['deleted_household'] as Map<String, dynamic>,
          )
        : null,
    pendingInvitations: [
      for (final i
          in (json['pending_invitations'] as List<Object?>? ?? const []))
        PendingInvitation.fromJson(i! as Map<String, dynamic>),
    ],
  );

  final String userId;
  final String? email;
  final bool hasHousehold;
  final String? householdId;
  final String? profileId;

  /// Whether a new family needs a founder code (`code`) or anyone may start one (`open`).
  final HouseholdCreation creation;

  /// The name in the account's metadata, when it has one (an account that signed in with
  /// Apple or Google before those were removed may).
  final String? fullName;
  final String? givenName;

  /// The family's name, when the account is in a live family (for a typed confirmation).
  final String? householdName;

  /// Why this account cannot leave its family yet (`last_guardian`), or null.
  final String? leaveBlocked;

  /// The family this account's adult profile sat in, once it was deleted; null otherwise.
  final DeletedHousehold? deletedHousehold;

  /// Invitations that name this account's confirmed email: H0 offers them before H1.
  final List<PendingInvitation> pendingInvitations;

  /// The family name suggested for H1: the surname of [fullName], when there is one.
  String? get suggestedFamilyName {
    final parts = (fullName ?? '').trim().split(RegExp(r'\s+'));
    return parts.length > 1 && parts.last.isNotEmpty ? parts.last : null;
  }
}

/// A family deleted but not yet purged (specs/20 J6): the account may restore it or start
/// afresh. `purgeAfter` is when the family is removed for good.
class DeletedHousehold {
  const DeletedHousehold({
    required this.id,
    required this.name,
    required this.deletedAt,
    required this.purgeAfter,
    required this.canRestore,
  });

  factory DeletedHousehold.fromJson(Map<String, dynamic> json) =>
      DeletedHousehold(
        id: json['id'] as String,
        name: json['name'] as String,
        deletedAt: DateTime.parse(json['deleted_at'] as String),
        purgeAfter: DateTime.parse(json['purge_after'] as String),
        canRestore: json['can_restore'] as bool? ?? false,
      );

  final String id;
  final String name;
  final DateTime deletedAt;
  final DateTime purgeAfter;

  /// A guardian within the 14 days.
  final bool canRestore;
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
