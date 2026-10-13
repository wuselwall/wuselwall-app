import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
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
/// The fixed bands are the header (with the next-up line), the day names, three zone
/// captions and the footer; the three zones share the rest by flex and never scroll.
/// There is no narrow-screen variant: the canvas is always [KioskCanvas.designWidth] wide.
class WeekBoardView extends ConsumerWidget {
  const WeekBoardView({required this.snapshot, super.key});

  final BoardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = snapshot.board;
    if (board == null) return const SizedBox.shrink();

    final night = ref.watch(nightProvider);
    final geometry = BoardGeometry(
      canvasWidth: KioskCanvas.designWidth,
      todayIndex: board.todayIndex,
    );
    final frame = BoardFrame(board: board, geometry: geometry, night: night);
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
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
                Column(
                  children: [
                    SizedBox(
                      height: DayHeaderRow.height,
                      child: DayHeaderRow(frame: frame),
                    ),
                    BoardCaption(
                      title: l10n.boardZoneWhere,
                      hint: l10n.boardZoneWhereHint,
                    ),
                    // Two units per member, so a household of four gets rows tall
                    // enough for two lines at 1280×800 (school span over its notes,
                    // band over its times); larger households fall back to one line.
                    Expanded(
                      flex: 4 * board.members.length.clamp(1, 8),
                      child: PresenceRows(frame: frame),
                    ),
                    BoardCaption(
                      title: l10n.boardZoneEvents,
                      hint: l10n.boardZoneEventsHint,
                    ),
                    Expanded(flex: 11, child: TermineRows(frame: frame)),
                    BoardCaption(
                      title: l10n.boardZoneMeal,
                      hint: l10n.boardZoneMealHint,
                    ),
                    Expanded(flex: 8, child: MealRow(frame: frame)),
                  ],
                ),
                if (frame.todayIndex != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: TodayBorderPainter(geometry, scheme.primary),
                      ),
                    ),
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
