import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';

const _enrolment = 'wuselwall://enrol?code=ABCD2345';
const _totp =
    'otpauth://totp/WuselWall:someone%40example.org?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP'
    '&issuer=WuselWall&algorithm=SHA1&digits=6&period=30';

QrImage _matrix(String data) => QrImage(
  QrCode(
    payload: QrPayload.fromString(data),
    errorCorrectLevel: QrErrorCorrectLevel.medium,
  ),
);

List<int> _rgb(Color c) => [
  (c.r * 255).round(),
  (c.g * 255).round(),
  (c.b * 255).round(),
];

/// Paints [painter] into a [logical]-sized square at [dpr] and returns RGBA pixels.
Future<({Uint8List rgba, int width})> _render(
  QrMatrixPainter painter,
  double logical,
  double dpr,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(dpr);
  painter.paint(canvas, Size.square(logical));
  final width = (logical * dpr).round();
  final image = await recorder.endRecording().toImage(width, width);
  final bytes = await image.toByteData();
  return (rgba: bytes!.buffer.asUint8List(), width: width);
}

void main() {
  for (final shade in Shade.values) {
    final ww = WwColors(shade: shade);
    final ink = _rgb(ww.qrInk), paper = _rgb(ww.qrPaper);

    for (final (name, data, logical, dpr) in [
      ('enrolment code, 1x', _enrolment, 224.0, 1.0),
      ('enrolment code, 2.625x', _enrolment, 224.0, 2.625),
      ('TOTP URI, 3x', _totp, 224.0, 3.0),
      ('TOTP URI, 1.5x', _totp, 180.0, 1.5),
    ]) {
      test('${shade.name}: every module matches the qr matrix, $name', () async {
        final matrix = _matrix(data);
        final painter = QrMatrixPainter(
          image: matrix,
          darkColor: ww.qrInk,
          lightColor: ww.qrPaper,
          devicePixelRatio: dpr,
        );
        final r = await _render(painter, logical, dpr);
        final n = matrix.moduleCount;
        final modulePx = (painter.moduleExtent(logical) * dpr).round();
        List<int> pixel(int x, int y) =>
            r.rgba.sublist((y * r.width + x) * 4, (y * r.width + x) * 4 + 3);

        // The first ink pixel on the diagonal is the top-left finder's outer corner.
        var origin = 0;
        while (!listEquals(pixel(origin, origin), ink)) {
          origin++;
        }

        // A quiet zone of at least 4 modules on every side, all paper.
        final end = origin + n * modulePx;
        expect(origin, greaterThanOrEqualTo(4 * modulePx));
        expect(r.width - end, greaterThanOrEqualTo(4 * modulePx));
        for (var y = 0; y < r.width; y++) {
          for (var x = 0; x < r.width; x++) {
            if (x < origin || y < origin || x >= end || y >= end) {
              expect(pixel(x, y), paper, reason: '($x,$y)');
            }
          }
        }

        // Every pixel of every module has the module's colour: crisp, no seams.
        for (var row = 0; row < n; row++) {
          for (var col = 0; col < n; col++) {
            final want = matrix.isDark(row, col) ? ink : paper;
            for (var dy = 0; dy < modulePx; dy++) {
              for (var dx = 0; dx < modulePx; dx++) {
                final x = origin + col * modulePx + dx;
                final y = origin + row * modulePx + dy;
                expect(pixel(x, y), want, reason: 'module ($row,$col)');
              }
            }
          }
        }
      });
    }
  }

  testWidgets('screen readers get the label as an image, at the given size', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(UiRegister.adult, Shade.light),
        home: const Center(
          child: QrCodeView(data: _enrolment, semanticsLabel: 'enrolment QR'),
        ),
      ),
    );
    expect(
      t.getSemantics(find.byType(QrCodeView)),
      matchesSemantics(label: 'enrolment QR', isImage: true),
    );
    expect(t.getSize(find.byType(QrCodeView)), const Size.square(224));
    semantics.dispose();
  });

  test('refuses an inverted (light on dark) code', () {
    final ww = WwColors(shade: Shade.dark);
    expect(
      () => QrMatrixPainter(
        image: _matrix(_enrolment),
        darkColor: ww.qrPaper,
        lightColor: ww.qrInk,
        devicePixelRatio: 1,
      ),
      throwsAssertionError,
    );
  });
}
