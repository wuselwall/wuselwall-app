/// The payload shown as a QR code next to the enrolment code, and how to read it back.
const _scheme = 'wuselwall';

String enrolmentQrPayload(String code) => '$_scheme://enrol?code=$code';

/// Extracts an enrolment code from scanned or typed text: the QR URI, or the bare code.
/// Returns null when [raw] holds no plausible code.
String? parseEnrolmentCode(String raw) {
  final text = raw.trim();
  final uri = Uri.tryParse(text);
  final candidate = (uri != null && uri.scheme == _scheme)
      ? uri.queryParameters['code']
      : text;
  final code = candidate?.trim().toUpperCase();
  return (code != null && RegExp(r'^[A-Z0-9]{8}$').hasMatch(code))
      ? code
      : null;
}
