import 'dart:typed_data';

import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/school/data/scan_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

/// No OCR service in the demo: use the same explanation as an unconfigured server.
class DemoScanRepository implements ScanRepository {
  const DemoScanRepository();

  @override
  Future<Result<ScanResult>> scan({
    required Uint8List image,
    required String mime,
    List<String> languages = const [],
    List<String> subjects = const [],
    List<SubjectRecord> subjectList = const [],
  }) async => const Err(NotFoundFailure(code: 'ocr_not_configured'));
}
