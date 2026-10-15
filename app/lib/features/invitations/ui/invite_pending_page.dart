import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

/// H0 "Einladung wartet" (specs/20, J1): an invitation names this account's confirmed email,
/// so it is offered before H1. "Beitreten" leads to the join confirmation; "Eigene Familie
/// anlegen" is H1 after all, which avoids a second, empty household for the same person.
class InvitePendingPage extends ConsumerWidget {
  const InvitePendingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionStateProvider).value;
    final pending = switch (session) {
      NeedsHousehold(:final account) => account.pendingInvitations,
      _ => const <PendingInvitation>[],
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space6),
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: Tokens.space4),
                for (final invitation in pending) ...[
                  Text(
                    invitation.inviterFirstName == null
                        ? l10n.inviteBannerNoInviter(invitation.householdName)
                        : l10n.inviteBanner(
                            invitation.inviterFirstName!,
                            invitation.householdName,
                          ),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Tokens.space2),
                  Text(
                    invitation.role == InvitationRole.guardian
                        ? l10n.inviteRoleLineGuardian
                        : l10n.inviteRoleLineMember,
                  ),
                  const SizedBox(height: Tokens.space4),
                  FilledButton(
                    key: ValueKey('join-${invitation.id}'),
                    onPressed: () =>
                        context.go(Routes.joinInvite, extra: invitation),
                    child: Text(l10n.inviteJoin),
                  ),
                  const SizedBox(height: Tokens.space6),
                ],
                OutlinedButton(
                  onPressed: () => context.go(Routes.newFamily),
                  child: Text(l10n.inviteNewFamilyInstead),
                ),
                const SizedBox(height: Tokens.space4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () =>
                        ref.read(identityRepositoryProvider).signOut(),
                    child: Text(l10n.householdNewSignOut),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
