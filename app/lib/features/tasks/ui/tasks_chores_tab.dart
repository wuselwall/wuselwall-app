import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/tasks/application/task_defaults.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_editor.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';

/// Chore admin (specs/06): every active definition with its kind, rhythm and people,
/// and the editor for each. An empty household is offered the starter pack instead.
class TasksChoresTab extends ConsumerWidget {
  const TasksChoresTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definitions = ref.watch(taskDefinitionsProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    return AsyncValueView<List<TaskDefinition>>(
      value: definitions,
      onRetry: () => ref.invalidate(taskDefinitionsProvider),
      data: (list) {
        final l10n = context.l10n;
        if (list.isEmpty) {
          return _Starter(onNew: () => _open(context, ref, members));
        }
        return ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: () => _open(context, ref, members),
                icon: const Icon(Icons.add),
                label: Text(l10n.tasksNewChore),
              ),
            ),
            const SizedBox(height: Tokens.space2),
            for (final d in list)
              _DefinitionTile(
                definition: d,
                members: members,
                onTap: () => _open(context, ref, members, existing: d),
              ),
          ],
        );
      },
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    List<Member> members, {
    TaskDefinition? existing,
  }) async {
    final defaults = await ref.read(taskDefaultsProvider.future);
    if (!context.mounted) return;
    await showTaskEditor(
      context,
      members: members,
      defaults: defaults,
      existing: existing,
    );
  }
}

class _DefinitionTile extends StatelessWidget {
  const _DefinitionTile({
    required this.definition,
    required this.members,
    required this.onTap,
  });

  final TaskDefinition definition;
  final List<Member> members;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = definition;
    final who = switch (d.assignment) {
      TaskAssignment.open =>
        d.assigneeIds.isEmpty
            ? l10n.tasksWhoOpen
            : _names(members, d.assigneeIds),
      _ => _names(members, d.assigneeIds),
    };
    final rhythm = taskRepeatOf(d.rrule).repeat;
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space2),
      child: ListTile(
        onTap: onTap,
        leading: TaskGlyph(iconKey: d.iconKey),
        title: Text(d.title),
        subtitle: Text(
          [
            taskKindLabel(context, d.kind),
            _rhythmLabel(l10n, rhythm),
            who,
            if (d.requiresVerification) l10n.tasksFieldVerification,
          ].join(' · '),
        ),
        trailing: PointsCoin(points: d.points, fontSize: 14),
      ),
    );
  }

  String _names(List<Member> members, List<String> ids) => [
    for (final id in ids)
      if (members.where((m) => m.id == id).firstOrNull case final m?)
        m.displayName,
  ].join(', ');

  String _rhythmLabel(AppLocalizations l10n, TaskRepeat r) => switch (r) {
    TaskRepeat.once => l10n.tasksRepeatOnce,
    TaskRepeat.daily => l10n.tasksRepeatDaily,
    TaskRepeat.weekdays => l10n.tasksRepeatWeekdays,
    TaskRepeat.weekly => l10n.tasksRepeatWeekly,
    TaskRepeat.biweekly => l10n.tasksRepeatBiweekly,
    TaskRepeat.monthly => l10n.tasksRepeatMonthly,
  };
}

/// Offers the starter pack (specs/21) to a household without chores, next to a first
/// chore of its own. The server skips the chores whose pool would be empty, so it is
/// safe for any family.
class _Starter extends ConsumerWidget {
  const _Starter({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return EmptyView(
      title: l10n.tasksNoChores,
      message: l10n.tasksStarterHelp,
      actions: [
        FilledButton(
          onPressed: () => _seed(context, ref),
          child: Text(l10n.tasksStarterAdd),
        ),
        OutlinedButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add),
          label: Text(l10n.tasksNewChore),
        ),
      ],
    );
  }

  Future<void> _seed(BuildContext context, WidgetRef ref) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final result = await ref
        .read(tasksRepositoryProvider)
        .seedStarter(actor: ref.read(actingProfileProvider));
    invalidateTasks(ref.invalidate);
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        context.showMessage(context.l10n.tasksStarterDone);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }
}
