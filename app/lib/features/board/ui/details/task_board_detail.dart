import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/tasks/application/task_actions.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';

/// The family task board (specs/09 "Touch behaviour"): today's chores in one column per
/// member, opened from the footer's task count. Ticking a chore is one of the three
/// mutations the wall allows, and it is made as the acting profile, so the bar sits at
/// the bottom to say who is ticking. Nothing here is smaller than the kiosk's 24 px.
class TaskBoardDetailBody extends StatelessWidget {
  const TaskBoardDetailBody({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Expanded(child: _Board()),
      ActingProfileBar(),
    ],
  );
}

/// Columns are never narrower than this; a family of more members scrolls sideways.
const _minColumn = 260.0;

class _Board extends ConsumerWidget {
  const _Board();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider);
    final tasks = ref.watch(tasksTodayProvider);
    // Balances and streaks are extras of the board: when they cannot be read, the
    // columns simply show no counter, and the chores still tick.
    final balances = ref.watch(pointBalancesProvider).value;
    final streaks = ref.watch(streaksProvider).value ?? const <Streak>[];
    return AsyncValueView<List<Member>>(
      value: members,
      onRetry: () => ref.invalidate(membersProvider),
      data: (list) => AsyncValueView<List<TaskInstance>>(
        value: tasks,
        onRetry: () => ref.invalidate(tasksTodayProvider),
        data: (items) => _Columns(
          members: list.where((m) => m.active).toList(),
          items: items,
          balances: balances,
          streaks: streaks,
        ),
      ),
    );
  }
}

class _Columns extends StatelessWidget {
  const _Columns({
    required this.members,
    required this.items,
    required this.balances,
    required this.streaks,
  });

  final List<Member> members;
  final List<TaskInstance> items;
  final Map<String, int>? balances;
  final List<Streak> streaks;

  @override
  Widget build(BuildContext context) {
    final anyone = items.where((t) => t.assignedProfileId == null).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = members.length + (anyone.isEmpty ? 0 : 1);
        final fits = constraints.maxWidth / (count == 0 ? 1 : count);
        final width = fits < _minColumn ? _minColumn : null;
        final columns = [
          for (final m in members)
            _Column(
              width: width,
              member: m,
              tasks: [
                for (final t in items)
                  if (t.assignedProfileId == m.id) t,
              ],
              points: balances?[m.id],
              streak: _longestStreak(m.id),
            ),
          if (anyone.isNotEmpty)
            _Column(width: width, member: null, tasks: anyone),
        ];
        if (width == null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final c in columns) Expanded(child: c)],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: columns,
          ),
        );
      },
    );
  }

  /// The member's longest run that is still going: "🔥 12". Null when nothing is.
  int? _longestStreak(String profileId) {
    var best = 0;
    for (final s in streaks) {
      if (s.profileId == profileId && s.currentLength > best) {
        best = s.currentLength;
      }
    }
    return best == 0 ? null : best;
  }
}

/// One member's column: a header in their ink with avatar, streak and points, then
/// their chores as large cards. The open-for-anyone column has no member.
class _Column extends StatelessWidget {
  const _Column({
    required this.width,
    required this.member,
    required this.tasks,
    this.points,
    this.streak,
  });

  final double? width;
  final Member? member;
  final List<TaskInstance> tasks;
  final int? points;
  final int? streak;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final m = member;
    final mc = m == null ? null : ww.member(m.color);
    final name = m?.displayName ?? l10n.tasksOpenForAnyone;
    final header = Container(
      color: mc?.ink ?? ww.sunken,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.space3),
      constraints: const BoxConstraints(minHeight: 80),
      child: Row(
        children: [
          if (m != null)
            TaskAvatar(
              name: m.displayName,
              color: m.color,
              size: 48,
              inverted: true,
            ),
          if (m != null) const SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              name,
              style: boardUi(
                28,
                weight: FontWeight.w800,
                color: mc?.onInk ?? ww.ink2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (streak != null)
            Text(
              l10n.tasksStreakBadge(streak!),
              style: boardNum(26, weight: FontWeight.w800, color: mc?.onInk),
              maxLines: 1,
            ),
          if (points != null) ...[
            const SizedBox(width: Tokens.space2),
            _Counter(points: points!),
          ],
        ],
      ),
    );

    final body = tasks.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space3),
              child: Text(
                l10n.boardNothingMoreToday,
                textAlign: TextAlign.center,
                style: boardUi(24, color: ww.ink2),
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(Tokens.space2),
            children: [
              for (final t in tasks)
                _TaskCard(task: t, ink: mc?.ink, tint: mc?.tint),
            ],
          );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
      ],
    );
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space1),
        child: column,
      ),
    );
  }
}

/// The member's points, which count up or down as they change (reduced motion: no
/// animation).
class _Counter extends StatelessWidget {
  const _Counter({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : Tokens.motionStandard,
      switchInCurve: Curves.easeOutCubic,
      child: KeyedSubtree(
        key: ValueKey(points),
        child: PointsCoin(points: points, fontSize: 26),
      ),
    );
  }
}

/// A chore as a large card: glyph, title, what it is worth, and a tick target of
/// kiosk size. A ticked card is struck through and shows "wartet auf Freigabe" when a
/// guardian still has to check it.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, this.ink, this.tint});

  final TaskInstance task;
  final Color? ink;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;
    final ticked = task.isTicked;
    final still = MediaQuery.disableAnimationsOf(context);
    final caption = task.awaitsApproval
        ? l10n.tasksWaitingApproval
        : (ticked ? l10n.tasksDone : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      child: BoardTap(
        label: task.title,
        onTap: () {
          if (!ticked) {
            unawaited(
              tickTask(
                context,
                ProviderScope.containerOf(context),
                task,
                offerUndo: false,
              ),
            );
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.fromLTRB(
            Tokens.space3,
            Tokens.space2,
            Tokens.space2,
            Tokens.space2,
          ),
          decoration: BoxDecoration(
            color: ticked ? ww.sunken : (tint ?? ww.sunken),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ww.line),
          ),
          child: Row(
            children: [
              TaskGlyph(iconKey: task.iconKey, size: 26),
              const SizedBox(width: Tokens.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          boardUi(
                            26,
                            weight: FontWeight.w700,
                            color: ticked ? ww.ink2 : scheme.onSurface,
                          ).copyWith(
                            decoration: ticked
                                ? TextDecoration.lineThrough
                                : null,
                            decorationThickness: 2,
                          ),
                    ),
                    if (caption != null || task.points > 0)
                      Text(
                        [
                          if (task.points > 0)
                            l10n.tasksPointsCount(task.points),
                          ?caption,
                        ].join(' · '),
                        style: boardUi(24, color: ww.ink2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: 56,
                child: _TickMark(
                  key: ValueKey('${task.id}-$ticked'),
                  ticked: ticked,
                  ink: ink ?? scheme.onSurface,
                  still: still,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tick. When it turns on it grows from 40 % to full size, which is the whole of
/// the feedback the wall gives; reduced motion shows the finished tick at once.
class _TickMark extends StatelessWidget {
  const _TickMark({
    required this.ticked,
    required this.ink,
    required this.still,
    super.key,
  });

  final bool ticked;
  final Color ink;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final icon = Icon(
      ticked ? Icons.check_circle : Icons.radio_button_unchecked,
      size: 44,
      color: ticked ? ww.success : ink,
    );
    if (!ticked || still) return Center(child: icon);
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: Tokens.motionEmphasised,
        curve: Curves.easeOutCubic,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: icon,
      ),
    );
  }
}
