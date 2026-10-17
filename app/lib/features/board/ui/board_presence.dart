import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_bands.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/details/board_details.dart';

/// Zone "Wer ist wo": one equal-height row per member, in household order. Children
/// show their school span; adults show their baseline quietly and their deviations as
/// bands (specs/09 "The zones").
class PresenceRows extends StatelessWidget {
  const PresenceRows({required this.frame, super.key});

  final BoardFrame frame;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final member in frame.board.members)
        Expanded(
          child: _MemberRow(frame: frame, member: member),
        ),
    ],
  );
}

/// Rows shorter than this put each day's content on one line.
const _compactRowHeight = 60.0;

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.frame, required this.member});

  final BoardFrame frame;
  final BoardMember member;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final board = frame.board;
      final rowHeight = constraints.maxHeight;
      final compact = rowHeight < _compactRowHeight;
      final runs = bandRuns(board, member.id);
      final bandDays = {
        for (final r in runs)
          for (var i = r.first; i <= r.last; i++) i,
      };
      final mc = context.ww.member(member.color);
      final ink = Theme.of(context).colorScheme.onSurface;
      final name = context.memberName(board, member);

      void openWeek() {
        unawaited(
          member.isChild
              ? openChildWeek(context, board, member.id)
              : openMemberWeek(context, board, member.id),
        );
      }

      return BoardRow(
        geometry: frame.geometry,
        children: [
          Positioned(
            left: 0,
            width: BoardGeometry.gutter,
            top: 0,
            bottom: 0,
            child: BoardTap(
              label: name,
              onTap: openWeek,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: ClipFit(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MemberAvatar(member: member, size: 48),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          name,
                          style: boardUi(
                            26,
                            weight: FontWeight.w700,
                            color: ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          for (var i = 0; i < BoardGeometry.dayCount; i++)
            if (member.isChild)
              ..._childDay(
                context,
                i,
                half: rowHeight / 2,
                bandDay: bandDays.contains(i),
                mc: mc,
                ink: ink,
              )
            else
              ..._adultDay(
                context,
                i,
                compact: compact,
                covered: bandDays.contains(i),
              ),
          if (!member.isChild)
            ..._baselineTracks(context, bandDays, compact: compact),
          for (final run in runs)
            ..._bandWidgets(
              context,
              run,
              compact: compact,
              half: rowHeight / 2,
              mc: mc,
              onTap: openWeek,
            ),
        ],
      );
    },
  );

  /// A child's day: the school span as a chip, or "frei" / the holiday's name. When a
  /// band covers the day, the chip takes the upper half and the band the lower.
  List<Widget> _childDay(
    BuildContext context,
    int i, {
    required double half,
    required bool bandDay,
    required MemberColors mc,
    required Color ink,
  }) {
    final board = frame.board;
    final g = frame.geometry;
    final l10n = context.l10n;
    final school = board.days[i].school[member.id];
    if (school == null) return const [];

    if (!school.hasSchool) {
      // A band that day (Oma, a trip) says more than "frei", and they would overlap.
      if (bandDay) return const [];
      // The day's own holiday is already named over the column: the row only says
      // "frei". A school's own free day (Ferien, a floating holiday) is named here.
      final holidayName = school.holidayName;
      final text =
          holidayName == null || holidayName == board.days[i].holiday?.name
          ? l10n.boardNoSchool
          : holidayName;
      return [
        Positioned(
          left: g.left(i),
          width: g.width(i),
          top: 0,
          bottom: 0,
          child: Padding(
            // In line with the text of a school chip.
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ShrinkText(
                text,
                style: boardCell(
                  24,
                  weight: FontWeight.w500,
                  color: context.ww.ink3,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    final span = context.span(school.starts!, school.ends!);
    final notes = [
      ...school.notable,
      if (school.careUntil case final until?)
        // Next to a notable lesson there is room only for "Hort 15".
        (school.notable.isEmpty ? l10n.boardCareUntil : l10n.boardCareShort)(
          school.careLabel ?? l10n.boardCareDefault,
          context.shortTime(until),
        ),
    ].join(' · ');
    final ww = context.ww;

    return [
      spanCell(
        g,
        i,
        i,
        BoardTap(
          label: l10n.boardSchoolSpan(span),
          onTap: () => unawaited(openSchoolDay(context, board, member.id, i)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: mc.tint,
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: mc.ink, width: 4)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ClipFit(
                  alignment: Alignment.centerLeft,
                  child: _SchoolText(
                    span: span,
                    notes: notes,
                    ink: ink,
                    ink2: ww.ink2,
                    // Compact rows keep span and notes on one line.
                    oneLine: half * 2 < _compactRowHeight,
                  ),
                ),
              ),
            ),
          ),
        ),
        top: 4,
        bottom: bandDay ? half : 4,
      ),
    ];
  }

  /// An adult's day without a band: the tap target and the "Termine bis …" line. The
  /// baseline itself is drawn across the day's run by [_baselineTracks]. A short row
  /// has no room for the busy line; the member's week detail still shows it.
  List<Widget> _adultDay(
    BuildContext context,
    int i, {
    required bool compact,
    required bool covered,
  }) {
    if (covered) return const [];
    final board = frame.board;
    final busy = board.days[i].busyUntil[member.id];
    return [
      spanCell(
        frame.geometry,
        i,
        i,
        BoardTap(
          label: context.fullDate(board.days[i].date),
          onTap: () => unawaited(openMemberWeek(context, board, member.id)),
          child: busy == null || compact
              ? const SizedBox.expand()
              : Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 8, 4),
                    child: _BusyLine(until: busy),
                  ),
                ),
        ),
      ),
    ];
  }

  /// The baseline as one quiet track per run of ordinary days, labelled once
  /// (specs/09 "Why only the deviation is loud"): five "Homeoffice" chips in a row would
  /// be louder than the one day that differs.
  List<Widget> _baselineTracks(
    BuildContext context,
    Set<int> bandDays, {
    required bool compact,
  }) {
    final baseline = member.baseline;
    if (baseline == null) return const [];
    final label = context.presenceLabel(baseline.state, baseline.label);
    final tracks = <Widget>[];
    var i = 0;
    while (i < BoardGeometry.dayCount) {
      if (bandDays.contains(i)) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < BoardGeometry.dayCount && !bandDays.contains(j + 1)) {
        j++;
      }
      tracks.add(
        Positioned(
          left: frame.geometry.spanLeft(i) + 4,
          width: frame.geometry.spanWidth(i, j) - 8,
          top: compact ? 0 : 5,
          bottom: compact ? 0 : null,
          height: compact ? null : 32,
          child: IgnorePointer(
            child: Center(
              child: _BaselineTrack(memberColor: member.color, label: label),
            ),
          ),
        ),
      );
      i = j + 1;
    }
    return tracks;
  }

  /// One band, drawn once across its run of days, with its busy line and its "+n".
  List<Widget> _bandWidgets(
    BuildContext context,
    BandRun run, {
    required bool compact,
    required double half,
    required MemberColors mc,
    required VoidCallback onTap,
  }) {
    final board = frame.board;
    final g = frame.geometry;
    final l10n = context.l10n;
    final band = run.band;
    final startIdx = band.firstDay.difference(board.weekStart).inDays;
    final endIdx = band.lastDay.difference(board.weekStart).inDays;
    final openStart =
        run.first > startIdx || (band.startsBeforeWeek && run.first == 0);
    final openEnd = run.last < endIdx || (band.endsAfterWeek && run.last == 6);

    final busyDays = [
      for (var i = run.first; i <= run.last; i++)
        if (board.days[i].busyUntil[member.id] case final t?) (i, t),
    ];
    final start = band.starts;
    final end = band.ends;
    final timeText = start == null
        ? null
        : end == null
        ? l10n.boardFrom(context.shortTime(start))
        : context.span(start, end);
    // Short rows keep the band to one line: time and busy line join the label. Tall
    // rows give the time its own line and draw the busy line under the band.
    final busyInline = compact && busyDays.isNotEmpty
        ? l10n.boardBusyUntil(context.shortTime(busyDays.first.$2))
        : null;
    final busyBelow = !compact && busyDays.isNotEmpty;
    final label = context.presenceLabel(band.state, band.label);
    final oneLineLabel = [label, ?timeText, ?busyInline].join(' · ');

    final schoolOnRun =
        member.isChild &&
        [
          for (var i = run.first; i <= run.last; i++)
            if (board.days[i].school[member.id]?.hasSchool ?? false) i,
        ].isNotEmpty;
    // A band shares its row with a busy line or a school chip: it gets one line then.
    final oneLine = compact || busyBelow || schoolOnRun;
    // A two-line band needs nearly the whole row.
    final bandInset = compact || !oneLine ? 2.0 : 4.0;
    return [
      for (final (i, t) in busyDays)
        if (busyBelow)
          Positioned(
            left: g.left(i) + 8,
            width: g.width(i) - 16,
            bottom: 2,
            height: 26,
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: _BusyLine(until: t),
              ),
            ),
          ),
      spanCell(
        g,
        run.first,
        run.last,
        BoardTap(
          label: label,
          onTap: onTap,
          // A short row gives the band almost all of its height; anything the band
          // cannot fit is clipped rather than breaking the grid.
          child: ClipFit(
            child: PresenceBandView(
              state: band.state,
              memberColor: member.color,
              label: oneLine ? oneLineLabel : label,
              detail: oneLine ? null : timeText,
              openStart: openStart,
              openEnd: openEnd,
              tentative: band.tentative,
              // Label and time share a member row: tight padding and lines.
              dense: true,
              lineHeight: 1.1,
            ),
          ),
        ),
        top: schoolOnRun ? half : bandInset,
        bottom: busyBelow ? 30 : bandInset,
        inset: 4,
      ),
      // Degradation rule 3: the other bands of a day are counted, not drawn.
      for (var i = run.first; i <= run.last; i++)
        if (board.presenceOn(member.id, i).length > 1)
          Positioned(
            left: g.left(i),
            width: g.width(i),
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 4),
                  child: Text(
                    l10n.boardMoreCount(
                      board.presenceOn(member.id, i).length - 1,
                    ),
                    style: boardUi(
                      24,
                      weight: FontWeight.w700,
                      color: context.ww.ink2,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
    ];
  }
}

/// A school day's span and notes: one line in short rows, two in tall ones.
class _SchoolText extends StatelessWidget {
  const _SchoolText({
    required this.span,
    required this.notes,
    required this.ink,
    required this.ink2,
    required this.oneLine,
  });

  final String span;
  final String notes;
  final Color ink;
  final Color ink2;
  final bool oneLine;

  @override
  Widget build(BuildContext context) {
    final spanStyle = boardNum(26, weight: FontWeight.w700, color: ink);
    final notesStyle = boardCell(24, weight: FontWeight.w600, color: ink2);
    if (oneLine) {
      // The span comes first and keeps its room; the notes lose their end instead.
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: span, style: spanStyle),
            if (notes.isNotEmpty) TextSpan(text: '  $notes', style: notesStyle),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          span,
          style: spanStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
        // The notes ("Sport · Hort bis 15") shrink a little before they lose their
        // end: the Hort time is the part a parent reads the board for.
        if (notes.isNotEmpty) ShrinkText(notes, style: notesStyle),
      ],
    );
  }
}

/// The baseline drawn across a run of days: a hairline-bordered track with the member's
/// dot and the label once, in ink-2. Quiet on purpose; never a band (specs/17).
class _BaselineTrack extends StatelessWidget {
  const _BaselineTrack({required this.memberColor, required this.label});

  final Color memberColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ww.sunken,
        border: Border.all(color: ww.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: ww.member(memberColor).ink,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // A one-day run is narrow: the label shrinks a little before it loses its
          // end, since the baseline is never the thing to read closely.
          Expanded(
            child: ShrinkText(
              label,
              style: boardUi(
                24,
                weight: FontWeight.w500,
                color: ww.ink2,
                height: 1.1,
              ),
              minScale: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Termine bis 16:30" (FR-1.19) in the room a day column has: a clock and "bis 16:30";
/// screen readers get the whole sentence.
class _BusyLine extends StatelessWidget {
  const _BusyLine({required this.until});

  final TimeOfDay until;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final time = context.shortTime(until);
    return Semantics(
      label: context.l10n.boardBusyUntil(time),
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(Icons.schedule, size: 20, color: ww.ink2),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.l10n.boardUntil(time),
              style: boardCell(24, weight: FontWeight.w600, color: ww.ink2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}
