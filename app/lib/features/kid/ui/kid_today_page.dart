import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/confetti.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/core/wusel/wusel_stage.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';
import 'package:wuselwall/features/kid/application/kid_providers.dart';
import 'package:wuselwall/features/kid/ui/kid_birthday.dart';
import 'package:wuselwall/features/kid/ui/kid_new_badge.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/application/today_tradition_provider.dart';
import 'package:wuselwall/features/rituals/ui/countdown_widgets.dart';
import 'package:wuselwall/features/rituals/ui/meal_wish_widgets.dart';
import 'package:wuselwall/features/rituals/ui/table_question_widgets.dart';
import 'package:wuselwall/features/rituals/ui/week_review_widgets.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';
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

  /// Counts the finished lists of this visit: the greeting's Wusel cheers for each.
  final _cheers = ValueNotifier<int>(0);

  /// The balance the pill shows while Wusel carries a coin home: it counts up when
  /// the coin lands, not when the server answers (specs/25 "Wusel on the move").
  final _heldBalance = ValueNotifier<int?>(null);

  /// Whether this visit came from another tab: Wusel hops in.
  late final bool _cameBack = ref.read(kidTabProvider.notifier).takeCameBack();

  @override
  void dispose() {
    _cheers.dispose();
    _heldBalance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final member = widget.member;
    final colors = context.ww.member(member.color);
    final balance = ref.watch(pointBalancesProvider).value;
    final points = kidBalanceOf(balance ?? const {}, member.id);
    // A grown-up's yes to a wished reward, from another device: the badge sound.
    kidListenForApprovals(ref, member.id);

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
          balance: ValueListenableBuilder<int?>(
            valueListenable: _heldBalance,
            builder: (context, held, _) =>
                KidBalancePill(key: _balanceKey, balance: held ?? points),
          ),
          cheers: _cheers,
          enter: _cameBack,
        ),
        // The greeting's Wusel holds up the star: one Wusel on the screen.
        KidNewBadge(actor: member.id, withWusel: false),
        const WeekReviewCard(kid: true),
        const TableQuestionCard(kid: true),
        KidSectionTitle(l10n.kidTasksTitle),
        _TasksSection(
          actor: member.id,
          balanceKey: _balanceKey,
          cheers: _cheers,
          heldBalance: _heldBalance,
          balance: points,
        ),
        KidCountdowns(actor: member.id),
        KidSectionTitle(l10n.kidSchoolTitle),
        _SchoolSection(actor: member.id),
        const SizedBox(height: Tokens.space4),
        _MealSection(actor: member.id),
        KidWishCard(member: member),
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
  const _TasksSection({
    required this.actor,
    required this.balanceKey,
    required this.cheers,
    required this.heldBalance,
    required this.balance,
  });

  final String actor;
  final GlobalKey balanceKey;
  final ValueNotifier<int> cheers;
  final ValueNotifier<int?> heldBalance;

  /// The balance shown now, held while Wusel carries the coin.
  final int balance;

  @override
  ConsumerState<_TasksSection> createState() => _TasksSectionState();
}

class _TasksSectionState extends ConsumerState<_TasksSection> {
  /// Ticked by the child but not yet confirmed by the list.
  final _pending = <String>{};

  /// Wusel's line for the finished list, picked once per visit so a rebuild does not
  /// change what it says.
  String? _allDoneLine;

  /// The all-done card: where Wusel goes for the last chore, since the card that was
  /// ticked moves down below it.
  final _allDoneKey = GlobalKey();
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
                key: _allDoneKey,
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
                    // The last chore of the day: Wusel's line. Wusel itself cheers in
                    // the greeting, its home, after a jump over the list, so there
                    // is never a second Wusel (specs/25 "Wusel on the move").
                    Text(
                      _allDoneLine ??= WuselLines.pick(
                        l10n,
                        WuselMoment.allDone,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
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
    // The tick sounds with the tick the child sees, at once: a sound 300 ms late feels
    // broken (specs/26). If the server then refuses, the card un-ticks with a message.
    // The last chore waits for the server instead and sounds only *fertig*, so the
    // child never hears two sounds on top of each other, nor a celebration for a tick
    // that did not count.
    if (!last) unawaited(celebration.cue(Cue.tick));
    setState(() => _pending.add(task.id));
    // A lively Wusel hops over to the card as the tick pops (specs/25 "Wusel on the
    // move"). For the last chore it goes to the all-done card, which appears above the
    // list and pushes the ticked card down; that card is there from the next frame.
    final stage = WuselStage.maybeOf(context);
    final balanceBefore = widget.heldBalance.value ?? widget.balance;
    final trip = _ChoreTrip(
      onTrip: (t) {
        if (!mounted) return;
        // The pill waits for the coin Wusel brings; released when Wusel is home
        // without one, or when the coin lands.
        widget.heldBalance.value = balanceBefore;
        unawaited(
          t.done.then((_) {
            if (!t.carriedHome) _releaseBalance();
          }),
        );
      },
    );
    if (stage == null) {
      trip.begin(null);
    } else if (last) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => trip.begin(mounted ? stage.visit(_allDoneKey) : null),
      );
    } else {
      trip.begin(stage.visit(_keyFor(task.id)));
    }
    final result = await container
        .read(tasksRepositoryProvider)
        .complete(actor: actor, instanceId: task.id);
    invalidateTasks(container.invalidate);
    if (!mounted) {
      trip.release((t) => t.goHome());
      return;
    }
    switch (result) {
      case Err(:final failure):
        // Home again, without a reaction: a refused tick is no moment for Wusel.
        trip.release((t) => t.goHome());
        setState(() => _pending.remove(task.id));
        context.showFailure(failure);
      case Ok(:final value):
        final points = value.pointsCredited;
        // One celebration per moment: ticking, undoing and ticking the last chore
        // again does not burst twice (specs/26).
        final celebrate =
            last && celebration.claimMoment(Celebration.lastChoreOf(actor));
        // Wusel takes the coin and carries it home, where it drops into the balance;
        // the coin sounds as it lands, unless *fertig* already sounded. Without a
        // trip the coin flies from the card, as before Wusel could travel.
        trip.release(
          (t) => t.goHome(
            happy: true,
            celebrate: celebrate,
            carry: points > 0,
            onHome: points > 0
                ? (hand) {
                    if (!mounted) return;
                    kidFlyCoin(
                      context,
                      fromPoint: hand,
                      to: widget.balanceKey,
                      points: points,
                      onLanded: _releaseBalance,
                    );
                    if (!celebrate) unawaited(celebration.cue(Cue.coin));
                  }
                : null,
          ),
          without: () {
            if (!mounted || points <= 0) return;
            if (!reduce) {
              kidFlyCoin(
                context,
                from: _keyFor(task.id),
                to: widget.balanceKey,
                points: points,
              );
            }
            if (!celebrate) unawaited(celebration.cue(Cue.coin));
          },
        );
        if (celebrate) {
          setState(() => _allDoneLine = null);
          widget.cheers.value++;
          showConfetti(
            context,
            colors: [
              for (final c in container.read(wuselTuftsProvider))
                context.ww.member(c).ink,
              context.ww.points,
            ],
          );
          unawaited(celebration.cue(Cue.fertig));
        } else if (last && points <= 0) {
          // The day was celebrated already: this is an ordinary tick.
          unawaited(celebration.cue(Cue.tick));
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

  void _releaseBalance() {
    if (mounted) widget.heldBalance.value = null;
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

/// Wusel's trip for one tick. The trip may set off after the server has answered (the
/// last chore's trip waits a frame for the all-done card), so the answer is kept until
/// Wusel is on its way, or, when Wusel does not travel, handed to [without].
class _ChoreTrip {
  _ChoreTrip({required this.onTrip});

  /// Called once Wusel is on its way.
  final void Function(WuselTrip trip) onTrip;

  bool _begun = false;
  WuselTrip? _trip;
  void Function(WuselTrip trip)? _go;
  VoidCallback? _without;

  void begin(WuselTrip? trip) {
    _begun = true;
    _trip = trip;
    if (trip != null) onTrip(trip);
    final go = _go;
    final without = _without;
    _go = null;
    _without = null;
    if (go == null) return;
    trip == null ? without?.call() : go(trip);
  }

  void release(void Function(WuselTrip trip) go, {VoidCallback? without}) {
    if (!_begun) {
      _go = go;
      _without = without;
    } else if (_trip case final trip?) {
      go(trip);
    } else {
      without?.call();
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
    final status = task.awaitsApproval
        ? l10n.kidAwaitsCheck
        : (done ? l10n.kidDone : null);
    // Done, the card fills with the brand tint and keeps full contrast: no fading
    // and no strike-through (specs/26 "The kid register's sticker skin").
    return Semantics(
      button: true,
      enabled: !done,
      label: [
        task.title,
        ?status,
        if (!done && task.points > 0) l10n.tasksPointsCount(task.points),
      ].join(', '),
      child: KidCard(
        onTap: done ? null : onTap,
        color: done ? ww.successContainer : null,
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
              _TickPop(
                done: done,
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
    );
  }
}

/// The tick on a chore card: it pops in on the snappy spring when the chore is done,
/// overshooting a little, and settles back small when it is undone. Under reduced
/// motion it lands at once (specs/26 "Motion").
class _TickPop extends StatefulWidget {
  const _TickPop({required this.done, required this.child});

  final bool done;
  final Widget child;

  /// The open circle sits a little smaller than the tick.
  static const open = 0.85;

  /// Where the pop starts from.
  static const from = 0.5;

  @override
  State<_TickPop> createState() => _TickPopState();
}

class _TickPopState extends State<_TickPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: widget.done ? 1 : _TickPop.open,
  );

  @override
  void didUpdateWidget(_TickPop old) {
    super.didUpdateWidget(old);
    if (old.done == widget.done) return;
    final target = widget.done ? 1.0 : _TickPop.open;
    if (!motionAllowed(context)) {
      _scale.value = target;
      return;
    }
    unawaited(
      _scale.animateWith(
        SpringSimulation(
          Tokens.springSnappy,
          widget.done ? _TickPop.from : _scale.value,
          target,
          0,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
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
    required this.cheers,
    this.enter = false,
  });

  final Member member;
  final Color tint;
  final Color ink;
  final Color onInk;
  final Widget balance;

  /// The finished lists of this visit: Wusel cheers at home for each.
  final ValueNotifier<int> cheers;

  /// Wusel hops in from the lower edge (back from another tab).
  final bool enter;

  @override
  ConsumerState<_KidGreeting> createState() => _KidGreetingState();
}

class _KidGreetingState extends ConsumerState<_KidGreeting> {
  /// The hello, picked once per visit so a rebuild does not change its words.
  String? _hello;

  /// Whether [_hello] was picked for the night: a new one when the night begins or
  /// ends.
  bool? _helloAtNight;

  /// Runs while the day loads or the device is offline. Wusel thinks only once it has
  /// fired (specs/25: "only after 2 s"), so a quick load never shows a thinking Wusel.
  Timer? _waitTimer;
  bool _thinking = false;

  /// Whether this visit has asked for the birthday's full screen.
  bool _birthdayAsked = false;

  @override
  void initState() {
    super.initState();
    widget.cheers.addListener(_onCheer);
  }

  void _onCheer() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.cheers.removeListener(_onCheer);
    _waitTimer?.cancel();
    super.dispose();
  }

  /// Starts the wait when [waiting] begins and forgets it when it ends.
  void _followWait(bool waiting) {
    if (waiting == (_waitTimer != null || _thinking)) return;
    _waitTimer?.cancel();
    _waitTimer = null;
    _thinking = false;
    if (!waiting) return;
    _waitTimer = Timer(kidThinkAfter, () {
      if (!mounted) return;
      setState(() {
        _waitTimer = null;
        _thinking = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final member = widget.member;
    final night = ref.watch(nightProvider);
    final today = ref.watch(kidTodayProvider);
    final title = Theme.of(context).textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w800);
    final Widget greeting;
    // The child's own birthday: Wusel cheers in the party hat (specs/25), where the
    // household keeps the birthday ambience on.
    final birthday =
        ref
            .watch(birthdaysTodayMembersProvider)
            .any((m) => m.id == member.id) &&
        ref.watch(ambienceProvider.select((a) => a.birthdays.isNotEmpty));
    // A quiet Wusel still comes for the special day, held still.
    final special = birthday && !night;
    if (special && !_birthdayAsked) {
      // The first open of the day: the full screen, once per device (specs/25).
      _birthdayAsked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          showKidBirthdayOnce(context, ref, member: member, today: today),
        );
      });
    }
    final presence = ref.watch(lighterDayProvider).wusel;
    final present =
        presence == WuselPresence.lively ||
        (presence == WuselPresence.quiet && special);

    // Offline (no network, or the board's last refresh failed, as on the wall) or the
    // day's chores still loading: after 2 s Wusel thinks instead of waving.
    final offline =
        ref.watch(connectivityProvider).value == false ||
        ref.watch(boardProvider.select((s) => s.isStale));
    final loading = ref.watch(
      tasksTodayProvider.select((t) => t.isLoading && !t.hasValue),
    );
    _followWait(offline || loading);
    final thinking = _thinking && !night && presence == WuselPresence.lively;

    if (_helloAtNight != night) {
      _hello = null;
      _helloAtNight = night;
    }
    if (present) {
      final hello = _hello ??= night
          ? l10n.wuselHelloNight(member.displayName)
          : WuselLines.pick(
              l10n,
              WuselLines.helloAt(DateTime.now()),
              name: member.displayName,
            );
      // After the hello, the day's first useful fact (specs/25).
      final fact = night || thinking
          ? null
          : kidFirstFact(
              ownBirthday: birthday,
              minutesNow: ref.watch(kidMinutesProvider),
              tradition: ref.watch(todayTraditionProvider),
              school: ref
                  .watch(schoolWeekProvider((today, kidTomorrowOf(today))))
                  .value
                  ?.dayOf(member.id, today),
              meal: ref.watch(
                boardProvider.select(
                  (s) => s.board?.days
                      .where((d) => d.date == today)
                      .firstOrNull
                      ?.meal,
                ),
              ),
              countdown: ref
                  .watch(countdownsProvider)
                  .where((c) => c.isFor(member.id))
                  .firstOrNull,
            );
      final line = thinking
          ? (offline ? l10n.wuselOffline : l10n.wuselWaiting)
          : fact == null
          ? hello
          : '$hello ${_factLine(l10n, fact, today)}';
      final cheers = widget.cheers.value;
      // A badge earned in the last two days: the greeting's Wusel holds up the star
      // (specs/25 `proud`), and the badge card below names it.
      final badge = ref.watch(kidNewBadgeProvider(member.id));
      greeting = WuselSays(
        line: line,
        pose: night
            ? WuselPose.sleep
            : thinking
            ? WuselPose.think
            : birthday || cheers > 0
            ? WuselPose.cheer
            : badge != null
            ? WuselPose.proud
            : WuselPose.wave,
        // Each finished list cheers again; a new badge is held up again.
        moment: (cheers, badge?.id),
        outfit: special ? WuselOutfit.party : null,
        quietAllowed: special,
        size: 88,
        tappable: true,
        style: title,
        // The home Wusel travels from (specs/25 "Wusel on the move").
        home: true,
        enter: widget.enter,
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

/// How long the kid home waits, loading or offline, before Wusel thinks (specs/25).
const kidThinkAfter = Duration(seconds: 2);

/// What Wusel says about [fact], at most eight words (specs/25 "Voice").
String _factLine(AppLocalizations l10n, KidFact fact, DateTime today) =>
    switch (fact) {
      KidBirthdayFact() => l10n.wuselFactBirthdayYou,
      KidTraditionFact(:final title) => l10n.wuselFactTradition(title),
      KidFirstLessonFact(:final subject) => l10n.wuselFactFirstLesson(subject),
      KidMealFact(slot: MealSlot.dinner, :final dish) =>
        l10n.wuselFactMealDinner(dish),
      KidMealFact(:final dish) => l10n.wuselFactMealLunch(dish),
      KidCountdownFact(:final countdown) => l10n.wuselFactCountdown(
        countdownTitle(l10n, countdown),
        countdownWhen(l10n, countdown, today),
      ),
    };
