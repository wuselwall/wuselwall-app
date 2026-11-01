import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exact_contrast.dart';

const _background = Color(0xffffffff);
const _foreground = Color(0xff666666);

class _NoopForegroundPainter extends CustomPainter {
  const _NoopForegroundPainter();

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(_NoopForegroundPainter oldDelegate) => false;
}

class _MultiplyForegroundPainter extends CustomPainter {
  const _MultiplyForegroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xff808080), BlendMode.multiply);
  }

  @override
  bool shouldRepaint(_MultiplyForegroundPainter oldDelegate) => false;
}

class _MutatingListenerPainter extends CustomPainter {
  RenderParagraph? paragraph;
  InlineSpan? originalSpan;
  bool armed = false;
  bool mutated = false;
  bool sawMutation = false;

  @override
  void addListener(VoidCallback listener) {
    if (armed && mutated) {
      paragraph!.text = originalSpan!;
      mutated = false;
      armed = false;
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    if (armed && !mutated) {
      paragraph!.text = const TextSpan(
        text: 'Original',
        style: TextStyle(
          fontFamily: 'AtkinsonHyperlegibleNext',
          fontSize: 12,
          color: Colors.white,
        ),
      );
      mutated = true;
      sawMutation = true;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MutatingListenerPainter oldDelegate) => false;
}

class _UnstableForegroundPainter extends CustomPainter {
  int _paints = 0;

  @override
  void paint(Canvas canvas, Size size) {
    final color = _paints.isEven ? Colors.red : Colors.blue;
    _paints++;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_UnstableForegroundPainter oldDelegate) => true;
}

Widget _page(Widget body) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: _background,
    body: Center(child: body),
  ),
);

Text _text(String value) => Text(
  value,
  style: const TextStyle(
    fontFamily: 'AtkinsonHyperlegibleNext',
    fontSize: 12,
    color: _foreground,
  ),
);

class _NeutralForegroundPainter extends CustomPainter {
  const _NeutralForegroundPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // This flat overlay is deliberately not the TextStyle foreground. It can
    // nevertheless land on the same sampled colour/blend line as the glyphs.
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 0.5, 0, 1, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_NeutralForegroundPainter oldDelegate) =>
      oldDelegate.color != color;
}

void main() {
  setUpAll(() async {
    final font = FontLoader('AtkinsonHyperlegibleNext')
      ..addFont(
        rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf'),
      );
    await font.load();
  });

  Future<ExactContrastReport> audit(WidgetTester tester, Widget child) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_page(child));
      await tester.pump();
      return await auditExactContrast(tester);
    } finally {
      semantics.dispose();
    }
  }

  testWidgets('perspective transformed text keeps the SDK verdict', (
    tester,
  ) async {
    final transform = Matrix4.identity()
      ..setEntry(3, 0, 0.004)
      ..setEntry(3, 1, 0.002);
    final report = await audit(
      tester,
      Transform(
        transform: transform,
        child: SizedBox(width: 240, child: _text('Perspective contrast')),
      ),
    );

    expect(report.rows, hasLength(1));
    expect(
      report.rows.single.classification,
      'UNDECIDED',
      reason: '${report.rows.single.toJson()}',
    );
    expect(report.rows.single.reason, 'Perspective transform');
  });

  testWidgets('a neutral foreground CustomPaint overlay is not a text proof', (
    tester,
  ) async {
    final report = await audit(
      tester,
      CustomPaint(
        foregroundPainter: const _NeutralForegroundPainter(Color(0xffaaaaaa)),
        child: SizedBox(
          width: 240,
          child: Center(child: _text('Overpainted contrast')),
        ),
      ),
    );

    expect(report.rows, hasLength(1));
    expect(report.rows.single.classification, 'UNDECIDED');
    expect(report.rows.single.reason, 'Foreground painter');
    expect(report.rows.single.foregroundPainterProof, 'unproven');
  });

  testWidgets('a no-op foreground painter is proven against the actual scene', (
    tester,
  ) async {
    final report = await audit(
      tester,
      CustomPaint(
        foregroundPainter: const _NoopForegroundPainter(),
        child: SizedBox(width: 240, child: Center(child: _text('No-op'))),
      ),
    );

    expect(report.rows, hasLength(1));
    expect(report.rows.single.classification, 'PASS');
    expect(report.rows.single.foregroundPainterProof, 'pixel-identical');
    expect(report.toJson()['foregroundPainterProofs'], {
      'pixelIdentical': 1,
      'unproven': 0,
    });
  });

  testWidgets('a B-only paragraph mutation prevents a painter proof', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    try {
      final painter = _MutatingListenerPainter();
      await tester.pumpWidget(
        _page(
          CustomPaint(
            foregroundPainter: painter,
            child: SizedBox(
              width: 240,
              child: Center(child: _text('Original')),
            ),
          ),
        ),
      );
      await tester.pump();
      final paragraph =
          tester.renderObject(find.text('Original')) as RenderParagraph;
      painter
        ..paragraph = paragraph
        ..originalSpan = paragraph.text
        ..armed = true;

      final sdk = await textContrastGuideline.evaluate(tester);
      expect(sdk.passed, isFalse, reason: 'The covered text must be detected');
      final report = await auditExactContrast(tester);

      expect(painter.mutated, isFalse, reason: 'restore callback must run');
      expect(painter.sawMutation, isTrue, reason: 'B-only style must change');
      expect(paragraph.text, same(painter.originalSpan));
      expect(report.rows, hasLength(1));
      expect(report.rows.single.text, 'Original');
      expect(report.rows.single.classification, 'UNDECIDED');
      expect(report.rows.single.reason, 'Foreground painter');
      expect(report.rows.single.foregroundPainterProof, 'unproven');
      expect(report.provenNodes, isEmpty);
      expect(
        retainedSdkContrast(sdk.reason ?? '', report.provenNodes),
        isNotNull,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('a background-dependent blend over glyphs stays undecided', (
    tester,
  ) async {
    final report = await audit(
      tester,
      CustomPaint(
        foregroundPainter: const _MultiplyForegroundPainter(),
        child: SizedBox(width: 240, child: Center(child: _text('Blended'))),
      ),
    );

    expect(report.rows, hasLength(1));
    expect(report.rows.single.classification, 'UNDECIDED');
    expect(report.rows.single.reason, 'Foreground painter');
    expect(report.rows.single.foregroundPainterProof, 'unproven');
  });

  testWidgets(
    'a replaced painter aborts the audit instead of changing the scene',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        const original = _NoopForegroundPainter();
        const replacement = _NeutralForegroundPainter(Colors.grey);
        await tester.pumpWidget(
          _page(
            CustomPaint(foregroundPainter: original, child: _text('Replace')),
          ),
        );
        await tester.pump();
        final render = tester.renderObject<RenderCustomPaint>(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                identical(widget.foregroundPainter, original),
          ),
        );
        tester.binding.addPostFrameCallback((_) {
          render.foregroundPainter = replacement;
        });
        await expectLater(
          auditExactContrast(tester),
          throwsA(isA<StateError>()),
        );
        expect(render.foregroundPainter, same(replacement));
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('an unstable scene stays undecided and restores its painter', (
    tester,
  ) async {
    final painter = _UnstableForegroundPainter();
    final report = await audit(
      tester,
      CustomPaint(
        key: const ValueKey('unstable-painter'),
        foregroundPainter: painter,
        child: SizedBox(width: 240, child: Center(child: _text('Unstable'))),
      ),
    );

    final render = tester.renderObject(
      find.byKey(const ValueKey('unstable-painter')),
    ) as RenderCustomPaint;
    expect(identical(render.foregroundPainter, painter), isTrue);
    expect(report.rows, hasLength(1));
    expect(report.rows.single.classification, 'UNDECIDED');
    expect(report.rows.single.reason, 'Foreground painter');
    expect(report.rows.single.foregroundPainterProof, 'unproven');
  });

  testWidgets('shear cannot promote compressed text to the large-text limit', (
    tester,
  ) async {
    final report = await audit(
      tester,
      Transform(
        transform: Matrix4.identity()..setEntry(0, 1, 1),
        child: const Text(
          'Sheared text',
          style: TextStyle(
            fontFamily: 'AtkinsonHyperlegibleNext',
            fontSize: 24,
            color: Color(0xff888888),
          ),
        ),
      ),
    );

    final row = report.rows.single;
    expect(row.classification, 'FAIL', reason: '${row.toJson()}');
    expect(row.effectiveSize, lessThan(24));
    expect(row.required, 4.5);
    expect(row.ratio, inExclusiveRange(3, 4.5));
    expect(report.provenNodes, isEmpty);
  });

  testWidgets('a later-painted Stack sibling is not a text proof', (
    tester,
  ) async {
    final report = await audit(
      tester,
      SizedBox(
        width: 240,
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _text('Overpainted contrast'),
            const Positioned(
              left: 120,
              top: 0,
              bottom: 0,
              width: 1,
              child: ColoredBox(color: Color(0xffaaaaaa)),
            ),
          ],
        ),
      ),
    );

    expect(report.rows, hasLength(1));
    expect(
      report.rows.single.classification,
      'UNDECIDED',
      reason: '${report.rows.single.toJson()}',
    );
    expect(report.rows.single.reason, 'Overlapping later-painted sibling');
  });
}
