import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/invitations/application/invitation_providers.dart';
import 'package:wuselwall/features/invitations/ui/invite_flow.dart';

/// Under Mitglieder: the household's open invitations, with "Erneut teilen" and
/// "Zurückziehen" below each one for a guardian on a personal phone.
class OpenInvitationRows extends ConsumerWidget {
  const OpenInvitationRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final open = (ref.watch(openInvitationsProvider).value ?? const [])
        .where((i) => i.isOpen)
        .toList();
    if (open.isEmpty) return const SizedBox.shrink();
    final canInvite = ref.watch(canInviteProvider);
    return Column(
      children: [
        for (final invitation in open)
          ListTile(
            key: ValueKey('open-invitation-${invitation.id}'),
            leading: const Icon(Icons.mark_email_unread_outlined),
            title: Text(invitation.profileName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inviteOpenUntil(
                    inviteDate(context, invitation.expiresAt),
                  ),
                ),
                if (canInvite)
                  Wrap(
                    spacing: Tokens.space1,
                    children: [
                      TextButton(
                        onPressed: () =>
                            reshareInvitation(context, ref, invitation),
                        child: Text(l10n.inviteShareAgain),
                      ),
                      TextButton(
                        onPressed: () =>
                            withdrawInvitation(context, ref, invitation),
                        child: Text(l10n.inviteWithdraw),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Erwachsene Person einladen": creates the person on the way (guardians only).
class InviteAdultTile extends ConsumerWidget {
  const InviteAdultTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canInviteProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ListTile(
      key: const ValueKey('invite-adult'),
      leading: const Icon(Icons.person_add_alt_1),
      title: Text(l10n.inviteAdultTitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => inviteAdultFlow(context, ref),
    );
  }
}

/// "Einladen" on an adult of the household who has no account and no open invitation.
class InviteMemberButton extends ConsumerWidget {
  const InviteMemberButton({required this.member, super.key});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (member.isChild || member.hasAccount || !ref.watch(canInviteProvider)) {
      return const SizedBox.shrink();
    }
    final invited = (ref.watch(openInvitationsProvider).value ?? const []).any(
      (i) => i.isOpen && i.profileId == member.id,
    );
    if (invited) return const SizedBox.shrink();
    return TextButton(
      key: ValueKey('invite-member-${member.id}'),
      onPressed: () => inviteAdultFlow(context, ref, member: member),
      child: Text(context.l10n.inviteInviteAction),
    );
  }
}
