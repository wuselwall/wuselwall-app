import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';
import 'package:wuselwall/features/identity/domain/enrol_code.dart';

/// The enrolment code as a QR code, dark on paper in every shade so it scans.
class EnrolmentQr extends StatelessWidget {
  EnrolmentQr({required String code, super.key})
    : payload = enrolmentQrPayload(code);

  /// What the QR code encodes; the new device parses it with `parseEnrolmentCode`.
  final String payload;

  @override
  Widget build(BuildContext context) =>
      QrCodeView(data: payload, semanticsLabel: context.l10n.enrolmentQrLabel);
}
