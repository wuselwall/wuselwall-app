import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(
    Platform.environment['QUALIFY_NATIVE_OUT'] ??
        '../build/qualification/native',
  );
  output.createSync(recursive: true);
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(name) || bytes.length < 8) {
        return false;
      }
      File('${output.path}/$name.png').writeAsBytesSync(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      File('${output.path}/results.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          for (final entry in (data ?? <String, dynamic>{}).entries)
            if (entry.key != 'screenshots') entry.key: entry.value,
        }),
      );
    },
  );
}
