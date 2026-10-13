import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/details/detail_parts.dart';
import 'package:wuselwall/features/board/ui/details/timetable_grid.dart';

/// One school day, Stunde by Stunde (specs/09 "Touch behaviour"): bell times, the
/// subject in its paper tile, the long breaks between, what is over and what is on
/// now, then the whole week's grid underneath with this day raised.
class SchoolDayDetailBody extends ConsumerWidget {
  const SchoolDayDetailBody({
    required this.board,
    required this.memberId,
    required this.dayIndex,
    super.key,
  });

  final WeekBoard board;
  final String memberId;
  final int dayIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final school = board.days[dayIndex].school[memberId];
    if (school == null || (!school.hasSchool && school.lessons.isEmpty)) {
      return Center(
        child: Text(
          l10n.boardNoSchoolToday,
          style: detailUi(28, context.ww.ink2),
        ),
      );
    }
    final timetable = board.timetableOf(memberId);
    final isToday = board.todayIndex == dayIndex;
    final now = ref.watch(nowProvider);
    final nowMinutes = minutesOf(TimeOfDay.fromDateTime(now));
    final entries = _entries(context, school, timetable);
    final pack = packStripFor(context, board, memberId, viewedIndex: dayIndex);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Tokens.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in entries)
            _entryRow(
              context,
              entry: e,
              isToday: isToday,
              nowMinutes: nowMinutes,
            ),
          if (pack != null) ...[const SizedBox(height: Tokens.space4), pack],
          if (timetable != null) ...[
            const SizedBox(height: Tokens.space8),
            DetailHeading(l10n.boardWholeWeek),
            TimetableGrid(
              board: board,
              timetable: timetable,
              raisedIndex: dayIndex,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }

  /// The day's rows in time order: the timetable's Stunden and breaks, then the rows
  /// off the grid (Hort, an AG). A break is shown only between two lessons.
  List<_Entry> _entries(
    BuildContext context,
    SchoolDay school,
    BoardTimetable? timetable,
  ) {
    final l10n = context.l10n;
    final periods = timetable?.periods ?? const <SchoolPeriod>[];
    final gridIndexes = {
      for (final p in periods)
        if (p.kind == PeriodKind.lesson) p.index,
    };
    final onGrid = <Lesson>{};
    final entries = <_Entry>[];
    for (final p in periods) {
      if (p.kind == PeriodKind.breakTime) {
        entries.add(_Entry(starts: p.starts, ends: p.ends, isBreak: true));
        continue;
      }
      final lesson = school.lessons
          .where((l) => l.period == p.index && gridIndexes.contains(l.period))
          .firstOrNull;
      if (lesson == null) continue;
      onGrid.add(lesson);
      entries.add(
        _Entry(
          starts: p.starts,
          ends: p.ends,
          periodLabel: l10n.boardPeriod(p.index),
          lesson: lesson,
        ),
      );
    }
    final rest = school.lessons.where((l) => !onGrid.contains(l)).toList()
      ..sort((a, b) => minutesOf(a.starts).compareTo(minutesOf(b.starts)));
    for (final l in rest) {
      entries.add(_Entry(starts: l.starts, ends: l.ends, lesson: l));
    }

    bool lessonIn(Iterable<_Entry> xs) => xs.any((e) => !e.isBreak);
    return [
      for (var i = 0; i < entries.length; i++)
        if (!entries[i].isBreak ||
            (lessonIn(entries.take(i)) && lessonIn(entries.skip(i + 1))))
          entries[i],
    ];
  }

  Widget _entryRow(
    BuildContext context, {
    required _Entry entry,
    required bool isToday,
    required int nowMinutes,
  }) {
    final l10n = context.l10n;
    final ww = context.ww;
    final endMinutes = minutesOf(entry.ends);
    final startMinutes = minutesOf(entry.starts);
    final past = isToday && endMinutes <= nowMinutes;
    final current =
        isToday && startMinutes <= nowMinutes && nowMinutes < endMinutes;
    final lesson = entry.lesson;

    if (entry.isBreak) {
      // A break is one slim line, indented to the tile column.
      return Opacity(
        opacity: past ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.only(
            left: _timeColumnWidth,
            bottom: Tokens.space2,
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l10n.boardBreak, style: detailUi(24, ww.ink3)),
                const TextSpan(text: ' '),
                TextSpan(
                  text: context.span(entry.starts, entry.ends),
                  style: detailNum(24, ww.ink3, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: past ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Tokens.space3),
        child: Container(
          padding: const EdgeInsets.only(left: Tokens.space3),
          decoration: current
              ? BoxDecoration(
                  border: Border(
                    left: BorderSide(color: context.accent, width: 3),
                  ),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _timeColumnWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.span(entry.starts, entry.ends),
                      style: detailNum(
                        26,
                        context.ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                    if (entry.periodLabel != null)
                      Text(entry.periodLabel!, style: detailUi(24, ww.ink2)),
                  ],
                ),
              ),
              if (lesson != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _tileMaxWidth,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (current)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Tokens.space2,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: context.accent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Tokens.space3,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      l10n.boardLessonNow,
                                      style: detailUi(
                                        24,
                                        Theme.of(context).colorScheme.onPrimary,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            PaperTile(
                              tint: lesson.tint,
                              struckThrough:
                                  lesson.status == LessonStatus.cancelled,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Tokens.space4,
                                vertical: Tokens.space3,
                              ),
                              child: LessonBody(
                                lesson: lesson,
                                title: lesson.subject,
                                titleSize: 28,
                                showTeacher: true,
                              ),
                            ),
                            if (past)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: Tokens.space2,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check, size: 28, color: ww.ink2),
                                    const SizedBox(width: Tokens.space2),
                                    Text(
                                      l10n.boardLessonOver,
                                      style: detailUi(24, ww.ink2),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
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

/// The left column of a day row: the bell span and the period, and the width the
/// lesson tiles start after.
const _timeColumnWidth = 170.0;

/// Lesson tiles stop growing here, so a wide wall does not stretch a line of text.
const _tileMaxWidth = 720.0;

/// A row of the day: a Stunde (with its lesson), a break, or a row off the grid.
class _Entry {
  const _Entry({
    required this.starts,
    required this.ends,
    this.isBreak = false,
    this.periodLabel,
    this.lesson,
  });

  final TimeOfDay starts;
  final TimeOfDay ends;
  final bool isBreak;
  final String? periodLabel;
  final Lesson? lesson;
}
