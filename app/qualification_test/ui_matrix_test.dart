// Explicitly selected by candidate qualification; outside default test/ discovery.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/demo/demo_clock.dart';

import '../qualification/fixture.dart';
import '../qualification/inventory.g.dart';

void main() {
  final inventory = jsonDecode(
    File('../qualification/inventory.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  const profile = String.fromEnvironment(
    'QUALIFY_MATRIX',
    defaultValue: 'canonical',
  );
  if (!['smoke', 'canonical', 'responsive', 'full'].contains(profile)) {
    throw ArgumentError('Unknown matrix: $profile');
  }
  final evidence = <Map<String, Object?>>[];
  var expected = 0;
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
  tearDownAll(() {
    final file = File('../build/qualification/flutter/$profile/results.json');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'schema': 1,
        'matrix': profile,
        'expected': expected,
        'executed': evidence.length,
        'qualification': 'INCOMPLETE',
        'openGates': inventory['openGates'],
        'results': evidence,
      }),
    );
  });

  for (final state
      in (inventory['states'] as List).cast<Map<String, dynamic>>()) {
    if (profile == 'smoke' &&
        !['today', 'shopping', 'settings'].contains(state['id'])) {
      continue;
    }
    final primary = state['scenario'] == 'kiosk'
        ? 1280
        : state['scenario'] == 'kid'
        ? 820
        : 390;
    final configurations =
        <({int width, String shade, double scale, String tier})>[];
    if (profile != 'responsive') {
      for (final shade
          in profile == 'smoke'
              ? ['light']
              : state['scenario'] == 'kiosk'
              ? ['light', 'dark', 'night']
              : ['light', 'dark']) {
        configurations.add((
          width: primary,
          shade: shade,
          scale: 1,
          tier: 'canonical',
        ));
      }
    }
    if (profile == 'responsive' || profile == 'full') {
      for (final width in (state['widths'] as List).cast<int>()) {
        for (final scale in [1.0, 2.0]) {
          configurations.add((
            width: width,
            shade: 'light',
            scale: scale,
            tier: 'responsive',
          ));
        }
      }
    }
    for (final lang
        in profile == 'smoke'
            ? ['de']
            : (inventory['locales'] as List).cast<String>()) {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final config in configurations) {
          expected++;
          final id =
              '${state['id']}-$lang-${config.shade}-${config.width}-${config.scale}-${platform.name}-${config.tier}';
          testWidgets(id, (tester) async {
            debugDefaultTargetPlatformOverride = platform;
            tester.view.physicalSize = Size(
              config.width.toDouble(),
              config.width == 1920
                  ? 1080
                  : state['scenario'] == 'kiosk'
                  ? 800
                  : config.width >= 768
                  ? 1024
                  : 844,
            );
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.localesTestValue = [Locale(lang)];
            tester.platformDispatcher.platformBrightnessTestValue =
                config.shade == 'light' ? Brightness.light : Brightness.dark;
            tester.platformDispatcher.textScaleFactorTestValue = config.scale;
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const FakeAccessibilityFeatures(disableAnimations: true);
            final handle = tester.ensureSemantics();
            final findings = <Map<String, Object?>>[];
            final row = <String, Object?>{
              'id': id,
              'status': 'NOT RUN',
              'findings': findings,
            };
            evidence.add(row);
            try {
              await tester.pumpWidget(
                qualificationApp(
                  scenario: state['scenario'] as String,
                  locale: Locale(lang),
                  shade: config.shade,
                  tab: state['tab'] as String? ?? 'today',
                  advanced: state['advanced'] == true,
                ),
              );
              await tester.pumpAndSettle();
              if (state['route'] != '/') {
                final container = ProviderScope.containerOf(
                  tester.element(find.byType(WuselWallApp)),
                );
                container.read(routerProvider).go(state['route'] as String);
                await tester.pumpAndSettle();
              }
              expect(
                find.byWidgetPredicate(
                  (w) =>
                      isQualificationDestination(w, state['widget'] as String),
                ),
                findsOneWidget,
                reason:
                    'The requested destination must be present before auditing',
              );
              expect(
                tester.takeException(),
                isNull,
                reason: 'Layout and framework errors fail qualification',
              );
              final root = tester
                  .binding
                  .renderViews
                  .first
                  .owner
                  ?.semanticsOwner
                  ?.rootSemanticsNode;
              expect(
                root,
                isNotNull,
                reason: 'No semantics is missing coverage',
              );
              var labeled = 0;
              void visit(SemanticsNode node) {
                if (node.label.trim().isNotEmpty) labeled++;
                node.visitChildren((child) {
                  visit(child);
                  return true;
                });
              }

              visit(root!);
              expect(
                labeled,
                greaterThan(2),
                reason: 'A vacuous audit cannot pass',
              );
              row['labeledNodes'] = labeled;
              for (final entry in {
                'labels': labeledTapTargetGuideline,
                'targets': platform == TargetPlatform.iOS
                    ? iOSTapTargetGuideline
                    : androidTapTargetGuideline,
                'textContrast': textContrastGuideline,
              }.entries) {
                final result = await entry.value.evaluate(tester);
                if (!result.passed) {
                  findings.add({'rule': entry.key, 'reason': result.reason});
                }
              }
              row['status'] = findings.isEmpty ? 'PASS' : 'FAIL';
              expect(
                findings,
                isEmpty,
                reason: 'Accessibility findings must be reviewed and fixed, never hidden',
              );
            } catch (error) {
              row['status'] = 'FAIL';
              row['error'] = error.toString();
              rethrow;
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              handle.dispose();
              debugDefaultTargetPlatformOverride = null;
              tester.view.reset();
              tester.platformDispatcher.clearAllTestValues();
              DemoClock.fixedNow = null;
              StillMode.enabled = false;
            }
          });
        }
      }
    }
  }
}
