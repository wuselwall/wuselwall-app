import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/household/application/household_leave_providers.dart';
import 'package:wuselwall/features/household/data/household_leave_repository.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// "Familie verlassen" in Einstellungen → Konto (specs/20 J6): an adult on their own phone
/// leaves the family. Disabled, with the reason, for the last guardian with an account.
class LeaveFamilyTile extends ConsumerStatefulWidget {
  const LeaveFamilyTile({super.key});

  @override
  ConsumerState<LeaveFamilyTile> createState() => _LeaveFamilyTileState();
}

class _LeaveFamilyTileState extends ConsumerState<LeaveFamilyTile> {
  var _busy = false;

  Future<void> _leave(String profileId) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveLeaveDialogTitle),
        content: Text(l10n.leaveLeaveDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.leaveCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.leaveLeaveConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(householdLeaveRepositoryProvider)
        .leaveFamily(profileId: profileId);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok():
        // The session is refreshed; the router takes the account to the new-family page.
        ref.invalidate(myAccountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(deviceProvider).value;
    final profileId = device?.profileId;
    if (device == null ||
        device.deviceClass != DeviceClass.personal ||
        device.register != UiRegister.adult ||
        profileId == null) {
      return const SizedBox.shrink();
    }
    final account = ref.watch(myAccountProvider).value;
    if (account == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final blocked = account.leaveBlocked != null;
    return ListTile(
      key: const ValueKey('leave-family'),
      leading: const Icon(Icons.logout),
      title: Text(l10n.leaveLeaveTile),
      subtitle: Text(blocked ? l10n.leaveLeaveBlocked : l10n.leaveLeaveExplain),
      enabled: !blocked && !_busy,
      onTap: _busy ? null : () => _leave(profileId),
    );
  }
}

/// "Familie löschen" in Einstellungen → Familie (specs/20 J6): a guardian on their own phone
/// types the family's name and deletes it. Every device signs out; the family is kept for
/// 14 days, then purged. Used inside the family section, which already gates it.
class DeleteFamilyTile extends ConsumerWidget {
  const DeleteFamilyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListTile(
      key: const ValueKey('delete-family'),
      leading: Icon(
        Icons.delete_forever_outlined,
        color: theme.colorScheme.error,
      ),
      title: Text(
        l10n.leaveDeleteTile,
        style: TextStyle(color: theme.colorScheme.error),
      ),
      subtitle: Text(l10n.leaveDeleteExplain),
      onTap: () => _start(context, ref),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final profileId = ref.read(deviceProvider).value?.profileId;
    final name = ref.read(myAccountProvider).value?.householdName;
    if (profileId == null || name == null || !context.mounted) return;

    final typed = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteFamilyDialog(familyName: name),
    );
    if (typed == null || !context.mounted) return;

    final result = await ref
        .read(householdLeaveRepositoryProvider)
        .deleteFamily(profileId: profileId, confirmName: typed);
    if (!context.mounted) return;
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok():
        // Every device is signed out on the server; this phone signs out here too.
        await ref.read(identityRepositoryProvider).signOut();
    }
  }
}

class _DeleteFamilyDialog extends StatefulWidget {
  const _DeleteFamilyDialog({required this.familyName});

  final String familyName;

  @override
  State<_DeleteFamilyDialog> createState() => _DeleteFamilyDialogState();
}

class _DeleteFamilyDialogState extends State<_DeleteFamilyDialog> {
  final _typed = TextEditingController();

  /// The same comparison the server makes: trimmed, case-insensitive.
  bool get _matches =>
      _typed.text.trim().toLowerCase() ==
      widget.familyName.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _typed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.leaveDeleteDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.leaveDeleteDialogBody),
          const SizedBox(height: Tokens.space4),
          TextField(
            key: const ValueKey('delete-family-name'),
            controller: _typed,
            decoration: InputDecoration(
              labelText: l10n.leaveDeleteNameLabel(widget.familyName),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.leaveCancel),
        ),
        FilledButton(
          key: const ValueKey('delete-family-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _matches
              ? () => Navigator.of(context).pop(_typed.text.trim())
              : null,
          child: Text(l10n.leaveDeleteConfirm),
        ),
      ],
    );
  }
}
