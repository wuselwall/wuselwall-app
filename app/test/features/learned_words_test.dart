import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/shopping/domain/match_correction.dart';

import '../support/fakes.dart';

final _de = lookupAppLocalizations(const Locale('de'));

/// Einstellungen > Einkaufen > Gelernte Wörter (specs/29): the words the family taught
/// the app, for guardians in Advanced, each with "Vergessen".
void main() {
  MatchCorrection word(String id, String text, String key, {String? by}) =>
      MatchCorrection(
        id: id,
        domain: 'shopping_category',
        text: text,
        key: key,
        setBy: by,
        setAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

  Future<FakeShoppingRepository> open(
    WidgetTester t, {
    SettingsView view = SettingsView.advanced,
    String? profileId = guardianId,
    String route = Routes.settingsShopping,
    List<MatchCorrection>? corrections,
    Result<void>? forgetResult,
  }) async {
    final shopping = FakeShoppingRepository(const [])
      ..corrections =
          corrections ??
          [
            word('c1', 'Guetzli', 'snacks', by: guardianId),
            word('c2', 'Znüni', 'my own aisle'),
          ];
    if (forgetResult != null) shopping.forgetCorrectionResult = forgetResult;
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device(profileId: profileId)),
        shopping: shopping,
        settingsView: view,
      ),
    );
    container.read(routerProvider).go(route);
    await t.pumpAndSettle();
    return shopping;
  }

  Finder groupTile() => find.byKey(const ValueKey('settings-group-shopping'));

  testWidgets('a guardian in Advanced sees each word, its category and who', (
    t,
  ) async {
    await open(t);

    expect(find.text(_de.settingsGroupShoppingTitle), findsOneWidget);
    expect(find.text(_de.settingsSectionLearnedWords), findsOneWidget);
    expect(find.text(_de.learnedWordsHelp), findsOneWidget);
    expect(find.text('Guetzli'), findsOneWidget);
    // A seeded key is translated and the person named; the date is today's.
    expect(find.textContaining('Snacks · von Papa, '), findsOneWidget);
    // A key the app does not know (a category the family made) is shown as it is.
    expect(find.text('Znüni'), findsOneWidget);
    expect(find.textContaining('my own aisle · '), findsOneWidget);
    expect(find.textContaining(' von '), findsOneWidget);
    expect(find.text(_de.learnedWordsForget), findsNWidgets(2));
  });

  testWidgets('Vergessen asks the server and the word leaves the list', (
    t,
  ) async {
    final shopping = await open(t);

    await t.tap(find.text(_de.learnedWordsForget).first);
    await t.pumpAndSettle();

    expect(shopping.forgottenCorrections, ['c1']);
    expect(find.text('Guetzli'), findsNothing);
    expect(find.text('Znüni'), findsOneWidget);
  });

  testWidgets('a refused forget says why and keeps the word', (t) async {
    final shopping = await open(
      t,
      forgetResult: const Err(PermissionFailure(code: 'guardian_required')),
    );

    await t.tap(find.text(_de.learnedWordsForget).first);
    await t.pumpAndSettle();

    expect(shopping.forgottenCorrections, ['c1']);
    expect(find.text('Guetzli'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('with nothing learned it explains where words come from', (
    t,
  ) async {
    await open(t, corrections: []);

    expect(find.text(_de.learnedWordsEmpty), findsOneWidget);
    expect(find.text(_de.learnedWordsForget), findsNothing);
  });

  testWidgets('Basic has no Einkaufen group; its page holds nothing', (
    t,
  ) async {
    await open(t, view: SettingsView.basic, route: Routes.settings);
    expect(groupTile(), findsNothing);

    // Opened directly, the page shows no word either.
    final container = ProviderScope.containerOf(
      t.element(find.byType(Scaffold).first),
    );
    container.read(routerProvider).go(Routes.settingsShopping);
    await t.pumpAndSettle();
    expect(find.text('Guetzli'), findsNothing);
    expect(find.text(_de.learnedWordsHelp), findsNothing);
  });

  testWidgets('Advanced lists the group on the top page', (t) async {
    await open(t, route: Routes.settings);
    expect(groupTile(), findsOneWidget);
    expect(find.text(_de.settingsGroupShoppingSubtitle), findsOneWidget);
  });

  testWidgets('a member who is no guardian does not see the words', (t) async {
    await open(t, profileId: kidId, route: Routes.settings);
    expect(groupTile(), findsNothing);
  });

  test('the group sits in the catalogue of groups, hidden in Basic', () {
    const basic = SettingsEnv(entries: [], guardian: true);
    const advanced = SettingsEnv(entries: [], advanced: true, guardian: true);
    const other = SettingsEnv(entries: [], advanced: true);
    expect(visibleItemCount(SettingsGroup.shopping, basic), 0);
    expect(visibleItemCount(SettingsGroup.shopping, advanced), 1);
    expect(visibleItemCount(SettingsGroup.shopping, other), 0);
    expect(hasHiddenSettings(basic, group: SettingsGroup.shopping), isTrue);
  });

  test('a correction row parses as the view returns it', () {
    final c = MatchCorrection.fromJson({
      'id': 'x',
      'domain': 'shopping_category',
      'text': 'Guetzli',
      'folded_text': 'guetzli',
      'key': 'snacks',
      'set_by': null,
      'set_at': '2026-10-31T10:00:00+00:00',
    });
    expect(c.text, 'Guetzli');
    expect(c.key, 'snacks');
    expect(c.setBy, isNull);
    expect(c.setAt.toUtc(), DateTime.utc(2026, 10, 31, 10));
  });
}
