import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// A finished export, ready to save: a zip file with one JSON file per table, or, from a
/// server before the zip export, the one JSON document.
class HouseholdExportFile {
  const HouseholdExportFile({required this.bytes, required this.zip});

  final Uint8List bytes;
  final bool zip;

  String get extension => zip ? 'zip' : 'json';
  String get mimeType => zip ? 'application/zip' : 'application/json';
}

/// The household's data (GDPR Art. 20, FR-5.16) from the `household-export` Edge Function,
/// which reads it page by page and streams it as a zip file, so years of data fit. The
/// server refuses anyone but a guardian on a personal device.
class HouseholdExportRepository {
  const HouseholdExportRepository(this._api);

  final ApiClient _api;

  /// The export of the household; [actor] is the acting profile.
  Future<Result<HouseholdExportFile>> export({required String? actor}) async {
    final zip = await _api.function(
      'household-export',
      body: {'actor': actor},
      parse: _zipFile,
    );
    // A server from before the zip export has no such function: it still has
    // `api.household_export`, the whole household as one JSON document.
    if (zip case Err(failure: NotFoundFailure())) {
      return _api.rpc(
        'household_export',
        params: {'p_actor': actor},
        parse: (json) => HouseholdExportFile(
          bytes: utf8.encode(const JsonEncoder.withIndent('  ').convert(json)),
          zip: false,
        ),
      );
    }
    return zip;
  }

  /// The function's reply as a zip file. A download that broke off has no end record, so it
  /// is refused here rather than saved as a file that will not open.
  static HouseholdExportFile _zipFile(Object? data) {
    if (data is! Uint8List || !looksLikeZip(data)) {
      throw const FormatException('the export is not a complete zip file');
    }
    return HouseholdExportFile(bytes: data, zip: true);
  }
}

/// Whether [bytes] start like a zip file and end with its end-of-directory record (written
/// without a comment, so it is the last 22 bytes).
bool looksLikeZip(Uint8List bytes) {
  if (bytes.length < 22) return false;
  bool signature(int at, int third, int fourth) =>
      bytes[at] == 0x50 &&
      bytes[at + 1] == 0x4b &&
      bytes[at + 2] == third &&
      bytes[at + 3] == fourth;
  final end = bytes.length - 22;
  return (signature(0, 3, 4) || end == 0) && signature(end, 5, 6);
}

final householdExportRepositoryProvider = Provider<HouseholdExportRepository>(
  (ref) => HouseholdExportRepository(ref.watch(apiClientProvider)),
);
