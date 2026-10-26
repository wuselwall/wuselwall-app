import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/core/wusel/wusel_stage.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/tasks/application/task_actions.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';
import 'package:wuselwall/features/wusel/ui/wusel_lines.dart';

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
            StreakBadge(
              days: streak!,
              style: boardNum(26, weight: FontWeight.w800, color: mc?.onInk),
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
              // A member's chores all done: their own moment and nobody else's
              // (specs/25, specs/27 rule 2).
              if (m != null)
                _MemberDone(
                  key: ValueKey('member-done-${m.id}'),
                  done: tasks.every((t) => t.isTicked),
                  line: WuselLines.stable(
                    l10n,
                    WuselMoment.wallMemberDone,
                    seed: _seed(m.id),
                    name: m.displayName,
                  ),
                ),
              for (final t in tasks)
                // Keyed, so a tick's state stays with its chore when the list changes.
                _TaskCard(
                  key: ValueKey(t.id),
                  task: t,
                  ink: mc?.ink,
                  tint: mc?.tint,
                ),
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

/// The line over a member's column once their chores are all ticked. Wusel cheers
/// beside it for [cheerFor] when the last one is ticked while the board is open
/// (specs/25 "Where Wusel appears", kiosk): a lively Wusel comes over from the
/// header's corner and goes back after ("Wusel on the move"); one that cannot travel
/// cheers here in place. A column that opens already done, and the rest of the day,
/// show the line alone.
class _MemberDone extends StatefulWidget {
  const _MemberDone({required this.done, required this.line, super.key});

  final bool done;
  final String line;

  static const cheerFor = Duration(seconds: 4);

  @override
  State<_MemberDone> createState() => _MemberDoneState();
}

class _MemberDoneState extends State<_MemberDone> {
  Timer? _cheer;

  /// The space above the line that the travelling Wusel cheers in.
  final _spot = GlobalKey();

  /// Whether the corner Wusel is visiting: the space stays until it is home again,
  /// then folds away, so the line itself never reflows.
  bool _visit = false;

  static const _size = 80.0;

  @override
  void didUpdateWidget(_MemberDone old) {
    super.didUpdateWidget(old);
    if (widget.done && !old.done) {
      final stage = WuselStage.maybeOf(context);
      _visit = stage?.canVisit ?? false;
      if (!_visit) {
        _cheer?.cancel();
        _cheer = Timer(_MemberDone.cheerFor, () {
          if (mounted) setState(() => _cheer = null);
        });
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final trip = stage!.visit(
          _spot,
          spot: WuselSpot.inside,
          size: _size,
          stay: _MemberDone.cheerFor,
          pose: WuselPose.cheer,
        );
        if (trip == null) {
          // Out of sight (a column scrolled away): the cheer in place.
          setState(() {
            _visit = false;
            _cheer = Timer(_MemberDone.cheerFor, () {
              if (mounted) setState(() => _cheer = null);
            });
          });
          return;
        }
        unawaited(
          trip.done.then((_) {
            if (mounted) setState(() => _visit = false);
          }),
        );
      });
    } else if (!widget.done) {
      _cheer?.cancel();
      _cheer = null;
      _visit = false;
    }
  }

  @override
  void dispose() {
    _cheer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.done) return const SizedBox.shrink();
    final style = boardUi(24, weight: FontWeight.w700);
    final Widget content;
    if (_cheer != null) {
      content = WuselSays(
        line: widget.line,
        pose: WuselPose.cheer,
        size: _size,
        style: style,
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_visit) SizedBox.square(key: _spot, dimension: _size),
          Text(widget.line, style: style),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      // A zero-length AnimatedSize finishes inside its own layout and asserts:
      // under reduced motion the size simply changes.
      child: motionAllowed(context)
          ? AnimatedSize(
              duration: Tokens.motionEmphasised,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: content,
            )
          : content,
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
    final still = !motionAllowed(context);
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
class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, this.ink, this.tint, super.key});

  final TaskInstance task;
  final Color? ink;
  final Color? tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;
    // A tick shows the moment it is made, before the server confirms it.
    final ticked = isTickShown(ref.watch(pendingTicksProvider), task);
    final caption = task.awaitsApproval
        ? l10n.tasksWaitingApproval
        : (ticked ? l10n.tasksDone : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      child: BoardTap(
        label: task.title,
        radius: 14,
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
                child: _TickMark(ticked: ticked, ink: ink ?? scheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tick. When it turns on while the board is shown it pops from half size
/// ([TickPop]), which is the whole of the feedback the wall gives (specs/26
/// "Celebrations"); a chore ticked before the board opened shows its tick at rest.
class _TickMark extends StatelessWidget {
  const _TickMark({required this.ticked, required this.ink});

  final bool ticked;
  final Color ink;

  @override
  Widget build(BuildContext context) => Center(
    child: TickPop(
      ticked: ticked,
      child: Icon(
        ticked ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 44,
        color: ticked ? context.ww.success : ink,
      ),
    ),
  );
}

/// The same number for a member on one day, on every device and every run.
int _seed(String id) =>
    id.codeUnits.fold(DateTime.now().day, (sum, unit) => sum + unit);
