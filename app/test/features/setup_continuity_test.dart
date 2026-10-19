import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/setup_link.dart';
import 'package:wuselwall/core/server/setup_store.dart';

import '../support/fakes.dart';

void main() {
  const token = '0123456789abcdef01234567';
  final server = Uri.parse('http://localhost');
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('pending setup skips front door and survives email restart', (
    t,
  ) async {
    final store = SetupStore();
    await store.save(SetupLink(server, token));
    final container = await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          setupStore: store,
          identity: FakeIdentityRepository(),
          signedIn: false,
        ),
        serverSessionProvider.overrideWithValue(ServerSession(hasSetup: true)),
      ],
    );
    final router = container.read(routerProvider);
    expect(router.routeInformationProvider.value.uri.path, Routes.signIn);
    router.go(Routes.setup);
    await t.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.signIn);
    expect(await store.read(server), token);
  });
  testWidgets('explicit back from email entry cancels setup capability', (
    t,
  ) async {
    final store = SetupStore();
    await store.save(SetupLink(server, token));
    final container = await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          setupStore: store,
          identity: FakeIdentityRepository(),
          signedIn: false,
        ),
        serverSessionProvider.overrideWithValue(ServerSession(hasSetup: true)),
      ],
    );
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      Routes.setup,
    );
    expect(await store.read(server), isNull);
  });
  testWidgets('saved capability is hidden, submitted and consumed on success', (
    t,
  ) async {
    final store = SetupStore();
    await store.save(SetupLink(server, token));
    final repo = FakeHouseholdOnboardingRepository();
    await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          setupStore: store,
          identity: FakeIdentityRepository(),
          household: repo,
        ),
      ],
    );
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.textContaining('Einrichtungslink gespeichert'), findsOneWidget);
    expect(find.text(token), findsNothing);
    await t.tap(find.text('Familie anlegen'));
    await t.pumpAndSettle();
    expect(repo.created.single.founderCode, token);
    expect(await store.read(server), isNull);
  });
  testWidgets('expired capability is not submitted from an already open form', (
    t,
  ) async {
    var now = DateTime.utc(2026);
    final store = SetupStore(now: () => now);
    await store.save(SetupLink(server, token));
    final repo = FakeHouseholdOnboardingRepository();
    await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          setupStore: store,
          identity: FakeIdentityRepository(),
          household: repo,
        ),
      ],
    );
    now = now.add(const Duration(days: 1));
    await t.tap(find.text('Familie anlegen'));
    await t.pumpAndSettle();
    expect(repo.created, isEmpty);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });
  testWidgets(
    'rejected saved capability is cleared and manual correction opens',
    (t) async {
      final store = SetupStore();
      await store.save(SetupLink(server, token));
      await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            setupStore: store,
            identity: FakeIdentityRepository(),
            household: FakeHouseholdOnboardingRepository(
              createResult: const Err(
                ValidationFailure(code: 'founder_code_invalid'),
              ),
            ),
          ),
        ],
      );
      await t.tap(find.text('Familie anlegen'));
      await t.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.textContaining('Einrichtungslink gespeichert'), findsNothing);
      expect(await store.read(server), isNull);
    },
  );
}
