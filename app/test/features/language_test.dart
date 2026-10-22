import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/l10n/app_language.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';

import '../support/fakes.dart';

Locale? _appLocale(WidgetTester t) =>
    t.widget<MaterialApp>(find.byType(MaterialApp)).locale;

void main() {
  group('SecureAppLanguageStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('follows the device until a choice is saved', () async {
      final store = SecureAppLanguageStore();
      expect(await store.read(), isNull);
      await store.write(const Locale('fr'));
      expect(await SecureAppLanguageStore().read(), const Locale('fr'));
      await store.write(null);
      expect(await SecureAppLanguageStore().read(), isNull);
    });

    test('a language the app does not ship falls back to the device', () async {
      FlutterSecureStorage.setMockInitialValues({'wuselwall.language': 'it'});
      expect(await SecureAppLanguageStore().read(), isNull);
    });
  });

  group('the language in Settings', () {
    Future<ProviderContainer> openSettings(
      WidgetTester t, {
      required AppLanguageStore store,
    }) async {
      final container = await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            language: store,
          ),
          pendingFirstRunProvider.overrideWith((ref) async => null),
        ],
      );
      container.read(routerProvider).go(Routes.settings);
      await t.pumpAndSettle();
      return container;
    }

    testWidgets('the app follows the device by default', (t) async {
      await openSettings(t, store: MemoryAppLanguageStore());
      expect(_appLocale(t), isNull);
      expect(find.widgetWithText(ListTile, 'Sprache'), findsOneWidget);
      expect(find.text('Automatisch: Deutsch'), findsOneWidget);
    });

    testWidgets('choosing English applies at once and is kept', (t) async {
      final store = MemoryAppLanguageStore();
      await openSettings(t, store: store);

      await t.tap(find.text('Sprache'));
      await t.pumpAndSettle();
      // The device's language and the four the app ships, each in its own name.
      expect(find.byType(RadioListTile<String>), findsNWidgets(5));
      await t.tap(find.text('English'));
      await t.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(_appLocale(t), const Locale('en'));
      expect(store.locale, const Locale('en'));
      // The whole screen switches: the tile and the page title.
      expect(find.widgetWithText(ListTile, 'Language'), findsOneWidget);
      expect(find.text('Sprache'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('a saved choice applies at start', (t) async {
      await openSettings(t, store: MemoryAppLanguageStore(const Locale('es')));
      expect(_appLocale(t), const Locale('es'));
      expect(find.widgetWithText(ListTile, 'Idioma'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
    });

    testWidgets('back to the device language', (t) async {
      final store = MemoryAppLanguageStore(const Locale('en'));
      await openSettings(t, store: store);
      await t.tap(find.text('Language'));
      await t.pumpAndSettle();
      // The appearance tile behind the dialog reads "Automatic" too.
      await t.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Automatic'),
        ),
      );
      await t.pumpAndSettle();
      expect(store.locale, isNull);
      expect(_appLocale(t), isNull);
      // The test device speaks German.
      expect(find.text('Automatisch: Deutsch'), findsOneWidget);
    });
  });
}
