import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/appearance.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

import '../support/fakes.dart';

ThemeMode _appMode(WidgetTester t) =>
    t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  group('SecureAppearanceStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('follows the OS until a choice is saved', () async {
      final store = SecureAppearanceStore();
      expect(await store.read(), ThemeMode.system);
      await store.write(ThemeMode.dark);
      expect(await SecureAppearanceStore().read(), ThemeMode.dark);
    });

    test('an unknown stored value falls back to the OS', () async {
      FlutterSecureStorage.setMockInitialValues({
        'wuselwall.appearance.theme_mode': 'sepia',
      });
      expect(await SecureAppearanceStore().read(), ThemeMode.system);
    });
  });

  group('the appearance in Settings', () {
    Future<ProviderContainer> openSettings(
      WidgetTester t, {
      required AppearanceStore store,
      DeviceInfo? current,
      String? acting,
    }) async {
      final container = await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: current ?? device()),
            appearance: store,
          ),
          // The wall's one-time checklist would stand in front of the settings.
          pendingFirstRunProvider.overrideWith((ref) async => null),
        ],
      );
      if (acting != null) {
        container.read(actingProfileProvider.notifier).select(acting);
      }
      container.read(routerProvider).go(Routes.settingsDevices);
      await t.pumpAndSettle();
      return container;
    }

    testWidgets('the app follows the OS by default', (t) async {
      await openSettings(t, store: MemoryAppearanceStore());
      expect(_appMode(t), ThemeMode.system);
      expect(find.widgetWithText(ListTile, 'Darstellung'), findsOneWidget);
      expect(find.text('Automatisch'), findsOneWidget);
    });

    testWidgets('choosing dark applies at once and is kept', (t) async {
      final store = MemoryAppearanceStore();
      await openSettings(t, store: store);

      await t.tap(find.text('Darstellung'));
      await t.pumpAndSettle();
      expect(find.byType(RadioListTile<ThemeMode>), findsNWidgets(3));
      await t.tap(find.text('Dunkel'));
      await t.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(_appMode(t), ThemeMode.dark);
      expect(
        Theme.of(t.element(find.text('Darstellung'))).brightness,
        Brightness.dark,
      );
      expect(store.mode, ThemeMode.dark);
      // The tile names the choice.
      expect(find.text('Dunkel'), findsOneWidget);
    });

    testWidgets('a saved choice applies at start', (t) async {
      await openSettings(t, store: MemoryAppearanceStore(ThemeMode.light));
      expect(_appMode(t), ThemeMode.light);
      expect(find.text('Hell'), findsOneWidget);
    });

    testWidgets('the wall display says that night wins', (t) async {
      final container = await openSettings(
        t,
        store: MemoryAppearanceStore(),
        current: device(
          deviceClass: DeviceClass.kiosk,
          register: UiRegister.kiosk,
        ),
        // The wall opens settings for whoever picked themselves.
        acting: guardianId,
      );
      final tile = find.text('Darstellung');
      await t.ensureVisible(tile);
      await t.pumpAndSettle();
      await t.tap(tile);
      await t.pumpAndSettle();
      expect(
        find.text('Nachts zeigt das Wanddisplay immer seine Nachtansicht.'),
        findsOneWidget,
      );
      await unmountApp(t, container);
    });
  });
}
