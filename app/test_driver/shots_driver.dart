import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves every screenshot an integration test takes to `$SHOTS_OUT/NAME.png`
/// (default: build/shots). Used with integration_test/shopping_shots_test.dart:
///
///   flutter drive --driver=test_driver/shots_driver.dart \
///     --target=integration_test/shopping_shots_test.dart -d DEVICE \
///     -t lib/main_demo.dart
Future<void> main() async {
  final out = Directory(Platform.environment['SHOTS_OUT'] ?? 'build/shots')
    ..createSync(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('${out.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
