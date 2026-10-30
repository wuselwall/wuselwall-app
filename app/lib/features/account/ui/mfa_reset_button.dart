import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/account/application/account_admin_providers.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// "Zwei-Faktor zurücksetzen" next to a co-guardian in Mitglieder (specs/20 J4). Shown only to a
/// guardian on their own phone, for another guardian with an account who has a verified
/// authenticator. The server checks the same and audits the reset.
class MfaResetButton extends ConsumerWidget {
  const MfaResetButton({required this.member, super.key});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const hidden = SizedBox.shrink();
    if (!member.isGuardian || !member.hasAccount) return hidden;
    if (ref.watch(deviceProvider).value?.deviceClass != DeviceClass.personal) {
      return hidden;
    }
    final acting = ref.watch(actingProfileProvider);
    if (acting == null || acting == member.id) return hidden;
    final viewer = (ref.watch(membersProvider).value ?? const <Member>[])
        .where((m) => m.id == acting)
        .firstOrNull;
    if (viewer == null || !viewer.isGuardian) return hidden;

    final security = ref.watch(memberSecurityProvider).value ?? const [];
    final hasMfa = security.any((s) => s.profileId == member.id && s.hasMfa);
    if (!hasMfa) return hidden;

    // A security action, so it says so: an icon, and one line on when it is needed.
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          key: ValueKey('mfa-reset-${member.id}'),
          onPressed: () => _reset(context, ref),
          icon: const Icon(Icons.lock_reset),
          label: Text(context.l10n.mfaResetAction),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: Tokens.space3),
          child: Text(
            context.l10n.mfaResetHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mfaResetConfirmTitle),
        content: Text(l10n.mfaResetConfirmBody(member.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mfaResetConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final actor = ref.read(actingProfileProvider);
    if (actor == null) return;

    final result = await ref
        .read(accountAdminRepositoryProvider)
        .resetMfa(actorProfileId: actor, profileId: member.id);
    if (!context.mounted) return;
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok():
        ref.invalidate(memberSecurityProvider);
        context.showMessage(l10n.mfaResetDone(member.displayName));
    }
  }
}
