import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/school/domain/timetable_import.dart';

/// What the family's server read from a photo (specs/24 "Scanning"): the payload the
/// preview shows, and how much of the text fit the grid.
class ScanResult {
  const ScanResult({
    required this.import,
    required this.placed,
    required this.unplaced,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
    import: parseTimetableImportJson(
      (json['payload'] as Map).cast<String, dynamic>(),
    ),
    placed: (json['placed'] as num?)?.toInt() ?? 0,
    unplaced: (json['unplaced'] as num?)?.toInt() ?? 0,
  );

  final TimetableImport import;
  final int placed;
  final int unplaced;
}

/// Sends a picture to the `timetable-scan` Edge Function. The server does the reading,
/// with its own OCR service; the app never contacts anyone else.
class ScanRepository {
  const ScanRepository(this._api);

  final ApiClient _api;

  Future<Result<ScanResult>> scan({
    required Uint8List image,
    required String mime,
  }) => _api.function(
    'timetable-scan',
    body: {'image': base64Encode(image), 'mime': mime},
    parse: (json) => ScanResult.fromJson(json! as Map<String, dynamic>),
  );
}

final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => ScanRepository(ref.watch(apiClientProvider)),
);
