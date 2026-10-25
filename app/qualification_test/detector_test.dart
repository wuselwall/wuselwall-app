// Prove the checks can fail before accepting a green matrix as evidence.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('AtkinsonHyperlegibleNext')
      ..addFont(
        rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf'),
      );
    await font.load();
  });
  testWidgets(
    'the contrast detector rejects known low-contrast rendered text',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        await t.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Text(
                  'Known contrast failure',
                  style: TextStyle(
                    fontFamily: 'AtkinsonHyperlegibleNext',
                    color: Color(0xffdddddd),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        );
        expect((await textContrastGuideline.evaluate(t)).passed, isFalse);
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'the target and label detectors reject an unlabeled small action',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Semantics(
                  onTap: () {},
                  button: true,
                  child: const SizedBox(width: 16, height: 16),
                ),
              ),
            ),
          ),
        );
        expect((await androidTapTargetGuideline.evaluate(t)).passed, isFalse);
        expect((await iOSTapTargetGuideline.evaluate(t)).passed, isFalse);
        expect((await labeledTapTargetGuideline.evaluate(t)).passed, isFalse);
      } finally {
        semantics.dispose();
      }
    },
  );
}
