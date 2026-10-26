import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/board_scroll_cue.dart';
import 'package:wuselwall/features/board/ui/details/board_details.dart';
import 'package:wuselwall/features/board/ui/details/detail_parts.dart';

/// One day in full (specs/09 "Touch behaviour"): every appointment on the left, who is
/// where and the hot meal on the right. Tapping a child's school line opens that school
/// day; [host] is the page the detail was opened from, still mounted after the pop.
class DayDetailBody extends ConsumerWidget {
  const DayDetailBody({
    required this.board,
    required this.dayIndex,
    required this.host,
    super.key,
  });

  final WeekBoard board;
  final int dayIndex;
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final nowMinutes = minutesOf(TimeOfDay.fromDateTime(now));
    final day = board.days[dayIndex];
    final isToday = isSameDay(day.date, board.today);
    final holiday = day.holiday;
    return Padding(
      padding: const EdgeInsets.all(Tokens.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (holiday != null) ...[
            Text(
              context.l10n.boardHolidayLabel(holiday.name),
              style: detailUi(26, context.ww.ink2, weight: FontWeight.w700),
            ),
            const SizedBox(height: Tokens.space4),
          ],
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: BoardScrollFade(
                    child: SingleChildScrollView(
                      child: _Appointments(
                        board: board,
                        dayIndex: dayIndex,
                        isToday: isToday,
                        nowMinutes: nowMinutes,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Tokens.space8),
                Expanded(
                  flex: 2,
                  child: BoardScrollFade(
                    child: SingleChildScrollView(
                      child: _WhoAndMeal(
                        board: board,
                        dayIndex: dayIndex,
                        host: host,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Appointments extends StatelessWidget {
  const _Appointments({
    required this.board,
    required this.dayIndex,
    required this.isToday,
    required this.nowMinutes,
  });

  final WeekBoard board;
  final int dayIndex;
  final bool isToday;
  final int nowMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final events = board.days[dayIndex].events;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailHeading(l10n.boardAppointmentsOf),
        if (events.isEmpty)
          Text(l10n.boardNoAppointments, style: detailUi(26, context.ww.ink3)),
        for (final e in events)
          _EventRow(
            event: e,
            board: board,
            isToday: isToday,
            nowMinutes: nowMinutes,
          ),
      ],
    );
  }
}

/// The title's line box is 26 px at height 1.2 before the text scale; the attendee
/// dot is centred on it.
const _dotSize = 20.0;

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.board,
    required this.isToday,
    required this.nowMinutes,
  });

  final BoardEvent event;
  final WeekBoard board;
  final bool isToday;
  final int nowMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final e = event;
    final scaler = MediaQuery.textScalerOf(context);
    final end = e.ends ?? e.starts;
    final over = isToday && end != null && minutesOf(end) < nowMinutes;
    final attendees = [
      for (final m in board.members)
        if (e.attendeeIds.contains(m.id)) m,
    ];
    // An appointment that is over recedes to the sunken ground; its text keeps its
    // full colour, so specs/17's 4.5:1 holds (t_10f0b348). Every row has the same
    // inset, so the columns line up whether a row is over or not.
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: over ? ww.sunken : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The time column grows with the text scale, so "ganztägig" and a
              // span stay whole words at 200 % (t_10f0b348).
              SizedBox(
                width: scaler.scale(150),
                child: Text(
                  eventSpan(context, e),
                  style: e.isAllDay
                      ? detailUi(26, ww.ink2, weight: FontWeight.w700)
                      : detailNum(26, context.ink, weight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.tentative ? '${e.title} ?' : e.title,
                      style: detailUi(26, context.ink, weight: FontWeight.w700),
                    ),
                    if (e.location case final location?)
                      Text(location, style: detailUi(24, ww.ink2)),
                    if (e.tentative)
                      Text(l10n.boardTentative, style: detailUi(24, ww.ink2)),
                  ],
                ),
              ),
              if (attendees.isNotEmpty) ...[
                const SizedBox(width: Tokens.space3),
                // Centred on the title line, so the dots read as the title's own.
                Padding(
                  padding: EdgeInsets.only(
                    top: (scaler.scale(26) * 1.2 - _dotSize) / 2,
                  ),
                  child: MemberDots(
                    size: _dotSize,
                    dots: [
                      for (final m in attendees)
                        MemberDot(
                          memberColor: m.color,
                          size: _dotSize,
                          semanticLabel: context.memberName(board, m),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WhoAndMeal extends StatelessWidget {
  const _WhoAndMeal({
    required this.board,
    required this.dayIndex,
    required this.host,
  });

  final WeekBoard board;
  final int dayIndex;
  final BuildContext host;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailHeading(l10n.boardZoneWhere),
        for (final m in board.members) _memberBlock(context, m),
        const SizedBox(height: Tokens.space4),
        DetailHeading(l10n.boardZoneMeal),
        Container(
          padding: const EdgeInsets.all(Tokens.space4),
          decoration: BoxDecoration(
            color: context.ww.sunken,
            borderRadius: BorderRadius.circular(14),
          ),
          child: MealFacts(board: board, meal: board.days[dayIndex].meal),
        ),
      ],
    );
  }

  Widget _memberBlock(BuildContext context, BoardMember m) {
    final ww = context.ww;
    final day = board.days[dayIndex];
    final bands = board.presenceOn(m.id, dayIndex);
    final busy = day.busyUntil[m.id];
    final school = day.school[m.id];
    final usual = board.usualOn(m.id, dayIndex);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // 48 px, so the initial is the kiosk's 24 px minimum; the circle grows
              // with the text scale so the scaled initial still fits (t_10f0b348).
              MemberAvatar(member: m, size: 48, growsWithText: true),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(
                  context.memberName(board, m),
                  style: detailUi(26, context.ink, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space2),
          for (final b in bands)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space2),
              child: _band(context, b, m, dayIndex),
            ),
          if (bands.isEmpty)
            for (final place in usual)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space2),
                child: BaselineChip(
                  memberColor: m.color,
                  label: context.usualLabel(place),
                  wraps: true,
                ),
              ),
          if (busy != null)
            Text(
              context.l10n.boardBusyUntil(context.time(busy)),
              style: detailUi(24, ww.ink2),
            ),
          if (school != null && school.hasSchool)
            _SchoolLine(
              school: school,
              onTap: () {
                Navigator.of(context).pop();
                unawaited(openSchoolDay(host, board, m.id, dayIndex));
              },
            ),
        ],
      ),
    );
  }

  Widget _band(BuildContext context, PresenceBand b, BoardMember m, int index) {
    final day = board.days[index].date;
    final s = b.starts;
    final e = b.ends;
    return PresenceBandView(
      state: b.state,
      memberColor: m.color,
      label: context.presenceLabel(b.state, b.label),
      detail: s != null && e != null ? context.span(s, e) : null,
      tentative: b.tentative,
      openStart: !isSameDay(day, b.firstDay),
      openEnd: !isSameDay(day, b.lastDay),
      wraps: true,
    );
  }
}

/// A child's school span with its notable lessons and care; tapping it opens the day.
class _SchoolLine extends StatelessWidget {
  const _SchoolLine({required this.school, required this.onTap});

  final SchoolDay school;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final s = school.starts!;
    final e = school.ends!;
    final care = school.careUntil;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.boardSchoolSpan(context.span(s, e)),
              style: detailNum(26, context.ink, weight: FontWeight.w700),
            ),
            if (school.notable.isNotEmpty)
              Text(school.notable.join(' · '), style: detailUi(24, ww.ink2)),
            if (care != null)
              Text(
                l10n.boardCareUntil(
                  school.careLabel ?? l10n.boardCareDefault,
                  context.time(care),
                ),
                style: detailUi(24, ww.ink2),
              ),
          ],
        ),
      ),
    );
  }
}
