import 'dart:async';

import 'package:flutter/material.dart';
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
      HighlightKind.cooked => l10n.weekHighlightCooked(h.title ?? ''),
      HighlightKind.helped => l10n.weekHighlightHelped,
      HighlightKind.here => l10n.weekHighlightHere,
    };

/// Opens the look-back of the week starting [weekStart]: a page on a phone or tablet,
/// a tap-through detail on the wall that returns to the board like every detail.
Future<void> openWeekReview(
  BuildContext context,
  DateTime weekStart, {
  bool board = false,
}) {
  if (board) {
    return showBoardDetail(
      context,
      title: context.l10n.weekReviewTitle,
      body: WeekReviewStory(weekStart: weekStart, board: true),
    );
  }
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.weekReviewTitle)),
        body: WeekReviewStory(weekStart: weekStart),
      ),
    ),
  );
}

/// The five cards of "Unsere Woche" (specs/27), sliding in one after another.
class WeekReviewStory extends ConsumerWidget {
  const WeekReviewStory({
    required this.weekStart,
    this.board = false,
    super.key,
  });

  final DateTime weekStart;
  final bool board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final review = ref.watch(weekReviewProvider(weekStart)).value;
    final members = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
    );
    final traditions = <String, Occurrence>{
      for (final o
          in ref
                  .watch(occurrencesProvider((from: weekStart, to: weekEnd)))
                  .value
                  ?.occurrences ??
              const <Occurrence>[])
        if (o.tradition) o.eventId: o,
    };
    final today = ref.watch(ritualTodayProvider);
    final ahead = [
      for (final c in ref.watch(countdownsProvider))
        if (c.daysFrom(today) <= 8) c,
    ].take(3).toList();

    final cards = <Widget>[
      _StoryCard(
        decor: Decor.sun,
        title: l10n.weekReviewTogether,
        child: Text(
          l10n.weekReviewChores(review?.choresDone ?? 0),
          style: _big(context),
        ),
      ),
      if (review != null && review.members.isNotEmpty)
        _StoryCard(
          decor: Decor.lilac,
          title: l10n.weekReviewMoments,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final h in review.members)
                if (members[h.profileId] case final m?)
                  _MemberLine(member: m, line: highlightLine(l10n, h)),
            ],
          ),
        ),
      if (review != null && review.meals.isNotEmpty)
        _StoryCard(
          decor: Decor.apricot,
          title: l10n.weekReviewMeals,
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
        _StoryCard(
          decor: Decor.mint,
          title: l10n.weekReviewTraditions,
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
                      size: 28,
                    ),
                    const SizedBox(width: Tokens.space1),
                    Text(o.title, style: _body(context)),
                  ],
                ),
            ],
          ),
        ),
      _StoryCard(
        decor: Decor.sky,
        title: l10n.weekReviewNext,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ahead.isEmpty)
                    Text(l10n.weekReviewCalmAhead, style: _body(context)),
                  for (final c in ahead)
                    Text(
                      '${countdownTitle(l10n, c)} · ${countdownWhen(l10n, c, today)}',
                      style: _body(context),
                    ),
                ],
              ),
            ),
            const FamilyWusel(
              pose: WuselPose.cheer,
              size: 96,
              quietAllowed: true,
            ),
          ],
        ),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        for (final (i, card) in cards.indexed) _SlideIn(index: i, child: card),
      ],
    );
  }

  TextStyle? _big(BuildContext context) => board
      ? boardUi(40, weight: FontWeight.w800)
      : Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800);

  TextStyle? _body(BuildContext context) => board
      ? boardUi(26, weight: FontWeight.w600)
      : Theme.of(context).textTheme.titleMedium;
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.decor,
    required this.title,
    required this.child,
  });

  final Decor decor;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space3),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.space4,
                  vertical: Tokens.space2,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ww.onDecor,
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(Tokens.space4), child: child),
          ],
        ),
      ),
    );
  }
}

class _MemberLine extends StatelessWidget {
  const _MemberLine({required this.member, required this.line});

  final Member member;
  final String line;

  @override
  Widget build(BuildContext context) {
    final colors = context.ww.member(member.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      child: Row(
        children: [
          CircleAvatar(
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
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Each card slides in a beat after the one before (250 ms each); still under
/// reduced motion.
class _SlideIn extends StatefulWidget {
  const _SlideIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Tokens.motionEmphasised,
  );
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.value > 0 || _delay != null) return;
    if (!motionAllowed(context)) {
      _c.value = 1;
      return;
    }
    _delay = Timer(
      Duration(milliseconds: 120 * widget.index),
      () => unawaited(_c.forward()),
    );
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = Curves.easeOutBack.transform(_c.value);
      return Opacity(
        opacity: _c.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      );
    },
    child: widget.child,
  );
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
              const FamilyWusel(
                pose: WuselPose.wave,
                size: 72,
                quietAllowed: true,
              ),
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
