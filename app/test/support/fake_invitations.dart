import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

/// An invitation that is open for a week from now.
OpenInvitation openInvitation({
  String id = 'inv-1',
  String profileId = 'p-sabine',
  String profileName = 'Sabine',
  InvitationRole role = InvitationRole.guardian,
  String? email,
}) => OpenInvitation(
  id: id,
  profileId: profileId,
  profileName: profileName,
  role: role,
  email: email,
  expiresAt: DateTime.now().add(const Duration(days: 7)),
);

/// The invitation repository in memory. Records what the screens asked for.
class FakeInvitationRepository implements InvitationRepository {
  FakeInvitationRepository({
    List<OpenInvitation>? open,
    this.household = 'Familie Huser',
    this.previewResult,
    this.acceptResult,
    this.createResult,
  }) : openList = open ?? [];

  final String household;
  final List<OpenInvitation> openList;

  /// What `preview` answers; a valid invitation from Papa for Sabine when unset.
  Result<PreviewOutcome>? previewResult;

  /// What `accept` answers; joined when unset.
  Result<AcceptOutcome>? acceptResult;

  /// What `create` answers; a fixed token and code when unset.
  Result<CreatedInvitation>? createResult;

  final created =
      <
        ({
          String? profileId,
          String? displayName,
          InvitationRole role,
          String? email,
        })
      >[];
  final revoked = <String>[];
  final previews = <String>[];
  final accepted =
      <
        ({
          String? secret,
          String? invitationId,
          String displayName,
          String? colorHex,
          String deviceLabel,
        })
      >[];

  @override
  Future<Result<CreatedInvitation>> create({
    String? profileId,
    String? displayName,
    required InvitationRole role,
    String? email,
  }) async {
    created.add((
      profileId: profileId,
      displayName: displayName,
      role: role,
      email: email,
    ));
    return createResult ??
        Ok(
          CreatedInvitation(
            id: 'inv-new-${created.length}',
            profileId: profileId ?? 'p-new',
            token: '0123456789abcdef0123456789abcdef',
            code: 'K7QM3XRP',
            expiresAt: DateTime.now().add(const Duration(days: 7)),
          ),
        );
  }

  @override
  Future<Result<void>> revoke(String id) async {
    revoked.add(id);
    openList.removeWhere((i) => i.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<List<OpenInvitation>>> open() async => Ok([...openList]);

  @override
  Future<Result<String>> householdName() async => Ok(household);

  @override
  Future<Result<PreviewOutcome>> preview(String secret) async {
    previews.add(secret);
    return previewResult ??
        Ok(
          PreviewValid(
            InvitationPreview(
              householdName: household,
              inviterFirstName: 'Papa',
              profileName: 'Sabine',
              role: InvitationRole.guardian,
              expiresAt: DateTime.now().add(const Duration(days: 7)),
            ),
          ),
        );
  }

  @override
  Future<Result<AcceptOutcome>> accept({
    String? secret,
    String? invitationId,
    required String displayName,
    String? colorHex,
    required String deviceLabel,
  }) async {
    accepted.add((
      secret: secret,
      invitationId: invitationId,
      displayName: displayName,
      colorHex: colorHex,
      deviceLabel: deviceLabel,
    ));
    return acceptResult ??
        const Ok(
          Accepted(
            householdId: 'h1',
            profileId: 'p-sabine',
            deviceId: 'd-sabine',
          ),
        );
  }
}

/// A refusal with no further detail, for the screens that map failures.
Err<T> refused<T>(String code) => Err(PermissionFailure(code: code));

/// The invitation kept on the phone, in memory.
class MemoryInvitationStore implements InvitationStore {
  MemoryInvitationStore([this.value]);

  StoredInvitation? value;

  @override
  Future<StoredInvitation?> read() async => value;

  @override
  Future<void> write(StoredInvitation invitation) async => value = invitation;

  @override
  Future<void> clear() async => value = null;
}
