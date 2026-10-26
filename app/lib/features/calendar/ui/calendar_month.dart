import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart' show isoWeekOf;
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart'
    show MemberDot;
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/calendar_month_layout.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart' show ageOn;
import 'package:wuselwall/features/rituals/domain/event_icons.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

/// The smallest edge of a day's tap target (specs/17).
const _minTap = 48.0;

/// The Ferien band under the day number: soft, so the day's lines stay the content.
final _ferienPaper = PaperTints.tints.firstWhere((t) => t.key == 'lemon');

/// The read-only month overview (specs/05 "Views"): six weeks, Monday first, with ISO
/// week numbers. Each day names its public holiday, its birthdays ("Paul wird 8") and
/// its key appointments and traditions; the other appointments are only counted. Ferien
/// run as a soft band across their days. Tapping a day opens it in the day view, where
/// appointments are edited. Birthdays show whatever `ambience.birthdays` says: the month
/// is information, the ambience only decoration.
class CalendarMonthView extends ConsumerWidget {
  const CalendarMonthView({required this.view, super.key});

  final CalendarView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = (from: view.from, to: view.to);
    final occurrences = ref.watch(monthOccurrencesProvider(window));
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final schoolHolidays =
        ref.watch(schoolDataProvider).value?.holidays ??
        const <HolidayRecord>[];
    final today = ref.watch(nowProvider.select(dateOnly));
    // The last month stays, dimmed, while the next one loads.
    return AsyncValueView(
      value: occurrences,
      keepPrevious: true,
      onRetry: () => ref.invalidate(monthOccurrencesProvider(window)),
      data: (data) => MonthGrid(
        plan: MonthPlan.of(
          month: view.month,
          occurrences: data.occurrences,
          members: members,
          publicHolidays:
              data.publicHolidays ?? _ownPublicHolidays(schoolHolidays),
          schoolHolidays: schoolHolidays,
        ),
        members: members,
        today: today,
        onOpenDay: ref.read(calendarViewProvider.notifier).openDay,
      ),
    );
  }
}

/// A server that does not name the window's public holidays yet: the family's own
/// household-wide ones, which every server lists with the school holidays.
Map<DateTime, String> _ownPublicHolidays(List<HolidayRecord> records) => {
  for (final h in records)
    if (h.kind == 'public_holiday' && h.schoolId == null)
      for (
        var d = dateOnly(h.startsOn);
        !d.isAfter(dateOnly(h.endsOn));
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d: h.name,
};

/// The grid itself: a weekday header, then six week rows that share the height, or
/// scroll when large text leaves too little room for each.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.plan,
    required this.members,
    required this.today,
    required this.onOpenDay,
    super.key,
  });

  final MonthPlan plan;
  final List<Member> members;
  final DateTime today;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final metrics = _Metrics.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        // Week numbers only where seven days keep their full tap width beside them.
        final weekColumn = metrics.weekColumn;
        final showWeeks = (box.maxWidth - weekColumn) / 7 >= _minTap;
        final gutter = showWeeks ? weekColumn : 0.0;
        final header = Row(
          children: [
            if (showWeeks)
              SizedBox(
                width: gutter,
                child: Text(
                  context.l10n.calendarWeekNumberShort,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: text.labelSmall?.copyWith(color: ww.ink2),
                ),
              ),
            for (final d in plan.weeks.first)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    context.weekdayShort(d.date),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(color: ww.ink2),
                  ),
                ),
              ),
          ],
        );
        final headerHeight =
            scaler.scale(text.labelMedium?.fontSize ?? 12) * 1.4 + 12;
        final available = math.max(0.0, box.maxHeight - headerHeight);
        final rowHeight = math.max(available / 6, metrics.minRow);
        final rows = Column(
          children: [
            for (var w = 0; w < plan.weeks.length; w++)
              SizedBox(
                height: rowHeight,
                child: _WeekRow(
                  days: plan.weeks[w],
                  ferien: plan.ferien[w],
                  gutter: gutter,
                  metrics: metrics,
                  members: members,
                  today: today,
                  onOpenDay: onOpenDay,
                ),
              ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: headerHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: ww.line)),
                ),
                child: Align(alignment: Alignment.center, child: header),
              ),
            ),
            Expanded(
              child: rowHeight * 6 > available + 0.5
                  ? SingleChildScrollView(child: rows)
                  : rows,
            ),
          ],
        );
      },
    );
  }
}

/// Sizes that follow the text scale, so 200 % text keeps whole lines.
class _Metrics {
  const _Metrics({
    required this.line,
    required this.number,
    required this.band,
    required this.weekColumn,
  });

  factory _Metrics.of(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = Theme.of(context).textTheme;
    final small = scaler.scale(text.labelSmall?.fontSize ?? 11);
    final number = scaler.scale(text.labelLarge?.fontSize ?? 14);
    return _Metrics(
      line: small * 1.3 + 3,
      number: number * 1.3 + 6,
      band: small * 1.3 + 2,
      weekColumn: 18 + scaler.scale(text.labelSmall?.fontSize ?? 11),
    );
  }

  /// One line of a day's contents.
  final double line;

  /// The day number's row.
  final double number;

  /// The Ferien band.
  final double band;

  /// The week number column.
  final double weekColumn;

  /// A row is never lower than the tap target, nor than its number and one line.
  double get minRow => math.max(_minTap + 16, number + line + 8);
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.days,
    required this.ferien,
    required this.gutter,
    required this.metrics,
    required this.members,
    required this.today,
    required this.onOpenDay,
  });

  final List<MonthDay> days;
  final List<FerienSpan> ferien;
  final double gutter;
  final _Metrics metrics;
  final List<Member> members;
  final DateTime today;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final text = Theme.of(context).textTheme;
    final week = isoWeekOf(days.first.date);
    final hasBand = ferien.isNotEmpty;
    return LayoutBuilder(
      builder: (context, box) {
        final column = (box.maxWidth - gutter) / 7;
        return Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (gutter > 0)
                  SizedBox(
                    width: gutter,
                    child: Semantics(
                      label: context.l10n.calendarWeekNumberLabel(week),
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$week',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: text.labelSmall?.copyWith(color: ww.ink2),
                        ),
                      ),
                    ),
                  ),
                for (final day in days)
                  Expanded(
                    child: _DayCell(
                      day: day,
                      metrics: metrics,
                      bandSlot: hasBand,
                      members: members,
                      isToday: day.date == today,
                      onTap: () => onOpenDay(day.date),
                    ),
                  ),
              ],
            ),
            for (final span in ferien)
              Positioned(
                left: gutter + span.first * column + (span.openStart ? 0 : 3),
                width:
                    (span.last - span.first + 1) * column -
                    (span.openStart ? 0 : 3) -
                    (span.openEnd ? 0 : 3),
                top: 2 + metrics.number,
                height: metrics.band,
                child: IgnorePointer(
                  child: ExcludeSemantics(child: _FerienBand(span: span)),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The soft band of a Ferien stretch in one week, named at its start. The text is the
/// shade's ink on the paper tint, never the faint ink3 (specs/17).
class _FerienBand extends StatelessWidget {
  const _FerienBand({required this.span});

  final FerienSpan span;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    const round = Radius.circular(6);
    return DecoratedBox(
      key: const ValueKey('month-ferien-band'),
      decoration: BoxDecoration(
        color: ww.paper(_ferienPaper),
        borderRadius: BorderRadius.horizontal(
          left: span.openStart ? Radius.zero : round,
          right: span.openEnd ? Radius.zero : round,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            span.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One line of a day's contents.
sealed class _Line {
  const _Line();
}

class _HolidayLine extends _Line {
  const _HolidayLine(this.name);
  final String name;
}

class _BirthdayLine extends _Line {
  const _BirthdayLine(this.member, this.text);
  final Member member;
  final String text;
}

class _EventLine extends _Line {
  const _EventLine(this.occurrence);
  final Occurrence occurrence;
}

/// "Paul wird 8", or whose birthday it is when the age is unknown.
String _birthdayText(AppLocalizations l10n, Member m, DateTime day) {
  final age = ageOn(m.birthday!, day);
  return age > 0
      ? l10n.countdownBirthdayTurns(m.displayName, age)
      : l10n.countdownBirthdayOf(m.displayName);
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.metrics,
    required this.bandSlot,
    required this.members,
    required this.isToday,
    required this.onTap,
  });

  final MonthDay day;
  final _Metrics metrics;

  /// The row has a Ferien band: every day keeps room for it under the number.
  final bool bandSlot;
  final List<Member> members;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ww = context.ww;
    final text = Theme.of(context).textTheme;
    final lines = <_Line>[
      if (day.publicHoliday case final name?) _HolidayLine(name),
      for (final m in day.birthdays)
        _BirthdayLine(m, _birthdayText(l10n, m, day.date)),
      for (final o in day.notable) _EventLine(o),
    ];
    final weekend =
        day.date.weekday == DateTime.saturday ||
        day.date.weekday == DateTime.sunday;
    final label = [
      context.fullDate(day.date),
      if (isToday) l10n.boardToday,
      if (day.publicHoliday case final name?) l10n.boardHolidayLabel(name),
      for (final m in day.birthdays) _birthdayText(l10n, m, day.date),
      if (day.ferien case final name?) l10n.calendarMonthFerien(name),
      for (final o in day.notable) o.title,
      if (day.others > 0) l10n.calendarMonthOthers(day.others),
    ].join(', ');

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      onTapHint: l10n.calendarMonthOpenDay,
      excludeSemantics: true,
      child: Material(
        color: weekend ? ww.sunken : Colors.transparent,
        child: InkWell(
          key: ValueKey('month-day-${isoDate(day.date)}'),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: isToday
                  ? Border.all(color: cs.primary, width: 2)
                  : Border(
                      right: BorderSide(color: ww.line),
                      bottom: BorderSide(color: ww.line),
                    ),
            ),
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, box) {
                  final room =
                      box.maxHeight -
                      4 -
                      metrics.number -
                      (bandSlot ? metrics.band + 2 : 0);
                  final fit = math.max(0, (room / metrics.line).floor());
                  final shown = math.min(fit, lines.length);
                  final more = lines.length - shown + day.others;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(3, 2, 3, 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: metrics.number,
                          child: _NumberRow(
                            day: day,
                            isToday: isToday,
                            more: more,
                            size: metrics.number,
                          ),
                        ),
                        if (bandSlot) SizedBox(height: metrics.band + 2),
                        for (final line in lines.take(shown))
                          SizedBox(
                            height: metrics.line,
                            child: _LineView(
                              line: line,
                              members: members,
                              size: metrics.line - 3,
                              roomy: box.maxWidth >= 80,
                              style: text.labelSmall?.copyWith(
                                color: day.inMonth ? cs.onSurface : ww.ink2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The day number (filled for today) and, at the right, "+n" for what the day holds
/// beyond its lines.
class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.day,
    required this.isToday,
    required this.more,
    required this.size,
  });

  final MonthDay day;
  final bool isToday;
  final int more;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ww = context.ww;
    final text = Theme.of(context).textTheme;
    final number = Text(
      '${day.date.day}',
      maxLines: 1,
      style: text.labelLarge?.copyWith(
        color: isToday
            ? cs.onPrimary
            : day.inMonth
            ? cs.onSurface
            : ww.ink2,
        fontWeight: day.inMonth || isToday ? FontWeight.w700 : FontWeight.w400,
      ),
    );
    // Both shrink rather than overflow when large text meets a narrow phone column.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: isToday
                ? Container(
                    constraints: BoxConstraints(minWidth: size - 2),
                    height: size - 2,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(size),
                    ),
                    child: number,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: number,
                  ),
          ),
        ),
        if (more > 0)
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                context.l10n.calendarMonthMore(more),
                key: const ValueKey('month-more'),
                maxLines: 1,
                style: text.labelSmall?.copyWith(
                  color: ww.ink2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LineView extends StatelessWidget {
  const _LineView({
    required this.line,
    required this.members,
    required this.size,
    required this.style,
    required this.roomy,
  });

  final _Line line;
  final List<Member> members;

  /// The height of an icon on the line.
  final double size;
  final TextStyle? style;

  /// Wide enough for a birthday's member dot beside the cake.
  final bool roomy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget label(String s, {TextStyle? override}) => Flexible(
      child: Text(
        s,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: override ?? style,
      ),
    );
    final children = <Widget>[
      ...switch (line) {
        _HolidayLine(:final name) => [
          label(
            name,
            override: style?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        _BirthdayLine(:final member, :final text) => [
          EmojiPicture(eventIconAsset('cake')!, size: size),
          const SizedBox(width: 2),
          // A phone's column keeps its few pixels for the name.
          if (roomy) ...[
            MemberDot(
              memberColor: member.color,
              size: math.max(6, size / 2.5),
              semanticLabel: member.displayName,
            ),
            const SizedBox(width: 3),
          ],
          label(text),
        ],
        _EventLine(:final occurrence) => [
          if (eventIconAsset(occurrence.iconKey) case final asset?)
            EmojiPicture(asset, size: size)
          else
            SizedBox(
              width: 3,
              height: size,
              child: ColoredBox(color: _leadColour(context, occurrence)),
            ),
          const SizedBox(width: 3),
          label(
            occurrence.title,
            override: style?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      },
    ];
    return Row(children: children);
  }

  /// The colour of an appointment without a picture: its first attendee's ink, an
  /// imported calendar's colour, or the brand colour for the whole family.
  Color _leadColour(BuildContext context, Occurrence o) {
    final ww = context.ww;
    if (o.isImported) {
      return ww
          .member(
            colourFromHex(o.colourHex) ?? Theme.of(context).colorScheme.primary,
          )
          .ink;
    }
    for (final id in o.attendeeIds) {
      for (final m in members) {
        if (m.id == id) return ww.member(m.color).ink;
      }
    }
    return Theme.of(context).colorScheme.primary;
  }
}
