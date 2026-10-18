import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/details/detail_parts.dart';

const _labelWidth = 150.0;
const _days = 5;

/// A break row: the Pause label in the left column, 22 px tall, no extra height.
const _breakHeight = 22.0;

/// The paper Stundenplan (specs/09 "Touch behaviour"): numbered Stunden down the left
/// with their bell times, Monday to Friday across the top. Lessons without a Stunde
/// (Hort, an AG) get rows of their own at the bottom. Empty cells stay empty; the
/// [raisedIndex] column is today, or the day that was tapped.
class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    required this.board,
    required this.timetable,
    this.raisedIndex,
    this.compact = false,
    super.key,
  });

  final WeekBoard board;
  final BoardTimetable timetable;

  /// 0–4, the column to raise; null or a weekend index raises nothing.
  final int? raisedIndex;

  /// Under a school day: no room line, tighter cells.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final raised = raisedIndex;
    final lessonsByDay = [
      for (var i = 0; i < _days; i++)
        board.days[i].school[timetable.memberId]?.lessons ?? const <Lesson>[],
    ];
    final periodIndexes = {
      for (final p in timetable.periods)
        if (p.kind == PeriodKind.lesson) p.index,
    };
    bool onGrid(Lesson l) =>
        l.period != null && periodIndexes.contains(l.period);

    final extras = <String, Lesson>{};
    for (final lessons in lessonsByDay) {
      for (final l in lessons) {
        if (!onGrid(l)) extras.putIfAbsent(_extraKey(l), () => l);
      }
    }
    final extraRows = extras.values.toList()
      ..sort((a, b) => minutesOf(a.starts).compareTo(minutesOf(b.starts)));

    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: _labelWidth),
            for (var i = 0; i < _days; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Text(
                        context.weekdayShort(board.days[i].date),
                        style: detailUi(
                          24,
                          raised == i ? context.accent : ww.ink2,
                          weight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        context.dayMonth(board.days[i].date),
                        style: detailNum(
                          24,
                          raised == i ? context.accent : ww.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        for (final p in timetable.periods)
          if (p.kind == PeriodKind.breakTime)
            _breakRow(context, raised)
          else
            _row(
              context,
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.boardPeriod(p.index),
                    style: detailUi(
                      24,
                      context.ink,
                      weight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  Text(
                    context.span(p.starts, p.ends),
                    style: detailNum(24, ww.ink2, height: 1),
                  ),
                ],
              ),
              cells: [
                for (final lessons in lessonsByDay)
                  lessons.where((l) => l.period == p.index).firstOrNull,
              ],
              raised: raised,
            ),
        for (final extra in extraRows)
          _row(
            context,
            label: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  extra.subject,
                  style: detailUi(
                    24,
                    context.ink,
                    weight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                Text(
                  context.span(extra.starts, extra.ends),
                  style: detailNum(24, ww.ink2, height: 1),
                ),
              ],
            ),
            cells: [
              for (final lessons in lessonsByDay)
                lessons
                    .where(
                      (l) => !onGrid(l) && _extraKey(l) == _extraKey(extra),
                    )
                    .firstOrNull,
            ],
            raised: raised,
          ),
      ],
    );

    if (raised == null || raised < 0 || raised >= _days) return grid;
    // Today's column is one frame, not a box per cell: its ground is painted behind the
    // grid, its 2 px primary border over it, both measured from the equal column widths.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - _labelWidth) / _days;
        final left = _labelWidth + columnWidth * raised;
        final scheme = Theme.of(context).colorScheme;
        return Stack(
          children: [
            Positioned(
              left: left,
              width: columnWidth,
              top: 0,
              bottom: 0,
              child: ColoredBox(color: scheme.surfaceContainerLow),
            ),
            grid,
            Positioned(
              left: left,
              width: columnWidth,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// A row of the grid: one Stunde (or an extra row) across the five days. Cells take
  /// the height of the tallest one, so the hairlines stay straight.
  Widget _row(
    BuildContext context, {
    required Widget label,
    required List<Lesson?> cells,
    required int? raised,
  }) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _labelWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
            child: label,
          ),
        ),
        for (var i = 0; i < _days; i++)
          Expanded(
            child: _Cell(
              raised: raised == i,
              child: cells[i] == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.all(2),
                      child: PaperTile(
                        tint: cells[i]!.tint,
                        struckThrough:
                            cells[i]!.status == LessonStatus.cancelled,
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: compact ? 3 : 6,
                        ),
                        child: LessonBody(
                          lesson: cells[i]!,
                          title: cells[i]!.shortName ?? cells[i]!.subject,
                          titleSize: 24,
                          showRoom: !compact,
                          dense: true,
                        ),
                      ),
                    ),
            ),
          ),
      ],
    ),
  );

  /// A break: a slim row with the Pause label in the left column and empty cells. It
  /// is as tall as its label at the current text scale, so the label is never cut.
  Widget _breakRow(BuildContext context, int? raised) => SizedBox(
    height: math.max(_breakHeight, MediaQuery.textScalerOf(context).scale(24)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _labelWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.l10n.boardBreak,
              style: detailUi(24, context.ww.ink3, height: 1),
            ),
          ),
        ),
        for (var i = 0; i < _days; i++)
          Expanded(child: _Cell(raised: raised == i, child: null)),
      ],
    ),
  );

  static String _extraKey(Lesson l) =>
      '${l.subject}|${minutesOf(l.starts)}|${minutesOf(l.ends)}';
}

/// One grid cell: a sunken hairline box. The raised column's cells draw nothing: its
/// ground and frame are one piece painted over the whole column.
class _Cell extends StatelessWidget {
  const _Cell({required this.raised, required this.child});

  final bool raised;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final body = child ?? const SizedBox.shrink();
    if (raised) return body;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ww.sunken,
        border: Border.all(color: ww.line),
      ),
      child: body,
    );
  }
}

/// A lesson's text inside its paper tile: the name in [title], the room (and teacher)
/// beneath, then the status the household needs to see: Entfall, Vertretung, a room
/// change, an extra lesson, and the note ("Frau Klein"). [dense] is the grid's tight
/// cell: the narrow face, lines set solid.
class LessonBody extends StatelessWidget {
  const LessonBody({
    required this.lesson,
    required this.title,
    this.titleSize = 26,
    this.showRoom = true,
    this.showTeacher = false,
    this.dense = false,
    super.key,
  });

  final Lesson lesson;
  final String title;
  final double titleSize;
  final bool showRoom;
  final bool showTeacher;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final where = joinParts([
      if (showRoom) lesson.room,
      if (showTeacher) lesson.teacher,
    ]);
    final status = switch (lesson.status) {
      LessonStatus.cancelled => l10n.boardLessonCancelled,
      LessonStatus.substituted => l10n.boardLessonSubstituted,
      LessonStatus.roomChange => l10n.boardLessonRoomChange,
      LessonStatus.extra => l10n.boardLessonExtra,
      LessonStatus.normal => null,
    };
    final note = lesson.note;
    final titleStyle = dense
        ? boardCell(
            titleSize,
            weight: FontWeight.w800,
            color: context.ink,
            height: 1,
          )
        : detailUi(titleSize, context.ink, weight: FontWeight.w800);
    final whereStyle = dense
        ? boardCell(24, weight: FontWeight.w600, color: ww.ink2, height: 1)
        : detailUi(24, ww.ink2);
    // No line limits, also in the grid's dense cell: a long name or room wraps and its
    // row grows, so nothing ends in an ellipsis at 150 or 200 % text (t_10f0b348).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        if (where.isNotEmpty) Text(where, style: whereStyle),
        if (status != null)
          Text(
            status,
            style: detailUi(
              24,
              lesson.status == LessonStatus.substituted
                  ? context.accent
                  : context.ink,
              weight: FontWeight.w700,
            ),
          ),
        if (note != null && note.isNotEmpty)
          Text(note, style: detailUi(24, ww.ink2)),
      ],
    );
  }
}
