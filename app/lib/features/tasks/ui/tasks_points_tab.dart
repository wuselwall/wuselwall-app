import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';

/// Each member's balance and their ledger, newest first. There is no ranking and no
/// comparison between people here: a balance is shown only for the person it belongs to.
class TasksPointsTab extends ConsumerWidget {
  const TasksPointsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(pointBalancesProvider);
    final ledger = ref.watch(pointLedgerProvider);
    final members = ref.watch(membersProvider);
    return AsyncValueView<Map<String, int>>(
      value: balances,
      onRetry: () => ref.invalidate(pointBalancesProvider),
      data: (map) => AsyncValueView<List<PointTransaction>>(
        value: ledger,
        onRetry: () => ref.invalidate(pointLedgerProvider),
        data: (rows) => AsyncValueView<List<Member>>(
          value: members,
          data: (list) => ListView(
            padding: const EdgeInsets.all(Tokens.space4),
            children: [
              for (final m in list.where((m) => m.active))
                _MemberPoints(
                  member: m,
                  balance: map[m.id] ?? 0,
                  rows: [
                    for (final r in rows)
                      if (r.profileId == m.id) r,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberPoints extends ConsumerWidget {
  const _MemberPoints({
    required this.member,
    required this.balance,
    required this.rows,
  });

  final Member member;
  final int balance;
  final List<PointTransaction> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final shown = rows.take(20).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TaskAvatar(name: member.displayName, color: member.color),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Text(
                    member.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PointsCoin(points: balance, fontSize: 20),
                if (member.active)
                  IconButton(
                    tooltip: l10n.tasksAdjust,
                    icon: const Icon(Icons.tune),
                    onPressed: () => _adjust(context, ref),
                  ),
              ],
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space2),
                child: Text(l10n.tasksNoLedger),
              )
            else
              for (final r in shown) _LedgerRow(row: r),
          ],
        ),
      ),
    );
  }

  Future<void> _adjust(BuildContext context, WidgetRef ref) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final change = await showDialog<({int amount, String note})>(
      context: context,
      builder: (_) => _AdjustDialog(name: member.displayName),
    );
    if (change == null || !context.mounted) return;
    final result = await ref
        .read(tasksRepositoryProvider)
        .adjustPoints(
          actor: ref.read(actingProfileProvider),
          profileId: member.id,
          amount: change.amount,
          note: change.note,
        );
    invalidateTasks(ref.invalidate);
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.row});

  final PointTransaction row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final when = row.occurredAt.toLocal();
    final time = TimeOfDay.fromDateTime(when);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_reason(l10n, row.reason)),
                Text(
                  [
                    '${context.dayMonth(when)} ${context.time(time)}',
                    if (row.note != null) row.note!,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.ww.ink2),
                ),
              ],
            ),
          ),
          PointsCoin(points: row.amount, fontSize: 14, signed: true),
        ],
      ),
    );
  }

  String _reason(AppLocalizations l10n, LedgerReason r) => switch (r) {
    LedgerReason.task =>
      row.sourceType == 'task_undo'
          ? l10n.tasksLedgerUndo
          : l10n.tasksLedgerTask,
    LedgerReason.redemption => l10n.tasksLedgerRedemption,
    LedgerReason.adjustment => l10n.tasksLedgerAdjustment,
    LedgerReason.badge => l10n.tasksLedgerBadge,
    LedgerReason.bonus => l10n.tasksLedgerBonus,
  };
}

/// A guardian's correction: a signed amount and the reason, which is required.
class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.name});

  final String name;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _amountError;
  String? _noteError;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final amount = int.tryParse(_amount.text.trim());
    final note = _note.text.trim();
    setState(() {
      _amountError = (amount == null || amount == 0)
          ? l10n.tasksAmountInvalid
          : null;
      _noteError = note.isEmpty ? l10n.tasksReasonRequired : null;
    });
    if (_amountError != null || _noteError != null) return;
    Navigator.pop(context, (amount: amount!, note: note));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.tasksAdjustTitle(widget.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(
              labelText: l10n.tasksFieldAmount,
              errorText: _amountError,
            ),
          ),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: l10n.tasksFieldReason,
              errorText: _noteError,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
