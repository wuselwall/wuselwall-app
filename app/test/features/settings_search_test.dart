import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/ui/settings_group_text.dart';
import 'package:wuselwall/features/settings/ui/settings_search.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

import '../support/fakes.dart';

final _en = lookupAppLocalizations(const Locale('en'));

/// An environment as `settingsEnvProvider` builds it: a guardian on a personal phone of
/// a build with a server, unless said otherwise.
SettingsEnv _env({
  bool advanced = false,
  DeviceClass? deviceClass = DeviceClass.personal,
  String? acting = 'p1',
  bool notifications = true,
  bool server = true,
  bool guardian = true,
}) => SettingsEnv(
  entries: demoSettingCatalogue(),
  advanced: advanced,
  deviceClass: deviceClass,
  deviceId: 'd1',
  acting: acting,
  notificationsAvailable: notifications,
  hasServer: server,
  guardian: guardian,
);

List<SettingsHit> _index(SettingsEnv env) => settingsSearchIndex(_en, env);

/// The hit for [rowId] in [group], or null; a null [rowId] is the group's own page.
SettingsHit? _hit(
  List<SettingsHit> index,
  SettingsGroup group, [
  String? rowId,
]) =>
    index.where((h) => h.group == group && h.item?.rowId == rowId).firstOrNull;

void main() {
  group('the index', () {
    test('a Basic device finds the rows only Advanced shows, and says so', () {
      final index = _index(_env());

      final dutyPoints = _hit(
        index,
        SettingsGroup.tasks,
        'tasks.points.duty_default',
      );
      expect(dutyPoints, isNotNull);
      expect(dutyPoints!.advancedOnly, isTrue);
      expect(dutyPoints.title, isNotEmpty);

      // A tile that Basic hides.
      expect(
        _hit(index, SettingsGroup.calendar, 'feedTokens')!.advancedOnly,
        isTrue,
      );
    });

    test('a Basic device finds the rows Basic shows, unmarked', () {
      final index = _index(_env());

      expect(
        _hit(
          index,
          SettingsGroup.tasks,
          'tasks.jokers_per_month',
        )!.advancedOnly,
        isFalse,
      );
      expect(
        _hit(index, SettingsGroup.account, 'security')!.advancedOnly,
        isFalse,
      );
      // So is a group that has something to show in Basic.
      expect(_hit(index, SettingsGroup.tasks)!.advancedOnly, isFalse);
    });

    test('a group that Basic shows nothing of is found, marked Advanced', () {
      final basic = _index(_env());
      expect(_hit(basic, SettingsGroup.kitchen)!.advancedOnly, isTrue);
      expect(
        _hit(basic, SettingsGroup.kitchen, 'board.rollover')!.advancedOnly,
        isTrue,
      );

      // In Advanced nothing is marked: everything is shown.
      final advanced = _index(_env(advanced: true));
      expect(advanced.where((h) => h.advancedOnly), isEmpty);
    });

    test('Basic and Advanced devices index the same rows', () {
      String name(SettingsHit h) => '${h.group.name}/${h.item?.rowId}';
      expect(
        _index(_env()).map(name).toSet(),
        _index(_env(advanced: true)).map(name).toSet(),
      );
    });

    test('every hit has a title and sits in its group', () {
      for (final hit in _index(_env())) {
        expect(hit.title, isNotEmpty, reason: hit.route);
        expect(hit.route, startsWith(hit.group.route));
      }
    });

    test('learned words are for a guardian only', () {
      expect(
        _hit(
          _index(_env(guardian: false)),
          SettingsGroup.shopping,
          'learnedWords',
        ),
        isNull,
      );
      expect(
        _index(_env(guardian: false))
            .where((h) => h.group == SettingsGroup.shopping),
        isEmpty,
        reason: 'a group with nothing to open has no hit either',
      );
      expect(
        _hit(_index(_env()), SettingsGroup.shopping, 'learnedWords'),
        isNotNull,
      );
    });

    test('the server row needs a build that chose a server', () {
      final without = _index(_env(server: false));
      expect(_hit(without, SettingsGroup.server, 'server'), isNull);
      expect(_hit(without, SettingsGroup.server), isNull);

      final with_ = _index(_env());
      expect(_hit(with_, SettingsGroup.server, 'server'), isNotNull);
      expect(_hit(with_, SettingsGroup.server), isNotNull);
    });

    test('reminders are for a personal phone with notifications', () {
      expect(
        _hit(_index(_env()), SettingsGroup.personal, 'reminders'),
        isNotNull,
      );
      expect(
        _hit(
          _index(_env(deviceClass: DeviceClass.shared)),
          SettingsGroup.personal,
          'reminders',
        ),
        isNull,
      );
      expect(
        _hit(
          _index(_env(notifications: false)),
          SettingsGroup.personal,
          'reminders',
        ),
        isNull,
      );
    });

    test('the account rows are not found off a personal phone', () {
      final shared = _index(_env(deviceClass: DeviceClass.shared));
      expect(shared.where((h) => h.group == SettingsGroup.account), isEmpty);
    });

    test('a heading that only repeats its row is left out', () {
      final index = _index(_env());
      final wusel = _hit(index, SettingsGroup.personal, 'member.wusel')!;
      expect(wusel.section, isNull);
      final outfit = _hit(
        index,
        SettingsGroup.personal,
        'member.wusel_outfit',
      )!;
      expect(outfit.section, _en.settingsSectionWusel);
    });
  });

  group('the route', () {
    test('a row leads to its group page with the row named', () {
      final hit = _hit(
        _index(_env()),
        SettingsGroup.tasks,
        'tasks.points.duty_default',
      )!;
      expect(
        hit.route,
        '${SettingsGroup.tasks.route}?row=tasks.points.duty_default',
      );
      expect(
        hit.route,
        Routes.settingsRow(SettingsGroup.tasks.route, hit.item!.rowId),
      );
      expect(Uri.parse(hit.route).queryParameters, {
        'row': 'tasks.points.duty_default',
      });
    });

    test('a tile leads to its group page with the tile named', () {
      final hit = _hit(_index(_env()), SettingsGroup.account, 'security')!;
      expect(hit.route, '${SettingsGroup.account.route}?row=security');
    });

    test('a group leads to its page alone', () {
      final hit = _hit(_index(_env()), SettingsGroup.meals)!;
      expect(hit.route, SettingsGroup.meals.route);
      expect(hit.route, isNot(contains('?')));
    });
  });

  group('searchSettings', () {
    final index = _index(_env());
    List<SettingsHit> search(String query) => searchSettings(_en, index, query);

    test('finds a row by its title, in any case', () {
      final hits = search('JOKERS');
      expect(
        hits.map((h) => h.item?.rowId),
        contains('tasks.jokers_per_month'),
      );
      expect(hits.first.title, _en.settingTasksJokersTitle);
    });

    test('finds a row by a word of its explanation alone', () {
      // Security's title says nothing of passkeys; the words on it do.
      final security = _hit(index, SettingsGroup.account, 'security')!;
      expect(security.title.toLowerCase(), isNot(contains('passkey')));
      final hits = search('passkey');
      expect(hits.map((h) => h.item?.rowId), contains('security'));
    });

    test('finds the security tile by the PIN on it', () {
      expect(
        search('PIN')
            .where((h) => h.group == SettingsGroup.account)
            .map((h) => h.item?.rowId),
        contains('security'),
      );
    });

    test('a title match comes before a match of the explanation only', () {
      final hits = search('reminder');
      final ids = [for (final h in hits) '${h.group.name}/${h.item?.rowId}'];
      // "Reminders" and "Reminder before events" are titles; the group Personal
      // only says "reminders" in its subtitle.
      final reminders = ids.indexOf('personal/reminders');
      final event = ids.indexOf('personal/notify.event_reminder');
      final personal = ids.indexOf('personal/null');
      expect(reminders, greaterThanOrEqualTo(0));
      expect(event, greaterThanOrEqualTo(0));
      expect(personal, greaterThan(reminders));
      expect(personal, greaterThan(event));
    });

    test('every term has to be found, in the title or around it', () {
      expect(search('server change').map((h) => h.item?.rowId), ['server']);
      expect(search('server zzzqq'), isEmpty);
    });

    test('a query that nothing answers, or no query, finds nothing', () {
      expect(search('zzzqq'), isEmpty);
      expect(search(''), isEmpty);
      expect(search('  '), isEmpty);
    });

    test('the limit cuts the list', () {
      final all = search('sh');
      expect(all.length, greaterThan(2));
      expect(
        searchSettings(_en, index, 'sh', limit: 2).map((h) => h.route),
        all.take(2).map((h) => h.route),
      );
    });
  });

  group('on the settings page', () {
    late ProviderContainer container;

    /// The settings page of a guardian on a personal phone, in English, in [view].
    Future<void> openSettings(
      WidgetTester t, {
      SettingsView view = SettingsView.basic,
      bool motion = false,
    }) async {
      container = await pumpApp(
        t,
        locale: const Locale('en'),
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            settingsView: view,
          ),
          householdSettingsRepositoryProvider.overrideWithValue(
            DemoHouseholdSettingsRepository(),
          ),
        ],
      );
      if (motion) {
        t.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures();
      }
      container.read(routerProvider).go(Routes.settings);
      await t.pumpAndSettle();
    }

    Finder searchField() => find.descendant(
      of: find.byKey(const ValueKey('settings-search')),
      matching: find.byType(TextField),
    );

    Future<void> search(WidgetTester t, String text) async {
      await t.enterText(searchField(), text);
      await t.pumpAndSettle();
    }

    Finder group(SettingsGroup g) =>
        find.byKey(ValueKey('settings-group-${g.name}'));

    Finder hit(SettingsGroup g, [String? rowId]) =>
        find.byKey(ValueKey('settings-hit-${g.name}-${rowId ?? ''}'));

    String path() => container
        .read(routerProvider)
        .routeInformationProvider
        .value
        .uri
        .toString();

    testWidgets('the field says what it searches', (t) async {
      await openSettings(t);
      expect(find.text(_en.settingsSearchHint), findsOneWidget);
    });

    testWidgets('typing replaces the groups by the results', (t) async {
      await openSettings(t);
      expect(group(SettingsGroup.family), findsOneWidget);

      await search(t, 'passkey');

      expect(group(SettingsGroup.family), findsNothing);
      expect(group(SettingsGroup.account), findsNothing);
      expect(hit(SettingsGroup.account, 'security'), findsOneWidget);
      expect(
        find.descendant(
          of: hit(SettingsGroup.account, 'security'),
          matching: find.text(_en.settingsSecurity),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a result says where the row lives and what it does', (
      t,
    ) async {
      await openSettings(t);
      await search(t, 'jokers');

      final tile = hit(SettingsGroup.tasks, 'tasks.jokers_per_month');
      expect(tile, findsOneWidget);
      expect(
        find.descendant(
          of: tile,
          matching: find.text(_en.settingsGroupTasksTitle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a query nothing answers shows the empty line', (t) async {
      await openSettings(t);
      await search(t, 'zzzqq');

      expect(
        find.byKey(const ValueKey('settings-search-empty')),
        findsOneWidget,
      );
      expect(find.text(_en.searchNothingFound), findsOneWidget);
      expect(group(SettingsGroup.family), findsNothing);
    });

    testWidgets('clearing the field brings the groups back', (t) async {
      await openSettings(t);
      await search(t, 'zzzqq');
      await t.tap(find.byKey(const ValueKey('search-clear')));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('settings-search-empty')), findsNothing);
      expect(group(SettingsGroup.family), findsOneWidget);
      expect(find.byType(SettingsHitTile), findsNothing);
    });

    testWidgets('a query of blanks leaves the groups alone', (t) async {
      await openSettings(t);
      await search(t, '   ');

      expect(group(SettingsGroup.family), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-search-empty')), findsNothing);
    });

    testWidgets('a row only Advanced shows says so in its result', (t) async {
      await openSettings(t);
      await search(t, 'moves on');

      final tile = hit(SettingsGroup.kitchen, 'board.rollover');
      expect(tile, findsOneWidget);
      expect(
        find.descendant(
          of: tile,
          matching: find.text(_en.settingsViewAdvanced),
        ),
        findsOneWidget,
      );

      await search(t, 'jokers');
      expect(
        find.descendant(
          of: hit(SettingsGroup.tasks, 'tasks.jokers_per_month'),
          matching: find.text(_en.settingsViewAdvanced),
        ),
        findsNothing,
      );
    });

    testWidgets('a row only Advanced shows switches the device to Advanced', (
      t,
    ) async {
      await openSettings(t);
      expect(container.read(showAdvancedSettingsProvider), isFalse);
      await search(t, 'moves on');

      await t.tap(hit(SettingsGroup.kitchen, 'board.rollover'));
      await t.pumpAndSettle();

      expect(container.read(showAdvancedSettingsProvider), isTrue);
      expect(path(), '${SettingsGroup.kitchen.route}?row=board.rollover');
      expect(
        find.byKey(const ValueKey('settings-row-board.rollover')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-row-focused')),
        findsOneWidget,
      );
      // The row that is marked is the one asked for.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings-row-focused')),
          matching: find.byKey(const ValueKey('setting-board.rollover')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a Basic row opens its page without changing the view', (
      t,
    ) async {
      await openSettings(t);
      await search(t, 'jokers');

      await t.tap(hit(SettingsGroup.tasks, 'tasks.jokers_per_month'));
      await t.pumpAndSettle();

      expect(container.read(showAdvancedSettingsProvider), isFalse);
      expect(path(), '${SettingsGroup.tasks.route}?row=tasks.jokers_per_month');
      expect(
        find.byKey(const ValueKey('settings-row-tasks.jokers_per_month')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings-row-focused')),
          matching: find.byKey(
            const ValueKey('setting-tasks.jokers_per_month'),
          ),
        ),
        findsOneWidget,
      );
      // Basic still hides what it hides.
      expect(
        find.byKey(const ValueKey('settings-row-tasks.kind_default')),
        findsNothing,
      );
    });

    testWidgets('a group result opens the page with no row marked', (t) async {
      await openSettings(t, view: SettingsView.advanced);
      await search(t, 'kitchen wall');

      await t.tap(hit(SettingsGroup.kitchen));
      await t.pumpAndSettle();

      expect(path(), SettingsGroup.kitchen.route);
      expect(find.byKey(const ValueKey('settings-row-focused')), findsNothing);
      expect(
        find.byKey(const ValueKey('settings-row-board.rollover')),
        findsOneWidget,
      );
    });

    testWidgets('with motion the mark fades out and nothing is left running', (
      t,
    ) async {
      await openSettings(t, motion: true);
      await search(t, 'jokers');

      await t.tap(hit(SettingsGroup.tasks, 'tasks.jokers_per_month'));
      // Shortly after opening the row is tinted ...
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      Color? tint() {
        final box = t.widget<DecoratedBox>(
          find.byKey(const ValueKey('settings-row-focused')),
        );
        return (box.decoration as BoxDecoration).color;
      }

      expect(tint()!.a, greaterThan(0.9));
      // ... and the 2.4 s fade ends clear.
      await t.pumpAndSettle();
      expect(tint()!.a, 0);
      expect(
        find.byKey(const ValueKey('settings-row-tasks.jokers_per_month')),
        findsOneWidget,
      );
    });

    testWidgets('a link to a row this device does not show marks nothing', (
      t,
    ) async {
      await openSettings(t);
      container
          .read(routerProvider)
          .go(Routes.settingsRow(SettingsGroup.tasks.route, 'no.such.row'));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('settings-row-focused')), findsNothing);
      expect(
        find.byKey(const ValueKey('settings-row-tasks.jokers_per_month')),
        findsOneWidget,
      );
    });
  });
}
