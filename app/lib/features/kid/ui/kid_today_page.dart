import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/confetti.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';
import 'package:wuselwall/features/kid/application/kid_providers.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/rituals/ui/countdown_widgets.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';
import 'package:wuselwall/features/wusel/ui/wusel_lines.dart';

/// "Mein Tag": the acting child's day. Chores as big cards that tick with a coin flying
/// to the balance; then today's lessons, tonight's meal and today's appointments.
class KidTodayPage extends ConsumerStatefulWidget {
  const KidTodayPage({required this.member, super.key});

  final Member member;

  @override
  ConsumerState<KidTodayPage> createState() => _KidTodayPageState();
}

class _KidTodayPageState extends ConsumerState<KidTodayPage> {
  /// Anchors the coin's flight and keeps the pill's state (its count) across rebuilds.
  final _balanceKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final member = widget.member;
    final colors = context.ww.member(member.color);
    final balance = ref.watch(pointBalancesProvider).value;
    final points = kidBalanceOf(balance ?? const {}, member.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space4,
        Tokens.space4,
        Tokens.space8,
      ),
      children: [
        _KidGreeting(
          member: member,
          tint: colors.tint,
          ink: colors.ink,
          onInk: colors.onInk,
          balance: KidBalancePill(key: _balanceKey, balance: points),
        ),
        KidSectionTitle(l10n.kidTasksTitle),
        _TasksSection(actor: member.id, balanceKey: _balanceKey),
        KidCountdowns(actor: member.id),
        KidSectionTitle(l10n.kidSchoolTitle),
        _SchoolSection(actor: member.id),
        const SizedBox(height: Tokens.space4),
        _MealSection(actor: member.id),
        KidSectionTitle(l10n.kidEventsTitle),
        _EventsSection(actor: member.id),
      ],
    );
  }
}

/// The chores of the day, the acting child's and the open ones. Ticking is optimistic:
/// the tick shows at once, the coin flies when the server has credited the points, and
/// "Rückgängig" stays on screen for five seconds.
class _TasksSection extends ConsumerStatefulWidget {
  const _TasksSection({required this.actor, required this.balanceKey});

  final String actor;
  final GlobalKey balanceKey;

  @override
  ConsumerState<_TasksSection> createState() => _TasksSectionState();
}

class _TasksSectionState extends ConsumerState<_TasksSection> {
  /// Ticked by the child but not yet confirmed by the list.
  final _pending = <String>{};

  /// Wusel's line for the finished list, picked once per visit so a rebuild does not
  /// change what it says.
  String? _allDoneLine;

  /// Counts the finished lists of this visit, so Wusel cheers again for each.
  int _celebrations = 0;
  final _cardKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  bool _done(TaskInstance t) => t.isTicked || _pending.contains(t.id);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tasks = ref.watch(tasksTodayProvider);
    return AsyncValueView<List<TaskInstance>>(
      value: tasks,
      onRetry: () => ref.invalidate(tasksTodayProvider),
      data: (all) {
        final items = kidMyTasks(all, widget.actor);
        if (items.isEmpty) {
          return KidCard(
            child: Text(
              l10n.kidTasksNone,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        final open = items.where((t) => !_done(t)).length;
        return Column(
          children: [
            if (open == 0)
              KidCard(
                color: context.ww.successContainer,
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.kidTasksAllDone,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: Tokens.space2),
                        const EmojiPicture(emojiParty, size: 32),
                      ],
                    ),
                    const SizedBox(height: Tokens.space2),
                    // The last chore of the day: Wusel cheers (specs/25).
                    WuselSays(
                      line: _allDoneLine ??= WuselLines.pick(
                        l10n,
                        WuselMoment.allDone,
                      ),
                      pose: WuselPose.cheer,
                      size: 112,
                      moment: _celebrations,
                      tappable: true,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(l10n.kidTasksAllDoneBody),
                  ],
                ),
              ),
            for (final t in items)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space2),
                child: _TaskCard(
                  key: _keyFor(t.id),
                  task: t,
                  done: _done(t),
                  onTap: () => unawaited(_tick(t)),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _tick(TaskInstance task) async {
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final reduce = kidReduceMotion(context);
    final actor = widget.actor;
    final celebration = container.read(celebrationProvider);
    // Whether this tick finishes the day's list (specs/26 "Celebrations").
    final mine = kidMyTasks(
      container.read(tasksTodayProvider).value ?? const [],
      actor,
    );
    final last = mine.where((t) => !_done(t) && t.id != task.id).isEmpty;
    unawaited(celebration.cue(Cue.tick));
    setState(() => _pending.add(task.id));
    final result = await container
        .read(tasksRepositoryProvider)
        .complete(actor: actor, instanceId: task.id);
    invalidateTasks(container.invalidate);
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        setState(() => _pending.remove(task.id));
        context.showFailure(failure);
      case Ok(:final value):
        if (value.pointsCredited > 0 && !reduce) {
          kidFlyCoin(
            context,
            from: _keyFor(task.id),
            to: widget.balanceKey,
            points: value.pointsCredited,
          );
        }
        if (last) {
          setState(() {
            _celebrations++;
            _allDoneLine = null;
          });
          showConfetti(
            context,
            colors: [
              for (final c in container.read(wuselTuftsProvider))
                context.ww.member(c).ink,
              context.ww.points,
            ],
          );
          unawaited(celebration.cue(Cue.fertig));
        } else if (value.pointsCredited > 0) {
          unawaited(celebration.cue(Cue.coin));
        }
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 5),
              content: Text(l10n.kidTaskDoneSnack(task.title)),
              action: SnackBarAction(
                label: l10n.kidUndo,
                onPressed: () => unawaited(
                  _undo(container, messenger, l10n, actor, task.id),
                ),
              ),
            ),
          );
    }
  }

  Future<void> _undo(
    ProviderContainer container,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    String actor,
    String instanceId,
  ) async {
    final result = await container
        .read(tasksRepositoryProvider)
        .undo(actor: actor, instanceId: instanceId);
    invalidateTasks(container.invalidate);
    switch (result) {
      case Ok():
        if (mounted) setState(() => _pending.remove(instanceId));
      case Err(:final failure):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message(l10n))));
    }
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.done,
    required this.onTap,
    super.key,
  });

  final TaskInstance task;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ww = context.ww;
    final reduce = kidReduceMotion(context);
    final motion = reduce ? Duration.zero : Tokens.motionEmphasised;
    final status = task.awaitsApproval
        ? l10n.kidAwaitsCheck
        : (done ? l10n.kidDone : null);
    return Opacity(
      opacity: done ? 0.6 : 1,
      child: Semantics(
        button: true,
        enabled: !done,
        label: [
          task.title,
          ?status,
          if (!done && task.points > 0) l10n.tasksPointsCount(task.points),
        ].join(', '),
        child: KidCard(
          onTap: done ? null : onTap,
          child: ExcludeSemantics(
            // One spoken label for the card (title, status, points): the children would
            // otherwise repeat the title (A10).
            child: Row(
              children: [
                ExcludeSemantics(
                  child: EmojiPicture(
                    taskIconAsset(task.iconKey) ?? taskIconAsset('star')!,
                    size: 40,
                  ),
                ),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        // The card's label already says the title; it is not read twice.
                        child: Text(
                          task.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: Tokens.space3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!done && task.points > 0)
                            PointsCoin(points: task.points, fontSize: 19),
                          if (status != null)
                            Text(status, style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: done ? 1 : 0.85,
                  duration: motion,
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 44,
                    color: done ? ww.success : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's lessons, from `school-week` (today and tomorrow in one call). The lesson
/// running now is enlarged; tomorrow's equipment is a footer.
class _SchoolSection extends ConsumerWidget {
  const _SchoolSection({required this.actor});

  final String actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(kidTodayProvider);
    final tomorrow = kidTomorrowOf(today);
    final minutes = ref.watch(kidMinutesProvider);
    final week = ref.watch(schoolWeekProvider((today, tomorrow)));
    final data = ref.watch(schoolDataProvider).value;
    IconData iconOf(String subject) => schoolIcon(data?.iconKeyFor(subject));

    return AsyncValueView<SchoolWeek>(
      value: week,
      onRetry: () => ref.invalidate(schoolWeekProvider((today, tomorrow))),
      data: (w) {
        if (w.timetableOf(actor) == null) {
          return KidCard(
            child: Text(
              l10n.kidNoTimetable,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        final needs = w.dayOf(actor, tomorrow)?.equipment ?? const <String>[];
        return Column(
          children: [
            KidDayLessons(
              day: w.dayOf(actor, today),
              iconOf: iconOf,
              minutesNow: minutes,
            ),
            if (needs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space3),
                child: KidCard(
                  color: context.ww.paper(
                    PaperTints.tints.firstWhere((t) => t.key == 'lemon'),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.backpack_rounded, size: 32),
                      const SizedBox(width: Tokens.space3),
                      Expanded(
                        child: Text(
                          l10n.kidTomorrowNeeds(needs.join(', ')),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Tonight's (or lunch's) warm meal from the week board, and whether the child eats it.
class _MealSection extends ConsumerWidget {
  const _MealSection({required this.actor});

  final String actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(kidTodayProvider);
    final board = ref.watch(boardProvider).board;
    final meal = board?.days.where((d) => d.date == today).firstOrNull?.meal;
    if (meal == null) return const SizedBox.shrink();
    final text = switch ((meal.slot, meal.title)) {
      (MealSlot.dinner, final String dish) => l10n.kidMealDinner(dish),
      (MealSlot.lunch, final String dish) => l10n.kidMealLunch(dish),
      (MealSlot.dinner, null) => l10n.kidMealNoneDinner,
      (MealSlot.lunch, null) => l10n.kidMealNoneLunch,
    };
    return KidCard(
      child: Row(
        children: [
          const Icon(Icons.restaurant_rounded, size: 40),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (meal.eating.contains(actor))
                  Text(
                    l10n.kidMealEatingYou,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The appointments the child attends today. Presence (who is at work) is not one.
class _EventsSection extends ConsumerWidget {
  const _EventsSection({required this.actor});

  final String actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(kidTodayProvider);
    final window = ref.watch(occurrencesProvider((from: today, to: today)));
    return AsyncValueView<OccurrenceWindow>(
      value: window,
      onRetry: () =>
          ref.invalidate(occurrencesProvider((from: today, to: today))),
      data: (w) {
        final list = kidEventsFor(w.occurrences, actor, today);
        if (list.isEmpty) {
          return KidCard(
            child: Text(
              l10n.kidNoEvents,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }
        return Column(
          children: [
            for (final o in list)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space2),
                child: KidCard(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 104,
                        child: Text(
                          o.localStarts == null
                              ? l10n.kidAllDay
                              : context.time(o.localStarts!),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontFamily: Tokens.fontNumeric,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              o.title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (o.location != null)
                              Text(
                                o.location!,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The top of "Mein Tag": Wusel waves and greets the child by name, with the points
/// beside it (specs/25 "Where Wusel appears"). At night Wusel sleeps. Without Wusel
/// (switched off) it is the child's initial and the plain greeting, as before.
class _KidGreeting extends ConsumerStatefulWidget {
  const _KidGreeting({
    required this.member,
    required this.tint,
    required this.ink,
    required this.onInk,
    required this.balance,
  });

  final Member member;
  final Color tint;
  final Color ink;
  final Color onInk;
  final Widget balance;

  @override
  ConsumerState<_KidGreeting> createState() => _KidGreetingState();
}

class _KidGreetingState extends ConsumerState<_KidGreeting> {
  String? _line;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final member = widget.member;
    final night = ref.watch(nightProvider);
    final present = ref.watch(lighterDayProvider).wusel == WuselPresence.lively;
    final title = Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w800);
    final Widget greeting;
    if (present) {
      final line = _line ??= night
          ? l10n.wuselHelloNight(member.displayName)
          : WuselLines.pick(
              l10n,
              WuselLines.helloAt(DateTime.now()),
              name: member.displayName,
            );
      greeting = WuselSays(
        line: line,
        pose: night ? WuselPose.sleep : WuselPose.wave,
        size: 88,
        tappable: true,
        style: title,
      );
    } else {
      greeting = Row(
        children: [
          ExcludeSemantics(
            // The initial is decoration: the greeting already names the child.
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.ink,
                shape: BoxShape.circle,
              ),
              child: Text(
                member.initial,
                style: TextStyle(
                  fontFamily: Tokens.fontUi,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: widget.onInk,
                ),
              ),
            ),
          ),
          const SizedBox(width: Tokens.space3),
          Flexible(
            child: Text(l10n.kidGreeting(member.displayName), style: title),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(Tokens.space4),
      decoration: BoxDecoration(
        color: widget.tint,
        borderRadius: BorderRadius.circular(KidCard.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: KeyedSubtree(
              key: const ValueKey('kid-greeting'),
              child: greeting,
            ),
          ),
          const SizedBox(width: Tokens.space2),
          widget.balance,
        ],
      ),
    );
  }
}
