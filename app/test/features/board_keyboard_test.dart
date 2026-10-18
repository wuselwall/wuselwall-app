import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';

void main() {
  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets(
      'Tab moves actual focus; ${key.keyLabel} activates that cell only',
      (t) async {
        final semantics = t.ensureSemantics();

        var settings = 0;
        var member = 0;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => settings++,
                    child: const Text('Settings'),
                  ),
                  BoardTap(
                    label: 'Member',
                    onTap: () => member++,
                    child: const SizedBox(width: 200, height: 56),
                  ),
                ],
              ),
            ),
          ),
        );
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        final node = t.getSemantics(find.byType(BoardTap));
        expect(node.flagsCollection.isFocused, Tristate.isTrue);
        final rings = t.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(BoardTap),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          rings.any(
            (w) => (w.decoration as BoxDecoration).border?.top.width == 3,
          ),
          isTrue,
        );
        await t.sendKeyEvent(key);
        await t.pump();
        expect(member, 1);
        expect(settings, 0);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'semantic focus transfers Flutter focus, semantic activation fires once',
    (t) async {
      final semantics = t.ensureSemantics();

      var first = 0;
      var second = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              BoardTap(
                label: 'First',
                onTap: () => first++,
                child: const SizedBox(width: 100, height: 56),
              ),
              BoardTap(
                label: 'Second',
                onTap: () => second++,
                child: const SizedBox(width: 100, height: 56),
              ),
            ],
          ),
        ),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final node = t.getSemantics(find.byType(BoardTap).last);
      node.owner!.performAction(node.id, SemanticsAction.focus);
      await t.pumpAndSettle();
      expect(
        t.getSemantics(find.byType(BoardTap).last).flagsCollection.isFocused,
        Tristate.isTrue,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(first, 0);
      expect(second, 1);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await t.pump();
      expect(second, 2);
      expect(find.bySemanticsLabel('Second'), findsOneWidget);
      semantics.dispose();
    },
  );
}
