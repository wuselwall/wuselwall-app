import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/core/wusel/wusel_look.dart';

/// The colours Wusel is drawn in for one shade (specs/25 "The drawing"): the body is
/// the brand's Tanne, the tufts are the family's member inks, and at night everything
/// is mixed 72 % over the night ground like the member inks are (specs/17).
@immutable
class WuselColors {
  const WuselColors({
    required this.body,
    required this.limb,
    required this.sclera,
    required this.pupil,
    required this.mouth,
    required this.tufts,
  });

  /// [tufts] are the members' stored colours in board order; they resolve to the
  /// shade's inks here. Empty (before a household exists): swatches 1–4.
  factory WuselColors.of(Shade shade, List<Color> tufts) {
    final inks = [
      for (final c in tufts.isEmpty ? _defaultTufts : tufts)
        MemberPalette.resolve(c).ink(shade),
    ];
    return switch (shade) {
      Shade.light => WuselColors(
        body: const Color(0xFF2D6A4F),
        limb: const Color(0xFF245A42),
        sclera: const Color(0xFFFFFFFF),
        pupil: Palette.light.ink,
        mouth: Palette.light.bg,
        tufts: inks,
      ),
      Shade.dark => WuselColors(
        body: const Color(0xFF6CC79A),
        limb: const Color(0xFF57B086),
        sclera: const Color(0xFFFFFFFF),
        pupil: Palette.light.ink,
        mouth: Palette.dark.bg,
        tufts: inks,
      ),
      Shade.night => WuselColors(
        body: _night(const Color(0xFF6CC79A)),
        limb: _night(const Color(0xFF57B086)),
        sclera: Palette.night.ink,
        pupil: Palette.night.bg,
        mouth: Palette.night.bg,
        tufts: inks,
      ),
    };
  }

  static final _defaultTufts = [
    for (final s in MemberPalette.swatches.take(4)) s.light,
  ];

  static Color _night(Color c) =>
      Color.alphaBlend(c.withValues(alpha: 0.72), Palette.night.bg);

  final Color body;
  final Color limb;
  final Color sclera;
  final Color pupil;
  final Color mouth;

  /// One per tuft, 1–6, already in the shade's inks.
  final List<Color> tufts;

  @override
  bool operator ==(Object other) =>
      other is WuselColors &&
      other.body == body &&
      other.limb == limb &&
      other.sclera == sclera &&
      other.pupil == pupil &&
      other.mouth == mouth &&
      _sameList(other.tufts, tufts);

  @override
  int get hashCode =>
      Object.hash(body, limb, sclera, pupil, mouth, Object.hashAll(tufts));

  static bool _sameList(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Draws Wusel from a [WuselLook] on the reference drawing's 100 × 100 grid
/// (`specs/brand/wusel.svg`), with room around it for arms, hats and confetti. No
/// assets, no dependencies; it repaints only when the look or the colours change.
class WuselPainter extends CustomPainter {
  const WuselPainter({
    required this.look,
    required this.colors,
    this.outfit = WuselOutfit.none,
    this.frontTuft,
  });

  final WuselLook look;
  final WuselColors colors;
  final WuselOutfit outfit;

  /// The tuft drawn first and longer: the member Wusel is speaking to (specs/25).
  final int? frontTuft;

  /// The drawing's frame in grid units: the body's 100 × 100 plus a margin.
  static const Rect frame = Rect.fromLTWH(-15, -22, 130, 130);

  static const _cheek = Color(0x99FF85AE);
  static const _ink = Color(0xFF1C1F23);
  static const _gold = Color(0xFFF2B705);
  static const _goldInk = Color(0xFF3E2A00);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / frame.width;
    canvas
      ..save()
      ..translate(
        (size.width - frame.width * scale) / 2,
        (size.height - frame.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-frame.left, -frame.top);

    if (look.confetti > 0) _confetti(canvas);

    // Everything that belongs to the body moves with it: lift, squash about the feet.
    canvas
      ..save()
      ..translate(0, look.lift)
      ..translate(50, 90)
      ..scale(1 - look.squash * 0.5, 1 + look.squash)
      ..translate(-50, -90);

    _tufts(canvas);
    // An arm that reaches outward starts behind the body; one that reaches in front of
    // it (a hand on the cheek) is drawn over it.
    _arms(canvas, inFront: false);
    if (look.feet) _feet(canvas);
    _body(canvas);
    _arms(canvas, inFront: true);
    _face(canvas);
    _outfit(canvas);
    if (look.prop == WuselProp.star) _star(canvas);
    canvas.restore();

    if (look.thinkDots > 0) _dots(canvas);
    if (look.sleepZ > 0) _zzz(canvas);
    canvas.restore();
  }

  static final Path _bodyPath = Path()
    ..moveTo(50, 27)
    ..cubicTo(75, 27, 88, 42, 88, 61)
    ..cubicTo(88, 81, 72, 90, 50, 90)
    ..cubicTo(28, 90, 12, 81, 12, 61)
    ..cubicTo(12, 42, 25, 27, 50, 27)
    ..close();

  void _body(Canvas canvas) {
    canvas.drawPath(_bodyPath, Paint()..color = colors.body);
    final cheek = Paint()..color = _cheek;
    canvas
      ..drawOval(
        Rect.fromCenter(center: const Offset(27, 70), width: 12, height: 7.2),
        cheek,
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(73, 70), width: 12, height: 7.2),
        cheek,
      );
  }

  /// One stroke per member along the top of the head. Standing tufts curl outwards
  /// like the reference; flying ones reach further, drooping ones fall to the sides.
  void _tufts(Canvas canvas) {
    final n = colors.tufts.length.clamp(1, 6);
    final spread = n <= 4 ? 27.0 : 34.0;
    final order = [for (var i = 0; i < n; i++) i];
    // The front tuft is painted last so it sits on top of its neighbours.
    if (frontTuft != null && frontTuft! < n) {
      order
        ..remove(frontTuft)
        ..add(frontTuft!);
    }
    for (final i in order) {
      final t = n == 1 ? 0.5 : i / (n - 1);
      final side = (t - 0.5) * 2; // −1 left … 1 right
      final base = Offset(50 - spread / 2 + spread * t, 28 + 4 * side * side);
      final front = i == frontTuft;
      // Angle from straight up, outward positive on the right.
      final droop = math.max(0, -look.tuftLift).toDouble();
      final length =
          ((front ? 23.0 : 19.0) + 6 * math.max(0, look.tuftLift)) *
          (1 - 0.35 * droop);
      // A middle tuft droops to the side it is nearer, so none hangs over the face.
      final droopSide = side.abs() < 0.01 ? (i.isEven ? -1.0 : 1.0) : side.sign;
      final angle =
          side * (0.35 + 0.25 * math.max(0, look.tuftLift)) +
          droopSide * droop * 0.85 +
          look.tuftSway;
      final dir = Offset(math.sin(angle), -math.cos(angle));
      final tip = base + dir * length;
      // The curl: the control point leans away from the direction of travel.
      final curl = -side.sign * (side == 0 ? 0 : 1) * (0.45 - droop * 0.2);
      final ctrlDir = Offset(math.sin(angle + curl), -math.cos(angle + curl));
      final ctrl = base + ctrlDir * (length * 0.55);
      final path = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = colors.tufts[i % colors.tufts.length]
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = front ? 7.5 : 6.5,
      );
    }
  }

  void _arms(Canvas canvas, {required bool inFront}) {
    final paint = Paint()
      ..color = colors.limb
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9;
    if (look.armLeft case final a? when (a < 0) == inFront) {
      const shoulder = Offset(17, 64);
      canvas.drawLine(
        shoulder,
        shoulder + Offset(-math.sin(a), math.cos(a)) * 17,
        paint,
      );
    }
    if (look.armRight case final a? when (a < 0) == inFront) {
      const shoulder = Offset(83, 64);
      canvas.drawLine(
        shoulder,
        shoulder + Offset(math.sin(a), math.cos(a)) * 17,
        paint,
      );
    }
  }

  void _feet(Canvas canvas) {
    final paint = Paint()
      ..color = colors.limb
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;
    canvas
      ..drawLine(const Offset(38, 88), const Offset(38, 96), paint)
      ..drawLine(const Offset(62, 88), const Offset(62, 96), paint);
  }

  void _face(Canvas canvas) {
    final pupil = Paint()..color = colors.pupil;
    final line = Paint()
      ..color = colors.pupil
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.2;
    switch (look.eyes) {
      case WuselEyes.happy:
        for (final x in const [29.0, 55.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(x, 58)
              ..quadraticBezierTo(x + 8, 48, x + 16, 58),
            line,
          );
        }
      case WuselEyes.closed:
        for (final x in const [30.0, 56.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(x, 56)
              ..quadraticBezierTo(x + 7, 62, x + 14, 56),
            line..strokeWidth = 4,
          );
        }
      case WuselEyes.round:
        if (look.eyeOpen < 0.15) {
          for (final x in const [30.0, 56.0]) {
            canvas.drawLine(Offset(x, 57), Offset(x + 14, 57), line);
          }
        } else {
          final sclera = Paint()..color = colors.sclera;
          for (final c in const [Offset(37, 56), Offset(63, 56)]) {
            canvas
              ..save()
              ..translate(c.dx, c.dy)
              ..scale(1, look.eyeOpen)
              ..drawCircle(Offset.zero, 9.5, sclera)
              ..drawCircle(look.gaze, 5, pupil)
              ..restore();
          }
        }
    }

    final mouth = Paint()
      ..color = colors.mouth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (look.mouth) {
      case WuselMouth.w:
        canvas.drawPath(
          Path()
            ..moveTo(40, 71)
            ..relativeQuadraticBezierTo(5, 7, 10, 0)
            ..relativeQuadraticBezierTo(5, 7, 10, 0),
          mouth
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.6,
        );
      case WuselMouth.open:
        canvas.drawPath(
          Path()
            ..moveTo(39, 69)
            ..quadraticBezierTo(50, 84, 61, 69)
            ..close(),
          mouth..style = PaintingStyle.fill,
        );
      case WuselMouth.sleepy:
        canvas.drawPath(
          Path()
            ..moveTo(45, 72)
            ..relativeQuadraticBezierTo(5, 3, 10, 0),
          mouth
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2,
        );
    }
  }

  void _star(Canvas canvas) {
    final a = look.armRight ?? 2.4;
    final hand = const Offset(83, 64) + Offset(math.sin(a), math.cos(a)) * 19;
    final centre = hand + const Offset(4, -8);
    final glint = 1 + 0.18 * look.propGlint;
    final star = Path();
    for (var k = 0; k < 10; k++) {
      final r = (k.isEven ? 11.0 : 4.8) * glint;
      final ang = -math.pi / 2 + k * math.pi / 5;
      final p = centre + Offset(math.cos(ang), math.sin(ang)) * r;
      k == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas
      ..drawPath(star, Paint()..color = _gold)
      ..drawPath(
        star,
        Paint()
          ..color = _goldInk
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2,
      );
  }

  void _dots(Canvas canvas) {
    final paint = Paint()..color = colors.limb;
    const dots = [
      (Offset(86, 30), 3.0),
      (Offset(95, 21), 4.0),
      (Offset(105, 10), 5.0),
    ];
    for (var i = 0; i < dots.length; i++) {
      final shown = ((look.thinkDots * 4) - i).clamp(0.0, 1.0);
      if (shown <= 0) continue;
      canvas.drawCircle(
        dots[i].$1,
        dots[i].$2,
        paint..color = colors.limb.withValues(alpha: shown),
      );
    }
  }

  void _zzz(Canvas canvas) {
    final colour = colors.limb.withValues(alpha: look.sleepZ.clamp(0, 1));
    void z(Offset at, double s) {
      final p = Path()
        ..moveTo(at.dx, at.dy)
        ..lineTo(at.dx + s, at.dy)
        ..lineTo(at.dx, at.dy + s)
        ..lineTo(at.dx + s, at.dy + s);
      canvas.drawPath(
        p,
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final drift = -6 * look.sleepZ;
    z(Offset(80, 20 + drift), 9);
    z(Offset(93, 6 + drift * 1.4), 6.5);
  }

  void _confetti(Canvas canvas) {
    // A fixed scatter in the family's colours plus points gold, rising and fading.
    final colours = [...colors.tufts, _gold];
    final p = look.confetti;
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final x = -8 + rnd.nextDouble() * 116;
      final y0 = 10 + rnd.nextDouble() * 20;
      final y = y0 - 30 * p + 18 * p * p;
      final rot = rnd.nextDouble() * math.pi + p * 4;
      final paint = Paint()
        ..color = colours[i % colours.length].withValues(alpha: 1 - p * 0.7);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(rot)
        ..drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2.5, -4, 5, 8),
            const Radius.circular(1.5),
          ),
          paint,
        )
        ..restore();
    }
  }

  void _outfit(Canvas canvas) {
    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    switch (outfit) {
      case WuselOutfit.none:
        return;
      case WuselOutfit.party:
        final hat = Path()
          ..moveTo(50, -6)
          ..lineTo(36, 27)
          ..lineTo(64, 27)
          ..close();
        canvas
          ..drawPath(hat, Paint()..color = Decor.coral.light)
          ..drawPath(hat, outline)
          ..drawCircle(const Offset(50, -7), 4, Paint()..color = _gold)
          ..drawCircle(
            const Offset(46, 14),
            2.4,
            Paint()..color = const Color(0xFFFFFFFF),
          )
          ..drawCircle(
            const Offset(54, 20),
            2.4,
            Paint()..color = const Color(0xFFFFFFFF),
          );
      case WuselOutfit.crown:
        final crown = Path()
          ..moveTo(34, 29)
          ..lineTo(34, 11)
          ..lineTo(42, 19)
          ..lineTo(50, 7)
          ..lineTo(58, 19)
          ..lineTo(66, 11)
          ..lineTo(66, 29)
          ..close();
        canvas
          ..drawPath(crown, Paint()..color = _gold)
          ..drawPath(crown, outline..color = _goldInk);
      case WuselOutfit.wizard:
        final hat = Path()
          ..moveTo(50, -10)
          ..lineTo(32, 28)
          ..lineTo(68, 28)
          ..close();
        canvas
          ..drawPath(hat, Paint()..color = const Color(0xFF1A4FA8))
          ..drawPath(hat, outline)
          ..drawLine(
            const Offset(26, 28),
            const Offset(74, 28),
            Paint()
              ..color = _ink
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round,
          )
          ..drawCircle(const Offset(48, 14), 2.6, Paint()..color = _gold);
      case WuselOutfit.wreath:
        const petals = [
          (Offset(30, 31), Color(0xFFFF85AE)),
          (Offset(40, 28), Color(0xFFFFC94D)),
          (Offset(50, 26), Color(0xFFFFFFFF)),
          (Offset(60, 28), Color(0xFFFFC94D)),
          (Offset(70, 31), Color(0xFFFF85AE)),
        ];
        for (final (at, colour) in petals) {
          canvas
            ..drawCircle(at, 5, Paint()..color = colour)
            ..drawCircle(at, 5, outline..strokeWidth = 1.2);
        }
      case WuselOutfit.sunglasses:
        final glass = Paint()..color = _ink;
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(25, 49, 24, 14),
              const Radius.circular(6),
            ),
            glass,
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(51, 49, 24, 14),
              const Radius.circular(6),
            ),
            glass,
          )
          ..drawLine(
            const Offset(48, 54),
            const Offset(52, 54),
            glass..strokeWidth = 3,
          );
      case WuselOutfit.scarf:
        final scarf = Paint()..color = const Color(0xFFC2255C);
        canvas
          ..drawPath(
            Path()
              ..moveTo(18, 76)
              ..quadraticBezierTo(50, 88, 82, 76)
              ..lineTo(82, 83)
              ..quadraticBezierTo(50, 95, 18, 83)
              ..close(),
            scarf,
          )
          ..drawPath(
            Path()
              ..moveTo(68, 82)
              ..lineTo(72, 98)
              ..lineTo(79, 96)
              ..lineTo(76, 81)
              ..close(),
            scarf,
          );
      case WuselOutfit.headphones:
        canvas
          ..drawPath(
            Path()
              ..moveTo(19, 58)
              ..quadraticBezierTo(19, 18, 50, 18)
              ..quadraticBezierTo(81, 18, 81, 58),
            Paint()
              ..color = _ink
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4,
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(11, 52, 12, 18),
              const Radius.circular(5),
            ),
            Paint()..color = const Color(0xFF08737F),
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(77, 52, 12, 18),
              const Radius.circular(5),
            ),
            Paint()..color = const Color(0xFF08737F),
          );
      case WuselOutfit.bow:
        final bow = Path()
          ..moveTo(50, 30)
          ..lineTo(36, 20)
          ..lineTo(36, 38)
          ..close()
          ..moveTo(50, 30)
          ..lineTo(64, 20)
          ..lineTo(64, 38)
          ..close();
        canvas
          ..drawPath(bow, Paint()..color = const Color(0xFFFF85AE))
          ..drawPath(bow, outline..strokeWidth = 1.6)
          ..drawCircle(
            const Offset(50, 30),
            4,
            Paint()..color = const Color(0xFFC2255C),
          );
    }
  }

  @override
  bool shouldRepaint(WuselPainter old) =>
      old.look != look ||
      old.colors != colors ||
      old.outfit != outfit ||
      old.frontTuft != frontTuft;
}
