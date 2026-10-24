import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';

/// A module's small picture in its band (specs/26 "Module bands"): a basket for the
/// shopping, a broom and a star for the tasks, a calendar page, a pot, a school bag and,
/// calm, two sliders for the settings. Drawn in code from the decorative colours, at
/// most two each, and cropped by the band's lower edge.
///
/// It is decoration: no text sits on it, it means nothing and a screen reader skips
/// it. It goes in the app bar's actions, before the buttons, so it takes its own room
/// and never lies under the title or a control; [fits] says whether there is that room.
/// Today has none (its band is the sky), and the night has no bands at all.
class ModuleIllustration extends StatelessWidget {
  const ModuleIllustration(this.module, {super.key});

  final AppModule module;

  /// The room it takes in the bar.
  static const width = 104.0;

  /// Whether the picture fits a bar whose title is [title] and whose other controls
  /// (back button, actions) take [controls] logical pixels, with the title at the
  /// text size in use and a gap after it. On a narrow phone it stays away rather than
  /// crowd the title.
  static bool fits(
    BuildContext context, {
    required String title,
    double controls = 0,
  }) {
    final theme = Theme.of(context);
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final need =
        Tokens.space4 + painter.width + Tokens.space6 + width + controls;
    painter.dispose();
    return MediaQuery.sizeOf(context).width >= need;
  }

  @override
  Widget build(BuildContext context) {
    final shade = context.ww.shade;
    if (shade == Shade.night || module == AppModule.today) {
      return const SizedBox.shrink();
    }
    return ExcludeSemantics(
      child: SizedBox(
        key: ValueKey('module-illustration-${module.name}'),
        width: width,
        // The bar's full height: the app bar gives its actions a loose one.
        height: double.infinity,
        child: ClipRect(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: ModuleIllustrationPainter(module: module, shade: shade),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [module]'s picture for [shade], centred and standing on the lower edge. The
/// shapes are laid out in units of the height, so a taller bar draws a larger picture.
/// Details are cut out in the band's own colour.
class ModuleIllustrationPainter extends CustomPainter {
  const ModuleIllustrationPainter({required this.module, required this.shade});

  final AppModule module;
  final Shade shade;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height;
    canvas
      ..save()
      ..translate(size.width / 2, 0)
      ..scale(s);
    final band = ModuleBands.of(module).of(shade);
    switch (module) {
      case AppModule.shopping:
        _basket(canvas, band);
      case AppModule.tasks:
        _broomAndStars(canvas, band);
      case AppModule.calendar:
        _calendarPage(canvas, band);
      case AppModule.meals:
        _pot(canvas, band);
      case AppModule.schedule:
        _schoolBag(canvas, band);
      case AppModule.settings:
        _sliders(canvas);
      case AppModule.today:
        break;
    }
    canvas.restore();
  }

  Paint _fill(Decor decor) => Paint()..color = decor.of(shade);

  Paint _stroke(Color colour, double width) => Paint()
    ..color = colour
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;

  /// A basket with two round fruits in it.
  void _basket(Canvas canvas, Color band) {
    final mint = Decor.mint.of(shade);
    canvas
      ..drawArc(
        const Rect.fromLTRB(-0.32, 0.2, 0.32, 1.0),
        math.pi,
        math.pi,
        false,
        _stroke(mint, 0.07),
      )
      ..drawCircle(const Offset(-0.14, 0.56), 0.15, _fill(Decor.sun))
      ..drawCircle(const Offset(0.13, 0.52), 0.16, _fill(Decor.sun))
      ..drawCircle(const Offset(0.13, 0.52), 0.16, _stroke(band, 0.025))
      ..drawPath(
        Path()
          ..moveTo(-0.42, 0.66)
          ..lineTo(0.42, 0.66)
          ..lineTo(0.32, 1.1)
          ..lineTo(-0.32, 1.1)
          ..close(),
        _fill(Decor.mint),
      )
      ..drawRRect(
        RRect.fromLTRBR(-0.46, 0.6, 0.46, 0.72, const Radius.circular(0.05)),
        _fill(Decor.mint),
      )
      ..drawLine(
        const Offset(-0.36, 0.83),
        const Offset(0.36, 0.83),
        _stroke(band, 0.03),
      )
      ..drawLine(
        const Offset(-0.33, 0.97),
        const Offset(0.33, 0.97),
        _stroke(band, 0.03),
      );
  }

  /// A broom leaning over, a big star and a small one.
  void _broomAndStars(Canvas canvas, Color band) {
    final apricot = Decor.apricot.of(shade);
    canvas
      ..drawPath(_star(const Offset(-0.28, 0.36), 0.2), _fill(Decor.sun))
      ..drawPath(_star(const Offset(0.36, 0.2), 0.1), _fill(Decor.sun))
      ..drawLine(
        const Offset(0.4, 0.06),
        const Offset(0.06, 0.74),
        _stroke(apricot, 0.06),
      )
      ..drawPath(
        Path()
          ..moveTo(-0.06, 0.64)
          ..lineTo(0.2, 0.77)
          ..lineTo(0.16, 1.1)
          ..lineTo(-0.26, 0.96)
          ..close(),
        _fill(Decor.apricot),
      )
      ..drawLine(
        const Offset(-0.05, 0.72),
        const Offset(0.17, 0.83),
        _stroke(band, 0.03),
      );
  }

  Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a), math.sin(a)) * radius;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// A calendar page with its rings, a grid of days and one day marked.
  void _calendarPage(Canvas canvas, Color band) {
    final lilac = _fill(Decor.lilac);
    canvas
      ..drawRRect(
        RRect.fromLTRBR(-0.36, 0.22, 0.36, 1.2, const Radius.circular(0.08)),
        _fill(Decor.sky),
      )
      ..drawRRect(
        RRect.fromLTRBAndCorners(
          -0.36,
          0.22,
          0.36,
          0.42,
          topLeft: const Radius.circular(0.08),
          topRight: const Radius.circular(0.08),
        ),
        lilac,
      )
      ..drawRRect(
        RRect.fromLTRBR(-0.2, 0.12, -0.13, 0.3, const Radius.circular(0.035)),
        lilac,
      )
      ..drawRRect(
        RRect.fromLTRBR(0.13, 0.12, 0.2, 0.3, const Radius.circular(0.035)),
        lilac,
      );
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        final left = -0.25 + col * 0.18;
        final top = 0.52 + row * 0.2;
        canvas.drawRRect(
          RRect.fromLTRBR(
            left,
            top,
            left + 0.14,
            top + 0.13,
            const Radius.circular(0.03),
          ),
          row == 0 && col == 1 ? lilac : (Paint()..color = band),
        );
      }
    }
  }

  /// A pot with its lid, two handles and three curls of steam.
  void _pot(Canvas canvas, Color band) {
    final steam = _stroke(Decor.apricot.of(shade), 0.04);
    for (final x in const [-0.16, 0.0, 0.16]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 0.42)
          ..cubicTo(x - 0.07, 0.34, x + 0.07, 0.24, x, 0.12),
        steam,
      );
    }
    final coral = _fill(Decor.coral);
    canvas
      ..drawArc(
        const Rect.fromLTRB(-0.42, 0.46, 0.42, 0.7),
        math.pi,
        math.pi,
        true,
        coral,
      )
      ..drawCircle(const Offset(0, 0.45), 0.05, coral)
      ..drawRRect(
        RRect.fromLTRBR(-0.5, 0.64, -0.3, 0.72, const Radius.circular(0.04)),
        coral,
      )
      ..drawRRect(
        RRect.fromLTRBR(0.3, 0.64, 0.5, 0.72, const Radius.circular(0.04)),
        coral,
      )
      ..drawRRect(
        RRect.fromLTRBR(-0.38, 0.6, 0.38, 1.2, const Radius.circular(0.1)),
        coral,
      )
      ..drawLine(
        const Offset(-0.38, 0.6),
        const Offset(0.38, 0.6),
        _stroke(band, 0.03),
      );
  }

  /// A school bag with its loop and a front pocket.
  void _schoolBag(Canvas canvas, Color band) {
    canvas
      ..drawArc(
        const Rect.fromLTRB(-0.13, 0.06, 0.13, 0.34),
        math.pi,
        math.pi,
        false,
        _stroke(Decor.lilac.of(shade), 0.05),
      )
      ..drawRRect(
        RRect.fromLTRBR(-0.34, 0.18, 0.34, 1.2, const Radius.circular(0.16)),
        _fill(Decor.lilac),
      )
      ..drawRRect(
        RRect.fromLTRBR(-0.22, 0.62, 0.22, 1.06, const Radius.circular(0.08)),
        _fill(Decor.sky),
      )
      ..drawLine(
        const Offset(-0.22, 0.74),
        const Offset(0.22, 0.74),
        _stroke(band, 0.025),
      );
  }

  /// Two sliders, and nothing else: settings stay calm.
  void _sliders(Canvas canvas) {
    for (final (decor, y, knob) in const [
      (Decor.sky, 0.38, 0.14),
      (Decor.mint, 0.72, -0.18),
    ]) {
      final colour = decor.of(shade);
      canvas
        ..drawRRect(
          RRect.fromLTRBR(
            -0.4,
            y - 0.03,
            0.4,
            y + 0.03,
            const Radius.circular(0.03),
          ),
          Paint()..color = colour.withValues(alpha: 0.6),
        )
        ..drawCircle(Offset(knob, y), 0.1, Paint()..color = colour);
    }
  }

  @override
  bool shouldRepaint(ModuleIllustrationPainter old) =>
      old.module != module || old.shade != shade;
}
