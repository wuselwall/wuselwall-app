import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/details/board_details.dart';

/// Zone "Warmes Essen": one warm meal per day. The whole zone is one tap target.
class MealRow extends StatelessWidget {
  const MealRow({required this.frame, super.key});

  final BoardFrame frame;

  @override
  Widget build(BuildContext context) {
    final board = frame.board;
    final g = frame.geometry;
    return BoardTap(
      label: [
        context.l10n.boardZoneMeal,
        for (final day in board.days)
          if (day.meal case final meal?) ...[
            context.fullDate(day.date),
            meal.title ?? context.l10n.boardMealNothingPlanned,
            if (board.member(meal.wishedBy ?? '') case final wisher?)
              context.l10n.mealsWishedBy(context.memberName(board, wisher)),
            if (meal.time case final time?) context.time(time),
            if (board.member(meal.cookId ?? '') case final cook?)
              context.l10n.boardMealCook(context.memberName(board, cook)),
            for (final member in board.members)
              (meal.eating.contains(member.id)
                  ? context.l10n.boardEating
                  : context.l10n.boardNotEating)(
                context.memberName(board, member),
              ),
            if (meal.guests > 0) context.l10n.boardMealGuests(meal.guests),
          ],
      ].join(', '),
      onTap: () => unawaited(openMealWeek(context, board)),
      child: BoardRow(
        geometry: g,
        children: [
          // The zone's name in the gutter, where the other zones name their rows.
          Positioned(
            left: 12,
            width: BoardGeometry.gutter - 20,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.boardZoneMeal,
                style: boardUi(
                  24,
                  weight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          for (var i = 0; i < BoardGeometry.dayCount; i++)
            if (board.days[i].meal case final meal?)
              Positioned(
                left: g.left(i),
                width: g.width(i),
                top: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                  child: LayoutBuilder(
                    builder: (context, c) =>
                        c.maxHeight <
                            MediaQuery.textScalerOf(context).scale(112)
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: _Dish(
                              meal: meal,
                              twoLines: false,
                              wishInk: _wishInk(context, board, meal),
                            ),
                          )
                        : ClipFit(
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: c.maxWidth,
                              child: _MealCell(
                                board: board,
                                meal: meal,
                                // Reserve time, two dish lines and wrapped metadata
                                // at the real scaler, not unscaled canvas heights.
                                twoLines:
                                    c.maxHeight >=
                                    MediaQuery.textScalerOf(context).scale(140),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// One day's meal: the slot as a sun or moon with its time (and guests), the dish on up
/// to two lines when the zone is tall enough, then a dot per member — filled when they
/// eat — and who is cooking.
class _MealCell extends StatelessWidget {
  const _MealCell({
    required this.board,
    required this.meal,
    required this.twoLines,
  });

  final WeekBoard board;
  final BoardMeal meal;

  /// Whether the dish may wrap onto a second line.
  final bool twoLines;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final time = meal.time;
    final cook = meal.cookId == null ? null : board.member(meal.cookId!);
    final slot = context.mealSlotLabel(meal.slot);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: [slot, ?(time == null ? null : context.time(time))].join(' '),
          excludeSemantics: true,
          child: Row(
            children: [
              Icon(
                meal.slot == MealSlot.lunch
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_outlined,
                size: 22,
                color: ww.ink3,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  time == null ? slot : context.time(time),
                  style: boardNum(
                    24,
                    weight: FontWeight.w600,
                    color: ww.ink3,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        _Dish(
          meal: meal,
          twoLines: twoLines,
          wishInk: _wishInk(context, board, meal),
        ),
        const SizedBox(height: 4),
        // The cook stays beside the dots while there is room, else takes the next
        // line; the dots and the guest count are separate Wrap children too, so a
        // crowded household's dots alone cannot force a fixed-width overflow.
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MemberDots(
              size: 12,
              dots: [
                for (final m in board.members)
                  MemberDot(
                    memberColor: m.color,
                    filled: meal.eating.contains(m.id),
                    size: 12,
                    semanticLabel: meal.eating.contains(m.id)
                        ? l10n.boardEating(context.memberName(board, m))
                        : l10n.boardNotEating(context.memberName(board, m)),
                  ),
              ],
            ),
            if (meal.guests > 0)
              Semantics(
                label: l10n.boardMealGuests(meal.guests),
                excludeSemantics: true,
                child: Text(
                  l10n.boardMoreCount(meal.guests),
                  style: boardCell(24, weight: FontWeight.w700, color: ww.ink2),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            if (cook != null)
              Semantics(
                label: l10n.boardMealCook(context.memberName(board, cook)),
                excludeSemantics: true,
                child: Text(
                  context.memberName(board, cook),
                  style: boardCell(24, weight: FontWeight.w600, color: ww.ink2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The dish truncates at the real text size, including a single long word.
/// A second line is allowed only when its scaled height fits the zone.
class _Dish extends StatelessWidget {
  const _Dish({required this.meal, required this.twoLines, this.wishInk});

  final BoardMeal meal;
  final bool twoLines;

  /// The wisher's ink: the dish then carries a star (specs/27 "Wunschessen").
  final Color? wishInk;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final title = meal.title;
    if (title == null) {
      return Text(
        context.l10n.boardMealNothingPlanned,
        style: boardCell(
          24,
          weight: FontWeight.w500,
          color: ww.ink3,
          italic: true,
        ),
        maxLines: twoLines ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final style = boardCell(
      24,
      weight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    );

    final text = Text(
      title,
      style: style,
      maxLines: twoLines ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );
    final ink = wishInk;
    if (ink == null) return text;
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 26, color: ink),
        const SizedBox(width: 4),
        Expanded(child: text),
      ],
    );
  }
}

/// The ink of the member whose wish [meal] is, or null.
Color? _wishInk(BuildContext context, WeekBoard board, BoardMeal meal) =>
    switch (board.member(meal.wishedBy ?? '')) {
      final m? => context.ww.member(m.color).ink,
      null => null,
    };
