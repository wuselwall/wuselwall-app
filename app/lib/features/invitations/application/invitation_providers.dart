import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

/// Hands a text to the platform's share sheet. A provider, so tests do not reach the platform.
typedef InviteSharer = Future<void> Function(String text);

final inviteSharerProvider = Provider<InviteSharer>(
  (ref) =>
      (text) async => SharePlus.instance.share(ShareParams(text: text)),
);

/// The household's open invitations (Mitglieder), refetched on demand.
final openInvitationsProvider =
    FutureProvider.autoDispose<List<OpenInvitation>>((ref) async {
      ref.watch(deviceKeyProvider);
      return (await ref.watch(invitationRepositoryProvider).open()).unwrap();
    });

/// The household's name, for the share message.
final householdNameProvider = FutureProvider.autoDispose<String>((ref) async {
  ref.watch(deviceKeyProvider);
  return (await ref.watch(invitationRepositoryProvider).householdName())
      .unwrap();
});

/// The invitation kept on this phone, if any.
final storedInvitationProvider = FutureProvider.autoDispose<StoredInvitation?>(
  (ref) => ref.watch(invitationStoreProvider).read(),
);

/// Whether this phone may invite people: a guardian on their own personal phone (specs/20).
/// The server decides in the end; this hides the actions it would refuse.
final canInviteProvider = Provider<bool>((ref) {
  final device = ref.watch(deviceProvider).value;
  if (device?.deviceClass != DeviceClass.personal) return false;
  final acting = ref.watch(actingProfileProvider);
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  return members.any((m) => m.id == acting && m.isGuardian);
});
