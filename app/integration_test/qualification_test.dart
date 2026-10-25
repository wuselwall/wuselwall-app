// Initial native rendering smoke. Platform audit adapters remain an explicit open gate.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/router.dart';

import '../qualification/fixture.dart';
import '../qualification/inventory.g.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const tablet = bool.fromEnvironment('QUALIFY_TABLET');
  const smoke = bool.fromEnvironment('QUALIFY_SMOKE');
  final nativeStates = (jsonDecode(nativeStatesJson) as List)
      .cast<Map<String, dynamic>>();
  final cases = nativeStates
      .where((s) => tablet || !['kid', 'kiosk'].contains(s['scenario']))
      .toList();
  var captured = 0;
  for (final locale in smoke ? ['de'] : ['de', 'en', 'fr', 'es']) {
    for (final shade in smoke ? ['light'] : ['light', 'dark']) {
      for (final sample in cases) {
        testWidgets("${sample['id']}-$locale-$shade", (t) async {
          await t.pumpWidget(
            qualificationApp(
              scenario: sample['scenario'] as String,
              locale: Locale(locale),
              shade: shade,
              tab: sample['tab'] as String? ?? 'today',
            ),
          );
          await t.pumpAndSettle();
          if (sample['route'] != '/') {
            final container = ProviderScope.containerOf(
              t.element(find.byType(WuselWallApp)),
            );
            container.read(routerProvider).go(sample['route'] as String);
            await t.pumpAndSettle();
          }
          expect(
            find.byWidgetPredicate(
              (w) => isQualificationDestination(w, sample['widget'] as String),
            ),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          if (defaultTargetPlatform == TargetPlatform.android) {
            await binding.convertFlutterSurfaceToImage();
            await t.pump();
          }
          await binding.takeScreenshot("${sample['id']}-$locale-$shade");
          captured++;
          binding.reportData = {
            ...?binding.reportData,
            'qualification': 'INCOMPLETE',
            'scope':
                'native Flutter rendering; no platform accessibility audit',
            'expected': cases.length * (smoke ? 1 : 8),
            'captured': captured,
            'logicalWidth': t.view.physicalSize.width / t.view.devicePixelRatio,
            'logicalHeight':
                t.view.physicalSize.height / t.view.devicePixelRatio,
            'devicePixelRatio': t.view.devicePixelRatio,
          };
          await t.pumpWidget(const SizedBox.shrink());
          await t.pump();
        });
      }
    }
  }
}
