import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a file to the platform: the share sheet on phones and tablets, a download in the
/// browser. [origin] anchors the share sheet on iPad.
typedef ShareExport = Future<void> Function({
  required String fileName,
  required Uint8List bytes,
  Rect? origin,
});

/// The platform share, behind a provider so tests do not reach the platform.
final shareExportProvider = Provider<ShareExport>(
  (ref) => ({required fileName, required bytes, origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/json', name: fileName),
        ],
        sharePositionOrigin: origin,
      ),
    );
  },
);

/// `wuselwall-export-YYYY-MM-DD.json` for the local date of [now].
String householdExportFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'wuselwall-export-${now.year}-${two(now.month)}-${two(now.day)}.json';
}
