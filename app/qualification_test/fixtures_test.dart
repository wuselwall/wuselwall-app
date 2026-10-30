// Candidate-only fixture integrity: every direct destination must render actual
// content in all shipped languages before its accessibility audit can count.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/demo/demo_clock.dart';

import '../qualification/fixture.dart';
import '../qualification/inventory.g.dart';

import 'settle.dart';

void main() {
  final inventory = jsonDecode(
    File('../qualification/inventory.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final states = (inventory['states'] as List)
      .cast<Map<String, dynamic>>()
      .where((s) => s['fixture'] == true);
  setUpAll(() async {
    for (final family in {
      'AtkinsonHyperlegibleNext': ['Regular', 'SemiBold', 'Bold', 'ExtraBold'],
      'BarlowSemiCondensed': ['Medium', 'SemiBold', 'Bold'],
    }.entries) {
      final loader = FontLoader(family.key);
      for (final weight in family.value) {
        loader.addFont(
          rootBundle.load('assets/fonts/${family.key}-$weight.ttf'),
        );
      }
      await loader.load();
    }
  });
  for (final locale in ['de', 'en', 'fr', 'es']) {
    for (final state in states) {
      testWidgets('${state['id']} fixture renders in $locale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.platformDispatcher.localesTestValue = [Locale(locale)];
        try {
          await tester.pumpWidget(
            qualificationApp(
              stateId: state['id'] as String,
              scenario: state['scenario'] as String,
              locale: Locale(locale),
              shade: 'light',
            ),
          );
          await settleQualification(tester);
          // Exercise the same navigation call used by both matrix runners.
          final container = ProviderScope.containerOf(
            tester.element(find.byType(WuselWallApp)),
          );
          container.read(routerProvider).go(state['route'] as String);
          await settleQualification(tester);
          expect(
            find.byWidgetPredicate(
              (w) => isQualificationDestination(w, state['widget'] as String),
            ),
            findsOneWidget,
          );
          if (state['id'] == 'pair') {
            expect(find.byKey(const ValueKey('pair-code')), findsOneWidget);
            expect(find.byKey(const ValueKey('pair-qr')), findsOneWidget);
          } else {
            expect(
              find.byType(CircularProgressIndicator),
              findsNothing,
              reason: 'A fixture that stays loading is missing coverage',
            );
          }
          if (!['splash-error', 'recipes-error'].contains(state['id'])) {
            expect(
              find.byType(ErrorView),
              findsNothing,
              reason: 'A data fixture must render content instead of an error',
            );
          }
          expect(
            tester.takeException(),
            isNull,
            reason: 'Fixtures must expose framework/layout errors',
          );
          if (state['id'] == 'recipes-error') {
            expect(find.byType(ErrorView), findsOneWidget);
          }
          expect(
            find.textContaining('coming soon', findRichText: true),
            findsNothing,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
          DemoClock.fixedNow = null;
          StillMode.enabled = false;
        }
      });
    }
  }
}
