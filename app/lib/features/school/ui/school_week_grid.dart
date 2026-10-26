import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/school/ui/school_icons.dart';

const _days = 5;
const _labelWidth = 84.0;

/// Below this width a lesson cell shows its icon and short code only; the full name,
/// room and change live in the tooltip and the lesson sheet (round-3 review C-6).
const _compactCell = 72.0;

/// Weekday dates, optionally with navigation beside Monday and Friday.
/// The left gutter matches the grid's period labels; the next-week button adds a
/// trailing 48 px gutter, which the parent also leaves beside the lesson grid.
class SchoolWeekHeader extends StatelessWidget {
  const SchoolWeekHeader({
    required this.dates,
    this.raisedIndex,
    this.onPrevious,
    this.onNext,
    super.key,
  });

  final List<DateTime> dates;
  final int? raisedIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ww = context.ww;
    return Row(
      children: [
        SizedBox(
          width: _labelWidth,
          child: onPrevious == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: context.l10n.schoolPrevWeek,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: onPrevious,
                  ),
                ),
        ),
        for (var i = 0; i < _days; i++)
          Expanded(
            child: Column(
              children: [
                Text(
                  context.weekdayShort(dates[i]),
                  style: TextStyle(
                    fontFamily: Tokens.fontUi,
                    fontWeight: FontWeight.w700,
                    color: raisedIndex == i ? scheme.primary : ww.ink2,
                  ),
                ),
                Text(
                  context.dayMonth(dates[i]),
                  style: SchoolWeekGrid._numeric(
                    raisedIndex == i ? scheme.primary : ww.ink3,
                  ),
                ),
              ],
            ),
          ),
        if (onNext != null)
          SizedBox(
            width: 48,
            child: IconButton(
              tooltip: context.l10n.schoolNextWeek,
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
          ),
      ],
    );
  }
}

/// A child's week as a paper grid (specs/15 "Views"): numbered Stunden with their bell
/// times down the left, Monday to Friday across. The [raisedIndex] column is today, or
/// the next school day. Cancelled lessons stay in place, struck through. Care and club
/// rows (Hort) sit under the lessons. Register-neutral: the adult section uses it with
/// body-sized type, the kiosk keeps its own grid.
class SchoolWeekGrid extends StatelessWidget {
  const SchoolWeekGrid({
    required this.timetable,
    required this.dates,
    required this.days,
    this.raisedIndex,
    this.nowMinutes,
    this.iconKeyOf,
    this.onLesson,
    this.showHeader = true,
    super.key,
  });

  final BoardTimetable timetable;

  /// False when the parent supplies a shared header with week navigation.
  final bool showHeader;

  /// Five dates, Monday to Friday.
  final List<DateTime> dates;

  /// The projected school day per date; null where the reply had none.
  final List<SchoolDay?> days;
  final int? raisedIndex;

  /// Minutes since midnight now, for marking the current lesson on the raised column.
  final int? nowMinutes;

  /// Subject name → icon key; lessons without one get the generic icon.
  final String? Function(String subjectName)? iconKeyOf;

  /// Called for a lesson with a Stunde: on long press, and on a tap on desktop.
  final void Function(int dayIndex, Lesson lesson)? onLesson;

  bool get _desktop => switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _grid(
      context,
      compact: (constraints.maxWidth - _labelWidth) / _days < _compactCell,
    ),
  );

  Widget _grid(BuildContext context, {required bool compact}) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final ww = context.ww;
    final raised = raisedIndex;
    final periodIndexes = {
      for (final p in timetable.periods)
        if (p.kind == PeriodKind.lesson) p.index,
    };
    final extras = <String, Lesson>{};
    for (final d in days) {
      for (final l in d?.lessons ?? const <Lesson>[]) {
        if (l.period == null || !periodIndexes.contains(l.period)) {
          extras.putIfAbsent(_extraKey(l), () => l);
        }
      }
    }
    final extraRows = extras.values.toList()
      ..sort((a, b) => minutesOf(a.starts).compareTo(minutesOf(b.starts)));

    Widget row({required Widget label, required List<Lesson?> cells}) =>
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _labelWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 6, 4),
                  child: label,
                ),
              ),
              for (var i = 0; i < _days; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: raised == i
                          ? scheme.primaryContainer.withAlpha(60)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: cells[i] == null
                        ? null
                        : _LessonCell(
                            lesson: cells[i]!,
                            iconKey: iconKeyOf?.call(cells[i]!.subject),
                            current:
                                raised == i &&
                                nowMinutes != null &&
                                cells[i]!.period != null &&
                                nowMinutes! >= minutesOf(cells[i]!.starts) &&
                                nowMinutes! < minutesOf(cells[i]!.ends),
                            onTap: onLesson == null || cells[i]!.period == null
                                ? null
                                : () => onLesson!(i, cells[i]!),
                            cellKey: ValueKey('lesson-$i-${cells[i]!.period}'),
                            tapOnPress: _desktop,
                            compact: compact,
                          ),
                  ),
                ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          SchoolWeekHeader(dates: dates, raisedIndex: raisedIndex),
          const SizedBox(height: 4),
        ],
        for (final p in timetable.periods)
          if (p.kind == PeriodKind.breakTime)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Text(
                      l10n.boardBreak,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel:
                          '${l10n.boardBreak} ${context.span(p.starts, p.ends)}',
                      style: TextStyle(
                        fontFamily: Tokens.fontUi,
                        fontSize: 11,
                        color: ww.ink3,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(height: 1, color: ww.line)),
                ],
              ),
            )
          else
            row(
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.boardPeriod(p.index),
                    style: TextStyle(
                      fontFamily: Tokens.fontUi,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    context.span(p.starts, p.ends),
                    style: _numeric(ww.ink2, size: 12),
                  ),
                ],
              ),
              cells: [
                for (final d in days)
                  d?.lessons.where((l) => l.period == p.index).firstOrNull,
              ],
            ),
        for (final extra in extraRows)
          row(
            label: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  extra.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Tokens.fontUi,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  context.span(extra.starts, extra.ends),
                  style: _numeric(ww.ink2, size: 12),
                ),
              ],
            ),
            cells: [
              for (final d in days)
                d?.lessons
                    .where(
                      (l) =>
                          (l.period == null ||
                              !periodIndexes.contains(l.period)) &&
                          _extraKey(l) == _extraKey(extra),
                    )
                    .firstOrNull,
            ],
          ),
      ],
    );
  }

  static String _extraKey(Lesson l) =>
      '${l.subject}|${minutesOf(l.starts)}|${minutesOf(l.ends)}';

  static TextStyle _numeric(Color color, {double size = 12}) => TextStyle(
    fontFamily: Tokens.fontNumeric,
    fontSize: size,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// One lesson in a cell: a paper tile with its icon, short name, room, and what changed.
/// A [compact] cell (a phone's five columns) shows the icon over the short code and a
/// change as an icon, never a cut word; the tooltip says it all.
class _LessonCell extends StatelessWidget {
  const _LessonCell({
    required this.lesson,
    required this.iconKey,
    required this.current,
    required this.onTap,
    required this.tapOnPress,
    required this.compact,
    this.cellKey,
  });

  final bool compact;

  final Key? cellKey;

  final Lesson lesson;
  final String? iconKey;
  final bool current;
  final VoidCallback? onTap;

  /// On desktop a tap opens the sheet; on a phone it is the long press.
  final bool tapOnPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;
    final cancelled = lesson.status == LessonStatus.cancelled;
    final status = switch (lesson.status) {
      LessonStatus.cancelled => l10n.boardLessonCancelled,
      LessonStatus.substituted => l10n.boardLessonSubstituted,
      LessonStatus.roomChange => l10n.boardLessonRoomChange,
      LessonStatus.extra => l10n.boardLessonExtra,
      LessonStatus.normal => null,
    };
    final name = lesson.shortName ?? lesson.subject;
    final full = [
      lesson.subject,
      ?lesson.room,
      ?status,
      if (lesson.note != null && lesson.note!.isNotEmpty) lesson.note!,
    ].join(' · ');
    if (compact) {
      final short =
          lesson.shortName ?? lesson.subject.characters.take(3).string;
      final mark = switch (lesson.status) {
        LessonStatus.substituted => Icons.swap_horiz,
        LessonStatus.roomChange => Icons.meeting_room_outlined,
        LessonStatus.extra => Icons.add_circle_outline,
        LessonStatus.cancelled || LessonStatus.normal =>
          lesson.note != null && lesson.note!.isNotEmpty
              ? Icons.info_outline
              : null,
      };
      return Semantics(
        label: full,
        button: onTap != null,
        excludeSemantics: true,
        child: Tooltip(
          message: full,
          child: InkWell(
            key: cellKey,
            borderRadius: BorderRadius.circular(10),
            onLongPress: onTap,
            onTap: tapOnPress ? onTap : null,
            child: PaperTile(
              tint: lesson.tint,
              struckThrough: cancelled,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Container(
                decoration: current
                    ? BoxDecoration(
                        border: Border.all(color: scheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      schoolIcon(iconKey),
                      size: 18,
                      color: scheme.onSurface,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        short,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: Tokens.fontUi,
                          fontWeight: FontWeight.w800,
                          decoration: cancelled
                              ? TextDecoration.lineThrough
                              : null,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (mark != null)
                      Icon(
                        mark,
                        size: 14,
                        color: lesson.status == LessonStatus.substituted
                            ? scheme.primary
                            : ww.ink2,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final tile = PaperTile(
      tint: lesson.tint,
      struckThrough: cancelled,
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      child: Container(
        decoration: current
            ? BoxDecoration(
                border: Border.all(color: scheme.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(schoolIcon(iconKey), size: 16, color: scheme.onSurface),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Tokens.fontUi,
                      fontWeight: FontWeight.w800,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (lesson.room != null)
              Text(
                lesson.room!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Tokens.fontUi,
                  fontSize: 12,
                  color: ww.ink2,
                ),
              ),
            if (status != null)
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Tokens.fontUi,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: lesson.status == LessonStatus.substituted
                      ? scheme.primary
                      : scheme.onSurface,
                ),
              ),
            if (lesson.note != null && lesson.note!.isNotEmpty)
              Text(
                lesson.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Tokens.fontUi,
                  fontSize: 12,
                  color: ww.ink2,
                ),
              ),
          ],
        ),
      ),
    );
    return Semantics(
      label: '${lesson.subject}${status == null ? '' : ', $status'}',
      button: onTap != null,
      child: InkWell(
        key: cellKey,
        borderRadius: BorderRadius.circular(10),
        onLongPress: onTap,
        onTap: tapOnPress ? onTap : null,
        child: tile,
      ),
    );
  }
}
