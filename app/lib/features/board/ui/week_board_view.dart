import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/board_footer.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_header.dart';
import 'package:wuselwall/features/board/ui/board_meal.dart';
import 'package:wuselwall/features/board/ui/board_presence.dart';
import 'package:wuselwall/features/board/ui/board_zones.dart';
import 'package:wuselwall/features/board/ui/kiosk_canvas.dart';

/// The kiosk week board, drawn at canvas size (wrap it in [KioskCanvas]).
///
/// Seven day columns; every column has the same zones in the same order at the same
/// height, so the eye reads by position (specs/09 "The rule that makes it readable").
/// The fixed bands are the header (with the next-up line), the day names, the dividers
/// between the zones and the footer; the three zones share the rest by flex and never
/// scroll.
/// There is no narrow-screen variant: the canvas is always [KioskCanvas.designWidth] wide.
class WeekBoardView extends ConsumerWidget {
  const WeekBoardView({required this.snapshot, super.key});

  final BoardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = snapshot.board;
    if (board == null) return const SizedBox.shrink();

    final night = ref.watch(nightProvider);
    final allEvents = ref.watch(boardAllEventsProvider);
    final geometry = BoardGeometry(
      canvasWidth: KioskCanvas.designWidth,
      todayIndex: board.todayIndex,
    );
    final frame = BoardFrame(
      board: board,
      geometry: geometry,
      night: night,
      allEvents: allEvents,
    );
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;
    final grounds = [
      for (var i = 0; i < BoardGeometry.dayCount; i++)
        frame.isPast(i)
            ? ww.sunken
            : frame.isToday(i)
            ? scheme.surfaceContainerLow
            : null,
    ];

    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          BoardHeader(frame: frame, snapshot: snapshot),
          if (snapshot.isStale) const BoardOfflineBanner(),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: GroundPainter(geometry, grounds)),
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
                Column(
                  children: [
                    SizedBox(
                      height: DayHeaderRow.heightOf(board),
                      child: DayHeaderRow(frame: frame),
                    ),
                    const BoardDivider(),
                    // Four units per member, so a household of four gets rows tall
                    // enough for two lines at 1280×800 (school span over its notes,
                    // band over its times); larger households fall back to one line.
                    // The day parts and the meal get the heights their two-line
                    // layouts need at that size too.
                    Expanded(
                      flex: 4 * board.members.length.clamp(1, 8),
                      child: PresenceRows(frame: frame),
                    ),
                    const BoardDivider(trailing: BoardAllEventsToggle()),
                    Expanded(flex: 11, child: TermineRows(frame: frame)),
                    const BoardDivider(),
                    Expanded(flex: 8, child: MealRow(frame: frame)),
                  ],
                ),
              ],
            ),
          ),
          BoardFooter(board: board, night: night),
        ],
      ),
    );
  }
}
