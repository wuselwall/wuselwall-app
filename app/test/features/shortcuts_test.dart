import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/shortcuts/data/shortcut_repository.dart';

import '../support/fakes.dart';

/// Records every key call; the key it creates is fixed so the dialog is predictable.
class FakeShortcutRepository implements ShortcutRepository {
  FakeShortcutRepository({this.tokensList = const []});

  final List<ShortcutToken> tokensList;
  final created = <({String? actor, String? profileId, String label})>[];
  final revoked = <({String? actor, String id})>[];

  @override
  Future<Result<List<ShortcutToken>>> tokens() async => Ok(tokensList);

  @override
  Future<Result<CreatedShortcutToken>> create({
    required String? actor,
    required String? profileId,
    required String label,
  }) async {
    created.add((actor: actor, profileId: profileId, label: label));
    return const Ok(CreatedShortcutToken(id: 's-new', token: 'wws_key123'));
  }

  @override
  Future<Result<void>> revoke({
    required String? actor,
    required String id,
  }) async {
    revoked.add((actor: actor, id: id));
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ShortcutToken _token({
  String id = 's1',
  String label = 'iPhone',
  String profileId = guardianId,
  DateTime? revokedAt,
}) => ShortcutToken(
  id: id,
  profileId: profileId,
  label: label,
  createdAt: DateTime(2026, 10, 1),
  lastUsedAt: DateTime.now().subtract(const Duration(hours: 3)),
  useCount: 12,
  revokedAt: revokedAt,
);

Future<void> _open(
  WidgetTester tester,
  FakeShortcutRepository keys, {
  String? profileId = guardianId,
}) async {
  await pumpApp(
    tester,
    overrides: [
      ...baseOverrides(
        identity: FakeIdentityRepository(current: device(profileId: profileId)),
      ),
      shortcutRepositoryProvider.overrideWithValue(keys),
    ],
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  );
  container.read(routerProvider).go(Routes.shortcuts);
  await tester.pumpAndSettle();
}

void main() {
  test('shortcutsAddress is the function under the server', () {
    expect(
      shortcutsAddress('https://api.example.org/'),
      'https://api.example.org/functions/v1/shortcuts',
    );
    expect(
      shortcutsAddress('https://api.example.org'),
      'https://api.example.org/functions/v1/shortcuts',
    );
  });

  test('a row of api.shortcut_tokens parses, revoked or not', () {
    final t = ShortcutToken.fromJson({
      'id': 's1',
      'profile_id': kidId,
      'label': 'iPad',
      'created_at': '2026-10-01T08:00:00Z',
      'last_used_at': null,
      'use_count': 0,
      'revoked_at': '2026-10-02T08:00:00Z',
    });
    expect(t.profileId, kidId);
    expect(t.lastUsedAt, isNull);
    expect(t.revoked, isTrue);
  });

  testWidgets('a guardian creates a key for a child and sees it once', (
    tester,
  ) async {
    final keys = FakeShortcutRepository();
    await _open(tester, keys);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Annas iPad');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Anna'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Schlüssel erstellen'));
    await tester.pumpAndSettle();

    expect(keys.created, [
      (actor: guardianId, profileId: kidId, label: 'Annas iPad'),
    ]);
    expect(find.text('Schlüssel für Anna'), findsOneWidget);
    final shown = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.data)
        .toList();
    expect(shown, contains('wws_key123'));
    expect(shown, contains('http://localhost/functions/v1/shortcuts'));
  });

  testWidgets('a key is the guardian\'s own unless someone else is chosen', (
    tester,
  ) async {
    final keys = FakeShortcutRepository();
    await _open(tester, keys);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'iPhone');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Schlüssel erstellen'));
    await tester.pumpAndSettle();

    expect(keys.created.single.profileId, guardianId);
  });

  testWidgets('a member sees their own keys and chooses nobody else', (
    tester,
  ) async {
    final keys = FakeShortcutRepository(
      tokensList: [
        _token(label: 'Papas iPhone'),
        _token(id: 's2', label: 'Annas iPad', profileId: kidId),
      ],
    );
    await _open(tester, keys, profileId: kidId);

    expect(find.text('Annas iPad'), findsOneWidget);
    expect(find.text('Papas iPhone'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Mein iPad');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Schlüssel erstellen'));
    await tester.pumpAndSettle();
    expect(keys.created.single.profileId, kidId);
  });

  testWidgets('revoking asks first, and a revoked key has no button', (
    tester,
  ) async {
    final keys = FakeShortcutRepository(
      tokensList: [
        _token(),
        _token(id: 's2', label: 'Altes iPhone', revokedAt: DateTime(2026, 10)),
      ],
    );
    await _open(tester, keys);

    expect(find.textContaining('Papa · 12 Abfragen'), findsNWidgets(2));
    expect(find.textContaining('Zuletzt benutzt: vor 3 Std.'), findsOneWidget);
    expect(find.textContaining('Gesperrt'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Sperren'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sperren'));
    await tester.pumpAndSettle();
    expect(keys.revoked, isEmpty, reason: 'confirmation comes first');
    await tester.tap(find.widgetWithText(FilledButton, 'Sperren'));
    await tester.pumpAndSettle();
    expect(keys.revoked, [(actor: guardianId, id: 's1')]);
  });
}
