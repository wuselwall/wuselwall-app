import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';
import 'package:wuselwall/features/kid/application/kid_providers.dart';
import 'package:wuselwall/features/kid/data/kid_badges_repository.dart';
import 'package:wuselwall/features/kid/ui/kid_new_badge.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';
import 'package:wuselwall/features/wusel/ui/wusel_lines.dart';

/// "Punkte": the acting child's balance, the reward shop, badges and streaks. Only this
/// child's numbers are read here; no other balance, streak or ranking appears.
class KidPointsPage extends ConsumerStatefulWidget {
  const KidPointsPage({required this.actor, super.key});

  final String actor;

  @override
  ConsumerState<KidPointsPage> createState() => _KidPointsPageState();
}

class _KidPointsPageState extends ConsumerState<KidPointsPage> {
  final _asking = <String>{};

  /// What Wusel says after a reward was asked for or redeemed on this visit, and a
  /// counter so it is proud again for the next one (specs/25 `proud`).
  String? _proudLine;
  int _proudMoment = 0;

  Future<void> _ask(Reward reward) async {
    final l10n = context.l10n;
    final container = ProviderScope.containerOf(context);
    setState(() => _asking.add(reward.id));
    final result = await container
        .read(tasksRepositoryProvider)
        .requestReward(actor: widget.actor, rewardId: reward.id);
    invalidateTasks(container.invalidate);
    if (!mounted) return;
    setState(() => _asking.remove(reward.id));
    switch (result) {
      case Ok(:final value):
        context.showMessage(
          value == RedemptionStatus.requested
              ? l10n.kidRequestSent
              : l10n.kidRedeemed,
        );
        setState(() {
          _proudMoment++;
          _proudLine = value == RedemptionStatus.requested
              ? WuselLines.pick(l10n, WuselMoment.rewardSent)
              : l10n.kidRedeemed;
        });
        // The badge sound is for a reward redeemed (specs/26); a request that waits
        // for a grown-up's yes is not there yet, and Wusel's line carries it.
        if (value != RedemptionStatus.requested) {
          unawaited(container.read(celebrationProvider).cue(Cue.badge));
        }
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A grown-up said yes on another device: the badge sound, and Wusel is proud.
    kidListenForApprovals(
      ref,
      widget.actor,
      onApproved: () => setState(() {
        _proudMoment++;
        _proudLine = l10n.kidRedeemed;
      }),
    );
    final balances = ref.watch(pointBalancesProvider).value ?? const {};
    final balance = kidBalanceOf(balances, widget.actor);
    final rewards = ref.watch(rewardsProvider);
    final redemptions = ref.watch(redemptionsProvider).value ?? const [];
    final waiting = {
      for (final r in redemptions)
        if (r.profileId == widget.actor &&
            r.status == RedemptionStatus.requested)
          r.rewardId,
    };
    final streaks = kidStreakRows(
      streaks: ref.watch(streaksProvider).value ?? const [],
      definitions: ref.watch(taskDefinitionsProvider).value ?? const [],
      actor: widget.actor,
    );

    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        _BalanceCard(balance: balance),
        // A new badge, unless Wusel is already proud of a reward just asked for.
        if (_proudLine == null) KidNewBadge(actor: widget.actor),
        if (_proudLine case final line?)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space3),
            child: WuselSays(
              line: line,
              pose: WuselPose.proud,
              size: 96,
              moment: _proudMoment,
              tappable: true,
            ),
          ),
        KidSectionTitle(l10n.kidRewardsTitle),
        AsyncValueView<List<Reward>>(
          value: rewards,
          onRetry: () => ref.invalidate(rewardsProvider),
          data: (list) => Column(
            children: [
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: Tokens.space2),
                  child: _RewardCard(
                    reward: r,
                    balance: balance,
                    waiting: waiting.contains(r.id),
                    busy: _asking.contains(r.id),
                    onAsk: () => _ask(r),
                  ),
                ),
            ],
          ),
        ),
        KidSectionTitle(l10n.kidBadgesTitle),
        ref
            .watch(kidBadgesProvider(widget.actor))
            .when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (badges) => Wrap(
                // Centred, so a last badge alone on its row does not sit apart.
                alignment: WrapAlignment.center,
                spacing: Tokens.space4,
                runSpacing: Tokens.space4,
                children: [
                  for (final b in kidBadgeRow(badges)) _BadgeTile(badge: b),
                ],
              ),
            ),
        if (streaks.isNotEmpty) ...[
          KidSectionTitle(l10n.kidStreaksTitle),
          for (final s in streaks)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space2),
              child: KidCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.kidStreak(s.days, s.title),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: Tokens.space2),
                    const EmojiPicture(emojiFire, size: 28),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(Tokens.space6),
      decoration: BoxDecoration(
        color: ww.points,
        borderRadius: BorderRadius.circular(UiRegister.kid.radius),
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, size: 56, color: ww.onPoints),
          const SizedBox(width: Tokens.space4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$balance',
                style: TextStyle(
                  fontFamily: Tokens.fontNumeric,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: ww.onPoints,
                ),
              ),
              Text(
                l10n.kidYourPoints,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: ww.onPoints, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One reward. Not affordable yet: a bar and "Noch N Punkte", never a red mark.
class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.balance,
    required this.waiting,
    required this.busy,
    required this.onAsk,
  });

  final Reward reward;
  final int balance;
  final bool waiting;
  final bool busy;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = kidRewardState(
      costPoints: reward.costPoints,
      balance: balance,
      waiting: waiting,
      soldOut: reward.soldOut,
    );
    final touch = UiRegister.kid.touchTarget;
    // One node per reward: title, cost and the state are spoken together; the action is
    // a child of this node, so the screen reader meets it inside its own reward.
    final spokenState = switch (state) {
      KidRewardState.needMore => l10n.kidNeedMore(
        kidPointsMissing(reward.costPoints, balance),
      ),
      KidRewardState.waiting => l10n.kidWaitsApproval,
      KidRewardState.soldOut => l10n.kidSoldOut,
      KidRewardState.ready => null,
    };
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: [
        reward.title,
        l10n.tasksPointsCount(reward.costPoints),
        ?spokenState,
      ].join(', '),
      child: KidCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The visible copy of the label above; the node carries the words.
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      EmojiPicture(
                        taskIconAsset(reward.iconKey) ?? emojiGift,
                        size: 40,
                      ),
                      const SizedBox(width: Tokens.space3),
                      Expanded(
                        child: Text(
                          reward.title,
                          // On a small phone one size smaller, so a long word
                          // ("Samstagsfilm") keeps to one line.
                          style:
                              (MediaQuery.sizeOf(context).width < 360
                                      ? theme.textTheme.titleMedium
                                      : theme.textTheme.titleLarge)
                                  ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      PointsCoin(points: reward.costPoints, fontSize: 19),
                    ],
                  ),
                  const SizedBox(height: Tokens.space3),
                  switch (state) {
                    KidRewardState.needMore => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: reward.costPoints == 0
                              ? 1
                              : (balance / reward.costPoints).clamp(0.0, 1.0),
                          minHeight: 10,
                        ),
                        const SizedBox(height: Tokens.space2),
                        Text(
                          spokenState!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    KidRewardState.waiting => Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded),
                        const SizedBox(width: Tokens.space2),
                        Text(spokenState!, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                    KidRewardState.soldOut => Text(
                      spokenState!,
                      style: theme.textTheme.bodyLarge,
                    ),
                    KidRewardState.ready => const SizedBox.shrink(),
                  },
                ],
              ),
            ),
            if (state == KidRewardState.ready)
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(touch),
                ),
                onPressed: busy ? null : onAsk,
                // The label takes the button's own foreground (onPrimary, which is the
                // member's onInk), not the page ink: ink on the member fill is near-invisible
                // in dark mode.
                child: Text(
                  l10n.kidRedeem,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A badge: one node with its title and whether it is earned. The medal is faint while
/// it is still to come; the text is not, so it keeps its contrast.
/// [style], or smaller until the longest word of [text] fits [width] on one line:
/// a badge name may wrap between words, never inside one ("Fünfundzwanzi / g").
TextStyle? _fitLongestWord(
  BuildContext context,
  String text,
  TextStyle? style,
  double width,
) {
  if (style == null) return null;
  // Measured as the Text draws it: the inherited style (the app's font) under it.
  final drawn = DefaultTextStyle.of(context).style.merge(style);
  final scaler = MediaQuery.textScalerOf(context);
  var widest = 0.0;
  for (final word in text.split(RegExp(r'\s+'))) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: drawn),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  if (widest <= width) return style;
  return style.copyWith(fontSize: (style.fontSize ?? 14) * width / widest);
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final KidBadge badge;

  /// Room for a badge and its name, the name wrapping between words.
  static const width = 128.0;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final l10n = context.l10n;
    final asset = taskIconAsset(badge.iconKey);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          '${badge.title}, '
          '${badge.earned ? l10n.kidBadgeEarned : l10n.kidBadgeNotYet}',
      child: SizedBox(
        width: _BadgeTile.width,
        child: Column(
          children: [
            Opacity(
              opacity: badge.earned ? 1 : 0.35,
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badge.earned
                      ? ww.points
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: asset != null
                    ? EmojiPicture(asset, size: 36)
                    : Icon(
                        Icons.workspace_premium_rounded,
                        size: 32,
                        color: badge.earned
                            ? ww.onPoints
                            : Theme.of(context).colorScheme.onSurface,
                      ),
              ),
            ),
            const SizedBox(height: Tokens.space1),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _fitLongestWord(
                context,
                badge.title,
                Theme.of(context).textTheme.labelLarge,
                _BadgeTile.width,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
