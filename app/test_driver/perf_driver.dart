import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Writes what the perf test reports (frame build/raster statistics per run) to
/// `$PERF_OUT/<name>.json` (default: build/perf).
Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      final out = Directory(Platform.environment['PERF_OUT'] ?? 'build/perf')
        ..createSync(recursive: true);
      await File(
        '${out.path}/${Platform.environment['PERF_NAME'] ?? 'perf'}.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    },
  );
}
