import 'dart:typed_data';

import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/school/data/proposals_repository.dart';
import 'package:wuselwall/features/school/data/scan_repository.dart';
import 'package:wuselwall/features/school/domain/proposal_models.dart';

/// The demo has no assistant and no OCR service: no proposals, and a scan that answers
/// as a server without OCR would, so the screens show their real words.
class DemoProposalsRepository implements ProposalsRepository {
  const DemoProposalsRepository();

  @override
  Future<Result<List<ProposalRecord>>> open() async => const Ok([]);

  @override
  Future<Result<void>> resolve({
    required String? actor,
    required String id,
    required bool applied,
  }) async => const Ok(null);
}

class DemoScanRepository implements ScanRepository {
  const DemoScanRepository();

  @override
  Future<Result<ScanResult>> scan({
    required Uint8List image,
    required String mime,
    List<String> languages = const [],
    List<String> subjects = const [],
  }) async => const Err(NotFoundFailure(code: 'ocr_not_configured'));
}
