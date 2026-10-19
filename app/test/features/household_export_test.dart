import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/household_export_providers.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/data/household_export_repository.dart';

import '../support/fakes.dart';

/// Records the export calls and answers with [result].
class FakeHouseholdExportRepository implements HouseholdExportRepository {
  FakeHouseholdExportRepository([this.result = const Ok('{}')]);

  Result<String> result;
  final actors = <String?>[];

  @override
  Future<Result<String>> export({required String? actor}) async {
    actors.add(actor);
    return result;
  }
}

void main() {
  const exportTile = ValueKey('export-data');

  Future<
    ({
      ProviderContainer container,
      FakeHouseholdExportRepository repo,
      List<({String fileName, Uint8List bytes})> shares,
    })
  >
  pumpSettings(
    WidgetTester t, {
    required DeviceInfo device,
    Result<String> result = const Ok('{"format": "wuselwall-export"}'),
  }) async {
    final repo = FakeHouseholdExportRepository(result);
    final shares = <({String fileName, Uint8List bytes})>[];
    final container = await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          settingsView: SettingsView.advanced,
          identity: FakeIdentityRepository(current: device),
        ),
        householdExportRepositoryProvider.overrideWithValue(repo),
        shareExportProvider.overrideWithValue(({
          required String fileName,
          required Uint8List bytes,
          Rect? origin,
        }) async {
          shares.add((fileName: fileName, bytes: bytes));
        }),
      ],
    );
    container.read(routerProvider).go(Routes.settings);
    await t.pumpAndSettle();
    return (container: container, repo: repo, shares: shares);
  }

  testWidgets(
    'a guardian on a personal phone sees the export with its explanation',
    (t) async {
      final s = await pumpSettings(t, device: device());
      expect(find.text('Familie'), findsOneWidget);
      expect(find.byKey(exportTile), findsOneWidget);
      expect(find.text('Daten exportieren'), findsOneWidget);
      expect(
        find.text(
          'Alle Daten eurer Familie als Datei, z. B. für einen Umzug auf einen anderen Server.',
        ),
        findsOneWidget,
      );
      await unmountApp(t, s.container);
    },
  );

  testWidgets('a child on a personal phone does not see the export', (t) async {
    final s = await pumpSettings(t, device: device(profileId: kidId));
    expect(find.byKey(exportTile), findsNothing);
    await unmountApp(t, s.container);
  });

  testWidgets('kiosk and shared devices do not see the export', (t) async {
    final kiosk = await pumpSettings(
      t,
      device: device(
        deviceClass: DeviceClass.kiosk,
        register: UiRegister.kiosk,
      ),
    );
    expect(find.byKey(exportTile), findsNothing);
    await unmountApp(t, kiosk.container);

    final shared = await pumpSettings(
      t,
      device: device(deviceClass: DeviceClass.shared, register: UiRegister.kid),
    );
    expect(find.byKey(exportTile), findsNothing);
    await unmountApp(t, shared.container);
  });

  testWidgets(
    'tapping exports through the repository and hands over a dated JSON file',
    (t) async {
      final s = await pumpSettings(t, device: device());
      await t.tap(find.byKey(exportTile));
      await t.pumpAndSettle();

      expect(s.repo.actors, [guardianId]);
      expect(s.shares, hasLength(1));
      final share = s.shares.single;
      expect(
        share.fileName,
        matches(RegExp(r'^wuselwall-export-\d{4}-\d{2}-\d{2}\.json$')),
      );
      expect(jsonDecode(utf8.decode(share.bytes)), {
        'format': 'wuselwall-export',
      });
      await unmountApp(t, s.container);
    },
  );

  testWidgets('a refused export shows the failure and hands over no file', (
    t,
  ) async {
    final s = await pumpSettings(
      t,
      device: device(),
      result: const Err(PermissionFailure(code: 'personal_device_required')),
    );
    await t.tap(find.byKey(exportTile));
    await t.pumpAndSettle();

    expect(s.shares, isEmpty);
    expect(
      find.text('Der Export geht nur vom eigenen Telefon aus.'),
      findsOneWidget,
    );
    await unmountApp(t, s.container);
  });

  test('the file name carries the local date', () {
    expect(
      householdExportFileName(DateTime(2026, 3, 7)),
      'wuselwall-export-2026-03-07.json',
    );
  });
}
