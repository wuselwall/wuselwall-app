import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/app_language.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

import '../support/fakes.dart';

Locale? _appLocale(WidgetTester t) =>
    t.widget<MaterialApp>(find.byType(MaterialApp)).locale;

/// The locale the screens are drawn in.
Locale _shown(WidgetTester t) =>
    Localizations.localeOf(t.element(find.byType(Scaffold).first));

/// A household whose region is [region] ("CH-ZH").
class _Region implements HouseholdSettingsRepository {
  _Region(this.region);

  final String region;

  @override
  Future<Result<List<SettingEntry>>> all() async => Ok([
    SettingEntry(
      key: 'household.region',
      scope: SettingScope.household,
      type: SettingType.region,
      constraints: const {},
      selfService: false,
      defaultValue: null,
      value: region,
      isDefault: false,
    ),
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

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

    test('a German variant is kept as its tag', () async {
      await SecureAppLanguageStore().write(const Locale('de', 'CH'));
      expect(await SecureAppLanguageStore().read(), const Locale('de', 'CH'));
    });

    test('plain German from before the variants still reads', () async {
      FlutterSecureStorage.setMockInitialValues({'wuselwall.language': 'de'});
      expect(await SecureAppLanguageStore().read(), const Locale('de'));
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
      String? region,
    }) async {
      final container = await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            language: store,
          ),
          pendingFirstRunProvider.overrideWith((ref) async => null),
          if (region != null)
            householdSettingsRepositoryProvider.overrideWithValue(
              _Region(region),
            ),
        ],
      );
      container.read(routerProvider).go(Routes.settingsDevices);
      await t.pumpAndSettle();
      return container;
    }

    testWidgets('the app follows the device by default', (t) async {
      await openSettings(t, store: MemoryAppLanguageStore());
      expect(_shown(t), const Locale('de'));
      expect(find.widgetWithText(ListTile, 'Sprache'), findsOneWidget);
      expect(find.text('Automatisch: Deutsch (Deutschland)'), findsOneWidget);
    });

    testWidgets('choosing English applies at once and is kept', (t) async {
      final store = MemoryAppLanguageStore();
      await openSettings(t, store: store);

      await t.tap(find.text('Sprache'));
      await t.pumpAndSettle();
      // The device's language, German's three variants and the other three languages,
      // each in its own name.
      expect(find.byType(RadioListTile<String>), findsNWidgets(7));
      await t.tap(find.text('English'));
      await t.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(_appLocale(t), const Locale('en'));
      expect(store.locale, const Locale('en'));
      // The whole screen switches: the tile and the page title.
      expect(find.widgetWithText(ListTile, 'Language'), findsOneWidget);
      expect(find.text('Sprache'), findsNothing);
      expect(find.text('Devices'), findsOneWidget);
    });

    testWidgets('a saved choice applies at start', (t) async {
      await openSettings(t, store: MemoryAppLanguageStore(const Locale('es')));
      expect(_appLocale(t), const Locale('es'));
      expect(find.widgetWithText(ListTile, 'Idioma'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
    });

    testWidgets("German follows the family's country", (t) async {
      await openSettings(t, store: MemoryAppLanguageStore(), region: 'CH-ZH');
      expect(_shown(t), const Locale('de', 'CH'));
      expect(find.text('Automatisch: Deutsch (Schweiz)'), findsOneWidget);
    });

    testWidgets("a person's own German beats the family's country", (t) async {
      final store = MemoryAppLanguageStore();
      await openSettings(t, store: store, region: 'CH-ZH');
      await t.tap(find.text('Sprache'));
      await t.pumpAndSettle();
      await t.tap(find.text('Deutsch (Deutschland)'));
      await t.pumpAndSettle();
      expect(store.locale, const Locale('de', 'DE'));
      expect(_shown(t), const Locale('de'));
      expect(find.text('Deutsch (Deutschland)'), findsOneWidget);
    });

    testWidgets('an Austrian family reads Austrian German', (t) async {
      await openSettings(t, store: MemoryAppLanguageStore(), region: 'AT-9');
      expect(_shown(t), const Locale('de', 'AT'));
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
      expect(_shown(t), const Locale('de'));
      // The test device speaks German.
      expect(find.text('Automatisch: Deutsch (Deutschland)'), findsOneWidget);
    });
  });
}
