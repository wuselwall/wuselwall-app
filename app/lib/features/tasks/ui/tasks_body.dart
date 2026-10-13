import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/ui/tasks_approvals_tab.dart';
import 'package:wuselwall/features/tasks/ui/tasks_chores_tab.dart';
import 'package:wuselwall/features/tasks/ui/tasks_points_tab.dart';
import 'package:wuselwall/features/tasks/ui/tasks_rewards_tab.dart';
import 'package:wuselwall/features/tasks/ui/tasks_today_tab.dart';

/// The five segments of the adult tasks screen. Freigaben carries the count of things
/// waiting for a guardian. The tab bar scrolls, so five labels fit a 390 px phone.
class TasksBody extends ConsumerWidget {
  const TasksBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final approvals = ref.watch(approvalCountProvider);
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.tasksTabToday),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (approvals > 0)
                      Badge.count(
                        count: approvals,
                        child: Text(l10n.tasksTabApprovals),
                      )
                    else
                      Text(l10n.tasksTabApprovals),
                  ],
                ),
              ),
              Tab(text: l10n.tasksTabChores),
              Tab(text: l10n.tasksTabRewards),
              Tab(text: l10n.tasksTabPoints),
            ],
          ),
          const Divider(height: 1),
          const Expanded(
            child: TabBarView(
              children: [
                TasksTodayTab(),
                TasksApprovalsTab(),
                TasksChoresTab(),
                TasksRewardsTab(),
                TasksPointsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
