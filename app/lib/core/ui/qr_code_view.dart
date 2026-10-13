import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';

/// A QR code drawn from `package:qr`'s module matrix, in the shade's `qrInk` on its
/// `qrPaper` — always dark on light, since many scanners do not read inverted codes.
/// The paper fills [size] and includes a quiet zone of [quietZone] modules (ISO/IEC
/// 18004 asks for 4). Error correction M survives glare on a screen better than L.
class QrCodeView extends StatelessWidget {
  const QrCodeView({
    required this.data,
    required this.semanticsLabel,
    this.size = 224,
    this.quietZone = 4,
    super.key,
  });

  /// What the code encodes. App-made and short; beyond version 40 `qr` throws.
  final String data;

  /// Read out instead of the image: a `context.l10n` string.
  final String semanticsLabel;

  /// Logical pixels, quiet zone included.
  final double size;
  final int quietZone;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
      ),
    );
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: QrMatrixPainter(
            image: image,
            darkColor: context.ww.qrInk,
            lightColor: context.ww.qrPaper,
            quietZone: quietZone,
            devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
          ),
        ),
      ),
    );
  }
}

/// Paints whole device pixels per module with anti-aliasing off: crisp edges, no seams
/// between neighbouring modules. The code is centred; what is left over is paper.
@visibleForTesting
class QrMatrixPainter extends CustomPainter {
  QrMatrixPainter({
    required this.image,
    required this.darkColor,
    required this.lightColor,
    required this.devicePixelRatio,
    this.quietZone = 4,
  }) : assert(
         darkColor.computeLuminance() < lightColor.computeLuminance(),
         'QR codes must be dark on light to scan reliably.',
       );

  final QrImage image;
  final Color darkColor;
  final Color lightColor;
  final double devicePixelRatio;
  final int quietZone;

  /// The side of one module in logical pixels: a whole number of device pixels.
  double moduleExtent(double extent) {
    final total = image.moduleCount + 2 * quietZone;
    final devicePixels = math.max(
      1,
      (extent * devicePixelRatio / total).floor(),
    );
    return devicePixels / devicePixelRatio;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = lightColor);
    final n = image.moduleCount;
    final module = moduleExtent(size.shortestSide);
    final code = module * n;
    double snap(double v) =>
        (v * devicePixelRatio).floorToDouble() / devicePixelRatio;
    final left = snap((size.width - code) / 2);
    final top = snap((size.height - code) / 2);

    // One rectangle per horizontal run of dark modules, filled as a single path.
    final path = Path();
    for (var row = 0; row < n; row++) {
      var col = 0;
      while (col < n) {
        if (!image.isDark(row, col)) {
          col++;
          continue;
        }
        final start = col;
        while (col < n && image.isDark(row, col)) {
          col++;
        }
        path.addRect(
          Rect.fromLTWH(
            left + start * module,
            top + row * module,
            (col - start) * module,
            module,
          ),
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = darkColor
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(QrMatrixPainter old) =>
      old.image != image ||
      old.darkColor != darkColor ||
      old.lightColor != lightColor ||
      old.devicePixelRatio != devicePixelRatio ||
      old.quietZone != quietZone;
}
