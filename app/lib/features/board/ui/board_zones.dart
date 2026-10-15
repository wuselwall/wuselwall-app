import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/details/board_details.dart';

/// The day names row: each column's weekday and date,
/// today's column marked with a bar and "Heute" in place of its weekday. A public holiday
/// of the week shows its name under the date, which makes the row taller for that week.
/// Tapping a column opens that day.
class DayHeaderRow extends StatelessWidget {
  const DayHeaderRow({required this.frame, super.key});

  static const height = 44.0;

  /// The row's height when a day of the week is a public holiday: a second line for it.
  static const holidayHeight = 72.0;

  /// The height the row needs for [board]: [holidayHeight] when any day has a holiday.
  static double heightOf(WeekBoard board) =>
      board.days.any((d) => d.holiday != null) ? holidayHeight : height;

  final BoardFrame frame;

  @override
  Widget build(BuildContext context) {
    final board = frame.board;
    final g = frame.geometry;
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;
    final today = frame.todayIndex;

    return BoardRow(
      geometry: g,
      children: [
        for (var i = 0; i < BoardGeometry.dayCount; i++)
          Positioned(
            left: g.left(i),
            width: g.width(i),
            top: 0,
            bottom: 0,
            child: BoardTap(
              label: _label(context, board.days[i]),
              onTap: () => unawaited(openDayDetail(context, board, i)),
              child: Opacity(
                opacity: frame.opacity(i),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (i == today)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 4,
                        child: ColoredBox(color: scheme.primary),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ClipFit(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // A narrow column shrinks the line a little rather than
                            // cutting the date.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    // Today says so in words instead of a pill: the
                                    // column is wide, but not wide enough for both.
                                    i == today
                                        ? context.l10n.boardToday
                                        : context.weekdayShort(
                                            board.days[i].date,
                                          ),
                                    style: boardNum(
                                      28,
                                      weight: FontWeight.w700,
                                      color: i == today
                                          ? scheme.primary
                                          : scheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.dayMonth(board.days[i].date),
                                    style: boardNum(
                                      24,
                                      weight: FontWeight.w500,
                                      color: ww.ink2,
                                    ),
                                    maxLines: 1,
                                    softWrap: false,
                                  ),
                                ],
                              ),
                            ),
                            if (board.days[i].holiday case final holiday?)
                              ShrinkText(
                                holiday.name,
                                style: boardCell(
                                  24,
                                  weight: FontWeight.w600,
                                  color: ww.ink2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The column's label for screen readers: the date, and the holiday when there is one.
String _label(BuildContext context, BoardDay day) {
  final date = context.fullDate(day.date);
  final holiday = day.holiday;
  return holiday == null
      ? date
      : '$date, ${context.l10n.boardHolidayLabel(holiday.name)}';
}

/// Zone "Termine": three fixed day parts, each row holding the key appointments of that
/// part per day, two at most, then "+n weitere". Ticks with the clock only to dim the
/// appointments that have already ended today.
class TermineRows extends ConsumerWidget {
  const TermineRows({required this.frame, super.key});

  final BoardFrame frame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    return Column(
      children: [
        for (final part in DayPart.values)
          Expanded(
            child: _PartRow(frame: frame, part: part, now: now),
          ),
      ],
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.frame, required this.part, required this.now});

  final BoardFrame frame;
  final DayPart part;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final board = frame.board;
    final g = frame.geometry;
    final settings = board.settings;
    final ink = Theme.of(context).colorScheme.onSurface;

    return BoardRow(
      geometry: g,
      children: [
        Positioned(
          left: 0,
          width: BoardGeometry.gutter,
          top: 0,
          bottom: 0,
          // The part's name only: the appointments carry their own times, so the
          // part's boundaries would only add a line to read.
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ClipFit(
              alignment: Alignment.centerLeft,
              child: Text(
                context.dayPartLabel(part),
                style: boardUi(24, weight: FontWeight.w700, color: ink),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ),
        for (var i = 0; i < BoardGeometry.dayCount; i++)
          Positioned(
            left: g.left(i),
            width: g.width(i),
            top: 0,
            bottom: 0,
            child: BoardTap(
              label: context.fullDate(board.days[i].date),
              onTap: () => unawaited(openDayDetail(context, board, i)),
              child: Opacity(
                opacity: frame.opacity(i),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                  child: LayoutBuilder(
                    builder: (context, c) => ClipFit(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: c.maxWidth,
                        child: _DayPartCell(
                          board: board,
                          events: [
                            for (final e in frame.eventsOf(i))
                              if (settings.partOf(e.starts) == part) e,
                          ],
                          isToday: frame.isToday(i),
                          now: now,
                          // Two lines for a lone appointment need ~52 canvas px.
                          roomy: c.maxHeight >= 52,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The key appointments of one day part in one column. The layout follows the count, so
/// the common case reads best: one appointment gets two lines (time and dots, then the
/// whole title), two get a line each, more show the first and "+n weitere".
class _DayPartCell extends StatelessWidget {
  const _DayPartCell({
    required this.board,
    required this.events,
    required this.isToday,
    required this.now,
    required this.roomy,
  });

  final WeekBoard board;
  final List<BoardEvent> events;
  final bool isToday;
  final DateTime now;

  /// Whether a lone appointment may take two lines.
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final nowMinutes = now.hour * 60 + now.minute;
    // Today's appointments that are already over recede.
    bool ended(BoardEvent e) => isToday && _endMinutes(e) < nowMinutes;

    if (events.length == 1 && roomy) {
      final e = events.single;
      return _EventBlock(board: board, event: e, ended: ended(e));
    }
    final shown = events.length > 2 || !roomy ? [events.first] : events;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in shown)
          _EventLine(board: board, event: e, ended: ended(e)),
        if (events.length > shown.length)
          Text(
            l10n.boardMoreEvents(events.length - shown.length),
            style: boardUi(
              24,
              weight: FontWeight.w700,
              color: context.ww.ink2,
              height: 1.1,
            ),
            maxLines: 1,
            softWrap: false,
          ),
      ],
    );
  }
}

List<MemberDot> _dotsOf(
  BuildContext context,
  WeekBoard board,
  BoardEvent e, {
  double size = 12,
}) => [
  for (final id in e.attendeeIds)
    if (board.member(id) case final m?)
      MemberDot(
        memberColor: m.color,
        semanticLabel: context.memberName(board, m),
        size: size,
      ),
];

String _titleOf(BoardEvent e) => e.tentative ? '${e.title} ?' : e.title;

/// The tentative treatment: a dashed ink-3 outline around the appointment.
Widget _tentative(BuildContext context, BoardEvent e, Widget child) =>
    e.tentative
    ? CustomPaint(
        painter: DashedOutlinePainter(context.ww.ink3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: child,
        ),
      )
    : child;

/// A lone appointment: time (or "ganztägig") with the attendee dots, the title under it.
class _EventBlock extends StatelessWidget {
  const _EventBlock({
    required this.board,
    required this.event,
    required this.ended,
  });

  final WeekBoard board;
  final BoardEvent event;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final ink = Theme.of(context).colorScheme.onSurface;
    final start = event.starts;
    final dots = _dotsOf(context, board, event);
    final block = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                start == null
                    ? context.l10n.boardAllDay
                    : context.cellTime(start),
                style: start == null
                    ? boardUi(
                        24,
                        weight: FontWeight.w600,
                        color: ww.ink2,
                        height: 1.1,
                      )
                    : boardNum(
                        24,
                        weight: FontWeight.w700,
                        color: ww.ink2,
                        height: 1.1,
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            if (dots.isNotEmpty) MemberDots(dots: dots, size: 12),
          ],
        ),
        Text(
          _titleOf(event),
          style: boardCell(24, weight: FontWeight.w700, color: ink),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ],
    );
    return Opacity(
      opacity: ended ? 0.45 : 1,
      child: _tentative(context, event, block),
    );
  }
}

/// One of two or more appointments in a cell: time and title on one line, dots after.
class _EventLine extends StatelessWidget {
  const _EventLine({
    required this.board,
    required this.event,
    required this.ended,
  });

  final WeekBoard board;
  final BoardEvent event;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final ink = Theme.of(context).colorScheme.onSurface;
    final start = event.starts;
    final dots = _dotsOf(context, board, event, size: 10);
    final row = Row(
      children: [
        if (start != null) ...[
          Text(
            context.shortTime(start),
            style: boardNum(
              24,
              weight: FontWeight.w700,
              color: ww.ink2,
              height: 1.1,
            ),
            maxLines: 1,
            softWrap: false,
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            _titleOf(event),
            style: boardCell(24, weight: FontWeight.w600, color: ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
        if (dots.isNotEmpty) ...[
          const SizedBox(width: 4),
          // Two lines share the cell: the dots shrink so the title keeps its room.
          MemberDots(dots: dots, size: 10),
        ],
      ],
    );
    return Opacity(
      opacity: ended ? 0.45 : 1,
      child: _tentative(context, event, row),
    );
  }
}

/// When an appointment is over, in minutes after midnight; all-day ones never are.
int _endMinutes(BoardEvent e) {
  final end = e.ends ?? e.starts;
  return end == null ? 24 * 60 : minutesOf(end);
}

/// "Alle Termine" (FR-8.11): every day column shows all its appointments, not only the key
/// ones, so a forgotten key flag cannot hide one from the kitchen. The whole 56 px band is the
/// target; the switch is filled while on. The kiosk reverts it to key-only when it goes idle
/// (register_home_page.dart).
class BoardAllEventsToggle extends ConsumerWidget {
  const BoardAllEventsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;
    final on = ref.watch(boardAllEventsProvider);
    final ink = on ? scheme.onPrimaryContainer : scheme.onSurface;

    return Semantics(
      toggled: on,
      button: true,
      label: l10n.boardAllEvents,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(boardAllEventsProvider.notifier).set(!on),
        child: SizedBox(
          height: BoardDivider.controlHeight,
          child: Center(
            child: Container(
              height: BoardDivider.controlHeight - 8,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: on ? scheme.primaryContainer : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: on ? scheme.primary : ww.ink3,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    on ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 26,
                    color: ink,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.boardAllEvents,
                    style: boardUi(24, weight: FontWeight.w700, color: ink),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
