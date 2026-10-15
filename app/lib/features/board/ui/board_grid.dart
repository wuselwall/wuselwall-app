import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';

/// What every zone needs to draw one column: the snapshot, its geometry and whether the
/// night variant is on. Days are read by index, so a zone never looks anything up.
class BoardFrame {
  const BoardFrame({
    required this.board,
    required this.geometry,
    required this.night,
    this.allEvents = false,
  });

  final WeekBoard board;
  final BoardGeometry geometry;
  final bool night;

  /// Every appointment of each day, not only the key ones (FR-8.11, "Alle Termine").
  final bool allEvents;

  /// The appointments the zones draw for day [i]: the key ones, or all with [allEvents].
  List<BoardEvent> eventsOf(int i) =>
      allEvents ? board.days[i].events : board.days[i].keyEvents;

  int? get todayIndex => board.todayIndex;

  DateTime date(int i) => board.days[i].date;

  bool isToday(int i) => i == todayIndex;

  /// A day before today: its content recedes (specs/09 "Today, and the rest of the week").
  bool isPast(int i) => date(i).isBefore(board.today);

  /// The opacity of a day's content: past days at half strength; at night everything
  /// except today and tomorrow at 40 % (specs/09 "Night").
  double opacity(int i) {
    final today = todayIndex;
    var o = 1.0;
    if (isPast(i)) o = math.min(o, 0.5);
    if (night && today != null && i != today && i != today + 1) {
      o = math.min(o, 0.4);
    }
    return o;
  }

  /// The lowest [opacity] over columns [first]..[last], for things that span them.
  double spanOpacity(int first, int last) {
    var o = 1.0;
    for (var i = first; i <= last; i++) {
      o = math.min(o, opacity(i));
    }
    return o;
  }
}

/// Places [child] over columns [first]..[last] of a row. A Stack child of [BoardRow].
Positioned spanCell(
  BoardGeometry g,
  int first,
  int last,
  Widget child, {
  double top = 0,
  double bottom = 0,
  double inset = 0,
}) => Positioned(
  left: g.spanLeft(first) + inset,
  width: g.spanWidth(first, last) - 2 * inset,
  top: top,
  bottom: bottom,
  child: child,
);

/// One row of the board: column hairlines first, then the row's cells. Rows are
/// transparent so the day grounds underneath show through.
class BoardRow extends StatelessWidget {
  const BoardRow({required this.geometry, required this.children, super.key});

  final BoardGeometry geometry;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: CustomPaint(painter: _LinePainter(geometry, context.ww.line)),
      ),
      ...children,
    ],
  );
}

class _LinePainter extends CustomPainter {
  const _LinePainter(this.geometry, this.color);

  final BoardGeometry geometry;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var i = 0; i < BoardGeometry.dayCount; i++) {
      canvas.drawRect(
        Rect.fromLTWH(geometry.left(i), 0, 1, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.color != color ||
      old.geometry.canvasWidth != geometry.canvasWidth ||
      old.geometry.todayIndex != geometry.todayIndex;
}

/// The column grounds across the whole body: today's column and past days.
/// `null` entries keep the page ground.
class GroundPainter extends CustomPainter {
  const GroundPainter(this.geometry, this.grounds);

  final BoardGeometry geometry;
  final List<Color?> grounds;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < grounds.length; i++) {
      final color = grounds[i];
      if (color == null) continue;
      canvas.drawRect(
        Rect.fromLTWH(geometry.left(i), 0, geometry.width(i), size.height),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(GroundPainter old) =>
      old.geometry.todayIndex != geometry.todayIndex ||
      old.geometry.canvasWidth != geometry.canvasWidth ||
      !_sameColors(old.grounds, grounds);

  static bool _sameColors(List<Color?> a, List<Color?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The 2 px primary border on both sides of today's column, drawn once over every zone.
class TodayBorderPainter extends CustomPainter {
  const TodayBorderPainter(this.geometry, this.color);

  final BoardGeometry geometry;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final i = geometry.todayIndex;
    if (i == null) return;
    final paint = Paint()..color = color;
    final left = geometry.left(i);
    final right = left + geometry.width(i);
    canvas
      ..drawRect(Rect.fromLTWH(left, 0, 2, size.height), paint)
      ..drawRect(Rect.fromLTWH(right - 2, 0, 2, size.height), paint);
  }

  @override
  bool shouldRepaint(TodayBorderPainter old) =>
      old.color != color ||
      old.geometry.todayIndex != geometry.todayIndex ||
      old.geometry.canvasWidth != geometry.canvasWidth;
}

/// A dashed outline around its child: the "not certain yet" treatment of a tentative
/// appointment, in ink-3.
class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 6.0;
    const gap = 4.0;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      const Radius.circular(6),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter old) => old.color != color;
}

/// Makes a tap target with a button semantics label. A GestureDetector, not an
/// InkWell: the board needs no ink ripples and must not depend on a Material ancestor.
class BoardTap extends StatelessWidget {
  const BoardTap({
    required this.label,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  // The label says what the tap opens; the cell's own texts would repeat it
  // ("Lotta, L, Lotta"), so they are not read out separately.
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    ),
  );
}

/// Lets content draw at its natural size inside a fixed cell and clips what does not
/// fit. A crowded cell then loses its last line instead of throwing a layout error,
/// and the zone keeps its geometry (specs/09 "must never scroll and never break").
class ClipFit extends StatelessWidget {
  const ClipFit({
    required this.child,
    this.alignment = Alignment.center,
    super.key,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: OverflowBox(
      alignment: alignment,
      minHeight: 0,
      maxHeight: double.infinity,
      child: child,
    ),
  );
}

/// The quiet band between two zones. The zones need no titles: the gutter names every
/// row (a member, a day part, the meal), so the band only separates them.
class BoardDivider extends StatelessWidget {
  const BoardDivider({this.trailing, super.key});

  static const height = 8.0;

  /// The band of a divider that carries a control: a 56 px kiosk tap target (specs/09).
  static const controlHeight = 56.0;

  /// A control at the right end of the band, such as the Termine zone's "Alle Termine".
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    return Container(
      height: trailing == null ? height : controlHeight,
      padding: trailing == null ? null : const EdgeInsets.only(right: 8),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: ww.sunken,
        border: Border.symmetric(horizontal: BorderSide(color: ww.line)),
      ),
      child: trailing,
    );
  }
}

/// Word text on the board: Atkinson Hyperlegible Next.
TextStyle boardUi(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color? color,
  double height = 1.15,
  bool italic = false,
}) => TextStyle(
  fontFamily: Tokens.fontUi,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
);

/// Times, dates and numbers on the board: Barlow Semi Condensed, tabular figures.
TextStyle boardNum(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color? color,
  double height = 1.15,
}) => TextStyle(
  fontFamily: Tokens.fontNumeric,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Words inside a day cell: Barlow Semi Condensed, the narrow face specs/17 chose so
/// seven columns hold their titles at 24 px. Atkinson stays for labels and names in
/// the gutter, the header and the details.
TextStyle boardCell(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color? color,
  double height = 1.1,
  bool italic = false,
}) => TextStyle(
  fontFamily: Tokens.fontNumeric,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
);
