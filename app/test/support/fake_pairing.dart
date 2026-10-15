import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';
import 'package:wuselwall/features/identity/data/pairing_repository.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';

/// Scripted pairing backend. Starts hand out a new request each time; polls answer from
/// [pollQueue] (pending when it is empty); approvals answer [approveResult].
class FakePairingRepository implements PairingRepository {
  static const _codes = ['K7QM3XRP', 'H4NT7WBC', 'P9ZD2KFA', 'M3VQ8RLE'];

  final pollQueue = <PairingPoll>[];

  /// Starts that fail before the good ones, in order (a rate limit, say).
  final startFailures = <Failure>[];
  Result<PairingApproval>? approveResult;
  var starts = 0;
  var polls = 0;
  final approvals =
      <
        ({String code, PairingKind kind, String label, String? childProfileId})
      >[];

  @override
  Future<Result<PairingRequest>> start() async {
    if (startFailures.isNotEmpty) {
      starts++;
      return Err(startFailures.removeAt(0));
    }
    final n = starts++;
    return Ok(
      PairingRequest(
        requestId: 'req-$n',
        secret: 'secret-$n',
        code: _codes[n % _codes.length],
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      ),
    );
  }

  @override
  Future<Result<PairingPoll>> poll(PairingRequest request) async {
    polls++;
    return Ok(
      pollQueue.isEmpty ? const PairingPending() : pollQueue.removeAt(0),
    );
  }

  @override
  Future<Result<PairingApproval>> approve({
    required String code,
    required PairingKind kind,
    required String label,
    String? childProfileId,
  }) async {
    approvals.add((
      code: code,
      kind: kind,
      label: label,
      childProfileId: childProfileId,
    ));
    return approveResult ??
        Ok(PairingApproval(deviceId: 'd-9', label: label, needsPin: false));
  }
}

/// In-memory first-run memory: unseen until [markSeen].
class FakeFirstRunStore implements FirstRunStore {
  final seen = <String>{};

  @override
  Future<bool> isSeen(String deviceId) async => seen.contains(deviceId);

  @override
  Future<void> markSeen(String deviceId) async => seen.add(deviceId);
}

/// A failure the pairing repository would raise for an unknown code.
const codeInvalid = ValidationFailure(code: 'code_invalid');
