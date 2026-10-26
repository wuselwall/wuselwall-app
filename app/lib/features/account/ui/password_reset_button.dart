import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/account/application/account_admin_providers.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// "Passwort zurücksetzen" next to another adult in Mitglieder (specs/20, Q48). Only on a
/// server without mail, where no code by mail can replace a forgotten password: a guardian
/// on their own phone creates a one-time code and hands it over in person. The server
/// checks the same and audits it.
class PasswordResetButton extends ConsumerWidget {
  const PasswordResetButton({required this.member, super.key});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const hidden = SizedBox.shrink();
    if (ref.watch(emailCodeSignInProvider) ||
        !ref.watch(serverSupportsProvider(featurePasswordReset))) {
      return hidden;
    }
    if (member.isChild || !member.hasAccount || !member.active) return hidden;
    if (ref.watch(deviceProvider).value?.deviceClass != DeviceClass.personal) {
      return hidden;
    }
    final acting = ref.watch(actingProfileProvider);
    if (acting == null || acting == member.id) return hidden;
    final viewer = (ref.watch(membersProvider).value ?? const <Member>[])
        .where((m) => m.id == acting)
        .firstOrNull;
    if (viewer == null || !viewer.isGuardian) return hidden;

    return TextButton(
      key: ValueKey('password-reset-${member.id}'),
      onPressed: () => _reset(context, ref),
      child: Text(context.l10n.passwordResetMemberAction),
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.passwordResetConfirmTitle(member.displayName)),
        content: Text(l10n.passwordResetConfirmBody(member.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.passwordResetConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final actor = ref.read(actingProfileProvider);
    if (actor == null) return;

    final result = await ref
        .read(accountAdminRepositoryProvider)
        .createPasswordResetCode(actorProfileId: actor, profileId: member.id);
    if (!context.mounted) return;
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok(value: final code):
        await showDialog<void>(
          context: context,
          builder: (context) =>
              _CodeDialog(name: member.displayName, code: code),
        );
    }
  }
}

class _CodeDialog extends StatelessWidget {
  const _CodeDialog({required this.name, required this.code});

  final String name;
  final EnrolmentCode code;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final until = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(code.expiresAt.toLocal()));
    return AlertDialog(
      title: Text(l10n.passwordResetCodeTitle(name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            formatPairingCode(code.code),
            key: const ValueKey('password-reset-code'),
            style: theme.textTheme.displaySmall?.copyWith(letterSpacing: 4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Tokens.space4),
          Text(l10n.passwordResetCodeHint(name, until)),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
