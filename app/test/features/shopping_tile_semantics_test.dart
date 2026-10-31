import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart' show appLocales, localizationsDelegates;
import 'package:wuselwall/features/shopping/ui/shopping_widgets.dart';

/// A catalogue tile that is already on the list (or pinned) says so in a hint. The
/// hint must sit on the tile's own labelled, tappable node: on its own node it is an
/// element without a name, which iOS's accessibility audit rejects and VoiceOver
/// reads as nothing but the hint.
void main() {
  Future<void> pumpTile(
    WidgetTester t, {
    required int count,
    bool pinned = false,
  }) => t.pumpWidget(
    MaterialApp(
      locale: const Locale('de'),
      supportedLocales: appLocales,
      localizationsDelegates: localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: ShoppingTile(
            width: 115,
            picture: const Icon(Icons.local_drink),
            label: 'Milch',
            count: count,
            pinned: pinned,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    ),
  );

  /// Every node a screen reader can land on: one with a hint or an action.
  List<SemanticsData> actionable(WidgetTester t) {
    final found = <SemanticsData>[];
    bool visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      if (!node.isMergedIntoParent &&
          (data.hint.isNotEmpty || data.actions != 0)) {
        found.add(data);
      }
      node.visitChildren(visit);
      return true;
    }

    visit(t.getSemantics(find.byType(Scaffold)));
    return found;
  }

  for (final (count, pinned, hint) in [
    (1, false, 'Schon auf der Liste'),
    (2, false, 'Schon auf der Liste'),
    (0, true, 'Angeheftet'),
    (1, true, 'Angeheftet, Schon auf der Liste'),
  ]) {
    testWidgets(
      'count $count, pinned $pinned: one labelled node carries "$hint"',
      (t) async {
        final semantics = t.ensureSemantics();
        await pumpTile(t, count: count, pinned: pinned);

        final nodes = actionable(t);
        expect(
          nodes,
          hasLength(1),
          reason: 'the hint must not form a node of its own',
        );
        final tile = nodes.single;
        expect(tile.label, contains('Milch'));
        expect(tile.hint, hint);
        expect(tile.hasAction(SemanticsAction.tap), isTrue);
        expect(tile.hasAction(SemanticsAction.longPress), isTrue);
        semantics.dispose();
      },
    );
  }

  testWidgets('a tile not on the list stays a single labelled node', (t) async {
    final semantics = t.ensureSemantics();
    await pumpTile(t, count: 0);
    final nodes = actionable(t);
    expect(nodes, hasLength(1));
    expect(nodes.single.label, 'Milch');
    expect(nodes.single.hint, isEmpty);
    semantics.dispose();
  });
}
