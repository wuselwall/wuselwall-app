import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_detail.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/details/child_week_detail.dart';
import 'package:wuselwall/features/board/ui/details/day_detail.dart';
import 'package:wuselwall/features/board/ui/details/detail_parts.dart';
import 'package:wuselwall/features/board/ui/details/meal_week_detail.dart';
import 'package:wuselwall/features/board/ui/details/member_week_detail.dart';
import 'package:wuselwall/features/board/ui/details/school_day_detail.dart';

/// Tap on a day column header or an empty part of a column: that day in full — every
/// appointment, every child's lessons, every presence band, the meal.
Future<void> openDayDetail(
  BuildContext context,
  WeekBoard board,
  int dayIndex,
) {
  final day = board.days[dayIndex];
  return showBoardDetail(
    context,
    title: context.fullDate(day.date),
    subtitle: isSameDay(day.date, board.today) ? context.l10n.boardToday : null,
    body: DayDetailBody(board: board, dayIndex: dayIndex, host: context),
  );
}

/// Tap on a child's name: that child's Stundenplan for the week, in the paper
/// timetable's own shape.
Future<void> openChildWeek(
  BuildContext context,
  WeekBoard board,
  String memberId,
) {
  final l10n = context.l10n;
  final timetable = board.timetableOf(memberId);
  final name = nameOf(context, board, memberId) ?? '';
  return showBoardDetail(
    context,
    title: l10n.boardTimetableTitle(name),
    subtitle: timetable == null
        ? null
        : joinParts([
            if (timetable.classLabel case final label?) l10n.boardClass(label),
            timetable.schoolName,
          ]),
    body: ChildWeekDetailBody(board: board, memberId: memberId),
  );
}

/// Tap on a child's school cell: that school day Stunde by Stunde, with the week grid
/// underneath and that day raised.
Future<void> openSchoolDay(
  BuildContext context,
  WeekBoard board,
  String memberId,
  int dayIndex,
) {
  final name = nameOf(context, board, memberId) ?? '';
  final day = board.days[dayIndex];
  return showBoardDetail(
    context,
    title: '$name · ${context.weekdayLong(day.date)}',
    subtitle: _schoolSubtitle(context, day.school[memberId]),
    body: SchoolDayDetailBody(
      board: board,
      memberId: memberId,
      dayIndex: dayIndex,
    ),
  );
}

/// Tap on an adult's name or presence cell: their week — baseline, deviations,
/// appointments, what they cook.
Future<void> openMemberWeek(
  BuildContext context,
  WeekBoard board,
  String memberId,
) {
  final member = board.member(memberId);
  final baseline = member?.baseline;
  return showBoardDetail(
    context,
    title: context.l10n.boardWeekOf(
      member == null ? '' : context.memberName(board, member),
    ),
    subtitle: baseline == null
        ? null
        : context.l10n.boardBaseline(
            context.presenceLabel(baseline.state, baseline.label),
          ),
    body: MemberWeekDetailBody(board: board, memberId: memberId),
  );
}

/// Tap on the meal zone: the week's meals with who is eating.
Future<void> openMealWeek(BuildContext context, WeekBoard board) =>
    showBoardDetail(
      context,
      title: context.l10n.boardMealWeek,
      body: MealWeekDetailBody(board: board),
    );

/// "Klasse 5b · Gesamtschule", or the care that is still on: "Mittwoch … · Betreuung bis
/// 15:00". Null when the day has no school data at all.
String? _schoolSubtitle(BuildContext context, SchoolDay? school) {
  if (school == null) return null;
  final l10n = context.l10n;
  final s = school.starts;
  final e = school.ends;
  if (s == null || e == null) {
    return school.holidayName ??
        (school.free == FreeReason.weekend
            ? l10n.boardWeekend
            : l10n.boardNoSchoolToday);
  }
  final care = school.careUntil;
  return joinParts([
    l10n.boardSchoolSpan(context.span(s, e)),
    if (care != null)
      l10n.boardCareUntil(
        school.careLabel ?? l10n.boardCareDefault,
        context.time(care),
      ),
  ]);
}
