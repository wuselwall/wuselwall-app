import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/household/data/household_leave_repository.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';

/// Shown to an account whose family was deleted and is not purged yet (specs/20 J6): a
/// guardian may restore it within the 14 days; anyone may start afresh instead.
class DeletedFamilyPage extends ConsumerStatefulWidget {
  const DeletedFamilyPage({this.account, super.key});

  /// The account the router shows this page for; null only during a rebuild.
  final Account? account;

  @override
  ConsumerState<DeletedFamilyPage> createState() => _DeletedFamilyPageState();
}

class _DeletedFamilyPageState extends ConsumerState<DeletedFamilyPage> {
  var _busy = false;

  Future<void> _run(
    Future<void> Function(HouseholdLeaveRepository repo) action,
  ) async {
    setState(() => _busy = true);
    final result = await Result.guard(
      () => action(ref.read(householdLeaveRepositoryProvider)),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(ok: (_) {}, err: context.showFailure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final deleted = widget.account?.deletedHousehold;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = deleted == null
        ? ''
        : DateFormat.yMMMMd(locale).format(deleted.purgeAfter.toLocal());

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            if (deleted != null) ...[
              Text(
                l10n.leaveDeletedTitle(deleted.name, date),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: Tokens.space4),
              Text(
                deleted.canRestore
                    ? l10n.leaveDeletedBodyGuardian
                    : l10n.leaveDeletedBodyMember,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: Tokens.space6),
              if (deleted.canRestore)
                FilledButton(
                  key: const ValueKey('deleted-restore'),
                  onPressed: _busy
                      ? null
                      : () => _run((r) => r.restoreFamily()),
                  child: Text(l10n.leaveRestore),
                ),
              const SizedBox(height: Tokens.space3),
              OutlinedButton(
                key: const ValueKey('deleted-start-afresh'),
                onPressed: _busy ? null : () => _run((r) => r.startAfresh()),
                child: Text(l10n.leaveStartAfresh),
              ),
              const SizedBox(height: Tokens.space2),
              Text(l10n.leaveStartAfreshHint, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
