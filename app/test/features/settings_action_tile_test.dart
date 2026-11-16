import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/settings/ui/action_tile.dart';

Future<void> _pump(WidgetTester t, double width, {VoidCallback? onTap}) async {
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: SettingsActionTile(
              leading: const Icon(Icons.smartphone),
              title: const Text('Kitchen tablet'),
              subtitle: const Text('Last seen today'),
              action: OutlinedButton(
                onPressed: () {},
                child: const Text('Block'),
              ),
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // A row that can be tapped is a button to a screen reader; its own action inside it is
  // a button in a button, which axe reports as nested-interactive and a screen reader
  // cannot reach.
  for (final width in [400.0, 800.0]) {
    testWidgets('the action is not inside the tappable row at $width px', (
      t,
    ) async {
      await _pump(t, width, onTap: () {});
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.byType(OutlinedButton),
        ),
        findsNothing,
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  }

  testWidgets('the action stands beside the text where there is room', (
    t,
  ) async {
    await _pump(t, 800, onTap: () {});
    final title = t.getTopLeft(find.text('Kitchen tablet'));
    final button = t.getTopLeft(find.byType(OutlinedButton));
    expect(button.dx, greaterThan(title.dx));
    expect(t.getTopRight(find.byType(OutlinedButton)).dx, 800);
  });

  testWidgets('the action stands under the text where the title starts', (
    t,
  ) async {
    await _pump(t, 400, onTap: () {});
    final title = t.getTopLeft(find.text('Kitchen tablet'));
    final button = t.getTopLeft(find.byType(OutlinedButton));
    expect(button.dx, title.dx);
    expect(
      button.dy,
      greaterThan(t.getBottomLeft(find.text('Last seen today')).dy),
    );
  });

  testWidgets('a row without action is a plain tile', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsActionTile(
            leading: Icon(Icons.smartphone),
            title: Text('Revoked tablet'),
            action: null,
          ),
        ),
      ),
    );
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
