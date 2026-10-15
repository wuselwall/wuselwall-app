import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/features/identity/domain/enrol_code.dart';
import 'package:wuselwall/features/setup/domain/camera_qr_decoder.dart';
import 'package:wuselwall/features/setup/ui/qr_scan_page.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

/// Renders [payload] as a QR code with a quiet zone, one [scale]-pixel square per module.
/// Returns the module matrix as rows of gray values: black 0, white 255.
List<List<int>> _render(String payload, {int scale = 4}) {
  final qr = QrImage(
    QrCode(
      payload: QrPayload.fromString(payload),
      errorCorrectLevel: QrErrorCorrectLevel.medium,
    ),
  );
  const quiet = 4;
  final modules = qr.moduleCount + 2 * quiet;
  final size = modules * scale;
  return List.generate(size, (y) {
    return List.generate(size, (x) {
      final mx = x ~/ scale - quiet;
      final my = y ~/ scale - quiet;
      final dark =
          mx >= 0 && my >= 0 && mx < qr.moduleCount && my < qr.moduleCount &&
          qr.isDark(my, mx);
      return dark ? 0 : 255;
    });
  });
}

/// A Y plane with [stride] bytes per row (padding beyond the width), as Android delivers.
ScanFrame _yuvFrame(List<List<int>> gray, {int padding = 13}) {
  final height = gray.length;
  final width = gray.first.length;
  final stride = width + padding;
  final bytes = Uint8List(stride * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      bytes[y * stride + x] = gray[y][x];
    }
    // Padding carries noise; the decoder must not read it.
    for (var x = width; x < stride; x++) {
      bytes[y * stride + x] = 128;
    }
  }
  return ScanFrame(
    bytes: bytes,
    width: width,
    height: height,
    bytesPerRow: stride,
    bgra: false,
  );
}

/// A BGRA frame with [padding] bytes at the end of each row, as iOS delivers.
ScanFrame _bgraFrame(List<List<int>> gray, {int padding = 6}) {
  final height = gray.length;
  final width = gray.first.length;
  final stride = width * 4 + padding;
  final bytes = Uint8List(stride * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * stride + x * 4;
      final v = gray[y][x];
      bytes[i] = v; // B
      bytes[i + 1] = v; // G
      bytes[i + 2] = v; // R
      bytes[i + 3] = 255; // A
    }
  }
  return ScanFrame(
    bytes: bytes,
    width: width,
    height: height,
    bytesPerRow: stride,
    bgra: true,
  );
}

/// The same image turned 90 degrees clockwise: a phone held in the other orientation.
List<List<int>> _rotate(List<List<int>> gray) {
  final h = gray.length;
  final w = gray.first.length;
  return List.generate(w, (y) => List.generate(h, (x) => gray[h - 1 - x][y]));
}

void main() {
  const code = 'ABCD2345';
  final payload = enrolmentQrPayload(code);

  group('decodeScanFrame', () {
    test('decodes a Y plane with row padding (Android YUV420)', () {
      expect(decodeScanFrame(_yuvFrame(_render(payload))), payload);
    });

    test('decodes BGRA with row padding (iOS)', () {
      expect(decodeScanFrame(_bgraFrame(_render(payload))), payload);
    });

    test('decodes a code held in the other orientation', () {
      // ZXing finds the finder patterns in any rotation, so no second pass is needed.
      final rotated = _rotate(_render(payload));
      expect(decodeScanFrame(_yuvFrame(rotated)), payload);
      expect(decodeScanFrame(_bgraFrame(rotated)), payload);
    });

    test('the decoded text is accepted by the enrolment parser', () {
      final text = decodeScanFrame(_bgraFrame(_render(payload)));
      expect(parseEnrolmentCode(text!), code);
    });

    test('returns null for a frame without a code', () {
      final blank = List.generate(120, (_) => List.filled(120, 255));
      expect(decodeScanFrame(_yuvFrame(blank)), isNull);
    });

    test('returns null for inconsistent sizes instead of throwing', () {
      final frame = ScanFrame(
        bytes: Uint8List(10),
        width: 100,
        height: 100,
        bytesPerRow: 100,
        bgra: false,
      );
      expect(decodeScanFrame(frame), isNull);
    });
  });

  group('QrScanPage fallbacks', () {
    Future<void> pumpPage(
      WidgetTester tester,
      ListCameras listCameras,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          home: QrScanPage(listCameras: listCameras),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the no-camera message and the typing fallback', (
      tester,
    ) async {
      await pumpPage(tester, () async => <CameraDescription>[]);
      final l10n = AppLocalizations.of(tester.element(find.byType(QrScanPage)));
      expect(find.text(l10n.scanCameraUnavailable), findsOneWidget);
      expect(find.text(l10n.scanTypeCode), findsOneWidget);
    });

    testWidgets('explains a refused camera permission', (tester) async {
      await pumpPage(
        tester,
        () async => throw CameraException('CameraAccessDenied', 'denied'),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(QrScanPage)));
      expect(find.text(l10n.scanCameraDenied), findsOneWidget);
      expect(find.text(l10n.scanTypeCode), findsOneWidget);
    });

    testWidgets('the typing fallback pops without a value', (tester) async {
      Object? popped = 'unset';
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => QrScanPage(
                      listCameras: () async => <CameraDescription>[],
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(QrScanPage)));
      await tester.tap(find.text(l10n.scanTypeCode));
      await tester.pumpAndSettle();
      expect(popped, isNull);
    });
  });
}
