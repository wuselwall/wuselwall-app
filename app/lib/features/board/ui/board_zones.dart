import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/details/board_details.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';

/// The day names row: each column's weekday and date,
/// today's column marked with a bar and "Heute" in place of its weekday. A public holiday
/// of the week shows its name under the date, which makes the row taller for that week.
/// Tapping a column opens that day.
class DayHeaderRow extends StatelessWidget {
  const DayHeaderRow({required this.frame, super.key});

  // A6: this row is each day's primary tap target (it opens that day's detail),
  // not a decorative band, so its actual hit area must clear the kiosk's real
  // 56 px minimum (specs/17, t_da411148) — not the 44 px it used before.
  static const height = 56.0;

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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                i == today
                                    ? context.l10n.boardToday
                                    : context.weekdayShort(board.days[i].date),
                                style: boardNum(
                                  24,
                                  weight: FontWeight.w700,
                                  color: i == today
                                      ? scheme.primary
                                      : scheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (MediaQuery.textScalerOf(context).scale(24) <=
                                32) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  context.dayMonth(board.days[i].date),
                                  style: boardNum(24, color: context.ww.ink2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (MediaQuery.textScalerOf(context).scale(24) <= 28)
                          if (board.days[i].holiday case final holiday?)
                            Text(
                              holiday.name,
                              style: boardCell(24, color: context.ww.ink2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      ],
                    ),
                  ),
                ],
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
/// part per day, two at most, then "+n weitere". A short zone uses one summary
/// per day. Ended appointments keep their full text contrast in every shade.
class TermineRows extends ConsumerWidget {
  const TermineRows({required this.frame, super.key});

  final BoardFrame frame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 168) {
          return BoardRow(
            geometry: frame.geometry,
            children: [
              Positioned(
                left: 12,
                width: BoardGeometry.gutter - 20,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.boardAppointmentsOf,
                    style: boardUi(
                      24,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              for (var i = 0; i < BoardGeometry.dayCount; i++)
                spanCell(
                  frame.geometry,
                  i,
                  i,
                  BoardTap(
                    label: [
                      context.fullDate(frame.board.days[i].date),
                      for (final e in frame.eventsOf(i))
                        '${e.starts == null ? context.l10n.boardAllDay : context.shortTime(e.starts!)} ${_titleOf(e)}',
                    ].join(', '),
                    onTap: () =>
                        unawaited(openDayDetail(context, frame.board, i)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: _DayPartCell(
                          board: frame.board,
                          events: frame.eventsOf(i),
                          isToday: frame.isToday(i),
                          now: now,
                          roomy: false,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        return Column(
          children: [
            for (final part in DayPart.values)
              Expanded(
                child: _PartRow(frame: frame, part: part, now: now),
              ),
          ],
        );
      },
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
                overflow: TextOverflow.ellipsis,
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
              label: [
                context.fullDate(board.days[i].date),
                context.dayPartLabel(part),
                for (final e in frame.eventsOf(i))
                  if (settings.partOf(e.starts) == part)
                    '${e.starts == null ? context.l10n.boardAllDay : context.shortTime(e.starts!)} ${_titleOf(e)}',
              ].join(', '),
              onTap: () => unawaited(openDayDetail(context, board, i)),
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
                        roomy:
                            c.maxHeight >=
                            MediaQuery.textScalerOf(context).scale(52),
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
    if (!roomy) {
      final e = events.first;
      return Row(
        children: [
          Expanded(
            child: Text(
              '${e.starts == null ? l10n.boardAllDay : context.shortTime(e.starts!)} ${_titleOf(e)}',
              style: boardCell(
                24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (events.length > 1)
            Text(
              l10n.boardMoreCount(events.length - 1),
              style: boardCell(24, color: context.ww.ink2),
            ),
        ],
      );
    }
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
        Row(
          children: [
            ?_iconOf(event),
            Expanded(
              child: Text(
                _titleOf(event),
                style: boardCell(24, weight: FontWeight.w700, color: ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ),
      ],
    );
    return _tradition(context, event, _tentative(context, event, block));
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
          Flexible(
            child: Text(
              context.shortTime(start),
              style: boardNum(
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
          const SizedBox(width: 6),
        ],
        ?_iconOf(event),
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
          Flexible(
            fit: FlexFit.loose,
            child: ClipRect(child: MemberDots(dots: dots, size: 10)),
          ),
        ],
      ],
    );
    return _tradition(context, event, _tentative(context, event, row));
  }
}

/// The event's picture before its title (specs/27), or nothing.
Widget? _iconOf(BoardEvent e) => switch (eventIconAsset(e.iconKey)) {
  final asset? => Padding(
    padding: const EdgeInsets.only(right: 4),
    child: EmojiPicture(asset, size: 24),
  ),
  null => null,
};

/// A family tradition sits on a lemon ribbon (specs/27): paper, so its text stays ink.
Widget _tradition(BuildContext context, BoardEvent e, Widget child) =>
    e.tradition
    ? DecoratedBox(
        decoration: BoxDecoration(
          color: context.ww.paper(
            PaperTints.tints.firstWhere((t) => t.key == 'lemon'),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(padding: const EdgeInsets.all(2), child: child),
      )
    : child;

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
      child: BoardTap(
        label: l10n.boardAllEvents,
        onTap: () => ref.read(boardAllEventsProvider.notifier).set(!on),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: BoardDivider.controlHeight,
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
