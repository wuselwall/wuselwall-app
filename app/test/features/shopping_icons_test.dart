import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';

void main() {
  test('every key has its picture at 1x, 2x and 3x', () {
    for (final key in shoppingIconKeys) {
      for (final path in [
        'assets/emoji/shopping/$key.png',
        'assets/emoji/shopping/2.0x/$key.png',
        'assets/emoji/shopping/3.0x/$key.png',
      ]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });

  test('the keys the server can return are the app’s keys', () {
    // Tests run with app/ as the working directory.
    final migration = File(
      '../supabase/migrations/20261015120000_catalog_icons.sql',
    ).readAsStringSync();
    final serverKeys = {
      for (final m in RegExp(r"\('[^']+', '([a-z_]+)'\)").allMatches(migration))
        m.group(1)!,
    };
    expect(serverKeys, shoppingIconKeys);
  });

  test('shoppingIconAsset maps known keys only', () {
    expect(shoppingIconAsset(null), isNull);
    expect(shoppingIconAsset('unicorn'), isNull);
    expect(shoppingIconAsset('milk'), 'assets/emoji/shopping/milk.png');
  });
}
