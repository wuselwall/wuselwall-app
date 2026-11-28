import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/recipe_view_page.dart';
import 'package:wuselwall/features/search/ui/search_page.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/tasks/ui/reward_editor.dart';
import 'package:wuselwall/features/tasks/ui/task_editor.dart';

import '../support/fake_meals.dart';
import '../support/fake_tasks.dart';
import '../support/fakes.dart';

final _de = lookupAppLocalizations(const Locale('de'));

/// A calendar whose `search` answers what the test says and remembers what was asked.
class _SearchCalendar extends FakeCalendarRepository {
  _SearchCalendar({this.result = const EventSearchResult()});

  EventSearchResult result;

  /// When set, the search fails with it.
  Failure? failure;

  /// The queries the server was asked, in order.
  final asked = <String>[];

  @override
  Future<Result<EventSearchResult>> search(String query, {int? limit}) async {
    asked.add(query);
    final failed = failure;
    return failed == null ? Ok(result) : Err(failed);
  }
}

DateTime _today() {
  final now = testNow();
  return DateTime(now.year, now.month, now.day);
}

DateTime _inDays(int days) {
  final today = _today();
  return DateTime(today.year, today.month, today.day + days);
}

/// An all-day appointment on [day] (to [last] when it spans days).
Occurrence _event(
  String title,
  DateTime day, {
  DateTime? last,
  String? location,
  bool recurring = false,
}) {
  final end = last ?? day;
  final id =
      '$title|${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  return Occurrence(
    id: id,
    eventId: 'e-$title',
    calendarId: 'cal',
    title: title,
    kind: EventKind.appointment,
    status: EventStatus.confirmed,
    importance: Importance.normal,
    allDay: true,
    start: day,
    end: DateTime(end.year, end.month, end.day + 1),
    localStartDate: day,
    localEndDate: end,
    location: location,
    isRecurring: recurring,
  );
}

/// The app configured for a server that announces [features].
AppConfig _server(List<String> features) => AppConfig.forServer(
  const AppConfig(
    environment: 'test',
    supabaseUrl: 'http://localhost',
    supabasePublishableKey: 'key',
  ),
  ServerInfo(
    supabaseUrl: Uri.parse('https://family.example.org'),
    publishableKey: 'sb_publishable_abc',
    apiVersion: 1,
    minAppVersion: '1.0.0',
    features: features,
  ),
);

ShoppingItem _shoppingItem(
  String id,
  String name, {
  bool checked = false,
  String? quantity,
}) => ShoppingItem(
  id: id,
  name: name,
  quantity: quantity,
  checked: checked,
  createdAt: DateTime(2026, 10, 11),
  listId: 'l1',
);

/// Something the family has of every kind the search finds, all of them with "Wusel" in
/// the name, which the settings (Wusel, Wusel on this device, …) answer to as well.
FakeTasksApi _tasks() => FakeTasksApi(
  tables: {
    'task_definitions': [
      definitionRow(id: 'd1', title: 'Wusel füttern'),
      definitionRow(id: 'd2', title: 'Bett machen'),
    ],
    'rewards': [
      {
        'id': 'r1',
        'title': 'Wusel-Plüschtier',
        'cost_points': 5,
        'requires_approval': true,
        'is_active': true,
      },
      {
        'id': 'r2',
        'title': 'Eis essen gehen',
        'cost_points': 5,
        'requires_approval': true,
        'is_active': true,
      },
    ],
  },
);

FakeMealsRepository _meals() => FakeMealsRepository(
  recipes: const [
    Recipe(
      id: 'rc1',
      title: 'Wusel-Waffeln',
      servingsDefault: 4,
      tags: ['Süss'],
    ),
    Recipe(id: 'rc2', title: 'Käsespätzle', servingsDefault: 4),
  ],
);

FakeShoppingRepository _shopping() => FakeShoppingRepository([
  _shoppingItem('i1', 'Wusel-Eis', quantity: '2 Becher'),
  _shoppingItem('i2', 'Wusel-Futter', checked: true),
  _shoppingItem('i3', 'Milch'),
]);

/// The adult home with the family's things above, on a server that [config] describes
/// (the default has every feature).
Future<ProviderContainer> _pump(
  WidgetTester t, {
  _SearchCalendar? calendar,
  AppConfig? config,
  Size size = const Size(1000, 1600),
  FakeIdentityRepository? identity,
  FakeTasksApi? tasks,
  FakeMealsRepository? meals,
  FakeShoppingRepository? shopping,
}) => pumpApp(
  t,
  size: size,
  overrides: [
    ...baseOverrides(
      identity: identity ?? FakeIdentityRepository(current: device()),
      shopping: shopping ?? _shopping(),
      appConfig: config,
    ),
    householdSettingsRepositoryProvider.overrideWithValue(
      DemoHouseholdSettingsRepository(),
    ),
  ],
  calendar: calendar ?? _SearchCalendar(),
  tasks: tasks ?? _tasks(),
  meals: meals ?? _meals(),
);

/// Opens the search over everything through the home bar's button.
Future<void> _openSearch(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('home-search')));
  await t.pumpAndSettle();
}

Finder _field() => find.descendant(
  of: find.byKey(const ValueKey('search-field')),
  matching: find.byType(TextField),
);

/// Types [text] and waits for what the search shows: the server is asked only after
/// the typing has rested.
Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(_field(), text);
  await t.pump();
  await t.pump(searchDebounce);
  await t.pump();
  await t.pumpAndSettle();
}

Finder _section(String name) => find.byKey(ValueKey('search-section-$name'));

Finder _rows(String section) =>
    find.descendant(of: _section(section), matching: find.byType(ListTile));

Finder _inSection(String section, String text) =>
    find.descendant(of: _section(section), matching: find.text(text));

void main() {
  group('the search over everything', () {
    testWidgets('says what it looks through before anything is typed', (
      t,
    ) async {
      await _pump(t);
      await _openSearch(t);

      expect(find.byKey(const ValueKey('search-field')), findsOneWidget);
      expect(find.text(_de.searchHint), findsOneWidget);
      expect(find.byKey(const ValueKey('search-intro')), findsOneWidget);
      expect(find.text(_de.searchIntro), findsOneWidget);
      expect(find.byKey(const ValueKey('search-results')), findsNothing);
      expect(find.byKey(const ValueKey('search-empty')), findsNothing);
    });

    testWidgets('finds each kind of thing under its own heading', (t) async {
      final calendar = _SearchCalendar(
        result: EventSearchResult(
          upcoming: [_event('Wusel-Fest', _inDays(3), location: 'Park')],
          past: [_event('Wusel-Rückblick', _inDays(-20))],
        ),
      );
      await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'wusel');

      // Appointments, from the server.
      expect(calendar.asked, ['wusel']);
      expect(_inSection('events', _de.searchSectionEvents), findsOneWidget);
      expect(_inSection('events', 'Wusel-Fest'), findsOneWidget);
      expect(_inSection('events-past', _de.searchSectionPast), findsOneWidget);
      expect(_inSection('events-past', 'Wusel-Rückblick'), findsOneWidget);
      // Chores and rewards share a heading.
      expect(_inSection('tasks', _de.searchSectionTasks), findsOneWidget);
      expect(find.byKey(const ValueKey('search-chore-d1')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-reward-r1')), findsOneWidget);
      // Recipes, shopping, settings.
      expect(_inSection('recipes', _de.mealsRecipesTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('search-recipe-rc1')), findsOneWidget);
      expect(_inSection('shopping', _de.shoppingTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('search-item-i1')), findsOneWidget);
      expect(_inSection('settings', _de.settingsTitle), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings-hit-personal-member.wusel')),
        findsOneWidget,
      );

      // What does not say "Wusel" is not there.
      expect(find.text('Bett machen'), findsNothing);
      expect(find.text('Eis essen gehen'), findsNothing);
      expect(find.text('Käsespätzle'), findsNothing);
      expect(find.text('Milch'), findsNothing);
    });

    testWidgets('lists the kinds in the order of the home tabs', (t) async {
      final calendar = _SearchCalendar(
        result: EventSearchResult(
          upcoming: [_event('Wusel-Fest', _inDays(3))],
          past: [_event('Wusel-Rückblick', _inDays(-20))],
        ),
      );
      await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'wusel');

      double top(String section) => t.getTopLeft(_section(section)).dy;
      final order = [
        top('events'),
        top('events-past'),
        top('tasks'),
        top('recipes'),
        top('shopping'),
        top('settings'),
      ];
      expect(order, [...order]..sort());
    });

    testWidgets('a result shows what the thing is and where it is', (t) async {
      final calendar = _SearchCalendar(
        result: EventSearchResult(
          upcoming: [
            _event('Wusel-Fest', _inDays(3), location: 'Park', recurring: true),
          ],
        ),
      );
      await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'wusel');

      // An appointment: its place is on its second line, a series has its icon.
      final event = find.byKey(
        ValueKey('search-event-Wusel-Fest|${_isoDay(3)}'),
      );
      expect(
        find.descendant(of: event, matching: find.textContaining('Park')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: event,
          matching: find.byIcon(Icons.event_repeat_outlined),
        ),
        findsOneWidget,
      );
      // A chore and a reward say which they are.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('search-chore-d1')),
          matching: find.text(_de.searchKindChore),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('search-reward-r1')),
          matching: find.text(_de.searchKindReward),
        ),
        findsOneWidget,
      );
      // A recipe its tags, an item its quantity and its list.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('search-recipe-rc1')),
          matching: find.text('Süss'),
        ),
        findsOneWidget,
      );
      final item = find.byKey(const ValueKey('search-item-i1'));
      expect(
        find.descendant(of: item, matching: find.text('Wusel-Eis · 2 Becher')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: item, matching: find.text('Supermarkt')),
        findsOneWidget,
      );
    });

    testWidgets('umlauts and case do not matter', (t) async {
      await _pump(t);
      await _openSearch(t);
      await _type(t, 'KAESESPAETZLE');

      expect(find.byKey(const ValueKey('search-recipe-rc2')), findsOneWidget);
    });

    testWidgets('an item that is ticked off is not an answer', (t) async {
      await _pump(t);
      await _openSearch(t);
      await _type(t, 'wusel');

      expect(find.byKey(const ValueKey('search-item-i1')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-item-i2')), findsNothing);
    });

    testWidgets('a query that nothing answers shows one line', (t) async {
      final calendar = _SearchCalendar();
      await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'zzzqq');

      expect(calendar.asked, ['zzzqq']);
      expect(find.byKey(const ValueKey('search-empty')), findsOneWidget);
      expect(find.text(_de.searchNothingFound), findsOneWidget);
      expect(find.byKey(const ValueKey('search-results')), findsNothing);
      expect(find.byKey(const ValueKey('search-intro')), findsNothing);
    });

    testWidgets('clearing the field brings the intro back', (t) async {
      await _pump(t);
      await _openSearch(t);
      await _type(t, 'wusel');
      expect(find.byKey(const ValueKey('search-results')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('search-clear')));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('search-intro')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-results')), findsNothing);
    });

    testWidgets('the server is asked once, after the typing has rested', (
      t,
    ) async {
      final calendar = _SearchCalendar();
      await _pump(t, calendar: calendar);
      await _openSearch(t);

      await t.enterText(_field(), 'wu');
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(_field(), 'wuse');
      await t.pump(const Duration(milliseconds: 100));
      await t.enterText(_field(), 'wusel');
      // The appointments wait; what the app holds is there at once.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('search-chore-d1')), findsOneWidget);
      expect(calendar.asked, isEmpty);

      await t.pump(searchDebounce);
      await t.pump();
      await t.pumpAndSettle();
      expect(calendar.asked, ['wusel']);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('one letter is not asked of the server', (t) async {
      final calendar = _SearchCalendar();
      await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'w');

      expect(calendar.asked, isEmpty);
      // The rest answers all the same.
      expect(find.byKey(const ValueKey('search-chore-d1')), findsOneWidget);
    });

    testWidgets('says there are more appointments than it shows', (t) async {
      final calendar = _SearchCalendar(
        result: EventSearchResult(
          upcoming: [_event('Wusel-Fest', _inDays(3))],
          more: true,
        ),
      );
      await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'wusel');

      expect(find.byKey(const ValueKey('search-more')), findsOneWidget);
      expect(find.text(_de.searchMore), findsOneWidget);
    });
  });

  group('long sections', () {
    List<ShoppingItem> apples(int count) => [
      for (var i = 1; i <= count; i++) _shoppingItem('a$i', 'Apfel $i'),
    ];

    testWidgets('show five rows and a way to see all of them', (t) async {
      await _pump(t, shopping: FakeShoppingRepository(apples(8)));
      await _openSearch(t);
      await _type(t, 'apfel');

      expect(searchSectionRows, 5);
      expect(_rows('shopping'), findsNWidgets(5));
      expect(find.byKey(const ValueKey('search-item-a5')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-item-a6')), findsNothing);
      final all = find.byKey(const ValueKey('search-all-shopping'));
      expect(all, findsOneWidget);
      expect(find.text(_de.searchShowAll(8)), findsOneWidget);

      await t.ensureVisible(all);
      await t.tap(all);
      await t.pumpAndSettle();

      expect(_rows('shopping'), findsNWidgets(8));
      expect(find.byKey(const ValueKey('search-item-a8')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-all-shopping')), findsNothing);
    });

    testWidgets('a section of exactly five has no such button', (t) async {
      await _pump(t, shopping: FakeShoppingRepository(apples(5)));
      await _openSearch(t);
      await _type(t, 'apfel');

      expect(_rows('shopping'), findsNWidgets(5));
      expect(find.byKey(const ValueKey('search-all-shopping')), findsNothing);
    });

    testWidgets('showing all of one section leaves the others cut', (t) async {
      await _pump(
        t,
        shopping: FakeShoppingRepository([
          ...apples(7),
          for (var i = 1; i <= 7; i++)
            _shoppingItem('b$i', 'Apfelsaft $i', quantity: null),
        ]),
        meals: FakeMealsRepository(
          recipes: [
            for (var i = 1; i <= 7; i++)
              Recipe(id: 'ra$i', title: 'Apfelkuchen $i', servingsDefault: 4),
          ],
        ),
      );
      await _openSearch(t);
      await _type(t, 'apfel');

      expect(_rows('recipes'), findsNWidgets(5));
      expect(_rows('shopping'), findsNWidgets(5));
      final all = find.byKey(const ValueKey('search-all-recipes'));
      await t.ensureVisible(all);
      await t.tap(all);
      await t.pumpAndSettle();

      expect(_rows('recipes'), findsNWidgets(7));
      expect(_rows('shopping'), findsNWidgets(5));
    });

    testWidgets('a new query cuts the sections again', (t) async {
      await _pump(t, shopping: FakeShoppingRepository(apples(8)));
      await _openSearch(t);
      await _type(t, 'apfel');
      final all = find.byKey(const ValueKey('search-all-shopping'));
      await t.ensureVisible(all);
      await t.tap(all);
      await t.pumpAndSettle();
      expect(_rows('shopping'), findsNWidgets(8));

      await _type(t, 'apfe');

      expect(_rows('shopping'), findsNWidgets(5));
    });

    testWidgets('appointments are cut the same way', (t) async {
      final calendar = _SearchCalendar(
        result: EventSearchResult(
          upcoming: [
            for (var i = 1; i <= 7; i++) _event('Fest $i', _inDays(i)),
          ],
        ),
      );
      await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'fest');

      expect(_rows('events'), findsNWidgets(5));
      final all = find.byKey(const ValueKey('search-all-events'));
      await t.ensureVisible(all);
      await t.tap(all);
      await t.pumpAndSettle();
      expect(_rows('events'), findsNWidgets(7));
    });
  });

  group('on a server without the search function', () {
    testWidgets('no appointments are looked for, and the intro says so', (
      t,
    ) async {
      final calendar = _SearchCalendar(
        result: EventSearchResult(upcoming: [_event('Wusel-Fest', _inDays(3))]),
      );
      final container = await _pump(
        t,
        calendar: calendar,
        config: _server(const ['trips']),
      );
      expect(container.read(eventSearchSupportedProvider), isFalse);
      await _openSearch(t);

      expect(find.text(_de.searchIntroLocal), findsOneWidget);
      expect(find.text(_de.searchIntro), findsNothing);

      await _type(t, 'wusel');

      expect(_section('events'), findsNothing);
      expect(_section('events-past'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Wusel-Fest'), findsNothing);
      expect(calendar.asked, isEmpty);
      // The rest works the same.
      expect(find.byKey(const ValueKey('search-chore-d1')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-recipe-rc1')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-item-i1')), findsOneWidget);
    });

    testWidgets('a query nothing holds shows the empty line at once', (
      t,
    ) async {
      final calendar = _SearchCalendar();
      await _pump(t, calendar: calendar, config: _server(const ['trips']));
      await _openSearch(t);
      await _type(t, 'zzzqq');

      expect(find.byKey(const ValueKey('search-empty')), findsOneWidget);
      expect(calendar.asked, isEmpty);
    });

    testWidgets('a server that announces it has the appointments', (t) async {
      final calendar = _SearchCalendar(
        result: EventSearchResult(upcoming: [_event('Wusel-Fest', _inDays(3))]),
      );
      final container = await _pump(
        t,
        calendar: calendar,
        config: _server(const ['search']),
      );
      expect(container.read(eventSearchSupportedProvider), isTrue);
      await _openSearch(t);
      await _type(t, 'wusel');

      expect(calendar.asked, ['wusel']);
      expect(_inSection('events', 'Wusel-Fest'), findsOneWidget);
    });
  });

  group('from the calendar', () {
    /// Opens the search from the Calendar tab, as a phone or a tablet shows it.
    Future<_SearchCalendar> openFromCalendar(
      WidgetTester t, {
      required Size size,
      AppConfig? config,
    }) async {
      final calendar = _SearchCalendar(
        result: EventSearchResult(
          upcoming: [
            for (var i = 1; i <= 7; i++) _event('Wusel-Fest $i', _inDays(i)),
          ],
          past: [_event('Wusel-Rückblick', _inDays(-20))],
        ),
      );
      final container = await _pump(
        t,
        calendar: calendar,
        size: size,
        config: config,
      );
      container.read(homeTabProvider.notifier).select(HomeTab.calendar);
      await t.pumpAndSettle();
      return calendar;
    }

    Finder searchPage() => find.byType(SearchPage);

    testWidgets('a phone has the entry in the view menu', (t) async {
      await openFromCalendar(t, size: const Size(390, 844));
      expect(find.byKey(const ValueKey('home-search')), findsNothing);
      expect(find.byKey(const ValueKey('calendar-search')), findsNothing);

      await t.tap(find.byTooltip(_de.calendarChooseView));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar-search')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-search')),
          matching: find.text(_de.searchEventsTitle),
        ),
        findsOneWidget,
      );

      await t.tap(find.byKey(const ValueKey('calendar-search')));
      await t.pumpAndSettle();

      expect(searchPage(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(_de.searchEventsTitle),
        ),
        findsOneWidget,
      );
      expect(find.text(_de.searchEventsHint), findsOneWidget);
      expect(find.text(_de.searchEventsIntro), findsOneWidget);
    });

    testWidgets('a wide bar has a button of its own', (t) async {
      await openFromCalendar(t, size: const Size(1348, 900));
      expect(find.byKey(const ValueKey('home-search')), findsNothing);
      final button = find.byKey(const ValueKey('calendar-search'));
      expect(button, findsOneWidget);
      expect(t.widget(button), isA<IconButton>());

      await t.tap(button);
      await t.pumpAndSettle();

      expect(searchPage(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(_de.searchEventsTitle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('only the appointments are searched, and all of them shown', (
      t,
    ) async {
      final calendar = await openFromCalendar(t, size: const Size(1348, 900));
      await t.tap(find.byKey(const ValueKey('calendar-search')));
      await t.pumpAndSettle();
      await _type(t, 'wusel');

      expect(calendar.asked, ['wusel']);
      // Seven appointments, none cut.
      expect(_rows('events'), findsNWidgets(7));
      expect(find.byKey(const ValueKey('search-all-events')), findsNothing);
      expect(_inSection('events-past', 'Wusel-Rückblick'), findsOneWidget);
      // Nothing of the rest: the family's chores, recipes, items and settings.
      expect(_section('tasks'), findsNothing);
      expect(_section('recipes'), findsNothing);
      expect(_section('shopping'), findsNothing);
      expect(_section('settings'), findsNothing);
      expect(find.byKey(const ValueKey('search-chore-d1')), findsNothing);
    });

    testWidgets('a query without appointments shows the empty line', (t) async {
      final calendar = await openFromCalendar(t, size: const Size(1348, 900));
      calendar.result = const EventSearchResult();
      await t.tap(find.byKey(const ValueKey('calendar-search')));
      await t.pumpAndSettle();
      // The family has a chore called Wusel füttern, but this is the calendar's search.
      await _type(t, 'wusel');

      expect(find.byKey(const ValueKey('search-empty')), findsOneWidget);
    });

    testWidgets(
      'a server without the function offers the search over the rest',
      (t) async {
        await openFromCalendar(
          t,
          size: const Size(1348, 900),
          config: _server(const ['trips']),
        );
        final button = find.byKey(const ValueKey('calendar-search'));
        expect(button, findsOneWidget);

        await t.tap(button);
        await t.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(_de.searchTitle),
          ),
          findsOneWidget,
        );
        await _type(t, 'wusel');
        expect(find.byKey(const ValueKey('search-chore-d1')), findsOneWidget);
      },
    );
  });

  group('the way in from the home', () {
    testWidgets('an adult has the button on Today, and it opens the search', (
      t,
    ) async {
      await _pump(t);
      expect(find.byKey(const ValueKey('home-search')), findsOneWidget);

      await _openSearch(t);

      expect(find.byType(SearchPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(_de.searchTitle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the other tabs have it too, the calendar does not', (t) async {
      final container = await _pump(t);
      for (final tab in HomeTab.values) {
        container.read(homeTabProvider.notifier).select(tab);
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('home-search')),
          tab == HomeTab.calendar ? findsNothing : findsOneWidget,
          reason: tab.name,
        );
      }
    });

    testWidgets('Back leaves the search where it was opened', (t) async {
      final container = await _pump(t);
      container.read(homeTabProvider.notifier).select(HomeTab.meals);
      await t.pumpAndSettle();
      await _openSearch(t);

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();

      expect(find.byType(SearchPage), findsNothing);
      expect(container.read(homeTabProvider), HomeTab.meals);
    });

    testWidgets('the children have no such button', (t) async {
      final container = await _pump(
        t,
        identity: FakeIdentityRepository(
          current: device(
            deviceClass: DeviceClass.shared,
            register: UiRegister.kid,
            profileId: null,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('home-search')), findsNothing);
      await unmountApp(t, container);
    });

    testWidgets('the wall has no such button', (t) async {
      final container = await _pump(
        t,
        identity: FakeIdentityRepository(
          current: device(
            deviceClass: DeviceClass.kiosk,
            register: UiRegister.kiosk,
            profileId: null,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('home-search')), findsNothing);
      await unmountApp(t, container);
    });
  });

  group('choosing a result', () {
    testWidgets('an appointment shows its day in the calendar', (t) async {
      final day = _inDays(10);
      final calendar = _SearchCalendar(
        result: EventSearchResult(upcoming: [_event('Wusel-Fest', day)]),
      );
      final container = await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'wusel');

      await t.tap(
        find.byKey(ValueKey('search-event-Wusel-Fest|${_isoDay(10)}')),
      );
      await t.pumpAndSettle();

      expect(find.byType(SearchPage), findsNothing);
      expect(container.read(homeTabProvider), HomeTab.calendar);
      final view = container.read(calendarViewProvider);
      expect(view.mode, CalendarMode.day);
      expect(view.anchor, day);
    });

    testWidgets('an appointment that is running shows today', (t) async {
      final calendar = _SearchCalendar(
        result: EventSearchResult(
          upcoming: [_event('Wusel-Lager', _inDays(-2), last: _inDays(1))],
        ),
      );
      final container = await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'wusel');

      await t.tap(
        find.byKey(ValueKey('search-event-Wusel-Lager|${_isoDay(-2)}')),
      );
      await t.pumpAndSettle();

      expect(container.read(homeTabProvider), HomeTab.calendar);
      expect(container.read(calendarViewProvider).anchor, _today());
    });

    testWidgets('a shopping item shows its list in the Shopping tab', (
      t,
    ) async {
      final container = await _pump(t);
      await _openSearch(t);
      await _type(t, 'wusel');

      await t.tap(find.byKey(const ValueKey('search-item-i1')));
      await t.pumpAndSettle();

      expect(find.byType(SearchPage), findsNothing);
      expect(container.read(homeTabProvider), HomeTab.shopping);
      expect(container.read(selectedListIdProvider), 'l1');
    });

    testWidgets('a recipe opens its view', (t) async {
      await _pump(t);
      await _openSearch(t);
      await _type(t, 'wusel');

      await t.tap(find.byKey(const ValueKey('search-recipe-rc1')));
      await t.pumpAndSettle();

      expect(find.byType(RecipeViewPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Wusel-Waffeln'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a chore opens its editor', (t) async {
      await _pump(t);
      await _openSearch(t);
      await _type(t, 'wusel');

      await t.tap(find.byKey(const ValueKey('search-chore-d1')));
      await t.pumpAndSettle();

      expect(find.byType(TaskEditorDialog), findsOneWidget);
      expect(find.text('Wusel füttern'), findsWidgets);
    });

    testWidgets('a reward opens its editor', (t) async {
      await _pump(t);
      await _openSearch(t);
      await _type(t, 'wusel');

      await t.tap(find.byKey(const ValueKey('search-reward-r1')));
      await t.pumpAndSettle();

      expect(find.byType(RewardEditorDialog), findsOneWidget);
    });

    testWidgets('a setting opens its page with the row in view', (t) async {
      final container = await _pump(t);
      await _openSearch(t);
      await _type(t, 'wusel');

      final hit = find.byKey(
        const ValueKey('settings-hit-personal-member.wusel'),
      );
      await t.ensureVisible(hit);
      await t.tap(hit);
      await t.pumpAndSettle();

      expect(
        container
            .read(routerProvider)
            .routeInformationProvider
            .value
            .uri
            .toString(),
        '/settings/personal?row=member.wusel',
      );
      expect(
        find.byKey(const ValueKey('settings-row-focused')),
        findsOneWidget,
      );
    });
  });

  group('when the appointments cannot be searched', () {
    testWidgets('a failure row with a retry shows beside the local results', (
      t,
    ) async {
      final calendar = _SearchCalendar()..failure = const NetworkFailure();
      await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'wusel');
      final failed = find.byKey(const ValueKey('search-events-failed'));
      expect(failed, findsOneWidget);
      // One try, no retries under the progress line: the row says so at once.
      expect(calendar.asked, hasLength(1));
      expect(
        find.descendant(of: failed, matching: find.text(_de.retry)),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // What the app holds itself is not held back.
      expect(find.byKey(const ValueKey('search-chore-d1')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-recipe-rc1')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-empty')), findsNothing);
    });

    testWidgets('the retry asks again and shows the answer', (t) async {
      final calendar = _SearchCalendar(
        result: EventSearchResult(upcoming: [_event('Wusel-Fest', _inDays(3))]),
      )..failure = const NetworkFailure();
      await _pump(t, calendar: calendar);
      await _openSearch(t);
      await _type(t, 'wusel');
      expect(
        find.byKey(const ValueKey('search-events-failed')),
        findsOneWidget,
      );

      calendar.failure = null;
      await t.tap(find.text(_de.retry));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('search-events-failed')), findsNothing);
      expect(_inSection('events', 'Wusel-Fest'), findsOneWidget);
    });
  });
}

/// The day [offset] days from today as the id of an appointment spells it.
String _isoDay(int offset) {
  final d = _inDays(offset);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
