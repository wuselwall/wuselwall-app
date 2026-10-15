import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';

/// Pairing (J3/J5): the new device's side (start, poll) and the guardian's (approve).
/// Holds no rules; the `api` functions do. Refusals that must not roll back the server's
/// attempt log come back as `{ok:false, reason}` and are turned into failures here.
class PairingRepository {
  const PairingRepository(this._api);

  final ApiClient _api;

  /// A new request with its code. A rate-limited start is a [PermissionFailure].
  Future<Result<PairingRequest>> start() => _api.rpc(
    'pairing_start',
    parse: (json) {
      final map = json! as Map<String, dynamic>;
      if (map['ok'] != true) {
        throw const PermissionFailure(code: 'rate_limited');
      }
      return PairingRequest.fromJson(map);
    },
  );

  /// One poll with the request's own secret. Rate limiting comes back as a value, so the
  /// caller can wait instead of showing an error.
  Future<Result<PairingPoll>> poll(PairingRequest request) => _api.rpc(
    'pairing_poll',
    params: {'p_request_id': request.requestId, 'p_secret': request.secret},
    parse: (json) => PairingPoll.fromJson(json! as Map<String, dynamic>),
  );

  /// A guardian on a personal phone approves the code the new device shows.
  Future<Result<PairingApproval>> approve({
    required String code,
    required PairingKind kind,
    required String label,
    String? childProfileId,
  }) => _api.rpc(
    'pairing_approve',
    params: {
      'p_actor': null,
      'p_code': code,
      'p_label': label.trim(),
      'p_kind': kind.wire,
      'p_profile': childProfileId,
    },
    parse: (json) {
      final map = json! as Map<String, dynamic>;
      if (map['ok'] != true) {
        throw switch (map['reason']) {
          'rate_limited' => const PermissionFailure(code: 'rate_limited'),
          _ => const ValidationFailure(code: 'code_invalid'),
        };
      }
      return PairingApproval(
        deviceId: map['device_id'] as String,
        label: map['label'] as String,
        needsPin: map['needs_pin'] as bool,
      );
    },
  );
}

final pairingRepositoryProvider = Provider<PairingRepository>(
  (ref) => PairingRepository(ref.watch(apiClientProvider)),
);
