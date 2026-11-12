import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/logging/log.dart';

/// A file the device opened the app with ("Open in WuselWall" on a calendar file,
/// specs/05 "Sharing one event"). The link plugin reports it like a link: `content://…`
/// on Android, `file://…` on iOS. The bootstrap puts it here; [FileHost] takes it once
/// somebody is signed in.
final openedFile = ValueNotifier<String?>(null);

/// Whether [raw] names a file on the device and not a web link.
bool isFileLink(String raw) {
  final scheme = Uri.tryParse(raw)?.scheme.toLowerCase();
  return scheme == 'content' || scheme == 'file';
}

const _channel = MethodChannel('wuselwall/files');

/// Reads at most [maxBytes] of the file behind [link]; null when it cannot be read or is
/// larger. Android reads `content://` through the activity that was given the file
/// (`MainActivity`); iOS hands over a copy inside the app's own folder.
typedef OpenedFileReader = Future<Uint8List?> Function(
  String link, {
  required int maxBytes,
});

/// Behind a provider so tests do not reach the platform.
final openedFileReaderProvider = Provider<OpenedFileReader>(
  (ref) => (link, {required maxBytes}) async {
    if (kIsWeb) return null;
    try {
      final uri = Uri.parse(link);
      if (uri.scheme == 'content') {
        return await _channel.invokeMethod<Uint8List>('read', {
          'uri': link,
          'maxBytes': maxBytes,
        });
      }
      final file = File.fromUri(uri);
      if (await file.length() > maxBytes) return null;
      return await file.readAsBytes();
    } on Object catch (e, st) {
      // The link may carry a file name: never logged.
      logError('Reading an opened file', error: e.runtimeType, stackTrace: st);
      return null;
    }
  },
);
