import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/household_export_providers.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/data/household_export_repository.dart';

import '../support/fakes.dart';

/// Records the export calls and answers with [result].
class FakeHouseholdExportRepository implements HouseholdExportRepository {
  FakeHouseholdExportRepository(this.result);

  Result<HouseholdExportFile> result;
  final actors = <String?>[];

  @override
  Future<Result<HouseholdExportFile>> export({required String? actor}) async {
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
      List<({String fileName, Uint8List bytes, String mimeType})> shares,
    })
  >
  pumpSettings(
    WidgetTester t, {
    required DeviceInfo device,
    Result<HouseholdExportFile>? result,
  }) async {
    final repo = FakeHouseholdExportRepository(
      result ?? Ok(HouseholdExportFile(bytes: emptyZip, zip: true)),
    );
    final shares = <({String fileName, Uint8List bytes, String mimeType})>[];
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
          required String mimeType,
          Rect? origin,
        }) async {
          shares.add((fileName: fileName, bytes: bytes, mimeType: mimeType));
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
    'tapping exports through the repository and hands over a dated zip file',
    (t) async {
      final s = await pumpSettings(t, device: device());
      await t.tap(find.byKey(exportTile));
      await t.pumpAndSettle();

      expect(s.repo.actors, [guardianId]);
      expect(s.shares, hasLength(1));
      final share = s.shares.single;
      expect(
        share.fileName,
        matches(RegExp(r'^wuselwall-export-\d{4}-\d{2}-\d{2}\.zip$')),
      );
      expect(share.mimeType, 'application/zip');
      expect(share.bytes, emptyZip);
      await unmountApp(t, s.container);
    },
  );

  testWidgets('from an older server the export is a dated JSON file', (
    t,
  ) async {
    final s = await pumpSettings(
      t,
      device: device(),
      result: Ok(
        HouseholdExportFile(
          bytes: utf8.encode('{"format": "wuselwall-export"}'),
          zip: false,
        ),
      ),
    );
    await t.tap(find.byKey(exportTile));
    await t.pumpAndSettle();

    final share = s.shares.single;
    expect(share.fileName, endsWith('.json'));
    expect(share.mimeType, 'application/json');
    expect(jsonDecode(utf8.decode(share.bytes)), {
      'format': 'wuselwall-export',
    });
    await unmountApp(t, s.container);
  });

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

  test('the file name carries the local date and the file type', () {
    expect(
      householdExportFileName(DateTime(2026, 3, 7), 'zip'),
      'wuselwall-export-2026-03-07.zip',
    );
  });

  group('the repository', () {
    test('returns the function\'s zip file', () async {
      final api = _ExportApi(reply: Ok(emptyZipWithEntry));
      final result = await HouseholdExportRepository(api).export(actor: 'p1');
      final file = (result as Ok<HouseholdExportFile>).value;
      expect(file.zip, isTrue);
      expect(file.bytes, emptyZipWithEntry);
      expect(api.calls, ['fn:household-export {actor: p1}']);
    });

    test(
      'falls back to the one-document export on a server without the function',
      () async {
        final api = _ExportApi(
          reply: const Err(NotFoundFailure(code: 'PGRST202')),
          document: const {'format': 'wuselwall-export', 'version': 1},
        );
        final result = await HouseholdExportRepository(api).export(actor: null);
        final file = (result as Ok<HouseholdExportFile>).value;
        expect(file.zip, isFalse);
        expect(jsonDecode(utf8.decode(file.bytes)), {
          'format': 'wuselwall-export',
          'version': 1,
        });
        expect(api.calls, [
          'fn:household-export {actor: null}',
          'household_export {p_actor: null}',
        ]);
      },
    );

    test('a refusal is not retried the old way', () async {
      final api = _ExportApi(
        reply: const Err(PermissionFailure(code: 'guardian_required')),
      );
      final result = await HouseholdExportRepository(api).export(actor: null);
      expect((result as Err).failure, isA<PermissionFailure>());
      expect(api.calls, hasLength(1));
    });

    test('a download that broke off is a failure, not a file', () async {
      final cut = Uint8List.sublistView(emptyZipWithEntry, 0, 40);
      final api = _ExportApi(reply: Ok(cut));
      final result = await HouseholdExportRepository(api).export(actor: null);
      expect(result, isA<Err<HouseholdExportFile>>());
    });
  });

  test('looksLikeZip wants the start and the end record of a zip', () {
    expect(looksLikeZip(emptyZip), isTrue);
    expect(looksLikeZip(emptyZipWithEntry), isTrue);
    expect(looksLikeZip(Uint8List.fromList(utf8.encode('{"a": 1}'))), isFalse);
    expect(looksLikeZip(Uint8List(0)), isFalse);
  });
}

/// An empty zip: nothing but the end-of-directory record.
final emptyZip = Uint8List.fromList([
  0x50, 0x4b, 0x05, 0x06, ...List.filled(18, 0), //
]);

/// The start of a zip (a local header signature), some data, and the end record.
final emptyZipWithEntry = Uint8List.fromList([
  0x50, 0x4b, 0x03, 0x04, ...List.filled(60, 7), ...emptyZip, //
]);

/// Answers the export's Edge Function and `api` call, recording both.
class _ExportApi implements ApiClient {
  _ExportApi({required this.reply, this.document});

  final Result<Uint8List> reply;
  final Object? document;
  final calls = <String>[];

  @override
  Future<Result<T>> function<T>(
    String name, {
    Map<String, dynamic>? body,
    required T Function(Object? json) parse,
  }) async {
    calls.add('fn:$name $body');
    return switch (reply) {
      Ok(:final value) => Result.guard(() async => parse(value)),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<T>> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    required T Function(Object? json) parse,
  }) async {
    calls.add('$fn $params');
    return Result.guard(() async => parse(document));
  }

  @override
  Future<Result<List<T>>> select<T>(
    String view, {
    String columns = '*',
    PostgrestTransformBuilder<PostgrestList> Function(
      PostgrestFilterBuilder<PostgrestList> query,
    )?
    build,
    required T Function(Map<String, dynamic> row) parse,
  }) => throw UnimplementedError();
}
