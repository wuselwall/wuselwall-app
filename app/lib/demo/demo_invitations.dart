import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

/// The demo's invitations: nothing leaves the page. Codes are fixed, so the screens can be
/// tried out: `K7QM3XRP` is a valid invitation from the father for the mother.
class DemoInvitationRepository implements InvitationRepository {
  final List<OpenInvitation> _open = [
    OpenInvitation(
      id: 'demo-invitation-ruth',
      profileId: 'demo-profile-ruth',
      profileName: 'Oma Ruth',
      role: InvitationRole.member,
      expiresAt: DateTime.now().add(const Duration(days: 6)),
    ),
  ];

  static String get _household => DemoData.tr4(
    'Familie Becker',
    'The Becker family',
    'Famille Becker',
    'Familia Becker',
  );

  @override
  Future<Result<CreatedInvitation>> create({
    String? profileId,
    String? displayName,
    required InvitationRole role,
    String? email,
  }) async => Ok(
    CreatedInvitation(
      id: 'demo-invitation-new',
      profileId: profileId ?? 'demo-profile-new',
      token: '5e1f0c9a7b3d4e2f8a6b1c0d9e8f7a6b',
      code: 'K7QM3XRP',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    ),
  );

  @override
  Future<Result<void>> revoke(String id) async {
    _open.removeWhere((i) => i.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<List<OpenInvitation>>> open() async => Ok([..._open]);

  @override
  Future<Result<String>> householdName() async => Ok(_household);

  @override
  Future<Result<PreviewOutcome>> preview(String secret) async => Ok(
    PreviewValid(
      InvitationPreview(
        householdName: _household,
        inviterFirstName: DemoData.name(DemoData.papa),
        profileName: DemoData.name(DemoData.mama),
        role: InvitationRole.guardian,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ),
    ),
  );

  @override
  Future<Result<AcceptOutcome>> accept({
    String? secret,
    String? invitationId,
    required String displayName,
    String? colorHex,
    required String deviceLabel,
  }) async => const Ok(
    Accepted(
      householdId: 'h1',
      profileId: 'p-invited',
      deviceId: 'demo-device',
    ),
  );
}

/// The demo's kept invitation, in memory.
class DemoInvitationStore implements InvitationStore {
  StoredInvitation? _value;

  @override
  Future<StoredInvitation?> read() async => _value;

  @override
  Future<void> write(StoredInvitation invitation) async => _value = invitation;

  @override
  Future<void> clear() async => _value = null;
}
