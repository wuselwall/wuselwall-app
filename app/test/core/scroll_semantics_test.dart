import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// What the app can and cannot say about a scrollable's own semantics node, the one
// iOS shows as `FlutterSemanticsScrollView`. Apple's accessibility audit reports that
// element as "has no description" (qualification/native/README.md, "Unnamed scroll
// views on iOS"). These tests pin the framework behaviour that finding rests on: if
// one fails after a Flutter upgrade, the framework has changed, and the finding and
// its review are to be looked at again.

/// The nodes below the root in tree order, with their depth.
List<(int, SemanticsData)> _nodes(WidgetTester t) {
  final found = <(int, SemanticsData)>[];
  void visit(SemanticsNode node, int depth) {
    found.add((depth, node.getSemanticsData()));
    node.visitChildren((child) {
      visit(child, depth + 1);
      return true;
    });
  }

  visit(
    t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
    0,
  );
  return found;
}

Widget _rows() => Column(
  children: [
    for (var i = 0; i < 40; i++)
      ListTile(title: Text('Zeile $i'), onTap: () {}),
  ],
);

void main() {
  testWidgets(
    'a label around a scrollable names a parent, not the scroll node',
    (t) async {
      final handle = t.ensureSemantics();
      for (final container in [false, true]) {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Semantics(
                label: 'Einkaufsliste',
                container: container,
                child: ListView(children: [_rows()]),
              ),
            ),
          ),
        );
        final nodes = _nodes(t);
        final scroll = nodes.singleWhere(
          (n) => n.$2.flagsCollection.hasImplicitScrolling,
        );
        final named = nodes.singleWhere((n) => n.$2.label == 'Einkaufsliste');
        expect(scroll.$2.label, isEmpty);
        expect(scroll.$2.tooltip, isEmpty);
        expect(
          named.$1,
          lessThan(scroll.$1),
          reason: 'the label is an ancestor',
        );
      }
      handle.dispose();
    },
  );

  testWidgets(
    'a label inside a scrollable names a child, not the scroll node',
    (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Semantics(label: 'Einkaufsliste', child: _rows()),
            ),
          ),
        ),
      );
      final nodes = _nodes(t);
      final scroll = nodes.singleWhere(
        (n) => n.$2.flagsCollection.hasImplicitScrolling,
      );
      final named = nodes.singleWhere((n) => n.$2.label == 'Einkaufsliste');
      expect(scroll.$2.label, isEmpty);
      expect(named.$1, greaterThan(scroll.$1), reason: 'the label is a child');
      handle.dispose();
    },
  );
}
