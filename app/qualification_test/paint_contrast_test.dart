import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../qualification/fixture.dart';

import 'paint_contrast.dart';
import 'settle.dart';

Widget sample(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

Widget label(
  String text, {
  Color color = Colors.black,
  Color background = Colors.white,
  double size = 16,
  FontWeight weight = FontWeight.normal,
  BoxBorder? border,
}) => Container(
  padding: const EdgeInsets.all(2),
  decoration: BoxDecoration(color: background, border: border),
  child: Text(
    text,
    style: TextStyle(
      fontFamily: 'AtkinsonHyperlegibleNext',
      fontSize: size,
      fontWeight: weight,
      color: color,
    ),
  ),
);

void main() {
  setUpAll(() async {
    final loader = FontLoader('AtkinsonHyperlegibleNext')
      ..addFont(
        rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf'),
      );
    await loader.load();
  });
  testWidgets(
    'paint proof distinguishes a valid text/border histogram disagreement',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(800, 600);
      addTearDown(t.view.reset);
      final handle = t.ensureSemantics();
      try {
        await t.pumpWidget(
          sample(
            label(
              'Ink',
              border: Border.all(color: const Color(0xffaaaaaa), width: 4),
            ),
          ),
        );
        final report = auditPaintContrast(t);
        expect(
          report.rows.single['classification'],
          'PROVEN_PASS',
          reason: '${report.toJson()}',
        );
        final sdk = await textContrastGuideline.evaluate(t);
        expect(sdk.passed, false);
        expect(sdk.passed && !report.failed, false);
        expect(report.failed, false);
      } finally {
        handle.dispose();
      }
    },
  );
  testWidgets(
    'paint proof blocks genuine low contrast and alpha-composited low contrast',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(800, 600);
      addTearDown(t.view.reset);
      final handle = t.ensureSemantics();
      try {
        for (final color in [
          const Color(0xffdddddd),
          const Color(0x22000000),
        ]) {
          await t.pumpWidget(sample(label('Low contrast', color: color)));
          final report = auditPaintContrast(t);
          expect(report.failed, true, reason: '${report.toJson()}');
          final sdk = await textContrastGuideline.evaluate(t);
          expect(sdk.passed && !report.failed, false);
        }
      } finally {
        handle.dispose();
      }
    },
  );
  testWidgets(
    'equal text at different positions cannot hide the failing instance',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(800, 600);
      addTearDown(t.view.reset);
      final handle = t.ensureSemantics();
      try {
        await t.pumpWidget(
          sample(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                label('Repeated label'),
                label('Repeated label', color: const Color(0xffdddddd)),
              ],
            ),
          ),
        );
        final report = auditPaintContrast(t);
        expect(report.failed, true, reason: '${report.toJson()}');
        expect(
          report.rows.where((r) => r['classification'] == 'PROVEN_FAIL'),
          hasLength(1),
        );
        final sdk = await textContrastGuideline.evaluate(t);
        expect(report.failed, true);
        expect(sdk.passed && !report.failed, false);
      } finally {
        handle.dispose();
      }
    },
  );
  testWidgets('opacity and gradient preserve SDK fallback', (t) async {
    final handle = t.ensureSemantics();
    try {
      for (final child in [
        Opacity(opacity: 0.5, child: label('Opacity')),
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.white, Colors.grey]),
          ),
          child: label('Gradient'),
        ),
        Stack(children: [label('Stack')]),
      ]) {
        await t.pumpWidget(sample(child));
        final report = auditPaintContrast(t);
        expect(
          report.rows.single['classification'],
          'UNSUPPORTED',
          reason: '${report.toJson()}',
        );
        final sdk = await textContrastGuideline.evaluate(t);
        expect(report.failed, false);
        expect(sdk.passed && !report.failed, sdk.passed);
      }
    } finally {
      handle.dispose();
    }
  });
  testWidgets(
    'large text threshold uses scaled size and bold weight without rounding ratios',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(800, 600);
      addTearDown(t.view.reset);
      final handle = t.ensureSemantics();
      try {
        expect(requiredPaintContrast(18, FontWeight.normal), 4.5);
        expect(requiredPaintContrast(24, FontWeight.normal), 3);
        expect(requiredPaintContrast(19, FontWeight.w800), 3);
        expect(requiredPaintContrast(19, FontWeight.w600), 4.5);
        await t.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: sample(label('Scaled', color: const Color(0xff888888))),
          ),
        );
        final report = auditPaintContrast(t);
        expect(
          report.rows.single['classification'],
          'PROVEN_PASS',
          reason: '${report.toJson()}',
        );
        final run = (report.rows.single['runs'] as List).single as Map;
        expect(run['effectiveSize'], 32);
        expect(run['required'], 3);
      } finally {
        handle.dispose();
      }
    },
  );
  testWidgets(
    'real calendar fixture retains raw SDK gate and writes paint evidence',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.reset);
      final handle = t.ensureSemantics();
      try {
        await t.pumpWidget(
          qualificationApp(
            stateId: 'calendar',
            scenario: 'adult',
            locale: const Locale('de'),
            shade: 'light',
            tab: 'calendar',
          ),
        );
        await settleQualification(t);
        final sdk = await textContrastGuideline.evaluate(t);
        final paint = auditPaintContrast(t);
        expect(paint.rows, isNotEmpty);
        final output = File('../build/qualification/flutter/paint-sample.json');
        output.parent.createSync(recursive: true);
        output.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'state': 'calendar-de-light-390-1',
            'sdk': {'passed': sdk.passed, 'reason': sdk.reason},
            'paint': paint.toJson(),
            'sdkOverrideEnabled': false,
          }),
        );
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        handle.dispose();
      }
    },
  );
}
