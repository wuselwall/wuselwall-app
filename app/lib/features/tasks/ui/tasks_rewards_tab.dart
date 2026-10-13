import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/tasks/application/task_defaults.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/reward_editor.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';

/// The reward catalogue and the redemption history. A member asks for a reward as the
/// acting profile; a guardian approves it in Freigaben and marks it handed over here.
class TasksRewardsTab extends ConsumerWidget {
  const TasksRewardsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(rewardsProvider);
    return AsyncValueView<List<Reward>>(
      value: rewards,
      onRetry: () => ref.invalidate(rewardsProvider),
      data: (list) => ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.tasksNewReward),
            ),
          ),
          const SizedBox(height: Tokens.space2),
          if (list.isEmpty)
            Text(context.l10n.tasksNoRewards)
          else
            for (final r in list) _RewardTile(reward: r),
          const SizedBox(height: Tokens.space6),
          const _History(),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, {Reward? existing}) =>
      openRewardEditor(context, ref, existing: existing);
}

/// Opens the reward editor with the household's defaults.
Future<void> openRewardEditor(
  BuildContext context,
  WidgetRef ref, {
  Reward? existing,
}) async {
  final defaults = await ref.read(taskDefaultsProvider.future);
  if (!context.mounted) return;
  await showRewardEditor(context, defaults: defaults, existing: existing);
}

class _RewardTile extends ConsumerWidget {
  const _RewardTile({required this.reward});

  final Reward reward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final balances = ref.watch(pointBalancesProvider).value ?? const {};
    final actor = ref.watch(actingProfileProvider);
    final balance = actor == null ? null : balances[actor];
    final short = balance == null ? 0 : reward.costPoints - balance;
    final notes = [
      if (reward.soldOut) l10n.tasksSoldOut,
      if (!reward.soldOut && short > 0) l10n.tasksMissingPoints(short),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space2),
      child: ListTile(
        onTap: () => openRewardEditor(context, ref, existing: reward),
        leading: TaskGlyph(iconKey: reward.iconKey),
        title: Text(reward.title),
        subtitle: notes.isEmpty ? null : Text(notes.join(' · ')),
        trailing: Wrap(
          spacing: Tokens.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PointsCoin(points: reward.costPoints, fontSize: 14),
            OutlinedButton(
              onPressed: reward.soldOut
                  ? null
                  : () => _ask(context, ref, reward),
              child: Text(l10n.tasksAskForReward),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ask(BuildContext context, WidgetRef ref, Reward reward) async {
    final l10n = context.l10n;
    final actor = ref.read(actingProfileProvider);
    if (actor == null) {
      context.showMessage(l10n.actingWho);
      return;
    }
    final result = await ref
        .read(tasksRepositoryProvider)
        .requestReward(actor: actor, rewardId: reward.id);
    invalidateTasks(ref.invalidate);
    if (!context.mounted) return;
    switch (result) {
      case Ok(:final value):
        context.showMessage(
          value == RedemptionStatus.approved
              ? l10n.tasksRedeemed
              : l10n.tasksRequestSent,
        );
      case Err(:final failure):
        context.showFailure(failure);
    }
  }
}

/// Redemptions, newest first, with the step each one is at. A guardian hands approved
/// rewards over here (`reward_fulfil`) after the PIN gate.
class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final redemptions = ref.watch(redemptionsProvider);
    final rewards = ref.watch(rewardsProvider).value ?? const <Reward>[];
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    return AsyncValueView<List<RewardRedemption>>(
      value: redemptions,
      onRetry: () => ref.invalidate(redemptionsProvider),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tasksHistory,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Tokens.space2),
          if (list.isEmpty) Text(l10n.tasksNoHistory),
          for (final r in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                rewards.where((w) => w.id == r.rewardId).firstOrNull?.title ??
                    '?',
              ),
              subtitle: Text(
                '${members.where((m) => m.id == r.profileId).firstOrNull?.displayName ?? '?'}'
                ' · ${context.dayMonth(r.requestedAt)}'
                ' · ${_status(l10n, r.status)}',
              ),
              trailing: r.status == RedemptionStatus.approved
                  ? TextButton(
                      onPressed: () => _fulfil(context, ref, r),
                      child: Text(l10n.tasksHandOver),
                    )
                  : PointsCoin(points: r.costPoints, fontSize: 14),
            ),
        ],
      ),
    );
  }

  String _status(AppLocalizations l10n, RedemptionStatus s) => switch (s) {
    RedemptionStatus.requested => l10n.tasksRedemptionRequested,
    RedemptionStatus.approved => l10n.tasksRedemptionApproved,
    RedemptionStatus.declined => l10n.tasksRedemptionDeclined,
    RedemptionStatus.fulfilled => l10n.tasksRedemptionFulfilled,
  };

  Future<void> _fulfil(
    BuildContext context,
    WidgetRef ref,
    RewardRedemption redemption,
  ) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final result = await ref
        .read(tasksRepositoryProvider)
        .fulfilReward(
          actor: ref.read(actingProfileProvider),
          redemptionId: redemption.id,
        );
    invalidateTasks(ref.invalidate);
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }
}
