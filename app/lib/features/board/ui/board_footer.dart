import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_detail.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/details/task_board_detail.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/rituals/ui/countdown_widgets.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';

/// The bottom line: open tasks per member, the night indicator, and the shopping count.
/// The shopping count opens the tile picker; the task count only says what is coming.
class BoardFooter extends StatelessWidget {
  const BoardFooter({required this.board, required this.night, super.key});

  static const height = 56.0;

  final WeekBoard board;
  final bool night;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: ww.sunken,
        border: Border(top: BorderSide(color: ww.line)),
      ),
      // A6: the vertical padding above sits *outside* this row, so without a
      // floor here the row (and therefore each BoardTap's actual hit area)
      // could land under 56 px tall even though the container around it
      // meets `height` — a nominal 56 button that is not actually 56
      // (specs/17, t_da411148). ConstrainedBox gives IntrinsicHeight a real
      // minimum to stretch every tappable child to.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: height),
        child: IntrinsicHeight(
          child: Row(
            // Stretched so every item's tap target is the bar's full height, not
            // just its text's — the bar itself grows past `height` at larger text
            // scales (specs/09: preserve system text scaling, never clip or
            // overflow). IntrinsicHeight gives the Row a finite height to stretch
            // to, instead of the unbounded height its loose Column slot allows.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BoardTap(
                  label: l10n.boardOpenToday,
                  onTap: () => unawaited(
                    showBoardDetail(
                      context,
                      title: l10n.boardOpenToday,
                      body: const TaskBoardDetailBody(),
                    ),
                  ),
                  child: Center(child: _OpenTasks(board: board)),
                ),
              ),
              // Vorfreude: the nearest countdowns (specs/27), giving way first.
              const Flexible(flex: 2, child: Center(child: BoardCountdowns())),
              const SizedBox(width: 16),
              if (night) ...[
                Icon(Icons.nightlight_round, size: 28, color: ww.ink3),
                const SizedBox(width: 8),
                // Flexible, not a fixed child: at large text scales with a long
                // locale string ("Nachtmodus") this label gives way to the
                // shopping action below rather than forcing a RenderFlex
                // overflow (specs/09: truncate content, not font size).
                Flexible(
                  child: Text(
                    l10n.boardNightMode,
                    style: boardUi(24, weight: FontWeight.w600, color: ww.ink3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              // Flexible: the shopping action's own label/count truncate before
              // the Row overflows at larger text scales (specs/09).
              Flexible(
                child: BoardTap(
                  label: l10n.boardShoppingList,
                  onTap: () => unawaited(
                    showBoardDetail(
                      context,
                      title: l10n.boardShoppingList,
                      body: const Column(
                        children: [
                          Expanded(child: ShoppingBody()),
                          ActingProfileBar(),
                        ],
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_basket_outlined,
                        size: 32,
                        color: scheme.onSurface,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          l10n.boardShoppingList,
                          style: boardUi(
                            26,
                            weight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${board.shoppingCount}',
                        style: boardNum(
                          26,
                          weight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Heute offen: Emma 2 · Paul 1", or a tick when nothing is open.
class _OpenTasks extends StatelessWidget {
  const _OpenTasks({required this.board});

  final WeekBoard board;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final ink = Theme.of(context).colorScheme.onSurface;
    final open = [
      for (final m in board.members)
        if ((board.openTasks[m.id] ?? 0) > 0) (m, board.openTasks[m.id]!),
    ];

    if (MediaQuery.textScalerOf(context).scale(24) > 32) {
      return Text(
        open.isEmpty
            ? l10n.boardAllDone
            : '${l10n.boardOpenToday}: ${open.map((e) => '${context.memberName(board, e.$1)} ${e.$2}').join(' · ')}',
        style: boardUi(24, color: ink),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (open.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 30, color: ww.success),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              l10n.boardAllDone,
              style: boardUi(26, weight: FontWeight.w600, color: ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      children: [
        Text(
          l10n.boardOpenToday,
          style: boardUi(26, weight: FontWeight.w600, color: ww.ink2),
          maxLines: 1,
          softWrap: false,
        ),
        for (final (m, count) in open)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberDot(
                memberColor: m.color,
                semanticLabel: context.memberName(board, m),
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.memberName(board, m),
                  style: boardUi(26, weight: FontWeight.w600, color: ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: boardNum(26, weight: FontWeight.w700, color: ink),
                maxLines: 1,
                softWrap: false,
              ),
            ],
          ),
      ],
    );
  }
}
