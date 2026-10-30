import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/ui/whole_words_text.dart';

/// Like Android 14's font scaling: small fonts grow by more than large ones, so
/// halving the font does not halve the drawn width.
class _NonLinear extends TextScaler {
  const _NonLinear();

  @override
  double scale(double fontSize) => fontSize * 1.3 + 4;

  @override
  double get textScaleFactor => 1.3;
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('AtkinsonHyperlegibleNext');
    for (final weight in ['Regular', 'Bold']) {
      loader.addFont(
        rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$weight.ttf'),
      );
    }
    await loader.load();
  });

  Future<RenderParagraph> pump(
    WidgetTester tester,
    String text, {
    TextScaler scaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'AtkinsonHyperlegibleNext',
              fontSize: 22,
            ),
            child: Center(
              child: SizedBox(width: 120, child: WholeWordsText(text)),
            ),
          ),
        ),
      ),
    );
    return tester.renderObject<RenderParagraph>(find.byType(RichText));
  }

  void expectWholeWords(RenderParagraph p, String text) {
    var start = 0;
    for (final word in text.split(' ')) {
      final boxes = p.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + word.length),
      );
      expect(
        {for (final b in boxes) b.top.round()},
        hasLength(1),
        reason: '"$word" breaks',
      );
      start += word.length + 1;
    }
  }

  testWidgets('a word too long for the width shrinks instead of breaking', (
    tester,
  ) async {
    const text = 'Fünfundzwanzig Aufgaben';
    expectWholeWords(await pump(tester, text), text);
  });

  testWidgets('also under a non-linear text scale (Android 14)', (
    tester,
  ) async {
    const text = 'Naturwissenschaften';
    expectWholeWords(
      await pump(tester, text, scaler: const _NonLinear()),
      text,
    );
  });

  testWidgets('words that fit keep their size', (tester) async {
    final p = await pump(tester, 'Mathe');
    expect(p.text.style?.fontSize, 22);
  });
}
