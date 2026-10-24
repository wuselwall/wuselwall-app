import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/core/ui/module_band.dart';

import '../support/fakes.dart';

Future<void> _home(WidgetTester t, Size size) async {
  await pumpApp(
    t,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device()),
      shopping: FakeShoppingRepository([item('1', 'Milch')]),
    ),
    size: size,
  );
}

Finder _picture(AppModule module) =>
    find.byKey(ValueKey('module-illustration-${module.name}'));

/// specs/26 "Module bands": each module's picture in its band, where it has room.
void main() {
  testWidgets('on a wide screen every module but Today has its picture', (
    t,
  ) async {
    await _home(t, const Size(1000, 1600));
    for (final (tab, module) in [
      ('Einkauf', AppModule.shopping),
      ('Aufgaben', AppModule.tasks),
      ('Kalender', AppModule.calendar),
      ('Essen', AppModule.meals),
      ('Stundenplan', AppModule.schedule),
    ]) {
      await t.tap(find.text(tab).last);
      await t.pumpAndSettle();
      expect(_picture(module), findsOneWidget, reason: tab);
    }
    await t.tap(find.text('Heute').last);
    await t.pumpAndSettle();
    expect(find.byType(ModuleIllustration), findsNothing);
  });

  testWidgets('a narrow phone keeps the toolbars free of it', (t) async {
    await _home(t, const Size(320, 640));
    // The calendar's bar is its toolbar on a phone.
    await t.tap(find.byTooltip('Kalender').last);
    await t.pumpAndSettle();
    expect(_picture(AppModule.calendar), findsNothing);
  });

  testWidgets('the picture is decoration: nothing for a screen reader', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await _home(t, const Size(1000, 1600));
    await t.tap(find.text('Einkauf').last);
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ExcludeSemantics),
        matching: _picture(AppModule.shopping),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('Settings have the calm stein band and its picture', (t) async {
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );
    container.read(routerProvider).go(Routes.settings);
    await t.pumpAndSettle();
    final bar = t.widget<AppBar>(find.byType(AppBar).first);
    expect(bar.backgroundColor, ModuleBands.of(AppModule.settings).light);
    expect(_picture(AppModule.settings), findsOneWidget);
  });
}
