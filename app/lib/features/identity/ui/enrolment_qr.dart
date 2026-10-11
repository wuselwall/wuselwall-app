import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/domain/enrol_code.dart';

/// The enrolment code as a QR code, on a white tile so it scans in dark mode too.
class EnrolmentQr extends StatelessWidget {
  EnrolmentQr({required String code, super.key})
    : payload = enrolmentQrPayload(code);

  /// What the QR code encodes; the new device parses it with `parseEnrolmentCode`.
  final String payload;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(Tokens.space3),
    child: QrImageView(
      data: payload,
      size: 200,
      semanticsLabel: context.l10n.enrolmentQrLabel,
    ),
  );
}
