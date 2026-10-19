import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/details/detail_parts.dart';

/// An adult's week, or a child's: one row per day with the deviations from the usual,
/// the appointments they are in, what they cook and (for a child) the school span.
/// Days already past recede; today is raised.
class MemberWeekDetailBody extends StatelessWidget {
  const MemberWeekDetailBody({
    required this.board,
    required this.memberId,
    super.key,
  });

  final WeekBoard board;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    final m = board.member(memberId);
    if (m == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Tokens.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < board.days.length; i++)
            _DayRow(board: board, member: m, index: i),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.board,
    required this.member,
    required this.index,
  });

  final WeekBoard board;
  final BoardMember member;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final day = board.days[index];
    final bands = board.presenceOn(member.id, index);
    final busy = day.busyUntil[member.id];
    final school = day.school[member.id];
    final meal = day.meal;
    final cooked = meal != null && meal.cookId == member.id ? meal : null;
    final own = [
      for (final e in day.events)
        if (e.attendeeIds.contains(member.id)) e,
    ];
    final usual = board.usualOn(member.id, index);

    return DayRow(
      date: day.date,
      raised: isSameDay(day.date, board.today),
      past: day.date.isBefore(board.today),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in bands)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space2),
              child: PresenceBandView(
                state: b.state,
                memberColor: member.color,
                label: context.presenceLabel(b.state, b.label),
                detail: b.starts != null && b.ends != null
                    ? context.span(b.starts!, b.ends!)
                    : null,
                tentative: b.tentative,
                openStart: !isSameDay(day.date, b.firstDay),
                openEnd: !isSameDay(day.date, b.lastDay),
                wraps: true,
              ),
            ),
          if (bands.isEmpty)
            if (usual.isNotEmpty)
              for (final place in usual)
                Padding(
                  padding: const EdgeInsets.only(bottom: Tokens.space2),
                  child: BaselineChip(
                    memberColor: member.color,
                    label: context.usualLabel(place),
                    wraps: true,
                  ),
                )
            else
              Text(l10n.boardNoDeviation, style: detailUi(24, ww.ink3)),
          if (busy != null)
            Text(
              l10n.boardBusyUntil(context.time(busy)),
              style: detailUi(24, ww.ink2),
            ),
          if (school != null && school.hasSchool)
            Text(
              l10n.boardSchoolSpan(context.span(school.starts!, school.ends!)),
              style: detailNum(24, ww.ink2, weight: FontWeight.w700),
            ),
          for (final e in own)
            Text(
              '${eventSpan(context, e)}  ${e.tentative ? '${e.title} ?' : e.title}',
              style: detailUi(24, ww.ink2),
            ),
          if (cooked != null)
            Text(
              '${l10n.boardCooking}: ${cooked.title ?? l10n.boardMealNothingPlanned}',
              style: detailUi(26, context.ink, weight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}
