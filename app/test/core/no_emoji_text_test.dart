import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web app would fetch an emoji font from Google (NFR-9), and emoji look different on
/// every platform: draw the bundled pictures (assets/emoji) instead of emoji characters.
final _emoji = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B50}]',
  unicode: true,
);

void main() {
  test('no Dart source outside comments draws an emoji character', () {
    final root = Directory('lib');
    final files = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('lib/l10n/generated'));
    final hits = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (_emoji.hasMatch(line)) {
          hits.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason:
          'emoji characters found (use assets/emoji pictures):\n${hits.join('\n')}',
    );
  });
}
