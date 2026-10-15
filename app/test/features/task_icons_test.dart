import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

void main() {
  test('every icon key has its picture in 1x, 2.0x and 3.0x', () {
    for (final key in taskIconKeys) {
      expect(
        File('assets/emoji/tasks/$key.png').existsSync(),
        isTrue,
        reason: 'missing 1x picture for $key',
      );
      for (final variant in ['2.0x', '3.0x']) {
        expect(
          File('assets/emoji/tasks/$variant/$key.png').existsSync(),
          isTrue,
          reason: 'missing $variant picture for $key',
        );
      }
      expect(taskIconAsset(key), 'assets/emoji/tasks/$key.png');
    }
    expect(taskIconAsset('unknown'), isNull);
    expect(taskIconAsset(null), isNull);
  });

  test('every icon key has a name in both languages', () {
    for (final locale in ['de', 'en']) {
      final l10n = lookupAppLocalizations(Locale(locale));
      for (final key in taskIconKeys) {
        expect(
          taskIconName(l10n, key),
          isNot(l10n.tasksFieldIcon),
          reason: 'no name for $key in $locale',
        );
      }
    }
  });
}
