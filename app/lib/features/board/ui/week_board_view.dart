import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_footer.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_header.dart';
import 'package:wuselwall/features/board/ui/board_meal.dart';
import 'package:wuselwall/features/board/ui/board_presence.dart';
import 'package:wuselwall/features/board/ui/board_zones.dart';
import 'package:wuselwall/features/board/ui/kiosk_canvas.dart';
import 'package:wuselwall/features/rituals/application/birthday_providers.dart';

/// The kiosk week board, drawn at canvas size (wrap it in [KioskCanvas]).
///
/// Seven day columns; every column has the same zones in the same order at the same
/// height, so the eye reads by position (specs/09 "The rule that makes it readable").
/// The fixed bands are the header (with the next-up line), the day names, the dividers
/// between the zones and the footer; the three zones share the rest by flex and never
/// scroll.
/// There is no narrow-screen variant: the canvas is always [KioskCanvas.designWidth] wide.
///
/// Looking ahead (specs/09 "Gestures"), [week] is next week's board: it fills the day
/// columns, while the header and the footer stay with today's [snapshot]. While it
/// loads or fails, [placeholder] stands where the columns go.
class WeekBoardView extends ConsumerWidget {
  const WeekBoardView({
    required this.snapshot,
    this.week,
    this.placeholder,
    super.key,
  });

  final BoardSnapshot snapshot;
  final WeekBoard? week;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = snapshot.board;
    if (today == null) return const SizedBox.shrink();

    final night = ref.watch(nightProvider);
    final allEvents = ref.watch(boardAllEventsProvider);
    BoardFrame frameOf(WeekBoard board) => BoardFrame(
      board: board,
      geometry: BoardGeometry(
        canvasWidth: KioskCanvas.designWidth,
        todayIndex: board.todayIndex,
      ),
      night: night,
      allEvents: allEvents,
    );
    final board = week ?? today;
    final frame = frameOf(board);
    final geometry = frame.geometry;
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;
    // A birthday this week takes the day names' second line, as a holiday does.
    final headerHeight = DayHeaderRow.heightOf(
      board,
      birthdays: ref
          .watch(weekBirthdaysProvider(board.days.first.date))
          .any((d) => d.isNotEmpty),
    );
    // Past days and, at night, every day but today and tomorrow recede through their
    // ground colour rather than through opacity on their own text (A6/A7,
    // `t_da411148`): the text keeps its full, contrast-checked colour in every shade.
    final grounds = [
      for (var i = 0; i < BoardGeometry.dayCount; i++)
        frame.recede(i)
            ? ww.sunken
            : frame.isToday(i)
            ? scheme.surfaceContainerLow
            : null,
    ];

    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          BoardHeader(
            frame: week == null ? frame : frameOf(today),
            snapshot: snapshot,
          ),
          if (snapshot.isStale) const BoardOfflineBanner(),
          if (placeholder case final placeholder?)
            Expanded(child: placeholder)
          else
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: GroundPainter(geometry, grounds),
                    ),
                  ),
                  // Under the zones: a bar that runs across today covers the border.
                  if (frame.todayIndex != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: TodayBorderPainter(geometry, scheme.primary),
                        ),
                      ),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final scaler = MediaQuery.textScalerOf(context);
                      final reserved =
                          headerHeight +
                          56 * board.members.length +
                          math.max(56, scaler.scale(24) * 1.15 + 12) +
                          2 * BoardDivider.height +
                          math.max(56, scaler.scale(24) * 1.1 + 10);
                      // Reduce appointment summaries before squeezing any action or
                      // meal below its floor. The zone and all seven days remain.
                      final appointmentHeight =
                          constraints.maxHeight - reserved >= 168
                          ? 168.0
                          : 56.0;
                      return Column(
                        children: [
                          SizedBox(
                            height: headerHeight,
                            child: DayHeaderRow(frame: frame),
                          ),
                          const BoardDivider(),
                          // Compact containing row actions have a real 56px floor.
                          SizedBox(
                            height: 56.0 * board.members.length,
                            child: PresenceRows(frame: frame),
                          ),
                          const BoardDivider(trailing: BoardViewSwitches()),
                          SizedBox(
                            height: appointmentHeight,
                            child: TermineRows(frame: frame),
                          ),
                          const BoardDivider(),
                          Expanded(flex: 8, child: MealRow(frame: frame)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          BoardFooter(board: today, night: night),
        ],
      ),
    );
  }
}
