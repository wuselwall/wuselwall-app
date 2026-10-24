import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/board/ui/board_detail.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';
import 'package:wuselwall/features/rituals/ui/countdown_widgets.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';

/// One member's line of the look-back: what happened, never a number (specs/27).
String highlightLine(AppLocalizations l10n, WeekHighlight h) =>
    switch (h.kind) {
      HighlightKind.badge => l10n.weekHighlightBadge(h.title ?? ''),
      HighlightKind.streak => l10n.weekHighlightStreak(h.title ?? ''),
      HighlightKind.allDone => l10n.weekHighlightAllDone,
      HighlightKind.reward => l10n.weekHighlightReward(h.title ?? ''),
      HighlightKind.wish => l10n.weekHighlightWish(h.title ?? ''),
      HighlightKind.attended => l10n.weekHighlightAttended(h.title ?? ''),
      HighlightKind.cooked => l10n.weekHighlightCooked(h.title ?? ''),
      HighlightKind.helped => l10n.weekHighlightHelped,
      HighlightKind.here => l10n.weekHighlightHere,
    };

/// Opens the look-back of the week starting [weekStart] as a story: full screen on a
/// phone or tablet, a tap-through detail on the wall that returns to the board like every
/// detail (specs/27).
Future<void> openWeekReview(
  BuildContext context,
  DateTime weekStart, {
  bool board = false,
}) {
  if (board) {
    return showBoardDetail(
      context,
      title: context.l10n.weekReviewTitle,
      body: Builder(
        builder: (context) => WeekReviewStory(
          weekStart: weekStart,
          board: true,
          // The detail has its own way back; the end of the story returns to the week.
          onDone: () => unawaited(Navigator.of(context).maybePop()),
        ),
      ),
    );
  }
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        body: SafeArea(
          child: WeekReviewStory(
            weekStart: weekStart,
            onClose: () => unawaited(Navigator.of(context).maybePop()),
          ),
        ),
      ),
    ),
  );
}

/// "Unsere Woche" (specs/27): the cards of the week as a story, one at a time. A tap on
/// the right goes on, a tap on the left goes back, and so do a swipe and the arrow keys.
/// A card with nothing to say is left out. Nothing moves by itself.
class WeekReviewStory extends ConsumerWidget {
  const WeekReviewStory({
    required this.weekStart,
    this.board = false,
    this.onClose,
    this.onDone,
    super.key,
  });

  final DateTime weekStart;

  /// Sized for the wall: larger type and targets, and no close button of its own.
  final bool board;

  /// Shows a close button; Escape closes too. Going on from the last card closes as well.
  final VoidCallback? onClose;

  /// Going on from the last card, where there is no close button (the wall).
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final loaded = ref.watch(weekReviewProvider(weekStart));
    // The family's number only once it is known: never a "0" while it loads.
    if (loaded.isLoading && !loaded.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final review = loaded.value;
    final members = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
    );
    final today = ref.watch(ritualTodayProvider);
    final occurrences =
        ref
            .watch(occurrencesProvider((from: weekStart, to: weekEnd)))
            .value
            ?.occurrences ??
        const <Occurrence>[];
    // The traditions that happened: begun by today, not called off.
    final traditions = <String, Occurrence>{
      for (final o in occurrences)
        if (o.tradition &&
            o.status != EventStatus.cancelled &&
            !o.localStartDate.isAfter(today))
          o.eventId: o,
    };
    final highlights = review == null
        ? const <WeekHighlight>[]
        : withEventHighlights(
            review.members,
            occurrences,
            weekStart: weekStart,
            today: today,
          );
    final ahead = [
      for (final c in ref.watch(countdownsProvider))
        if (c.daysFrom(today) <= 8) c,
    ].take(3).toList();
    final body = _body(context);

    final cards = <_StoryPage>[
      if (review != null)
        _StoryPage(
          decor: Decor.sun,
          title: l10n.weekReviewTogether,
          board: board,
          child: Text(
            l10n.weekReviewChores(review.choresDone),
            style: _big(context),
          ),
        ),
      if (highlights.isNotEmpty)
        _StoryPage(
          decor: Decor.lilac,
          title: l10n.weekReviewMoments,
          board: board,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final h in highlights)
                if (members[h.profileId] case final m?)
                  _MemberLine(
                    member: m,
                    line: highlightLine(l10n, h),
                    iconKey: h.kind == HighlightKind.attended
                        ? h.iconKey
                        : null,
                    style: body,
                    board: board,
                  ),
            ],
          ),
        ),
      if (review != null && review.meals.isNotEmpty)
        _StoryPage(
          decor: Decor.apricot,
          title: l10n.weekReviewMeals,
          board: board,
          child: Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space2,
            children: [
              for (final meal in review.meals)
                Chip(
                  avatar: meal.wishedBy != null
                      ? const Icon(Icons.star_rounded)
                      : meal.firstTime
                      ? const Icon(Icons.auto_awesome)
                      : null,
                  labelStyle: board ? boardUi(22) : null,
                  label: Text(
                    meal.firstTime
                        ? '${meal.title} · ${l10n.weekReviewNewRecipe}'
                        : meal.title,
                  ),
                ),
            ],
          ),
        ),
      if (traditions.isNotEmpty)
        _StoryPage(
          decor: Decor.mint,
          title: l10n.weekReviewTraditions,
          board: board,
          child: Wrap(
            spacing: Tokens.space3,
            runSpacing: Tokens.space2,
            children: [
              for (final o in traditions.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmojiPicture(
                      eventIconAsset(o.iconKey) ?? eventIconAsset('star')!,
                      size: board ? 40 : 28,
                    ),
                    const SizedBox(width: Tokens.space1),
                    Text(o.title, style: body),
                  ],
                ),
            ],
          ),
        ),
      // The story's one Wusel cheers at its end (specs/27, card 5).
      _StoryPage(
        decor: Decor.sky,
        title: l10n.weekReviewNext,
        board: board,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ahead.isEmpty)
                    Text(l10n.weekReviewCalmAhead, style: body),
                  for (final c in ahead)
                    Text(
                      '${countdownTitle(l10n, c)} · ${countdownWhen(l10n, c, today)}',
                      style: body,
                    ),
                ],
              ),
            ),
            FamilyWusel(
              pose: WuselPose.cheer,
              size: board ? 140 : 96,
              quietAllowed: true,
            ),
          ],
        ),
      ),
    ];

    return _StoryPager(
      pages: cards,
      board: board,
      onClose: onClose,
      onDone: onDone ?? onClose,
    );
  }

  TextStyle? _big(BuildContext context) => board
      ? boardUi(56, weight: FontWeight.w800)
      : Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800);

  TextStyle? _body(BuildContext context) => board
      ? boardUi(30, weight: FontWeight.w600)
      : Theme.of(context).textTheme.titleMedium;
}

/// The story itself: a progress bar of segments, one card at a time, and the ways
/// between them. Under reduced motion a card replaces the one before without sliding.
class _StoryPager extends StatefulWidget {
  const _StoryPager({
    required this.pages,
    required this.board,
    required this.onClose,
    required this.onDone,
  });

  final List<_StoryPage> pages;
  final bool board;
  final VoidCallback? onClose;
  final VoidCallback? onDone;

  @override
  State<_StoryPager> createState() => _StoryPagerState();
}

class _StoryPagerState extends State<_StoryPager> {
  final _controller = PageController();
  var _index = 0;

  int get _count => widget.pages.length;

  @override
  void didUpdateWidget(covariant _StoryPager old) {
    super.didUpdateWidget(old);
    // A card that arrives or goes while the story is open (a late load) keeps the
    // reader within the story.
    if (_index >= _count) {
      _index = _count - 1;
      if (_controller.hasClients) _controller.jumpToPage(_index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int to) {
    if (to < 0) return;
    if (to >= _count) {
      widget.onDone?.call();
      return;
    }
    if (to == _index) return;
    setState(() => _index = to);
    if (!_controller.hasClients) return;
    if (motionAllowed(context)) {
      unawaited(
        _controller.animateToPage(
          to,
          duration: Tokens.motionEmphasised,
          curve: Curves.easeOutCubic,
        ),
      );
    } else {
      _controller.jumpToPage(to);
    }
  }

  void _next() => _go(_index + 1);

  void _previous() => _go(_index - 1);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final board = widget.board;
    final target = board ? 56.0 : 48.0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): rtl
            ? _previous
            : _next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): rtl
            ? _next
            : _previous,
        const SingleActivator(LogicalKeyboardKey.escape): ?widget.onClose,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                Tokens.space4,
                Tokens.space2,
                widget.onClose == null ? Tokens.space4 : Tokens.space1,
                Tokens.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Progress(
                      count: _count,
                      index: _index,
                      height: board ? 8 : 4,
                    ),
                  ),
                  if (widget.onClose case final close?)
                    IconButton(
                      key: const ValueKey('week-review-close'),
                      tooltip: l10n.close,
                      icon: const Icon(Icons.close),
                      onPressed: close,
                    ),
                ],
              ),
            ),
            Expanded(
              child: Semantics(
                container: true,
                liveRegion: true,
                label: l10n.weekReviewCardOf(_index + 1, _count),
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    key: const ValueKey('week-review-pages'),
                    behavior: HitTestBehavior.opaque,
                    // A third on the reading side goes back, the rest goes on.
                    onTapUp: (d) {
                      final third = constraints.maxWidth / 3;
                      final back = rtl
                          ? d.localPosition.dx > constraints.maxWidth - third
                          : d.localPosition.dx < third;
                      back ? _previous() : _next();
                    },
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v.abs() < 50) return;
                      (v < 0) != rtl ? _next() : _previous();
                    },
                    child: PageView(
                      controller: _controller,
                      // The gestures above move the story, so reduced motion holds.
                      physics: const NeverScrollableScrollPhysics(),
                      children: widget.pages,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                0,
                Tokens.space4,
                Tokens.space3,
              ),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    key: const ValueKey('week-review-previous'),
                    tooltip: l10n.weekReviewPreviousCard,
                    constraints: BoxConstraints.tight(Size.square(target)),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _index == 0 ? null : _previous,
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    key: const ValueKey('week-review-next'),
                    tooltip: l10n.weekReviewNextCard,
                    constraints: BoxConstraints.tight(Size.square(target)),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _index == _count - 1 && widget.onDone == null
                        ? null
                        : _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The segments at the top of the story: one per card, the ones seen filled.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.count,
    required this.index,
    required this.height,
  });

  final int count;
  final int index;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ww = context.ww;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: AnimatedContainer(
                duration: motionAllowed(context)
                    ? Tokens.motionStandard
                    : Duration.zero,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i <= index ? scheme.primary : ww.line,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One card of the story, filling the page: its colour band and title, then what it says.
class _StoryPage extends StatelessWidget {
  const _StoryPage({
    required this.decor,
    required this.title,
    required this.board,
    required this.child,
  });

  final Decor decor;
  final String title;
  final bool board;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final pad = board ? Tokens.space6 : Tokens.space4;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ww.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: ww.decor(decor),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: pad,
                  vertical: board ? Tokens.space4 : Tokens.space3,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: board
                        ? boardUi(
                            36,
                            weight: FontWeight.w800,
                            color: ww.onDecor,
                          )
                        : Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: ww.onDecor,
                          ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberLine extends StatelessWidget {
  const _MemberLine({
    required this.member,
    required this.line,
    required this.style,
    required this.board,
    this.iconKey,
  });

  final Member member;
  final String line;
  final TextStyle? style;
  final bool board;

  /// The picture of the tradition or event the line names, when it has one.
  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.ww.member(member.color);
    final picture = eventIconAsset(iconKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      child: Row(
        children: [
          CircleAvatar(
            radius: board ? 28 : 20,
            backgroundColor: colors.ink,
            foregroundColor: colors.onInk,
            child: Text(member.initial),
          ),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${member.displayName}  ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: line),
                ],
              ),
              style: style,
            ),
          ),
          if (picture != null) ...[
            const SizedBox(width: Tokens.space2),
            EmojiPicture(picture, size: board ? 40 : 28),
          ],
        ],
      ),
    );
  }
}

/// "Unsere Woche" on Today and the kid tablet while the look-back is open.
class WeekReviewCard extends ConsumerWidget {
  const WeekReviewCard({this.kid = false, super.key});

  final bool kid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekReviewDueProvider);
    if (week == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    void open() => unawaited(openWeekReview(context, week));
    if (kid) {
      return Padding(
        padding: const EdgeInsets.only(top: Tokens.space3),
        child: KidCard(
          color: context.ww.band(AppModule.today),
          onTap: open,
          child: Row(
            children: [
              // No Wusel of its own: the kid home's greeting has the screen's one.
              const Icon(Icons.auto_awesome, size: 40),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(
                  l10n.weekReviewTitle,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      );
    }
    return Card(
      color: context.ww.band(AppModule.today),
      child: ListTile(
        leading: const Icon(Icons.auto_awesome),
        title: Text(l10n.weekReviewTitle),
        subtitle: Text(l10n.weekReviewOpen),
        trailing: const Icon(Icons.chevron_right),
        onTap: open,
      ),
    );
  }
}

/// The wall's way into the look-back: a tile in the footer while it is open. It
/// never rotates in by itself, because the board must show the week (P6).
class BoardWeekReviewTile extends ConsumerWidget {
  const BoardWeekReviewTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(weekReviewDueProvider);
    if (week == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return BoardTap(
      label: l10n.weekReviewTitle,
      onTap: () => unawaited(openWeekReview(context, week, board: true)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 28),
          const SizedBox(width: 8),
          Text(
            l10n.weekReviewTitle,
            style: boardUi(26, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
