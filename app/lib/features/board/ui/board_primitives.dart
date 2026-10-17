import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';

/// Geometry shared by the presence band and its painters (specs/17 "Presence
/// treatments"). Hatch and dot periods are in logical px at kiosk scale.
const _bandRadius = 8.0;
const _tipDepth = 12.0;
const _hatchPeriod = 6.0;
const _hatchStroke = 2.0;
const _dotGrid = 7.0;
const _dotRadius = 1.5;
const _dashOn = 6.0;
const _dashOff = 4.0;

/// One line of text that shrinks a little before it loses its end: down to [minScale],
/// then it keeps that size and ends in an ellipsis. A label in a narrow column stays
/// readable from across the room instead of shrinking to a smudge.
class ShrinkText extends StatelessWidget {
  const ShrinkText(
    this.text, {
    required this.style,
    this.minScale = 0.8,
    super.key,
  });

  final String text;
  final TextStyle style;
  final double minScale;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final natural = painter.width;
      painter.dispose();
      // A little under the exact ratio: glyph widths do not scale quite linearly,
      // and the exact size would still lose its last letter.
      final scale = natural <= c.maxWidth ? 1.0 : c.maxWidth / natural * 0.97;
      // NFR-16/A6: no kiosk text may render below the kiosk's 24 px floor, whatever
      // [minScale] asks for. A caller's narrower minScale (e.g. the baseline track's
      // 0.7) only matters when the base size is already above the floor; once scale
      // would cross it, the label truncates with an ellipsis instead of shrinking
      // further (specs/09 "degradation rules": truncate content, not font size).
      final floorScale = (UiRegister.kiosk.minFontSize / style.fontSize!).clamp(
        0.0,
        1.0,
      );
      final effectiveMinScale = math.max(minScale, floorScale);
      final fitted = scale >= effectiveMinScale ? scale : effectiveMinScale;
      return Text(
        text,
        style: style.copyWith(fontSize: style.fontSize! * fitted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      );
    },
  );
}

/// A presence deviation drawn with its state's treatment (specs/17 "Presence
/// treatments"): working solid, home office hatched, travel chevron + ✈, away dashed,
/// off outlined, childcare dotted. Fills the width it is given; one line of [label]
/// and an optional second line [detail] ("8:30–14:00").
///
/// [openStart] / [openEnd]: the band continues from the previous / into the next
/// column; that side gets square corners and no border, so neighbouring cells join
/// into one band. [tentative] draws the outline dashed whatever the state.
class PresenceBandView extends StatelessWidget {
  const PresenceBandView({
    required this.state,
    required this.memberColor,
    required this.label,
    this.detail,
    this.openStart = false,
    this.openEnd = false,
    this.tentative = false,
    this.dense = false,
    this.fontSize = 24,
    this.lineHeight,
    super.key,
  });

  final PresenceState state;

  /// The member's stored colour; resolve with `context.ww.member(memberColor)`.
  final Color memberColor;
  final String label;
  final String? detail;
  final bool openStart;
  final bool openEnd;
  final bool tentative;

  /// Smaller padding for crowded cells.
  final bool dense;

  /// Text and icon size: 24 on the wall (the kiosk minimum), the theme's body size in
  /// the adult and kid registers.
  final double fontSize;

  /// The text's line height; null keeps the font's own. The wall sets it tighter so a
  /// band's label and time fit a member row together.
  final double? lineHeight;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final mc = ww.member(memberColor);
    final ink = Theme.of(context).colorScheme.onSurface;
    final shown = tentative ? '$label ?' : label;
    final tip = state == PresenceState.travel && !openEnd;

    Color? fill;
    var pattern = _Pattern.flat;
    var textColor = ink;
    var pill = false;
    IconData? icon;
    Color? iconColor;
    switch (state) {
      case PresenceState.working:
        fill = mc.ink;
        textColor = mc.onInk;
      case PresenceState.homeOffice:
        fill = mc.tint;
        pattern = _Pattern.hatch;
        pill = true;
      case PresenceState.travel:
        fill = mc.ink;
        textColor = mc.onInk;
        icon = Icons.flight;
        iconColor = mc.onInk;
      case PresenceState.away:
        fill = mc.tint;
      case PresenceState.off:
        textColor = ww.ink3;
      case PresenceState.childcare:
        fill = mc.tint;
        pattern = _Pattern.dots;
        pill = true;
        icon = Icons.child_care;
        iconColor = mc.ink;
    }

    // Away is dashed by design; any tentative band is dashed too. Off keeps its thin
    // solid outline unless it is tentative.
    final dashed = tentative || state == PresenceState.away;
    final double? borderWidth = dashed
        ? 2
        : state == PresenceState.off
        ? 1.5
        : null;

    final vPad = dense ? 3.0 : 6.0;
    final hPad = dense ? 6.0 : 10.0;

    final textBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A narrow band shrinks its label a little before cutting it.
        ShrinkText(
          shown,
          style: TextStyle(
            fontFamily: Tokens.fontUi,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: textColor,
            height: lineHeight,
          ),
        ),
        if (detail != null)
          Text(
            detail!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Tokens.fontNumeric,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: lineHeight,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );

    // Hatched and dotted bands put their words on a small tint pill so the stripes
    // never sit under text.
    final body = pill
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: mc.tint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: textBlock,
            ),
          )
        : textBlock;

    Widget leading(IconData i, Color c) => Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(i, size: fontSize, color: c),
    );

    final row = Row(
      children: [
        if (openStart) leading(Icons.chevron_left, textColor),
        if (icon != null) leading(icon, iconColor ?? textColor),
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: body),
        ),
        if (openEnd)
          Icon(Icons.chevron_right, size: fontSize, color: textColor),
      ],
    );

    final ground = fill == null
        ? null
        : _GroundPainter(
            fill: fill,
            pattern: pattern,
            mark: mc.ink,
            tip: tip,
            openStart: openStart,
            openEnd: openEnd,
          );

    return Semantics(
      label: '$shown${detail != null ? ', $detail' : ''}',
      excludeSemantics: true,
      child: CustomPaint(
        painter: ground,
        foregroundPainter: borderWidth == null
            ? null
            : _BorderPainter(
                color: mc.ink,
                width: borderWidth,
                dashed: dashed,
                tip: tip,
                openStart: openStart,
                openEnd: openEnd,
              ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            hPad,
            vPad,
            hPad + (tip ? _tipDepth : 0),
            vPad,
          ),
          child: row,
        ),
      ),
    );
  }
}

/// The quiet baseline chip: `sunken` ground, `ink-2` text, a 10 px dot in the member's
/// ink (6 px at phone scale, larger on the wall). Never a band (specs/17).
class BaselineChip extends StatelessWidget {
  const BaselineChip({
    required this.memberColor,
    required this.label,
    super.key,
  });

  final Color memberColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final mc = ww.member(memberColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ww.sunken,
        borderRadius: BorderRadius.circular(_bandRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: mc.ink, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Tokens.fontUi,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: ww.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One member dot: filled in the member's ink, or hollow (a ring) when [filled] is
/// false. Always carries a semantics label.
class MemberDot extends StatelessWidget {
  const MemberDot({
    required this.memberColor,
    required this.semanticLabel,
    this.filled = true,
    this.size = 14,
    super.key,
  });

  final Color memberColor;
  final String semanticLabel;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mc = context.ww.member(memberColor);
    final ring = math.max(2.0, size / 7);
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: filled
              ? BoxDecoration(color: mc.ink, shape: BoxShape.circle)
              : BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: mc.ink, width: ring),
                ),
        ),
      ),
    );
  }
}

/// A row of [MemberDot]s with a small gap, in the order given. A Wrap, so a crowded
/// meal or event wraps onto a second line rather than overflowing its cell.
class MemberDots extends StatelessWidget {
  const MemberDots({required this.dots, this.size = 14, super.key});

  final List<MemberDot> dots;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gap = size * 0.35;
    return Wrap(spacing: gap, runSpacing: gap, children: dots);
  }
}

/// A member's avatar: a circle in their ink with their initial in `onInk`.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({required this.member, this.size = 40, super.key});

  final BoardMember member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mc = context.ww.member(member.color);
    return Semantics(
      label: member.displayName,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: mc.ink, shape: BoxShape.circle),
        child: Text(
          member.initial,
          style: TextStyle(
            fontFamily: Tokens.fontUi,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.5,
            color: mc.onInk,
          ),
        ),
      ),
    );
  }
}

/// A lesson tile ground: the subject's paper tint (specs/17 "paper") with a 1 px `line`
/// border, `ink` text. [tint] is a `PaperTints` key; unknown or null → `stone`.
class PaperTile extends StatelessWidget {
  const PaperTile({
    required this.child,
    this.tint,
    this.struckThrough = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    super.key,
  });

  final Widget child;
  final String? tint;

  /// Entfall: the tile recedes (50 % opacity) and gets a diagonal strike.
  final bool struckThrough;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    final tints = PaperTints.tints;
    final paper =
        tints.where((t) => t.key == tint).firstOrNull ??
        tints.firstWhere((t) => t.key == 'stone');
    final tile = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ww.paper(paper),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ww.line),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        child: child,
      ),
    );
    if (!struckThrough) return tile;
    return CustomPaint(
      foregroundPainter: _StrikePainter(ww.ink2),
      child: Opacity(opacity: 0.5, child: tile),
    );
  }
}

enum _Pattern { flat, hatch, dots }

/// The band's outline as a path, with its corners rounded by [radius] (clamped to the
/// rect). A side that is open ([openStart] / [openEnd]) is square; with [border] set
/// the open side is skipped, so a border never closes the seam between two cells. A
/// [tip] makes the right end a point [_tipDepth] deep (travel, when not open).
Path _bandPath(
  Rect r, {
  required bool openStart,
  required bool openEnd,
  required bool tip,
  required double radius,
  bool border = false,
}) {
  final l = r.left;
  final t = r.top;
  final rt = r.right;
  final b = r.bottom;
  final rad = math.max(0.0, math.min(radius, math.min(r.width, r.height) / 2));
  final depth = tip ? math.min(_tipDepth, r.width / 2) : 0.0;
  final p = Path();

  if (openStart) {
    p.moveTo(l, t);
  } else {
    p.moveTo(l, t + rad);
    p.arcToPoint(Offset(l + rad, t), radius: Radius.circular(rad));
  }

  if (openEnd) {
    p.lineTo(rt, t);
  } else if (tip) {
    p.lineTo(rt - depth, t);
  } else {
    p.lineTo(rt - rad, t);
    p.arcToPoint(Offset(rt, t + rad), radius: Radius.circular(rad));
  }

  if (openEnd) {
    if (border) {
      p.moveTo(rt, b);
    } else {
      p.lineTo(rt, b);
    }
  } else if (tip) {
    p.lineTo(rt, (t + b) / 2);
    p.lineTo(rt - depth, b);
  } else {
    p.lineTo(rt, b - rad);
    p.arcToPoint(Offset(rt - rad, b), radius: Radius.circular(rad));
  }

  if (openStart) {
    p.lineTo(l, b);
  } else {
    p.lineTo(l + rad, b);
    p.arcToPoint(Offset(l, b - rad), radius: Radius.circular(rad));
  }

  // A border with an open start must not close the left seam.
  if (!border || !openStart) p.close();
  return p;
}

/// Splits [src] into dashes of [on] px with gaps of [off] px.
Path _dashed(Path src, double on, double off) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    var d = 0.0;
    var drawing = true;
    while (d < m.length) {
      final next = math.min(d + (drawing ? on : off), m.length);
      if (drawing) out.addPath(m.extractPath(d, next), Offset.zero);
      d = next;
      drawing = !drawing;
    }
  }
  return out;
}

/// The band's ground: a flat fill, or a fill with diagonal stripes or a dot grid
/// clipped to the band shape.
class _GroundPainter extends CustomPainter {
  const _GroundPainter({
    required this.fill,
    required this.pattern,
    required this.mark,
    required this.tip,
    required this.openStart,
    required this.openEnd,
  });

  final Color fill;
  final _Pattern pattern;
  final Color mark;
  final bool tip;
  final bool openStart;
  final bool openEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _bandPath(
      Offset.zero & size,
      openStart: openStart,
      openEnd: openEnd,
      tip: tip,
      radius: _bandRadius,
    );
    canvas.drawPath(path, Paint()..color = fill);
    if (pattern == _Pattern.flat) return;

    canvas.save();
    canvas.clipPath(path);
    final paint = Paint()..color = mark;
    if (pattern == _Pattern.hatch) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = _hatchStroke;
      for (var x = -size.height; x < size.width; x += _hatchPeriod) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          paint,
        );
      }
    } else {
      for (var y = _dotGrid / 2; y < size.height; y += _dotGrid) {
        for (var x = _dotGrid / 2; x < size.width; x += _dotGrid) {
          canvas.drawCircle(Offset(x, y), _dotRadius, paint);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GroundPainter old) =>
      old.fill != fill ||
      old.pattern != pattern ||
      old.mark != mark ||
      old.tip != tip ||
      old.openStart != openStart ||
      old.openEnd != openEnd;
}

/// The band's outline, inset by half its stroke so it sits inside the band's bounds.
class _BorderPainter extends CustomPainter {
  const _BorderPainter({
    required this.color,
    required this.width,
    required this.dashed,
    required this.tip,
    required this.openStart,
    required this.openEnd,
  });

  final Color color;
  final double width;
  final bool dashed;
  final bool tip;
  final bool openStart;
  final bool openEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = width / 2;
    var path = _bandPath(
      (Offset.zero & size).deflate(inset),
      openStart: openStart,
      openEnd: openEnd,
      tip: tip,
      radius: _bandRadius - inset,
      border: true,
    );
    if (dashed) path = _dashed(path, _dashOn, _dashOff);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant _BorderPainter old) =>
      old.color != color ||
      old.width != width ||
      old.dashed != dashed ||
      old.tip != tip ||
      old.openStart != openStart ||
      old.openEnd != openEnd;
}

/// The diagonal strike of an Entfall tile, from bottom-left to top-right.
class _StrikePainter extends CustomPainter {
  const _StrikePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _StrikePainter old) => old.color != color;
}
