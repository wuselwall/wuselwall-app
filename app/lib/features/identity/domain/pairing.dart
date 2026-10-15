import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// The pairing code the new device shows (specs/20 J3): eight symbols without 0/O/1/I, shown
/// as K7QM-3XRP. Typed or scanned text is normalised before the check.
final _pairingCode = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$');

const _pairingHost = 'wuselwall.app';

/// The code in the display form: K7QM-3XRP.
String formatPairingCode(String code) =>
    code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

/// What the new device's QR code encodes. The phone's camera follows the link to the
/// website, the app's own scanner reads the code from the fragment.
String pairingQrPayload(String code) => 'https://$_pairingHost/p/#$code';

/// Reads a pairing code from typed or scanned text: the bare code (with or without the
/// hyphen, in any case), or a WuselWall link whose fragment or last path segment is the code.
/// Returns null when [raw] holds no plausible code.
String? parsePairingCode(String raw) {
  final text = raw.trim();
  final uri = Uri.tryParse(text);
  final String candidate;
  if (uri != null && uri.hasScheme) {
    if (uri.host != _pairingHost) return null;
    candidate = uri.fragment.isNotEmpty
        ? uri.fragment
        : (uri.pathSegments.isEmpty ? '' : uri.pathSegments.last);
  } else {
    candidate = text;
  }
  final code = candidate.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  return _pairingCode.hasMatch(code) ? code : null;
}

/// What the guardian says the new device is (G1). Each kind maps to the device class,
/// the UI register and, for a child's phone, the bound child (specs/20 G1 table).
enum PairingKind {
  wallDisplay('wall_display', DeviceClass.kiosk, UiRegister.kiosk),
  kidTablet('kid_tablet', DeviceClass.shared, UiRegister.kid),
  familyTablet('family_tablet', DeviceClass.shared, UiRegister.adult),
  childPhone('child_phone', DeviceClass.personal, UiRegister.kid);

  const PairingKind(this.wire, this.deviceClass, this.register);

  /// The value the `api.pairing_approve` function takes.
  final String wire;
  final DeviceClass deviceClass;
  final UiRegister register;

  /// True for a child's own phone, which is bound to one child profile.
  bool get bindsChild => this == childPhone;

  /// The kind whose wire value is [wire], or null for an unknown one (a route parameter).
  static PairingKind? fromWire(String? wire) {
    for (final kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }
}

/// The request the new device holds: the id and secret it polls with, and the code shown.
class PairingRequest {
  const PairingRequest({
    required this.requestId,
    required this.secret,
    required this.code,
    required this.expiresAt,
  });

  factory PairingRequest.fromJson(Map<String, dynamic> json) => PairingRequest(
    requestId: json['request_id'] as String,
    secret: json['secret'] as String,
    code: json['code'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );

  final String requestId;
  final String secret;
  final String code;
  final DateTime expiresAt;
}

/// What a poll says. Only [PairingApproved] carries credentials, and only once.
sealed class PairingPoll {
  const PairingPoll();

  factory PairingPoll.fromJson(Map<String, dynamic> json) =>
      switch (json['status']) {
        'pending' => const PairingPending(),
        'expired' => const PairingExpired(),
        'rate_limited' => const PairingRateLimited(),
        'approved' => PairingApproved(
          email: json['email'] as String,
          password: json['password'] as String,
          householdName: json['household_name'] as String,
          deviceClass: DeviceClass.parse(json['class'] as String),
          register: UiRegister.values.byName(json['register'] as String),
        ),
        _ => const PairingInvalid(),
      };
}

final class PairingPending extends PairingPoll {
  const PairingPending();
}

final class PairingExpired extends PairingPoll {
  const PairingExpired();
}

final class PairingInvalid extends PairingPoll {
  const PairingInvalid();
}

final class PairingRateLimited extends PairingPoll {
  const PairingRateLimited();
}

final class PairingApproved extends PairingPoll {
  const PairingApproved({
    required this.email,
    required this.password,
    required this.householdName,
    required this.deviceClass,
    required this.register,
  });

  final String email;
  final String password;
  final String householdName;
  final DeviceClass deviceClass;
  final UiRegister register;
}

/// The result of an approval on the guardian's phone. [needsPin] is true while this
/// guardian has no PIN yet (G2 follows).
class PairingApproval {
  const PairingApproval({
    required this.deviceId,
    required this.label,
    required this.needsPin,
  });

  final String deviceId;
  final String label;
  final bool needsPin;
}
