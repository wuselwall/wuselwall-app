import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/domain/enrol_code.dart';

/// Full-screen camera view that pops with the first code [parse] accepts: by default an
/// enrolment code; the server choice passes its own parser and gets the raw text back.
/// Not covered by automated tests (needs a camera); the parsing it relies on is.
class QrScanPage extends StatefulWidget {
  const QrScanPage({this.title, this.parse = parseEnrolmentCode, super.key});

  final String? title;
  final String? Function(String raw) parse;

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = widget.parse(barcode.rawValue ?? '');
      if (code != null) {
        _done = true;
        Navigator.pop(context, code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title ?? context.l10n.scanTitle)),
    body: MobileScanner(onDetect: _onDetect),
  );
}
