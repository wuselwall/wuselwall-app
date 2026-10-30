import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_scroll_cue.dart';
import 'package:wuselwall/features/board/ui/details/detail_parts.dart';
import 'package:wuselwall/features/board/ui/details/timetable_grid.dart';

/// A child's Stundenplan for the week, in the paper timetable's own shape. Today's
/// column is raised; tomorrow's packing list sits underneath.
class ChildWeekDetailBody extends StatelessWidget {
  const ChildWeekDetailBody({
    required this.board,
    required this.memberId,
    super.key,
  });

  final WeekBoard board;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    final timetable = board.timetableOf(memberId);
    if (timetable == null) {
      return Center(
        child: Text(
          context.l10n.boardNoSchoolToday,
          style: detailUi(28, context.ww.ink2),
        ),
      );
    }
    final pack = packStripFor(context, board, memberId);
    return BoardScrollFade(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Tokens.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TimetableGrid(
              board: board,
              timetable: timetable,
              raisedIndex: board.todayIndex,
            ),
            if (pack != null) ...[const SizedBox(height: Tokens.space6), pack],
          ],
        ),
      ),
    );
  }
}
