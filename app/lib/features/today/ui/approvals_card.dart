import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/application/tasks_tab.dart';

/// What waits for the acting guardian (specs/16 step 10.5, Q47): "2 Aufgaben zu prüfen ·
/// 1 Belohnungswunsch", one card that opens Aufgaben → Freigaben. Without push this is
/// how a child's request reaches a parent. It has no "Gesehen": it goes once the last
/// request is decided, and members never see it.
class ApprovalsCard extends ConsumerWidget {
  const ApprovalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(guardianApprovalsProvider);
    if (pending.total == 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final counts = [
      if (pending.checks > 0) l10n.todayApprovalsChecks(pending.checks),
      if (pending.requests > 0) l10n.todayApprovalsRequests(pending.requests),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          Icons.fact_check_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          l10n.todayApprovalsTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(counts.join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ref.read(tasksTabProvider.notifier).select(TasksTab.approvals);
          ref.read(homeTabProvider.notifier).select(HomeTab.tasks);
        },
      ),
    );
  }
}
