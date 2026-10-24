import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// The sky behind a header (specs/26 "Ambience"): the phase of the day, a sun or a
/// moon, a hill, the season and today's occasions. It changes decoration only, never
/// the layout, and nothing on it carries meaning: the text in front of it stays `ink`.
/// Without `device.sky` it is the module's plain band.
class AmbienceSky extends ConsumerWidget {
  const AmbienceSky({required this.child, this.fallback, super.key});

  final Widget child;

  /// The ground when the sky is switched off; the shade's surface if null.
  final Color? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ww = context.ww;
    if (!ref.watch(lighterDayProvider).sky) {
      return ColoredBox(
        color: fallback ?? Theme.of(context).colorScheme.surface,
        child: child,
      );
    }
    final ambience = ref.watch(ambienceProvider);
    return AnimatedSwitcher(
      // The phase changes with a slow cross-fade nobody notices from two metres.
      duration: const Duration(seconds: 30),
      child: CustomPaint(
        key: ValueKey((ambience.phase, ww.shade)),
        painter: SkyPainter(ambience: ambience, shade: ww.shade),
        child: child,
      ),
    );
  }
}

/// Paints [ambience] for [shade]. In light the phase's gradient; in dark the sun band
/// with the same shapes and no gradient; at night the night sky with dim stars.
class SkyPainter extends CustomPainter {
  const SkyPainter({required this.ambience, required this.shade});

  final Ambience ambience;
  final Shade shade;

  bool get _night => shade == Shade.night;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final phase = _night
        ? SkyPhase.night
        // Outside the night theme, the night hours keep the evening's light sky.
        : (ambience.phase == SkyPhase.night
              ? SkyPhase.evening
              : ambience.phase);
    if (shade == Shade.light || _night) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [phase.top, phase.bottom],
          ).createShader(rect),
      );
    } else {
      canvas.drawRect(
        rect,
        Paint()..color = ModuleBands.of(AppModule.today).dark,
      );
    }

    if (_night) {
      _stars(canvas, size);
      _moon(canvas, size);
      if (ambience.newYear) _fireworks(canvas, size);
      return;
    }
    _sun(canvas, size, phase);
    _hill(canvas, size);
    if (ambience.season case final season?) _season(canvas, size, season);
    if (ambience.easter) _eggs(canvas, size);
    if (ambience.advent > 0) _candles(canvas, size, ambience.advent);
    if (ambience.birthdays.isNotEmpty) _bunting(canvas, size);
  }

  void _sun(Canvas canvas, Size size, SkyPhase phase) {
    // Low in the morning on the left, high at noon, setting on the right.
    final x = switch (phase) {
      SkyPhase.morning => 0.42,
      SkyPhase.day => 0.36,
      _ => 0.52,
    };
    final y = switch (phase) {
      SkyPhase.morning => 0.62,
      SkyPhase.day => 0.22,
      _ => 0.72,
    };
    final r = size.height * 0.2;
    final colour = shade == Shade.light
        ? phase.orb
        : Decor.sun.dark.withValues(alpha: 0.7);
    canvas.drawCircle(
      Offset(size.width * x, size.height * y),
      r,
      Paint()..color = colour,
    );
  }

  void _moon(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.52, size.height * 0.35);
    final r = size.height * 0.18;
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..drawCircle(
        c,
        r,
        Paint()..color = SkyPhase.night.orb.withValues(alpha: 0.55),
      )
      ..drawCircle(
        c + Offset(r * 0.45, -r * 0.15),
        r * 0.9,
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();
  }

  void _stars(Canvas canvas, Size size) {
    // Dim and few: nothing bright and static on an always-on screen at night.
    final paint = Paint()..color = Palette.night.ink2.withValues(alpha: 0.45);
    final r = math.Random(3);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(
        Offset(r.nextDouble() * size.width, r.nextDouble() * size.height * 0.8),
        0.8 + r.nextDouble() * 0.8,
        paint,
      );
    }
  }

  void _hill(Canvas canvas, Size size) {
    final colour = shade == Shade.light
        ? ModuleBands.of(AppModule.today).light.withValues(alpha: 0.9)
        : Palette.dark.surface.withValues(alpha: 0.5);
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * 0.05,
        size.height * 0.78,
        size.width * 1.1,
        size.height * 0.9,
      ),
      Paint()..color = colour,
    );
  }

  void _season(Canvas canvas, Size size, Season season) {
    final r = math.Random(season.index + 11);
    final colour = switch (season) {
      Season.spring => const Color(0xFFFF85AE),
      Season.summer => Decor.sun.light,
      Season.autumn => Decor.apricot.light,
      Season.winter => const Color(0xFFFFFFFF),
    }.withValues(alpha: shade == Shade.light ? 0.85 : 0.5);
    final paint = Paint()..color = colour;
    for (var i = 0; i < 9; i++) {
      // Only in the right two thirds: the clock and date sit on the left.
      final at = Offset(
        size.width * (0.38 + r.nextDouble() * 0.6),
        size.height * (0.08 + r.nextDouble() * 0.6),
      );
      switch (season) {
        case Season.autumn:
          canvas
            ..save()
            ..translate(at.dx, at.dy)
            ..rotate(r.nextDouble() * math.pi)
            ..drawOval(const Rect.fromLTWH(-4, -2, 8, 4), paint)
            ..restore();
        case Season.summer:
          canvas.drawCircle(at, 1.6, paint);
        case Season.spring || Season.winter:
          canvas.drawCircle(at, 2.4, paint);
      }
    }
  }

  void _eggs(Canvas canvas, Size size) {
    final colours = [Decor.coral, Decor.sky, Decor.mint];
    for (var i = 0; i < 3; i++) {
      final c = Offset(size.width * (0.7 + i * 0.05), size.height * 0.86);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 9, height: 12),
        Paint()..color = colours[i].of(shade),
      );
    }
  }

  void _candles(Canvas canvas, Size size, int lit) {
    final base = size.height * 0.9;
    for (var i = 0; i < 4; i++) {
      final x = size.width * 0.86 + i * 14;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, base - 22, 8, 22),
          const Radius.circular(2),
        ),
        Paint()..color = Decor.coral.of(shade),
      );
      if (i < lit) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x + 4, base - 28),
            width: 6,
            height: 10,
          ),
          Paint()..color = Decor.sun.light,
        );
      }
    }
  }

  void _bunting(Canvas canvas, Size size) {
    // Little flags in the birthday child's colour across the top of the sky.
    final colours = [
      for (final stored in ambience.birthdays)
        MemberPalette.resolve(stored).ink(shade),
    ];
    const flags = 18;
    final step = size.width / flags;
    final line = Paint()
      ..color = colours.first.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), line);
    for (var i = 0; i < flags; i++) {
      final x = i * step + step * 0.15;
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + step * 0.7, 0)
        ..lineTo(x + step * 0.35, 12)
        ..close();
      canvas.drawPath(path, Paint()..color = colours[i % colours.length]);
    }
  }

  void _fireworks(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.night.ink2.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final c in [
      Offset(size.width * 0.7, size.height * 0.35),
      Offset(size.width * 0.84, size.height * 0.5),
    ]) {
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + d * 4, c + d * 11, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) =>
      old.ambience != ambience || old.shade != shade;
}
