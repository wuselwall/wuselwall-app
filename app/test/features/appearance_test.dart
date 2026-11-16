import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/appearance.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/ui/look_chooser.dart';

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

    test(
      'the themes are the standard ones, not yet offered, until kept',
      () async {
        final store = SecureAppearanceStore();
        expect(await store.readLooks(), const Looks());
        await store.writeLooks(const Looks().choosing(Look.pflaume));
        expect(
          await SecureAppearanceStore().readLooks(),
          const Looks(dark: Look.pflaume, asked: true),
        );
      },
    );

    test(
      'a theme this app does not know falls back to the standard one',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'wuselwall.appearance.look_light': 'kakao',
          'wuselwall.appearance.look_dark': 'teal',
          'wuselwall.appearance.look_asked': '1',
        });
        expect(
          await SecureAppearanceStore().readLooks(),
          const Looks(asked: true),
        );
      },
    );
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
      // The tile names the appearance and the themes that can be on screen.
      expect(find.text('Automatisch · Frisch, Blaue Stunde'), findsOneWidget);
    });

    testWidgets('choosing dark applies at once and is kept', (t) async {
      final store = MemoryAppearanceStore();
      await openSettings(t, store: store);

      await t.tap(find.text('Darstellung'));
      await t.pumpAndSettle();
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      await t.tap(find.text('Dunkel'));
      await t.pumpAndSettle();

      // The sheet stays, so the themes can be chosen too; it is its own preview.
      expect(find.byType(LookChooser), findsOneWidget);
      expect(_appMode(t), ThemeMode.dark);
      expect(
        Theme.of(t.element(find.byType(LookChooser))).brightness,
        Brightness.dark,
      );
      expect(store.mode, ThemeMode.dark);
      await t.tap(find.text('Fertig'));
      await t.pumpAndSettle();
      expect(find.byType(LookChooser), findsNothing);
      // The tile names the choice: only the dark theme can be on screen now.
      expect(find.text('Dunkel · Blaue Stunde'), findsOneWidget);
    });

    testWidgets('choosing a theme applies at once and is kept', (t) async {
      final store = MemoryAppearanceStore(ThemeMode.dark);
      await openSettings(t, store: store);
      await t.tap(find.text('Darstellung'));
      await t.pumpAndSettle();

      // Two light themes and four dark ones, each a button that says its state.
      for (final look in Look.values.where((l) => l != Look.night)) {
        expect(find.byKey(ValueKey('look-${look.name}')), findsOneWidget);
      }
      expect(
        t.getSemantics(find.bySemanticsLabel('Blaue Stunde')),
        isSemantics(isButton: true, isSelected: true, hasSelectedState: true),
      );

      await t.tap(find.byKey(const ValueKey('look-kakao')));
      await t.pumpAndSettle();
      expect(store.looks.dark, Look.kakao);
      expect(store.looks.light, Look.frisch);
      // The sheet and the page behind it both show the new ground.
      final context = t.element(find.byType(LookChooser));
      expect(context.ww.look, Look.kakao);
      expect(
        Theme.of(t.element(find.text('Darstellung').first))
            .scaffoldBackgroundColor,
        Palette.kakao.bg,
      );
      expect(
        t.getSemantics(find.bySemanticsLabel('Kakao')),
        isSemantics(isButton: true, isSelected: true, hasSelectedState: true),
      );

      // A light theme is kept for when the device shows light.
      await t.tap(find.byKey(const ValueKey('look-sonnig')));
      await t.pumpAndSettle();
      expect(store.looks.light, Look.sonnig);
      expect(context.ww.look, Look.kakao);
    });

    testWidgets('a saved choice applies at start', (t) async {
      await openSettings(
        t,
        store: MemoryAppearanceStore(
          ThemeMode.light,
          const Looks(light: Look.sonnig, asked: true),
        ),
      );
      expect(_appMode(t), ThemeMode.light);
      expect(find.text('Hell · Sonnig'), findsOneWidget);
      expect(
        Theme.of(t.element(find.text('Darstellung'))).scaffoldBackgroundColor,
        Palette.sonnig.bg,
      );
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

  group('the first look (specs/20)', () {
    Future<ProviderContainer> arrive(
      WidgetTester t, {
      required MemoryAppearanceStore store,
      DeviceInfo? current,
    }) async {
      final container = await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: current ?? device()),
            appearance: store,
          ),
          pendingFirstRunProvider.overrideWith((ref) async => null),
        ],
      );
      await t.pumpAndSettle();
      return container;
    }

    testWidgets('a personal device is offered its colours once, at home', (
      t,
    ) async {
      final store = MemoryAppearanceStore(ThemeMode.system, const Looks());
      final container = await arrive(t, store: store);

      expect(find.text('Wie soll WuselWall aussehen?'), findsOneWidget);
      // Offered counts, whatever happens to the sheet.
      expect(store.looks.asked, isTrue);

      await t.tap(find.byKey(const ValueKey('look-sonnig')));
      await t.pumpAndSettle();
      expect(store.looks.light, Look.sonnig);
      await t.tap(find.text('Fertig'));
      await t.pumpAndSettle();
      expect(find.text('Wie soll WuselWall aussehen?'), findsNothing);

      // Leaving home and coming back does not ask again.
      container.read(routerProvider).go(Routes.settingsDevices);
      await t.pumpAndSettle();
      container.read(routerProvider).go(Routes.home);
      await t.pumpAndSettle();
      expect(find.text('Wie soll WuselWall aussehen?'), findsNothing);
    });

    testWidgets('a device that was asked before is left alone', (t) async {
      await arrive(t, store: MemoryAppearanceStore());
      expect(find.text('Wie soll WuselWall aussehen?'), findsNothing);
    });

    testWidgets('a shared tablet and the wall are not asked', (t) async {
      for (final current in [
        device(deviceClass: DeviceClass.shared, register: UiRegister.adult),
        device(deviceClass: DeviceClass.kiosk, register: UiRegister.kiosk),
      ]) {
        final store = MemoryAppearanceStore(ThemeMode.system, const Looks());
        final container = await arrive(t, store: store, current: current);
        expect(
          find.text('Wie soll WuselWall aussehen?'),
          findsNothing,
          reason: current.deviceClass.name,
        );
        expect(store.looks.asked, isFalse);
        await unmountApp(t, container);
      }
    });
  });
}
