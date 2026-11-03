import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_clock.dart';
import 'package:wuselwall/features/identity/data/pairing_repository.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';

/// The demo's pairing: the new device shows a fixed code, polls and never gets approved.
/// Nothing leaves the page.
class DemoPairingRepository implements PairingRepository {
  @override
  Future<Result<PairingRequest>> start() async => Ok(
    PairingRequest(
      requestId: 'demo-request',
      secret: 'demo-secret',
      code: 'K7QM3XRP',
      expiresAt: DemoClock.now().add(const Duration(minutes: 10)),
    ),
  );

  @override
  Future<Result<PairingPoll>> poll(PairingRequest request) async =>
      const Ok(PairingPending());

  @override
  Future<Result<PairingApproval>> approve({
    required String code,
    required PairingKind kind,
    required String label,
    String? childProfileId,
  }) async => const Err(ValidationFailure(code: 'code_invalid'));
}
