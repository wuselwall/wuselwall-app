import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/features/wusel/ui/wusel_lines.dart';

void main() {
  final locales = [
    for (final code in ['de', 'en', 'fr', 'es'])
      lookupAppLocalizations(Locale(code)),
  ];
  final de = locales.first;

  tearDown(() {
    WuselLines.random = null;
    WuselLines.reset();
    StillMode.enabled = false;
  });

  test(
    'every moment has three to five different variants in every language',
    () {
      for (final l10n in locales) {
        for (final moment in WuselMoment.values) {
          final variants = WuselLines.variants(l10n, moment, name: 'Lotta');
          expect(
            variants.length,
            inInclusiveRange(3, 5),
            reason: '${l10n.localeName} $moment',
          );
          expect(
            variants.toSet(),
            hasLength(variants.length),
            reason: '${l10n.localeName} $moment',
          );
        }
      }
    },
  );

  test('a line never comes twice in a row', () {
    WuselLines.random = math.Random(7);
    for (final moment in WuselMoment.values) {
      final seen = <String>{};
      String? last;
      for (var i = 0; i < 200; i++) {
        final line = WuselLines.pick(de, moment, name: 'Lotta');
        expect(line, isNot(last), reason: '$moment, pick $i');
        seen.add(line);
        last = line;
      }
      // And it does rotate: every variant shows up.
      expect(seen, hasLength(WuselLines.variants(de, moment).length));
    }
  });

  test('still mode and tests take the first variant every time', () {
    for (final moment in WuselMoment.values) {
      final first = WuselLines.variants(de, moment, name: 'Lotta').first;
      expect(WuselLines.pick(de, moment, name: 'Lotta'), first);
      expect(WuselLines.pick(de, moment, name: 'Lotta'), first);
    }
    WuselLines.random = math.Random(7);
    StillMode.enabled = true;
    for (final moment in WuselMoment.values) {
      final first = WuselLines.variants(de, moment, name: 'Lotta').first;
      for (var i = 0; i < 20; i++) {
        expect(WuselLines.pick(de, moment, name: 'Lotta'), first);
      }
    }
  });

  test('stable picks the same variant for the same seed', () {
    for (var seed = 0; seed < 10; seed++) {
      expect(
        WuselLines.stable(de, WuselMoment.wallMorning, seed: seed),
        WuselLines.stable(de, WuselMoment.wallMorning, seed: seed),
      );
    }
  });
}
