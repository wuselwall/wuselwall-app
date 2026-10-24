import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_info.dart';

import '../support/fake_school.dart';
import '../support/fakes.dart';

final de = lookupAppLocalizations(const Locale('de'));

/// The app configured for a server that announces [features] (and maybe its release).
AppConfig serverConfig({List<String> features = const [], String? release}) {
  final server = ServerInfo(
    supabaseUrl: Uri.parse('https://family.example.org'),
    publishableKey: 'sb_publishable_abc',
    apiVersion: 1,
    minAppVersion: '1.0.0',
    features: features,
    serverVersion: release,
  );
  return AppConfig.forServer(
    const AppConfig(
      environment: 'test',
      supabaseUrl: 'http://localhost',
      supabasePublishableKey: 'key',
    ),
    server,
  );
}

Future<void> _openImportMenu(WidgetTester t, AppConfig config) async {
  final school = FakeSchoolRepository(
    data: referenceSchoolData(withTimetable: false),
  );
  await pumpApp(
    t,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device()),
      appConfig: config,
    ),
    school: school,
  );
  await t.tap(find.text(de.scheduleTitle));
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(OutlinedButton, de.schoolImportAction));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'a server without the scan greys the photo way out and says why',
    (t) async {
      await _openImportMenu(t, serverConfig(features: ['school']));

      final photo = find.byKey(const ValueKey('import-way-photo'));
      expect(t.widget<ListTile>(photo).enabled, isFalse);
      expect(find.text(de.schoolImportPhotoUnavailable), findsOneWidget);
      // The text way still works.
      expect(
        t
            .widget<ListTile>(find.byKey(const ValueKey('import-way-text')))
            .enabled,
        isTrue,
      );
    },
  );

  testWidgets('a server that announces the scan offers it', (t) async {
    await _openImportMenu(
      t,
      serverConfig(features: ['school', 'timetable-scan']),
    );
    final photo = find.byKey(const ValueKey('import-way-photo'));
    expect(t.widget<ListTile>(photo).enabled, isTrue);
    expect(find.text(de.schoolImportPhotoUnavailable), findsNothing);
  });

  testWidgets('settings show the app, the server release and the API', (
    t,
  ) async {
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
        appConfig: serverConfig(release: '0.3.0'),
      ),
    );
    container.read(routerProvider).go(Routes.settingsHelp);
    await t.pumpAndSettle();
    final tile = find.byKey(const ValueKey('settings-versions'));
    await t.scrollUntilVisible(tile, 200);
    expect(
      find.descendant(
        of: tile,
        matching: find.text(de.settingsVersionsLine('1.1.0', '0.3.0', '1')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a server from before 0.3.0 shows its release as unknown', (
    t,
  ) async {
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
        appConfig: serverConfig(),
      ),
    );
    container.read(routerProvider).go(Routes.settingsHelp);
    await t.pumpAndSettle();
    final tile = find.byKey(const ValueKey('settings-versions'));
    await t.scrollUntilVisible(tile, 200);
    expect(
      find.descendant(
        of: tile,
        matching: find.text(
          de.settingsVersionsLine('1.1.0', de.settingsVersionUnknown, '1'),
        ),
      ),
      findsOneWidget,
    );
  });
}
