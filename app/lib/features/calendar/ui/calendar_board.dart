import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart' show ClipFit;
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/busy_until_sheet.dart';
import 'package:wuselwall/features/calendar/ui/calendar_layout.dart';
import 'package:wuselwall/features/calendar/ui/calendar_tiles.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

const _gutterWidth = 44.0;
const _hourHeight = 52.0;
const _gridHeight = (gridEndHour - gridStartHour) * _hourHeight;

/// One presence band row: a member's bands, one lane per member (specs/05 "Week").
const _presenceRowHeight = 30.0;

/// One all-day chip row.
const _allDayRowHeight = 26.0;

/// More rows than this and the pinned area scrolls on its own, within a share of the
/// board's height, so the time grid keeps room.
const _pinnedRowsBeforeCap = 3;
const _pinnedCapShare = 0.35;

/// The grid opens at 07:00, or an hour before the first timed appointment if earlier.
const _openHour = 7;

/// The day, three-day or week grid (specs/05 "Views"). From the top: a header per
/// column, then a pinned area (one presence lane per member who has presence, then the
/// all-day chips) that stays put while the time grid from 06:00 to 22:00 scrolls under
/// it. Weekends sit on sunken ground, like a paper calendar.
class CalendarBoard extends StatefulWidget {
  const CalendarBoard({
    required this.view,
    required this.window,
    required this.members,
    required this.now,
    this.bottomClearance = 0,
    super.key,
  });

  final CalendarView view;
  final OccurrenceWindow window;
  final List<Member> members;

  /// The current minute; the "now" line sits here on today's column.
  final DateTime now;

  /// Room left under the time grid's last hour, so the floating buttons never cover
  /// it once scrolled to the end.
  final double bottomClearance;

  @override
  State<CalendarBoard> createState() => _CalendarBoardState();
}

class _CalendarBoardState extends State<CalendarBoard> {
  // The offset is set before the first frame, so the grid never shows the top first.
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: _initialOffset(),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The grid's offset for the opening view: 07:00, or an hour before the earliest
  /// timed appointment of the visible days when that is earlier.
  double _initialOffset() {
    final days = widget.view.days;
    final blocks = [
      for (final day in days) ...timedBlocksOn(day, widget.window.occurrences),
    ];
    var target = _openHour * 60;
    for (final b in blocks) {
      target = math.min(target, b.start - 60);
    }
    target = math.max(gridStartHour * 60, target);
    return _y(target);
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.view.days;
    final today = dateOnly(widget.now);
    final occurrences = widget.window.occurrences;
    final pinned = _PinnedPlan.of(days, occurrences, widget.members);

    final board = LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final cap = pinned.rowCount > _pinnedRowsBeforeCap && maxHeight.isFinite
            ? maxHeight * _pinnedCapShare
            : double.infinity;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DayHeaders(days: days, today: today),
            if (!pinned.isEmpty)
              _Pinned(
                plan: pinned,
                days: days,
                members: widget.members,
                now: widget.now,
                visibleHeight: math.min(pinned.height, cap),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.only(bottom: widget.bottomClearance),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _HourLabels(),
                    for (final day in days)
                      Expanded(
                        child: _TimeCell(
                          day: day,
                          blocks: timedBlocksOn(day, occurrences),
                          members: widget.members,
                          now: widget.now,
                          isToday: dateOnly(day) == today,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    return Stack(
      children: [
        board,
        if (occurrences.isEmpty)
          Center(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.calendarEmpty,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: context.ww.ink2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayHeaders extends StatelessWidget {
  const _DayHeaders({required this.days, required this.today});

  final List<DateTime> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(width: _gutterWidth),
      for (final day in days)
        Expanded(
          child: _DayHeader(
            day: day,
            isToday: dateOnly(day) == today,
            single: days.length == 1,
            narrow: days.length >= 7,
          ),
        ),
    ],
  );
}

class _DayHeader extends ConsumerWidget {
  const _DayHeader({
    required this.day,
    required this.isToday,
    required this.single,
    required this.narrow,
  });

  final DateTime day;
  final bool isToday;
  final bool single;
  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final ww = context.ww;
    final text = Theme.of(context).textTheme;
    final accent = isToday ? cs.primary : null;
    // A tap on a day's header sets "Termine bis …" for that day (FR-1.19).
    return Tooltip(
      message: context.l10n.busyTitle,
      child: InkWell(
        onTap: () => showBusyUntilSheet(context, ref, day),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: single
              ? Text(
                  context.fullDate(day),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    color: accent ?? cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.weekdayShort(day),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(
                        color: accent ?? ww.ink2,
                      ),
                    ),
                    Text(
                      narrow ? '${day.day}' : context.dayMonth(day),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        color: accent ?? cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Whether [day] is a Saturday or Sunday.
bool _isWeekend(DateTime day) =>
    day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

/// An occurrence over the visible columns: [first]..[last] are column indexes, [row]
/// the sub-row it is packed into.
class _Span {
  _Span(this.occurrence, this.first, this.last);

  final Occurrence occurrence;
  final int first;
  final int last;
  int row = 0;
}

/// The presence bands of one member, packed into sub-rows so overlapping bands of the
/// same member stack instead of covering each other.
class _Lane {
  _Lane(this.memberId);

  /// The first attendee; null for presence nobody attends.
  final String? memberId;
  final spans = <_Span>[];
  int rows = 1;
}

/// What the pinned area shows for the visible columns. Built once per frame from the
/// window, so the lanes and rows are the same whatever the scroll position.
class _PinnedPlan {
  _PinnedPlan._(this.lanes, this.chips, this.chipRows);

  factory _PinnedPlan.of(
    List<DateTime> days,
    List<Occurrence> occurrences,
    List<Member> members,
  ) {
    final origin = dateOnly(days.first);
    final last = days.length - 1;

    // Visible columns covered by [o], or null when it misses them all.
    _Span? spanOf(Occurrence o) {
      final from = dateOnly(o.localStartDate);
      final to = dateOnly(o.localEndDate);
      if (to.isBefore(origin) || from.isAfter(dateOnly(days.last))) return null;
      return _Span(
        o,
        math.max(0, _dayIndex(from, origin)),
        math.min(last, _dayIndex(to, origin)),
      );
    }

    final order = {for (var i = 0; i < members.length; i++) members[i].id: i};
    final lanes = <String?, _Lane>{};
    final chips = <_Span>[];
    for (final o in occurrences) {
      if (o.isPresence) {
        final span = spanOf(o);
        if (span == null) continue;
        final key = o.attendeeIds.isEmpty ? null : o.attendeeIds.first;
        lanes.putIfAbsent(key, () => _Lane(key)).spans.add(span);
      } else if (o.allDay) {
        final span = spanOf(o);
        if (span != null) chips.add(span);
      }
    }

    int rank(_Lane l) =>
        l.memberId == null ? 1 << 30 : (order[l.memberId] ?? 1 << 29);
    final laneList = lanes.values.toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    for (final lane in laneList) {
      lane.rows = _packRows(lane.spans);
    }
    final chipRows = _packRows(chips);
    return _PinnedPlan._(laneList, chips, chipRows);
  }

  final List<_Lane> lanes;
  final List<_Span> chips;
  final int chipRows;

  bool get isEmpty => lanes.isEmpty && chips.isEmpty;

  /// Rows the user sees: a lane is one row, however many sub-rows it needs.
  int get rowCount => lanes.length + chipRows;

  double get height =>
      lanes.fold(0.0, (h, l) => h + l.rows * _presenceRowHeight) +
      chipRows * _allDayRowHeight;
}

/// Whole days from [origin] to [day], by calendar date, so a time change in between
/// does not shift the count.
int _dayIndex(DateTime day, DateTime origin) => DateTime.utc(
  day.year,
  day.month,
  day.day,
).difference(DateTime.utc(origin.year, origin.month, origin.day)).inDays;

/// Greedy packing: each span takes the first sub-row whose last span has ended before
/// it starts. Returns the number of sub-rows.
int _packRows(List<_Span> spans) {
  spans.sort(
    (a, b) => a.first != b.first
        ? a.first.compareTo(b.first)
        : b.last.compareTo(a.last),
  );
  final rowEnds = <int>[];
  for (final s in spans) {
    var row = rowEnds.indexWhere((end) => end < s.first);
    if (row == -1) {
      row = rowEnds.length;
      rowEnds.add(s.last);
    } else {
      rowEnds[row] = s.last;
    }
    s.row = row;
  }
  return rowEnds.length;
}

/// The pinned area: a lane per member with presence, bands drawn across their days,
/// then the all-day chips. It sits between the day headers and the scrolling grid.
class _Pinned extends StatelessWidget {
  const _Pinned({
    required this.plan,
    required this.days,
    required this.members,
    required this.now,
    required this.visibleHeight,
  });

  final _PinnedPlan plan;
  final List<DateTime> days;
  final List<Member> members;
  final DateTime now;

  /// Less than the plan's height when the area scrolls.
  final double visibleHeight;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final cs = Theme.of(context).colorScheme;
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = (constraints.maxWidth - _gutterWidth) / days.length;
        double left(int i) => _gutterWidth + i * colWidth;
        final children = <Widget>[
          // Weekend ground first, under everything.
          for (var i = 0; i < days.length; i++)
            if (_isWeekend(days[i]))
              Positioned(
                left: left(i),
                width: colWidth,
                top: 0,
                bottom: 0,
                child: ColoredBox(color: ww.sunken),
              ),
        ];

        var top = 0.0;
        for (final lane in plan.lanes) {
          final color = _colourOfMember(lane.memberId, members);
          final laneHeight = lane.rows * _presenceRowHeight;
          if (color != null) {
            final member = members.firstWhere((m) => m.id == lane.memberId);
            children.add(
              Positioned(
                left: 0,
                width: _gutterWidth,
                top: top,
                height: laneHeight,
                child: Center(
                  child: MemberDot(
                    memberColor: color,
                    size: 8,
                    semanticLabel: member.displayName,
                  ),
                ),
              ),
            );
          }
          for (final s in lane.spans) {
            final o = s.occurrence;
            final width = (s.last - s.first + 1) * colWidth - 2;
            children.add(
              Positioned(
                left: left(s.first) + 1,
                width: width,
                top: top + s.row * _presenceRowHeight + 2,
                height: _presenceRowHeight - 4,
                child: ClipFit(
                  child: _Named(
                    name: width < narrowColumn ? o.title : null,
                    child: PresenceBandView(
                      state: o.presenceState ?? PresenceState.working,
                      memberColor: color ?? cs.onSurfaceVariant,
                      // A band one narrow day wide is its colour and icon only: a word
                      // would show as "Die…" (round-3 review L-8); the tooltip names it.
                      label: width < narrowColumn ? '' : o.title,
                      openStart: o.localStartDate.isBefore(
                        dateOnly(days.first),
                      ),
                      openEnd: o.localEndDate.isAfter(dateOnly(days.last)),
                      tentative: o.isTentative,
                      dense: true,
                      fontSize:
                          Theme.of(context).textTheme.bodySmall?.fontSize ?? 12,
                    ),
                  ),
                ),
              ),
            );
          }
          top += laneHeight;
        }

        if (plan.chips.isNotEmpty) {
          children.add(
            Positioned(
              left: 0,
              width: _gutterWidth,
              top: top,
              height: plan.chipRows * _allDayRowHeight,
              // "ganztägig" does not fit the hour gutter ("ganzt…"): a mark with the
              // word as its tooltip and label.
              child: Padding(
                padding: const EdgeInsets.only(top: 3, right: 6),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Tooltip(
                    message: context.l10n.boardAllDay,
                    child: Semantics(
                      label: context.l10n.boardAllDay,
                      excludeSemantics: true,
                      child: Icon(
                        Icons.calendar_view_day_outlined,
                        size: 16,
                        color: ww.ink3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          for (final s in plan.chips) {
            children.add(
              Positioned(
                left: left(s.first) + 1,
                width: (s.last - s.first + 1) * colWidth - 2,
                top: top + s.row * _allDayRowHeight + 2,
                height: _allDayRowHeight - 4,
                child: OccurrenceTile(
                  occurrence: s.occurrence,
                  members: members,
                  now: now,
                  compact: true,
                  width: (s.last - s.first + 1) * colWidth - 2,
                ),
              ),
            );
          }
        }

        return SizedBox(
          width: constraints.maxWidth,
          height: plan.height,
          child: Stack(children: children),
        );
      },
    );

    final area = visibleHeight < plan.height
        ? SizedBox(
            height: visibleHeight,
            child: SingleChildScrollView(child: content),
          )
        : content;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ww.line)),
      ),
      child: area,
    );
  }
}

class _HourLabels extends StatelessWidget {
  const _HourLabels();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: context.ww.ink3);
    return SizedBox(
      width: _gutterWidth,
      height: _gridHeight,
      child: Stack(
        children: [
          for (var h = gridStartHour; h < gridEndHour; h++)
            Positioned(
              top: (h - gridStartHour) * _hourHeight + 2,
              left: 0,
              right: 6,
              child: Text(
                context.shortTime(TimeOfDay(hour: h, minute: 0)),
                textAlign: TextAlign.right,
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.day,
    required this.blocks,
    required this.members,
    required this.now,
    required this.isToday,
  });

  final DateTime day;
  final List<DayBlock> blocks;
  final List<Member> members;
  final DateTime now;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final cs = Theme.of(context).colorScheme;
    final nowMinute = now.hour * 60 + now.minute;
    final showNow =
        isToday &&
        nowMinute >= gridStartHour * 60 &&
        nowMinute <= gridEndHour * 60;
    return SizedBox(
      height: _gridHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _isWeekend(day) ? ww.sunken : null,
          border: Border(left: BorderSide(color: ww.line)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                for (var h = gridStartHour; h <= gridEndHour; h++)
                  Positioned(
                    top: _y(h * 60),
                    left: 0,
                    right: 0,
                    child: Container(height: 1, color: ww.line),
                  ),
                for (final b in blocks)
                  Positioned(
                    top: _y(b.start) + 1,
                    height: _blockHeight(b),
                    left: width * b.lane / b.lanes + 1,
                    width: width / b.lanes - 2,
                    child: OccurrenceTile(
                      occurrence: b.occurrence,
                      members: members,
                      now: now,
                      width: width / b.lanes - 2,
                      height: _blockHeight(b),
                    ),
                  ),
                if (showNow)
                  Positioned(
                    top: _y(nowMinute),
                    left: 0,
                    right: 0,
                    height: 2,
                    child: ColoredBox(color: cs.primary),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A block's height: its span, but never less than a line of text.
double _blockHeight(DayBlock b) {
  final span = _y(b.end) - _y(b.start) - 2;
  return span < 20 ? 20 : span;
}

/// Minutes from midnight to a y offset on the grid.
double _y(int minute) => (minute - gridStartHour * 60) / 60 * _hourHeight;

/// A narrow band or chip without its words keeps them as a tooltip.
class _Named extends StatelessWidget {
  const _Named({required this.name, required this.child});

  /// Null where the words are shown.
  final String? name;
  final Widget child;

  @override
  Widget build(BuildContext context) => switch (name) {
    final name? => Tooltip(message: name, child: child),
    null => child,
  };
}

/// The member colour of a lane's member, or null when nobody attends.
Color? _colourOfMember(String? memberId, List<Member> members) {
  if (memberId == null) return null;
  for (final m in members) {
    if (m.id == memberId) return m.color;
  }
  return null;
}
