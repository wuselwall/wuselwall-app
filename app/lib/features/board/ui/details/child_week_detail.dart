import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_scroll_cue.dart';
import 'package:wuselwall/features/board/ui/details/detail_parts.dart';
import 'package:wuselwall/features/board/ui/details/timetable_grid.dart';
import 'package:wuselwall/features/school/ui/pack_item_sheet.dart';

/// A child's Stundenplan for the week, in the paper timetable's own shape. Today's
/// column is raised; tomorrow's packing list sits underneath, with the things noted for
/// tomorrow to remove and one more to note while someone who may is acting (specs/15).
/// A child without a timetable sees only the packing part.
class ChildWeekDetailBody extends ConsumerWidget {
  const ChildWeekDetailBody({
    required this.board,
    required this.memberId,
    super.key,
  });

  final WeekBoard board;
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While someone may note things, the live board of the same week: a thing noted or
    // removed here shows at once. At rest, the board the detail was opened with.
    final canNote = ref.watch(canNotePackItemProvider);
    final live = canNote ? ref.watch(boardProvider).board : null;
    final board = live != null && live.weekStart == this.board.weekStart
        ? live
        : this.board;
    final timetable = board.timetableOf(memberId);
    final pack = packStripFor(context, board, memberId);
    final today = board.todayIndex;
    final tomorrow = today == null
        ? null
        : DateTime(board.today.year, board.today.month, board.today.day + 1);
    final noted = today != null && today + 1 < board.days.length
        ? board.days[today + 1].packOf(memberId)
        : const <PackItem>[];
    final theme = Theme.of(context);
    final chips = tomorrow == null
        ? null
        : Theme(
            // Kiosk size: read from across the kitchen, tapped standing.
            data: theme.copyWith(
              chipTheme: theme.chipTheme.copyWith(
                labelStyle: detailUi(22, context.ink),
                padding: const EdgeInsets.all(Tokens.space2),
              ),
            ),
            child: PackItemChips(
              childId: memberId,
              date: tomorrow,
              items: noted,
            ),
          );
    return BoardScrollFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Tokens.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (timetable != null)
              TimetableGrid(
                board: board,
                timetable: timetable,
                raisedIndex: board.todayIndex,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Tokens.space6),
                child: Text(
                  context.l10n.boardNoSchoolToday,
                  textAlign: TextAlign.center,
                  style: detailUi(28, context.ww.ink2),
                ),
              ),
            if (pack != null) ...[const SizedBox(height: Tokens.space6), pack],
            if (chips != null) ...[
              const SizedBox(height: Tokens.space4),
              Align(alignment: AlignmentDirectional.centerStart, child: chips),
            ],
          ],
        ),
      ),
    );
  }
}
