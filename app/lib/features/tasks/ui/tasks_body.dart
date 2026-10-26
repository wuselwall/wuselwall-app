import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/edge_fade.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/application/tasks_tab.dart';
import 'package:wuselwall/features/tasks/ui/tasks_approvals_tab.dart';
import 'package:wuselwall/features/tasks/ui/tasks_chores_tab.dart';
import 'package:wuselwall/features/tasks/ui/tasks_points_tab.dart';
import 'package:wuselwall/features/tasks/ui/tasks_rewards_tab.dart';
import 'package:wuselwall/features/tasks/ui/tasks_today_tab.dart';

/// The five segments of the adult tasks screen. Freigaben carries the count of things
/// waiting for a guardian. The tab bar scrolls, so five labels fit a 390 px phone, and
/// fades at the edge while more tabs lie beyond it. The segment shown is
/// [tasksTabProvider], so Today's approvals card can open Freigaben.
class TasksBody extends ConsumerStatefulWidget {
  const TasksBody({super.key});

  @override
  ConsumerState<TasksBody> createState() => _TasksBodyState();
}

class _TasksBodyState extends ConsumerState<TasksBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: TasksTab.values.length,
    vsync: this,
    initialIndex: ref.read(tasksTabProvider).index,
  )..addListener(_remember);

  void _remember() {
    if (_tabs.indexIsChanging) return;
    ref.read(tasksTabProvider.notifier).select(TasksTab.values[_tabs.index]);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tasksTabProvider, (_, next) {
      if (_tabs.index != next.index) _tabs.animateTo(next.index);
    });
    final l10n = context.l10n;
    final approvals = ref.watch(approvalCountProvider);
    return Column(
      children: [
        // Five labels scroll on a phone: the bar fades where more tabs lie beyond
        // its edge, so "Belohnungen" half cut reads as "scroll for more".
        EdgeFade(
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.tasksTabToday),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.tasksTabApprovals),
                    if (approvals > 0) ...[
                      const SizedBox(width: Tokens.space2),
                      Badge.count(count: approvals),
                    ],
                  ],
                ),
              ),
              Tab(text: l10n.tasksTabChores),
              Tab(text: l10n.tasksTabRewards),
              Tab(text: l10n.tasksTabPoints),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              TasksTodayTab(),
              TasksApprovalsTab(),
              TasksChoresTab(),
              TasksRewardsTab(),
              TasksPointsTab(),
            ],
          ),
        ),
      ],
    );
  }
}
