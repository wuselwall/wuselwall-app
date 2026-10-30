import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exact_contrast.dart';

const _background = Color(0xffffffff);
const _foreground = Color(0xff666666);

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
