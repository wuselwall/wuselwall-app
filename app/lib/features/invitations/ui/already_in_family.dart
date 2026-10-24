import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/household/application/household_leave_providers.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/household/ui/leave_family_tiles.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

/// An invitation link opened on a device that already belongs to a family (specs/20, J2: one
/// household per account). The invitation is previewed, then [showAlreadyInFamily] says so.
Future<void> invitationOpenedWhileInFamily(
  BuildContext context,
  WidgetRef ref,
  String secret,
) async {
  final l10n = context.l10n;
  final checked = await ref.read(invitationRepositoryProvider).preview(secret);
  if (!context.mounted) return;
  StoredInvitation? invitation;
  switch (checked) {
    case Ok(value: PreviewValid(:final preview)):
      invitation = StoredInvitation.fromPreview(secret, preview);
    case Ok(value: PreviewRefused(:final reason)):
      // Nothing to join: leaving would gain nothing.
      context.showMessage(
        reason == 'rate_limited' ? l10n.inviteRateLimited : l10n.inviteNoLonger,
      );
      return;
    case Err():
      // Offline or refused for another reason: the family is still named.
      invitation = null;
  }
  await showAlreadyInFamily(context, ref, invitation: invitation);
}

/// "Du bist schon in Familie X" with the way to leave it (specs/20, J2), never leaving by
/// itself. [invitation] is what the preview named, null when it could not be read. When the
/// person leaves, the invitation is kept on this phone first, so the join confirmation comes
/// next. [kept] says the invitation is already kept (it came through the sign-in); it is
/// forgotten unless the person leaves.
Future<void> showAlreadyInFamily(
  BuildContext context,
  WidgetRef ref, {
  StoredInvitation? invitation,
  bool kept = false,
}) async {
  final store = ref.read(invitationStoreProvider);
  Account? account;
  try {
    account = await ref.read(myAccountProvider.future);
  } on Object {
    account = null;
  }
  // The router may be replacing the page below (the splash after a sign-in); a dialog shown
  // before that frame would be removed with it.
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return;
  final device = ref.read(deviceProvider).value;
  final current = account?.householdName;
  List<Member> members;
  try {
    members = await ref.read(membersProvider.future);
  } on Object {
    members = const [];
  }
  if (!context.mounted) return;
  final same =
      invitation != null &&
      current != null &&
      _sameFamily(invitation, current, members);

  final leave = await showDialog<bool>(
    context: context,
    builder: (_) => _AlreadyInFamilyDialog(
      current: current,
      invitation: invitation,
      same: same,
      onOwnPhone: canLeaveFamilyHere(device),
      leaveBlocked: account?.leaveBlocked != null,
    ),
  );
  final profileId = device?.profileId;
  if (leave != true || profileId == null || !context.mounted) {
    if (kept) await store.clear();
    return;
  }
  final left = await confirmAndLeaveFamily(
    context,
    ref,
    profileId: profileId,
    // Kept before the leave, so the session that follows finds it (the join confirmation).
    beforeLeave: invitation == null || kept
        ? null
        : () => store.write(invitation),
  );
  if (!left && invitation != null) await store.clear();
}

/// The preview names a household only by its name (no id leaves the server for a stranger).
/// Family names repeat (they start from a surname), so the same name counts as this family
/// only when the inviter is also one of its guardians; without an inviter the name decides.
bool _sameFamily(
  StoredInvitation invitation,
  String current,
  List<Member> members,
) {
  if (!_sameName(invitation.householdName, current)) return false;
  final inviter = invitation.inviterFirstName;
  if (inviter == null) return true;
  return members.any(
    (m) =>
        m.isGuardian &&
        _sameName(m.displayName.trim().split(' ').first, inviter),
  );
}

bool _sameName(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

class _AlreadyInFamilyDialog extends StatelessWidget {
  const _AlreadyInFamilyDialog({
    required this.current,
    required this.invitation,
    required this.same,
    required this.onOwnPhone,
    required this.leaveBlocked,
  });

  /// The family this account is in; null when it could not be read.
  final String? current;
  final StoredInvitation? invitation;

  /// The invitation is for the family the account is already in.
  final bool same;
  final bool onOwnPhone;
  final bool leaveBlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final invited = invitation;
    final canLeave = !same && onOwnPhone && !leaveBlocked;
    final family = current;
    final String hint;
    if (same && family != null) {
      hint = l10n.inviteAlreadyInSame(family);
    } else if (!onOwnPhone) {
      hint = l10n.inviteAlreadyInDevice;
    } else if (leaveBlocked) {
      hint = l10n.leaveLeaveBlocked;
    } else if (invited != null) {
      hint = l10n.inviteAlreadyInLeaveHint;
    } else {
      hint = l10n.inviteAlreadyInLeaveHintUnknown;
    }
    return AlertDialog(
      key: const ValueKey('already-in-family'),
      title: Text(
        family == null
            ? l10n.leaveErrAlreadyInHousehold
            : l10n.inviteAlreadyInTitle(family),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (invited != null && !same) ...[
            Text(
              invited.inviterFirstName == null
                  ? l10n.inviteBannerNoInviter(invited.householdName)
                  : l10n.inviteBanner(
                      invited.inviterFirstName!,
                      invited.householdName,
                    ),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: Tokens.space2),
          ],
          Text(hint),
        ],
      ),
      actions: canLeave
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const ValueKey('already-in-leave'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.leaveLeaveTile),
              ),
            ]
          : [
              FilledButton(
                key: const ValueKey('already-in-close'),
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.close),
              ),
            ],
    );
  }
}
