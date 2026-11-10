import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/home/ui/register_home_page.dart';

import '../support/fakes.dart';

void main() {
  for (final language in ['de', 'en', 'fr', 'es']) {
    testWidgets(
      'rail at 840px keeps every tab and Settings Back in $language',
      (t) async {
        final l10n = lookupAppLocalizations(Locale(language));
        final container = await pumpApp(
          t,
          size: const Size(839, 900),
          locale: Locale(language),
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
        );
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        await openTab(t, l10n.calendarTitle);
        t.view.physicalSize = const Size(840, 900);
        await t.pumpAndSettle();
        expect(find.byType(NavigationBar), findsNothing);
        expect(
          t.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
          HomeTab.calendar.index,
        );
        for (final tab in HomeTab.values) {
          await openTab(
            t,
            (homeSections[tab]!.navLabel ?? homeSections[tab]!.label)(l10n),
          );
          expect(container.read(homeTabProvider), tab);
        }
        // The last tab remains Shopping through both return paths and a width change.
        for (final systemBack in [true, false]) {
          await t.tap(find.byTooltip(l10n.settingsTitle));
          await t.pumpAndSettle();
          if (systemBack) {
            await t.binding.handlePopRoute();
          } else {
            await t.tap(find.byType(BackButton));
          }
          await t.pumpAndSettle();
          expect(selectedHomeDestination(t), HomeTab.shopping.index);
        }
        t.view.physicalSize = const Size(390, 844);
        await t.pumpAndSettle();
        expect(
          t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          HomeTab.shopping.index,
        );
        expect(t.takeException(), isNull);
        await unmountApp(t, container);
      },
    );

    testWidgets('rail scrolls in a short window with large $language text', (
      t,
    ) async {
      final container = await pumpApp(
        t,
        size: const Size(1024, 400),
        locale: Locale(language),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      final l10n = lookupAppLocalizations(Locale(language));
      await openTab(t, l10n.shoppingNavLabel);
      expect(selectedHomeDestination(t), HomeTab.shopping.index);
      await openTab(t, l10n.todayTitle);
      expect(selectedHomeDestination(t), HomeTab.today.index);
      expect(t.takeException(), isNull);
      await unmountApp(t, container);
    });
  }
}
