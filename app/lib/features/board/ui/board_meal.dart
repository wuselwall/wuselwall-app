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
      label: context.l10n.boardZoneMeal,
      onTap: () => unawaited(openMealWeek(context, board)),
      child: BoardRow(
        geometry: g,
        children: [
          for (var i = 0; i < BoardGeometry.dayCount; i++)
            if (board.days[i].meal case final meal?)
              Positioned(
                left: g.left(i),
                width: g.width(i),
                top: 0,
                bottom: 0,
                child: Opacity(
                  opacity: frame.opacity(i),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                    child: LayoutBuilder(
                      builder: (context, c) => ClipFit(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: c.maxWidth,
                          child: _MealCell(
                            board: board,
                            meal: meal,
                            // Two dish lines and the cook's line need about 112 canvas px.
                            twoLines: c.maxHeight >= 112,
                          ),
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
        _Dish(meal: meal, twoLines: twoLines),
        const SizedBox(height: 4),
        Row(
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
            if (meal.guests > 0) ...[
              const SizedBox(width: 4),
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
            ],
            if (cook != null) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  label: l10n.boardMealCook(context.memberName(board, cook)),
                  excludeSemantics: true,
                  child: Text(
                    context.memberName(board, cook),
                    style: boardCell(
                      24,
                      weight: FontWeight.w600,
                      color: ww.ink2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The dish. A one-word dish shrinks a little rather than break mid-word
/// ("Fischstäbch-en"); longer names may take a second line when there is room.
class _Dish extends StatelessWidget {
  const _Dish({required this.meal, required this.twoLines});

  final BoardMeal meal;
  final bool twoLines;

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
    if (!title.trim().contains(' ')) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(title, style: style, maxLines: 1, softWrap: false),
      );
    }
    return Text(
      title,
      style: style,
      maxLines: twoLines ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
