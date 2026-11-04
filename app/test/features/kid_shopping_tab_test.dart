import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';

import '../support/fakes.dart';

/// The family's settings, which a test may change while the app runs.
class _Settings implements HouseholdSettingsRepository {
  _Settings(this.rows);

  List<SettingEntry>? rows;

  @override
  Future<Result<List<SettingEntry>>> all() async {
    final rows = this.rows;
    return rows == null ? const Err(NetworkFailure()) : Ok(List.of(rows));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The demo catalogue, with the family's switch at [value].
List<SettingEntry> _catalogue({required bool value}) => [
  for (final e in demoSettingCatalogue())
    if (e.key == 'household.kid_shopping')
      SettingEntry(
        key: e.key,
        scope: e.scope,
        type: e.type,
        constraints: e.constraints,
        selfService: e.selfService,
        defaultValue: e.defaultValue,
        value: value,
        isDefault: !value,
      )
    else
      e,
];

void main() {
  Future<(_Settings, ProviderContainer)> pumpKid(
    WidgetTester t,
    List<SettingEntry>? rows,
  ) async {
    final settings = _Settings(rows);
    final container = await pumpApp(
      t,
      size: const Size(820, 1180),
      overrides: [
        ...baseOverrides(
          identity: FakeIdentityRepository(
            current: device(profileId: kidId, register: UiRegister.kid),
          ),
        ),
        householdSettingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    await t.pumpAndSettle();
    return (settings, container);
  }

  // The tooltip holds the label as written; the visible one may be shortened to fit.
  List<String?> tabLabels(WidgetTester t) => [
    for (final d in t.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    ))
      d.tooltip,
  ];

  Future<void> openTab(WidgetTester t, String label) async {
    await t.tap(
      find.byWidgetPredicate(
        (w) => w is NavigationDestination && w.tooltip == label,
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('a new family has four tabs and no Shopping', (t) async {
    final (_, container) = await pumpKid(t, demoSettingCatalogue());
    expect(tabLabels(t), ['Mein Tag', 'Stundenplan', 'Punkte', 'Familie']);
    expect(find.byType(ShoppingBody), findsNothing);

    // The bar's index follows the tabs that are there, not the enum's.
    await openTab(t, 'Familie');
    final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 3);
    expect(find.byType(ShoppingBody), findsNothing);
    await unmountApp(t, container);
  });

  testWidgets('with the switch on the fifth tab opens the shopping list', (
    t,
  ) async {
    final (_, container) = await pumpKid(t, _catalogue(value: true));
    expect(tabLabels(t), [
      'Mein Tag',
      'Stundenplan',
      'Punkte',
      'Einkaufen',
      'Familie',
    ]);

    await openTab(t, 'Einkaufen');
    expect(find.byType(ShoppingBody), findsOneWidget);
    await unmountApp(t, container);
  });

  testWidgets('switched off on the tab itself, the child is back on Mein Tag', (
    t,
  ) async {
    final (settings, container) = await pumpKid(t, _catalogue(value: true));
    await openTab(t, 'Einkaufen');

    settings.rows = _catalogue(value: false);
    container.invalidate(householdSettingsProvider);
    await t.pumpAndSettle();

    expect(find.byType(ShoppingBody), findsNothing);
    final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    await unmountApp(t, container);
  });

  testWidgets('a server older than the switch keeps the tab', (t) async {
    final (_, container) = await pumpKid(t, [
      for (final e in demoSettingCatalogue())
        if (e.key != 'household.kid_shopping') e,
    ]);
    expect(tabLabels(t), contains('Einkaufen'));
    await unmountApp(t, container);
  });

  testWidgets('settings that cannot be read keep the tab', (t) async {
    final (_, container) = await pumpKid(t, null);
    expect(tabLabels(t), contains('Einkaufen'));
    await unmountApp(t, container);
  });
}
