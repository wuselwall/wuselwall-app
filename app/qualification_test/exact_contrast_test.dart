// Controls for the exact contrast audit: it must fail real failures, prove the
// cases the SDK estimate misattributes, and stay undecided where paint is mixed.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exact_contrast.dart';

const _paper = Color(0xfff7f4ee);
const _ink = Color(0xff4a4a4a);
const _line = Color(0xffd9d5cd);

void _ignorePointer(PointerDownEvent event) {}

TextStyle _style({Color color = _ink, double size = 12}) => TextStyle(
  fontFamily: 'AtkinsonHyperlegibleNext',
  fontSize: size,
  color: color,
);

class _NoopForegroundPainter extends CustomPainter {
  const _NoopForegroundPainter();

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(_NoopForegroundPainter oldDelegate) => false;
}

class _OutlineForegroundPainter extends CustomPainter {
  const _OutlineForegroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = _line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_OutlineForegroundPainter oldDelegate) => false;
}

class _OneGlyphBackgroundPainter extends CustomPainter {
  const _OneGlyphBackgroundPainter(this.glyphBox);

  final Rect glyphBox;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(glyphBox, Paint()..color = const Color(0xff666666));
  }

  @override
  bool shouldRepaint(_OneGlyphBackgroundPainter oldDelegate) =>
      oldDelegate.glyphBox != glyphBox;
}

Widget _page(Widget body) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: _paper,
    body: Center(child: body),
  ),
);

void main() {
  setUpAll(() async {
    final font = FontLoader('AtkinsonHyperlegibleNext')
      ..addFont(
        rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf'),
      );
    await font.load();
  });

  Future<T> withSemantics<T>(
    WidgetTester t,
    Widget page,
    Future<T> Function() body,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 600);
    addTearDown(t.view.reset);
    final semantics = t.ensureSemantics();
    try {
      await t.pumpWidget(page);
      await t.pump();
      return await body();
    } finally {
      semantics.dispose();
    }
  }

  testWidgets('a real low-contrast text is a decided FAIL', (t) async {
    await withSemantics(
      t,
      _page(
        Text('Known contrast failure', style: _style(color: _line, size: 16)),
      ),
      () async {
        final report = await auditExactContrast(t);
        final row = report.rows.single;
        expect(row.classification, 'FAIL');
        expect(row.ratio, lessThan(2));
        expect(row.required, 4.5);
        expect(report.provenNodes, isEmpty);
        expect((await textContrastGuideline.evaluate(t)).passed, isFalse);
      },
    );
  });

  testWidgets(
    'readable text in a bordered table: the SDK misattributes the border, '
    'the exact audit proves the text and supersedes that estimate',
    (t) async {
      await withSemantics(
        t,
        _page(
          SizedBox(
            width: 400,
            child: Table(
              border: TableBorder.all(color: _line, width: 2),
              children: [
                TableRow(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.all(2),
                        child: Text('9:55–10:40', style: _style()),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        () async {
          final sdk = await textContrastGuideline.evaluate(t);
          expect(
            sdk.passed,
            isFalse,
            reason: 'The control must reproduce the misattribution',
          );
          final report = await auditExactContrast(t);
          expect(report.rows, hasLength(5));
          for (final row in report.rows) {
            expect(row.classification, 'PASS', reason: row.reason);
            expect(row.background, _paper.toARGB32());
            expect(row.foreground, _ink.toARGB32());
            expect(row.ratio, greaterThan(4.5));
          }
          final superseded = <String>[];
          final retained = retainedSdkContrast(
            sdk.reason ?? '',
            report.provenNodes,
            superseded: superseded,
          );
          expect(retained, isNull);
          expect(superseded, isNotEmpty);
        },
      );
    },
  );

  testWidgets('text over a gradient stays undecided', (t) async {
    await withSemantics(
      t,
      _page(
        Container(
          width: 300,
          height: 40,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.white, Colors.black]),
          ),
          alignment: Alignment.center,
          child: Text('Over a gradient', style: _style(size: 14)),
        ),
      ),
      () async {
        final row = (await auditExactContrast(t)).rows.single;
        expect(row.classification, 'UNDECIDED');
        expect(row.reason, 'No flat background under the text');
      },
    );
  });

  testWidgets('faded text stays undecided', (t) async {
    await withSemantics(
      t,
      _page(Opacity(opacity: 0.5, child: Text('Faded', style: _style()))),
      () async {
        final row = (await auditExactContrast(t)).rows.single;
        expect(row.classification, 'UNDECIDED');
        expect(row.reason, 'Opacity below 1');
      },
    );
  });

  testWidgets('an icon glyph is not text and leaves no row', (t) async {
    await withSemantics(
      t,
      _page(
        Semantics(
          label: 'Chosen',
          child: const Icon(Icons.check, color: _line, size: 22),
        ),
      ),
      () async => expect((await auditExactContrast(t)).rows, isEmpty),
    );
  });

  testWidgets(
    'an icon-only paragraph under a foreground painter does not block its '
    'merged text node',
    (t) async {
      await withSemantics(
        t,
        _page(
          Semantics(
            container: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  foregroundPainter: const _NoopForegroundPainter(),
                  child: const Icon(Icons.check, color: _line, size: 22),
                ),
                const SizedBox(width: 8),
                Text('Readable action', style: _style()),
              ],
            ),
          ),
        ),
        () async {
          final report = await auditExactContrast(t);
          expect(report.rows, hasLength(1));
          final row = report.rows.single;
          expect(row.text, 'Readable action');
          expect(row.classification, 'PASS', reason: row.reason);
          expect(report.provenNodes, contains(row.semanticsId));
        },
      );
    },
  );

  testWidgets(
    'a fade that does not overflow is decided; one that does is not',
    (t) async {
      await withSemantics(
        t,
        _page(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                child: Text(
                  'Fits',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: _style(size: 14),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'This one is far too long to fit',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: _style(size: 14),
                ),
              ),
            ],
          ),
        ),
        () async {
          final rows = await auditExactContrast(t);
          final fits = rows.rows.singleWhere((r) => r.text == 'Fits');
          final long = rows.rows.singleWhere((r) => r.text != 'Fits');
          expect(fits.classification, 'PASS', reason: fits.reason);
          expect(long.classification, 'UNDECIDED');
          expect(long.reason, 'Text fade changes glyph opacity');
        },
      );
    },
  );

  testWidgets('an outlined foreground painter stays unproven without a proof', (
    t,
  ) async {
    await withSemantics(
      t,
      _page(
        CustomPaint(
          foregroundPainter: const _OutlineForegroundPainter(),
          child: SizedBox(
            width: 240,
            height: 64,
            child: Center(child: Text('Inside the outline', style: _style())),
          ),
        ),
      ),
      () async {
        final row = (await auditExactContrast(t)).rows.single;
        expect(row.text, 'Inside the outline');
        expect(row.classification, 'UNDECIDED', reason: row.reason);
        expect(row.reason, 'Foreground painter');
      },
    );
  });

  testWidgets(
    'text spanning flat backgrounds accounts for ambiguous plateaus',
    (t) async {
      Widget halves(Color left, Color right) => Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 60, height: 30, color: left),
              Container(width: 60, height: 30, color: right),
            ],
          ),
          Text('Across', style: _style(size: 14)),
        ],
      );
      await withSemantics(t, _page(halves(Colors.white, _paper)), () async {
        final row = (await auditExactContrast(t)).rows.single;
        expect(row.classification, 'PASS', reason: row.reason);
        expect(row.background2, isNotNull);
      });
      await withSemantics(
        t,
        _page(halves(Colors.white, const Color(0xff8a8a8a))),
        () async {
          final row = (await auditExactContrast(t)).rows.single;
          expect(row.classification, 'UNDECIDED', reason: row.reason);
          expect(row.reason, 'Ambiguous low-contrast background candidate');
        },
      );
    },
  );

  testWidgets(
    'a low-contrast background beneath one glyph cannot be diluted by a long '
    'paragraph',
    (t) async {
      const text =
          'MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM';
      final style = _style(color: Colors.black, size: 12);
      final layout = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 300);
      final glyph = layout
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1),
          )
          .single
          .toRect();
      await withSemantics(
        t,
        _page(
          CustomPaint(
            key: const ValueKey('single-glyph-background'),
            painter: _OneGlyphBackgroundPainter(glyph),
            child: SizedBox(
              width: 300,
              height: layout.height,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(text, style: style),
              ),
            ),
          ),
        ),
        () async {
          final renderBackground = t.renderObject(
            find.byKey(const ValueKey('single-glyph-background')),
          ) as RenderCustomPaint;
          final paragraph = t.renderObject(find.text(text)) as RenderParagraph;
          final actualGlyph = MatrixUtils.transformRect(
            paragraph.getTransformTo(renderBackground),
            paragraph
                .getBoxesForSelection(
                  const TextSelection(baseOffset: 0, extentOffset: 1),
                )
                .single
                .toRect(),
          );
          expect(glyph.inflate(1).contains(actualGlyph.center), isTrue);
          expect(actualGlyph.width, closeTo(glyph.width, 1));
          expect(actualGlyph.height, closeTo(glyph.height, 1));
          final row = (await auditExactContrast(t)).rows.single;
          expect(row.classification, 'UNDECIDED', reason: '${row.toJson()}');
          expect(
            row.reason,
            anyOf(
              'Ambiguous low-contrast background candidate',
              'More than two flat background candidates',
            ),
          );
        },
      );
    },
  );

  testWidgets(
    'an empty hit-test Listener later in a Stack does not obscure text',
    (t) async {
      await withSemantics(
        t,
        _page(
          SizedBox(
            width: 240,
            height: 32,
            child: Stack(
              children: [
                Center(child: Text('Listener control', style: _style())),
                const Positioned.fill(
                  child: Listener(
                    onPointerDown: _ignorePointer,
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
        () async {
          final row = (await auditExactContrast(t)).rows.single;
          expect(row.text, 'Listener control');
          expect(row.classification, 'PASS', reason: row.reason);
        },
      );
    },
  );

  testWidgets('a zero-area later Stack sibling does not obscure text', (
    t,
  ) async {
    await withSemantics(
      t,
      _page(
        SizedBox(
          width: 240,
          height: 32,
          child: Stack(
            children: [
              Center(child: Text('Zero-area control', style: _style())),
              const Positioned(
                left: 120,
                top: 0,
                bottom: 0,
                width: 0,
                child: ColoredBox(color: _line),
              ),
            ],
          ),
        ),
      ),
      () async {
        final row = (await auditExactContrast(t)).rows.single;
        expect(row.text, 'Zero-area control');
        expect(row.classification, 'PASS', reason: row.reason);
      },
    );
  });

  testWidgets(
    'a second background below half of every glyph still cannot be ignored',
    (t) async {
      await withSemantics(
        t,
        _page(
          SizedBox(
            width: 300,
            height: 30,
            child: Stack(
              children: [
                SizedBox.expand(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(
                        flex: 52,
                        child: ColoredBox(color: Colors.white),
                      ),
                      const Expanded(
                        flex: 48,
                        child: ColoredBox(color: Color(0xff8a8a8a)),
                      ),
                    ],
                  ),
                ),
                Center(child: Text('MMMMMMMM', style: _style(size: 14))),
              ],
            ),
          ),
        ),
        () async {
          final report = await auditExactContrast(t);
          final row = report.rows.single;
          expect(row.classification, isNot('PASS'), reason: '${row.toJson()}');
          if (row.classification == 'FAIL') {
            expect(row.ratio, lessThan(4.5));
          } else {
            expect(row.reason, contains('background'));
          }
          expect(report.provenNodes, isEmpty);
        },
      );
    },
  );

  testWidgets(
    'paper around an avatar circle is not a background of its letter',
    (t) async {
      await withSemantics(
        t,
        _page(
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xff7b3fe4),
            ),
            alignment: Alignment.center,
            child: Text(
              'E',
              style: _style(
                color: Colors.white,
                size: 11,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        () async {
          final row = (await auditExactContrast(t)).rows.single;
          expect(row.classification, 'PASS', reason: row.reason);
          expect(row.background, 0xff7b3fe4);
          expect(row.background2, isNull);
        },
      );
    },
  );

  testWidgets('a bar right under the glyphs cannot lower a proven contrast', (
    t,
  ) async {
    await withSemantics(
      t,
      _page(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Erweitert', style: _style(size: 15)),
            Container(width: 70, height: 3, color: Colors.white),
          ],
        ),
      ),
      () async {
        final row = (await auditExactContrast(t)).rows.single;
        expect(row.classification, 'PASS', reason: row.reason);
        expect(row.background, _paper.toARGB32());
        // A nearby white plateau may be attributed conservatively, but the
        // ratio remains safe on both the paper and the white surface.
        expect(row.ratio, greaterThan(4.5), reason: '${row.toJson()}');
      },
    );
  });

  testWidgets('translucent text is measured as its composited colour', (
    t,
  ) async {
    await withSemantics(
      t,
      _page(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Strong', style: _style(color: const Color(0xdd000000))),
            Text('Weak', style: _style(color: const Color(0x55000000))),
          ],
        ),
      ),
      () async {
        final rows = (await auditExactContrast(t)).rows;
        final strong = rows.singleWhere((r) => r.text == 'Strong');
        final weak = rows.singleWhere((r) => r.text == 'Weak');
        expect(strong.classification, 'PASS', reason: strong.reason);
        expect(weak.classification, 'FAIL', reason: weak.reason);
        expect(weak.ratio, lessThan(3));
      },
    );
  });

  test(
    'maskedNodes names nodes whose paragraphs all lie under a shader mask',
    () {
      ExactContrastRow row(int id, String cls, [String? reason]) =>
          ExactContrastRow(
            semanticsId: id,
            text: 'x',
            classification: cls,
            reason: reason,
          );
      final report = ExactContrastReport([
        row(1, 'UNDECIDED', 'Shader mask'),
        row(2, 'UNDECIDED', 'Shader mask'),
        row(2, 'PASS'),
        row(3, 'UNDECIDED', 'Opacity below 1'),
      ]);
      expect(report.maskedNodes, {1});
      expect(report.provenNodes, isEmpty);
    },
  );

  test('retainedSdkContrast keeps unproven nodes and unparsed text', () {
    const reason =
        'SemanticsNode#18(Rect.fromLTRB(0.0, 0.0, 1.0, 1.0), label: "a", '
        'textDirection: ltr):\n'
        'Expected contrast ratio of at least 4.5 but found 1.30 for a font '
        'size of 12.0.\n\n\n'
        'SemanticsNode#20(Rect.fromLTRB(0.0, 0.0, 1.0, 1.0), label: "b", '
        'textDirection: ltr):\n'
        'Expected contrast ratio of at least 4.5 but found 2.10 for a font '
        'size of 12.0.';
    expect(sdkContrastBlocks(reason).keys, [18, 20]);
    final kept = retainedSdkContrast(reason, {18})!;
    expect(kept, contains('SemanticsNode#20'));
    expect(kept, isNot(contains('SemanticsNode#18')));
    expect(retainedSdkContrast(reason, {18, 20}), isNull);
    expect(
      retainedSdkContrast(reason, {}),
      sdkContrastBlocks(reason).values.expand((b) => b).join('\n\n'),
    );
    expect(retainedSdkContrast('unparsed text', {1}), 'unparsed text');
  });

  test('retainedSdkContrast preserves a prefix before parsed SDK blocks', () {
    const reason =
        'Unrecognized SDK summary\n'
        'SemanticsNode#18(Rect.fromLTRB(0.0, 0.0, 1.0, 1.0), label: "a", '
        'textDirection: ltr):\n'
        'Expected contrast ratio of at least 4.5 but found 1.30 for a font '
        'size of 12.0.';
    final retained = retainedSdkContrast(reason, {18});
    expect(retained, 'Unrecognized SDK summary');
    expect(
      retainedSdkContrast(reason, {}),
      contains('Unrecognized SDK summary\n\nSemanticsNode#18'),
    );
  });
}
