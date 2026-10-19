import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/tasks/application/task_actions.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';

/// Today's chores of the whole family, grouped by member in household order. Anyone
/// can tick a chore as the acting profile; the open-for-anyone ones sit at the end.
class TasksTodayTab extends ConsumerWidget {
  const TasksTodayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);
    final tasks = ref.watch(tasksTodayProvider);
    final streaks = ref.watch(streaksProvider).value ?? const <Streak>[];
    final noChores = ref.watch(taskDefinitionsProvider).value?.isEmpty ?? false;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tasksTodayProvider),
      child: AsyncValueView<List<Member>>(
        value: members,
        data: (list) => AsyncValueView<List<TaskInstance>>(
          value: tasks,
          onRetry: () => ref.invalidate(tasksTodayProvider),
          data: (items) => _Groups(
            members: list.where((m) => m.active).toList(),
            items: items,
            streaks: streaks,
            noChores: noChores,
          ),
        ),
      ),
    );
  }
}

class _Groups extends StatelessWidget {
  const _Groups({
    required this.members,
    required this.items,
    required this.streaks,
    required this.noChores,
  });

  final List<Member> members;
  final List<TaskInstance> items;
  final List<Streak> streaks;

  /// The household has no chores at all, so the empty day leads to the Chores tab.
  final bool noChores;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (items.isEmpty) {
      final tabs = DefaultTabController.maybeOf(context);
      return EmptyView(
        message: l10n.tasksNothingToday,
        actions: [
          if (noChores && tabs != null)
            FilledButton.icon(
              // The Chores tab, where the starter pack and the editor are.
              onPressed: () => tabs.animateTo(2),
              icon: const Icon(Icons.add),
              label: Text(l10n.tasksNewChore),
            ),
        ],
      );
    }
    final children = <Widget>[];
    for (final m in members) {
      final mine = items.where((t) => t.assignedProfileId == m.id).toList();
      if (mine.isEmpty) continue;
      children
        ..add(_GroupHeader(member: m))
        ..addAll([
          for (final t in mine)
            _TaskTile(
              task: t,
              streak: streakOf(streaks, t.assignedProfileId, t.definitionId),
            ),
        ]);
    }
    final anyone = items.where((t) => t.assignedProfileId == null).toList();
    if (anyone.isNotEmpty) {
      children
        ..add(_GroupHeader(member: null))
        ..addAll([for (final t in anyone) _TaskTile(task: t, streak: null)]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space2,
        Tokens.space4,
        Tokens.space6,
      ),
      children: children,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.member});

  final Member? member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = member;
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space4, bottom: Tokens.space2),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            if (m != null)
              // The visible name below is the heading; the avatar repeats it.
              ExcludeSemantics(
                child: TaskAvatar(
                  name: m.displayName,
                  color: m.color,
                  size: 32,
                ),
              )
            else
              Icon(
                Icons.people_alt_outlined,
                color: theme.colorScheme.onSurface,
              ),
            const SizedBox(width: Tokens.space2),
            Text(
              m?.displayName ?? context.l10n.tasksOpenForAnyone,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.streak});

  final TaskInstance task;
  final Streak? streak;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ww = context.ww;
    final ticked = task.isTicked;
    final muted = theme.colorScheme.onSurfaceVariant;
    final facts = [
      taskKindLabel(context, task.kind),
      if (task.awaitsApproval) l10n.tasksWaitingApproval,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: Tokens.space1),
      child: ListTile(
        minVerticalPadding: Tokens.space2,
        leading: TaskGlyph(iconKey: task.iconKey),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: ticked ? TextDecoration.lineThrough : null,
            color: ticked ? muted : null,
          ),
        ),
        subtitle: Wrap(
          spacing: Tokens.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (task.points > 0) PointsCoin(points: task.points, fontSize: 14),
            Text(facts),
            if (streak != null)
              StreakBadge(
                days: streak!.currentLength,
                style: TextStyle(color: ww.ink2),
              ),
          ],
        ),
        trailing: IconButton(
          tooltip: ticked ? l10n.tasksDone : l10n.tasksActionTick,
          iconSize: 30,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Icon(
            ticked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: ticked ? ww.success : theme.colorScheme.onSurface,
          ),
          onPressed: ticked
              ? null
              : () => unawaited(
                  tickTask(context, ProviderScope.containerOf(context), task),
                ),
        ),
      ),
    );
  }
}
