import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_dialogs.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';

/// What a guardian must decide: ticked chores that wait for a check, and reward
/// requests. Every decision passes the PIN gate (specs/08) before it is sent.
class TasksApprovalsTab extends ConsumerWidget {
  const TasksApprovalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks = ref.watch(pendingVerificationsProvider);
    final redemptions = ref.watch(redemptionsProvider);
    return AsyncValueView<List<TaskInstance>>(
      value: checks,
      onRetry: () => ref.invalidate(pendingVerificationsProvider),
      data: (pending) => AsyncValueView<List<RewardRedemption>>(
        value: redemptions,
        onRetry: () => ref.invalidate(redemptionsProvider),
        data: (all) {
          final requests = [
            for (final r in all)
              if (r.status == RedemptionStatus.requested) r,
          ];
          final l10n = context.l10n;
          if (pending.isEmpty && requests.isEmpty) {
            return Center(child: Text(l10n.tasksApprovalsEmpty));
          }
          final members = ref.watch(membersProvider).value ?? const <Member>[];
          final rewards = ref.watch(rewardsProvider).value ?? const <Reward>[];
          return ListView(
            padding: const EdgeInsets.all(Tokens.space4),
            children: [
              if (pending.isNotEmpty) ...[
                _Heading(l10n.tasksCheckChores),
                for (final t in pending)
                  _CheckTile(
                    task: t,
                    doneBy: _nameOf(members, t.completedByProfileId),
                  ),
              ],
              if (requests.isNotEmpty) ...[
                _Heading(l10n.tasksRewardRequests),
                for (final r in requests)
                  _RequestTile(
                    redemption: r,
                    reward: rewards
                        .where((w) => w.id == r.rewardId)
                        .firstOrNull,
                    name: _nameOf(members, r.profileId),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _nameOf(List<Member> members, String? id) =>
    members.where((m) => m.id == id).firstOrNull?.displayName ?? '?';

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Tokens.space2, bottom: Tokens.space2),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

/// Verifies a guardian's decision on a ticked chore and sends it after the PIN gate.
Future<void> _verify(
  BuildContext context,
  WidgetRef ref,
  TaskInstance task, {
  required bool approve,
}) async {
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  final result = await ref
      .read(tasksRepositoryProvider)
      .verify(
        actor: ref.read(actingProfileProvider),
        instanceId: task.id,
        approve: approve,
      );
  ref.invalidate(pendingVerificationsProvider);
  invalidateTasks(ref.invalidate);
  if (!context.mounted) return;
  if (result case Err(:final failure)) context.showFailure(failure);
}

Future<void> _decideReward(
  BuildContext context,
  WidgetRef ref,
  RewardRedemption redemption, {
  required bool approve,
}) async {
  String? note;
  if (!approve) {
    note = await askTaskNote(context, title: context.l10n.tasksDecline);
    if (note == null || !context.mounted) return;
  }
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  final result = await ref
      .read(tasksRepositoryProvider)
      .decideReward(
        actor: ref.read(actingProfileProvider),
        redemptionId: redemption.id,
        approve: approve,
        note: (note == null || note.isEmpty) ? null : note,
      );
  invalidateTasks(ref.invalidate);
  if (!context.mounted) return;
  if (result case Err(:final failure)) context.showFailure(failure);
}

class _CheckTile extends ConsumerWidget {
  const _CheckTile({required this.task, required this.doneBy});

  final TaskInstance task;
  final String doneBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space2),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TaskGlyph(iconKey: task.iconKey),
                const SizedBox(width: Tokens.space2),
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (task.points > 0)
                  PointsCoin(points: task.points, fontSize: 14),
              ],
            ),
            Text(l10n.tasksDoneBy(doneBy)),
            const SizedBox(height: Tokens.space2),
            _Decisions(
              onDecline: () => _verify(context, ref, task, approve: false),
              onApprove: () => _verify(context, ref, task, approve: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({
    required this.redemption,
    required this.reward,
    required this.name,
  });

  final RewardRedemption redemption;
  final Reward? reward;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = reward?.title ?? '?';
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space2),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.tasksRequestedBy(name, title),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                PointsCoin(points: redemption.costPoints, fontSize: 14),
              ],
            ),
            const SizedBox(height: Tokens.space2),
            _Decisions(
              onDecline: () =>
                  _decideReward(context, ref, redemption, approve: false),
              onApprove: () =>
                  _decideReward(context, ref, redemption, approve: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _Decisions extends StatelessWidget {
  const _Decisions({required this.onDecline, required this.onApprove});

  final VoidCallback onDecline;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: Tokens.space2,
      children: [
        OutlinedButton(onPressed: onDecline, child: Text(l10n.tasksDecline)),
        FilledButton(onPressed: onApprove, child: Text(l10n.tasksApprove)),
      ],
    );
  }
}
