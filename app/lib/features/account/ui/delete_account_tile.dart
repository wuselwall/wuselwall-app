import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/account/application/account_admin_providers.dart';
import 'package:wuselwall/features/account/ui/reauth_dialogs.dart';
import 'package:wuselwall/features/household/application/household_leave_providers.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// "Konto löschen" in Einstellungen → Konto (specs/20 J6). The account, its sign-in methods and
/// its devices go; the profile stays in the family. Disabled, with the reason, for the last
/// guardian with an account. A stale sign-in is renewed first (the server asks for a sign-in
/// of at most five minutes, and the second factor where the account has one), then the
/// deletion is retried once.
class DeleteAccountTile extends ConsumerStatefulWidget {
  const DeleteAccountTile({super.key});

  @override
  ConsumerState<DeleteAccountTile> createState() => _DeleteAccountTileState();
}

class _DeleteAccountTileState extends ConsumerState<DeleteAccountTile> {
  var _busy = false;

  Future<void> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountDeleteDialogTitle),
        content: Text(l10n.accountDeleteDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('delete-account-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.accountDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final repo = ref.read(accountAdminRepositoryProvider);
    var result = await repo.deleteAccount();
    if (!mounted) return;
    if (result case Err(:final failure) when isStepUpFailure(failure)) {
      final renewed = await renewSignIn(
        context,
        ref,
        emailBody: l10n.accountDeleteReauthBody,
        passwordBody: l10n.accountDeleteReauthPasswordBody,
      );
      if (!mounted) return;
      if (!renewed) {
        setState(() => _busy = false);
        return;
      }
      result = await repo.deleteAccount();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    // On success the repository has signed this phone out: the router shows the front door.
    if (result case Err(:final failure)) context.showFailure(failure);
  }

  @override
  Widget build(BuildContext context) {
    // Adults on their own phone only: a child's phone has no account of its own to delete.
    final device = ref.watch(deviceProvider).value;
    if (device == null ||
        device.deviceClass != DeviceClass.personal ||
        device.register != UiRegister.adult) {
      return const SizedBox.shrink();
    }
    final account = ref.watch(myAccountProvider).value;
    if (account == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final blocked = account.leaveBlocked != null;
    return ListTile(
      key: const ValueKey('delete-account'),
      leading: Icon(
        Icons.person_remove_outlined,
        color: theme.colorScheme.error,
      ),
      title: Text(
        l10n.accountDeleteTile,
        style: TextStyle(color: theme.colorScheme.error),
      ),
      subtitle: Text(
        blocked ? l10n.accountDeleteBlocked : l10n.accountDeleteExplain,
      ),
      enabled: !blocked && !_busy,
      onTap: blocked || _busy ? null : _delete,
    );
  }
}
