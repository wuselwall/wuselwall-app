import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_presence.dart';
import 'package:wuselwall/features/board/ui/details/child_week_detail.dart';
import 'package:wuselwall/features/board/ui/details/task_board_detail.dart';
import 'package:wuselwall/features/board/ui/week_board_page.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/application/child_view.dart';
import 'package:wuselwall/features/kid/ui/kid_home.dart';
import 'package:wuselwall/features/kid/ui/kid_points_page.dart';
import 'package:wuselwall/features/kid/ui/kid_simple_home.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';

/// The simple view of a child under twelve (specs/09 "The simple view"): what the kids'
/// tablet, the tablet for everyone and the wall show once such a child is chosen, and
/// what the family's two switches for children take away. The providers behind it are
/// in child_view_test.dart.
const _anna = 'p-anna'; // eight
const _ben = 'p-ben'; // thirteen

final _en = lookupAppLocalizations(const Locale('en'));

final _members = [
  const Member(
    id: guardianId,
    displayName: 'Papa',
    color: Color(0xFF2E7D6B),
    role: Role.guardian,
    active: true,
  ),
  Member(
    id: _anna,
    displayName: 'Anna',
    color: const Color(0xFFFF8800),
    role: Role.member,
    active: true,
    isChild: true,
    hasAccount: false,
    birthday: youngChildBirthday(),
  ),
  Member(
    id: _ben,
    displayName: 'Ben',
    color: const Color(0xFF1D4E89),
    role: Role.member,
    active: true,
    isChild: true,
    hasAccount: false,
    birthday: olderChildBirthday(),
  ),
];

/// The family's settings, which a test may change while the app runs.
class _Settings implements HouseholdSettingsRepository {
  _Settings(this.rows);

  List<SettingEntry> rows;

  @override
  Future<Result<List<SettingEntry>>> all() async => Ok(List.of(rows));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The demo catalogue with the family's two switches for children.
List<SettingEntry> _catalogue({
  required bool shopping,
  required bool calendar,
}) => [
  for (final e in demoSettingCatalogue())
    if (e.key == kidShoppingKey || e.key == kidCalendarKey)
      SettingEntry(
        key: e.key,
        scope: e.scope,
        type: e.type,
        constraints: e.constraints,
        selfService: e.selfService,
        defaultValue: e.defaultValue,
        value: e.key == kidShoppingKey ? shopping : calendar,
        isDefault: false,
      )
    else
      e,
];

DateTime _today() => DateTime(testNow().year, testNow().month, testNow().day);

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// An appointment of [day] at 15:00 for [who].
Occurrence _appointment(
  String id,
  String title,
  DateTime day,
  List<String> who,
) => Occurrence(
  id: id,
  eventId: 'e-$id',
  calendarId: 'c',
  title: title,
  kind: EventKind.appointment,
  status: EventStatus.confirmed,
  importance: Importance.normal,
  allDay: false,
  start: DateTime(day.year, day.month, day.day, 15),
  end: DateTime(day.year, day.month, day.day, 16),
  localStartDate: day,
  localEndDate: day,
  localStarts: const TimeOfDay(hour: 15, minute: 0),
  localEnds: const TimeOfDay(hour: 16, minute: 0),
  attendeeIds: who,
);

/// The week board of the wall, with the family in household order.
WeekBoard _wallBoard() {
  final today = testNow();
  final monday = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));
  return WeekBoard.fromJson({
    'week_start': _iso(monday),
    'today': _iso(today),
    'generated_at': today.toUtc().toIso8601String(),
    'members': [
      {
        'id': guardianId,
        'display_name': 'Papa',
        'color': '#2E7D6B',
        'kind': 'adult',
      },
      {
        'id': _anna,
        'display_name': 'Anna',
        'color': '#FF8800',
        'kind': 'child',
      },
      {'id': _ben, 'display_name': 'Ben', 'color': '#1D4E89', 'kind': 'child'},
    ],
    'presence': <Map<String, dynamic>>[],
    'timetables': <Map<String, dynamic>>[],
    'days': [
      for (var i = 0; i < 7; i++)
        {
          'date': _iso(monday.add(Duration(days: i))),
          'events': <Map<String, dynamic>>[],
          'busy_until': <Map<String, dynamic>>[],
          'school': <Map<String, dynamic>>[],
        },
    ],
    'open_tasks': [
      {'member_id': _anna, 'count': 1},
    ],
    'shopping_count': 0,
  });
}

/// The app of the running test, unmounted at its end: the wall keeps timers in its
/// container, and Flutter checks for pending timers before the container is disposed.
ProviderContainer? _running;

void _test(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets(name, (t) async {
    await body(t);
    final container = _running;
    if (container != null) await unmountApp(t, container);
    _running = null;
  });
}

Future<ProviderContainer> _pump(
  WidgetTester t, {
  DeviceClass deviceClass = DeviceClass.shared,
  UiRegister register = UiRegister.kid,
  bool shopping = false,
  bool calendar = true,
  FakeCalendarRepository? calendarRepository,
  FakeTasksApi? tasks,
  FakeBoardRepository? board,
  Size size = const Size(1000, 1600),
}) async {
  final container = await pumpApp(
    t,
    size: size,
    locale: const Locale('en'),
    overrides: [
      ...baseOverrides(
        identity: FakeIdentityRepository(
          current: device(deviceClass: deviceClass, register: register),
          members: _members,
        ),
        shopping: FakeShoppingRepository([item('i1', 'Milk')]),
      ),
      householdSettingsRepositoryProvider.overrideWithValue(
        _Settings(_catalogue(shopping: shopping, calendar: calendar)),
      ),
    ],
    calendar: calendarRepository,
    tasks: tasks,
    board: board,
  );
  _running = container;
  return container;
}

/// Takes the device as [who]: from the picker the kids' tablet shows to nobody, else
/// from the avatar bar, as a child does.
Future<void> _choose(WidgetTester t, String who) async {
  final picker = find.byKey(ValueKey('kid-pick-$who'));
  final avatar = picker.evaluate().isNotEmpty
      ? picker
      : find.byKey(ValueKey('avatar-$who')).last;
  await t.ensureVisible(avatar);
  await t.tap(avatar);
  await t.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester t, String key) async {
  final target = find.byKey(ValueKey(key));
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pumpAndSettle();
}

/// The labels of the adult home's destinations, in order.
List<String> _destinations(WidgetTester t) {
  final rail = find.byType(NavigationRail);
  if (rail.evaluate().isNotEmpty) {
    return [
      for (final d in t.widget<NavigationRail>(rail).destinations)
        (d.label as Text).data!,
    ];
  }
  return [
    for (final d in t.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    ))
      d.tooltip ?? '',
  ];
}

Finder get _simple => find.byType(KidSimpleHome);

/// The day buttons of the simple view, which are keyed `kid-simple-day-<n>`.
Finder get _dayButtons => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      RegExp(r'^kid-simple-day-\d$')
          .hasMatch((w.key! as ValueKey<String>).value),
);

void main() {
  group('the kids\' tablet', () {
    _test('shows the simple view to a child of eight, not the tab bar', (
      t,
    ) async {
      await _pump(t);
      expect(find.byType(KidHome), findsOneWidget);
      expect(_simple, findsNothing);

      await _choose(t, _anna);

      expect(_simple, findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(KidHome), findsNothing);
    });

    _test('shows the tab bar to a child of thirteen, not the simple view', (
      t,
    ) async {
      await _pump(t);

      await _choose(t, _ben);

      expect(find.byType(KidHome), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(_simple, findsNothing);
    });

    _test('changes view as the device is handed from one child to the next', (
      t,
    ) async {
      await _pump(t);
      await _choose(t, _anna);
      expect(_simple, findsOneWidget);

      await _choose(t, _ben);
      expect(_simple, findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);

      await _choose(t, _anna);
      expect(_simple, findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    _test('offers four days with the calendar switched on', (t) async {
      await _pump(t, calendar: true);
      await _choose(t, _anna);

      expect(_dayButtons, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(ValueKey('kid-simple-day-$i')), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kid-simple-day-0')),
          matching: find.text(_en.kidTodayMarker),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kid-simple-day-1')),
          matching: find.text(_en.kidSimpleTomorrow),
        ),
        findsOneWidget,
      );
    });

    _test('offers no day buttons with the calendar switched off', (t) async {
      await _pump(t, calendar: false);
      await _choose(t, _anna);

      expect(_simple, findsOneWidget);
      expect(_dayButtons, findsNothing);
      // Today stays: the chores of the day are still there.
      expect(find.text(_en.kidTasksTitle), findsOneWidget);
    });

    _test('shows only the child\'s own appointments, and tomorrow\'s on tap', (
      t,
    ) async {
      final today = _today();
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      await _pump(
        t,
        calendarRepository: FakeCalendarRepository([
          _appointment('a-today', 'Dentist Anna', today, [_anna]),
          _appointment('a-tomorrow', 'Swimming Anna', tomorrow, [_anna]),
          _appointment('b-today', 'Football Ben', today, [_ben]),
          _appointment('p-today', 'Meeting Papa', today, [guardianId]),
          _appointment('b-tomorrow', 'Piano Ben', tomorrow, [_ben]),
        ]),
        tasks: FakeTasksApi(
          tables: {
            'task_instances': [
              instanceRow(
                id: 'i-table',
                title: 'Lay the table',
                assignee: _anna,
                dueOn: _iso(today),
              ),
            ],
          },
        ),
      );
      await _choose(t, _anna);

      // Today: her appointment and her chores; nobody else's.
      expect(find.text('Dentist Anna'), findsOneWidget);
      expect(find.text('Football Ben'), findsNothing);
      expect(find.text('Meeting Papa'), findsNothing);
      expect(find.text('Swimming Anna'), findsNothing);
      expect(find.text(_en.kidTasksTitle), findsOneWidget);

      await _tapKey(t, 'kid-simple-day-1');

      expect(find.text('Swimming Anna'), findsOneWidget);
      expect(find.text('Piano Ben'), findsNothing);
      expect(find.text('Dentist Anna'), findsNothing);
      // The chores are today's: tomorrow has none, and its own heading.
      expect(find.text(_en.kidTasksTitle), findsNothing);
      expect(find.text(_en.kidSimpleAppointments), findsOneWidget);

      await _tapKey(t, 'kid-simple-day-0');
      expect(find.text('Dentist Anna'), findsOneWidget);
      expect(find.text(_en.kidTasksTitle), findsOneWidget);
    });

    _test('has the Shopping card only where the family switched it on', (
      t,
    ) async {
      await _pump(t, shopping: false);
      await _choose(t, _anna);
      expect(find.byKey(const ValueKey('kid-simple-shopping')), findsNothing);
    });

    _test('opens the shopping list from its card and comes back', (t) async {
      await _pump(t, shopping: true);
      await _choose(t, _anna);
      expect(find.byKey(const ValueKey('kid-simple-days')), findsOneWidget);
      expect(find.byKey(const ValueKey('kid-simple-back')), findsNothing);

      await _tapKey(t, 'kid-simple-shopping');

      expect(find.byType(ShoppingBody), findsOneWidget);
      expect(find.byKey(const ValueKey('kid-simple-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('kid-simple-days')), findsNothing);

      await _tapKey(t, 'kid-simple-back');

      expect(find.byKey(const ValueKey('kid-simple-days')), findsOneWidget);
      expect(find.byType(ShoppingBody), findsNothing);
      expect(find.byKey(const ValueKey('kid-simple-back')), findsNothing);
    });

    _test('opens the points from the pill and comes back', (t) async {
      await _pump(t);
      await _choose(t, _anna);
      expect(find.byType(KidPointsPage), findsNothing);

      await _tapKey(t, 'kid-simple-points');

      expect(find.byType(KidPointsPage), findsOneWidget);
      expect(find.byKey(const ValueKey('kid-simple-back')), findsOneWidget);

      await _tapKey(t, 'kid-simple-back');

      expect(find.byType(KidPointsPage), findsNothing);
      expect(find.byKey(const ValueKey('kid-simple-days')), findsOneWidget);
    });
  });

  group('the tablet for everyone', () {
    _test('offers Shopping only to an adult where the family keeps it back', (
      t,
    ) async {
      await _pump(t, register: UiRegister.adult, shopping: false);

      // Nobody has chosen: a child may be standing there.
      expect(_destinations(t), contains(_en.calendarTitle));
      expect(_destinations(t), isNot(contains(_en.shoppingNavLabel)));

      await _choose(t, guardianId);

      expect(_destinations(t), contains(_en.shoppingNavLabel));
      expect(_destinations(t), hasLength(6));
    });

    _test('shows the simple view to a child of eight', (t) async {
      await _pump(t, register: UiRegister.adult);
      expect(find.byType(NavigationRail), findsOneWidget);

      await _choose(t, _anna);

      expect(_simple, findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    _test('gives a child of thirteen the adult tabs without Shopping, and a '
        'calendar of their own', (t) async {
      final today = _today();
      await _pump(
        t,
        register: UiRegister.adult,
        shopping: false,
        calendarRepository: FakeCalendarRepository([
          _appointment('b-today', 'Football Ben', today, [_ben]),
          _appointment('a-today', 'Dentist Anna', today, [_anna]),
          _appointment('p-today', 'Meeting Papa', today, [guardianId]),
        ]),
      );

      await _choose(t, _ben);

      expect(_simple, findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(_destinations(t), isNot(contains(_en.shoppingNavLabel)));
      expect(_destinations(t), contains(_en.calendarTitle));

      await openTab(t, _en.calendarTitle);

      expect(find.text(_en.calendarChildDays), findsOneWidget);
      // Only his own appointments: the others' are not drawn.
      expect(find.text('Football Ben'), findsOneWidget);
      expect(find.text('Dentist Anna'), findsNothing);
      expect(find.text('Meeting Papa'), findsNothing);
    });

    _test('gives an adult the whole calendar, without the child\'s bar', (
      t,
    ) async {
      await _pump(t, register: UiRegister.adult);
      await _choose(t, guardianId);

      await openTab(t, _en.calendarTitle);

      expect(find.text(_en.calendarChildDays), findsNothing);
    });
  });

  group('the wall', () {
    Future<ProviderContainer> pumpWall(
      WidgetTester t, {
      bool shopping = false,
    }) => _pump(
      t,
      deviceClass: DeviceClass.kiosk,
      register: UiRegister.kiosk,
      shopping: shopping,
      board: FakeBoardRepository(_wallBoard()),
      tasks: FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(
              id: 'i-table',
              title: 'Lay the table',
              assignee: _anna,
              dueOn: _iso(testNow()),
            ),
          ],
        },
      ),
    );

    Finder nameOf(String name) => find.descendant(
      of: find.byType(PresenceRows),
      matching: find.text(name),
    );

    String? acting(ProviderContainer c) => c.read(actingProfileProvider);

    _test('a tap on a child of eight opens their simple view and the way back '
        'to the week', (t) async {
      final c = await pumpWall(t);
      expect(find.byType(WeekBoardPage), findsOneWidget);
      expect(acting(c), isNull);

      await t.tap(nameOf('Anna'));
      await t.pumpAndSettle();

      expect(acting(c), _anna);
      expect(_simple, findsOneWidget);
      expect(find.byType(WeekBoardPage), findsNothing);
      expect(find.byKey(const ValueKey('kid-simple-week')), findsOneWidget);
      // It is the wall's simple view: the wall itself is still a wall.
      expect(find.text(_en.boardBackToWeek), findsOneWidget);

      await _tapKey(t, 'kid-simple-week');

      expect(acting(c), isNull);
      expect(_simple, findsNothing);
      expect(find.byType(WeekBoardPage), findsOneWidget);
    });

    _test('a tap on a child of thirteen opens the timetable, nobody acts', (
      t,
    ) async {
      final c = await pumpWall(t);

      await t.tap(nameOf('Ben'));
      await t.pumpAndSettle();

      expect(find.byType(ChildWeekDetailBody), findsOneWidget);
      expect(acting(c), isNull);
      expect(_simple, findsNothing);
      expect(find.byType(WeekBoardPage), findsOneWidget);
    });

    _test('for an adult who chose their name, a child of eight\'s name opens '
        'the timetable, where things to bring are noted', (t) async {
      final c = await pumpWall(t);
      c.read(actingProfileProvider.notifier).select(guardianId);
      await t.pump();

      await t.tap(nameOf('Anna'));
      await t.pumpAndSettle();

      expect(find.byType(ChildWeekDetailBody), findsOneWidget);
      expect(acting(c), guardianId);
      expect(_simple, findsNothing);
    });

    _test('a tap on an adult opens their week, nobody acts', (t) async {
      final c = await pumpWall(t);

      await t.tap(nameOf('Papa'));
      await t.pumpAndSettle();

      expect(acting(c), isNull);
      expect(_simple, findsNothing);
    });

    _test(
      'the shopping list asks for an adult where the family keeps it back',
      (t) async {
        final c = await pumpWall(t, shopping: false);

        await t.tap(find.text(_en.boardShoppingList));
        await t.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('wall-shopping-adults')),
          findsOneWidget,
        );
        expect(find.text(_en.boardShoppingAskAdult), findsOneWidget);
        expect(find.byType(ShoppingBody), findsNothing);

        c.read(actingProfileProvider.notifier).select(guardianId);
        await t.pumpAndSettle();

        expect(find.byType(ShoppingBody), findsOneWidget);
        expect(
          find.byKey(const ValueKey('wall-shopping-adults')),
          findsNothing,
        );
      },
    );

    _test('the shopping list asks for an adult when an older child is acting', (
      t,
    ) async {
      final c = await pumpWall(t, shopping: false);
      c.read(actingProfileProvider.notifier).select(_ben);
      await t.pumpAndSettle();

      await t.tap(find.text(_en.boardShoppingList));
      await t.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('wall-shopping-adults')),
        findsOneWidget,
      );
      expect(find.byType(ShoppingBody), findsNothing);
    });

    _test('the shopping list opens at once where the family allows it', (
      t,
    ) async {
      await pumpWall(t, shopping: true);

      await t.tap(find.text(_en.boardShoppingList));
      await t.pumpAndSettle();

      expect(find.byType(ShoppingBody), findsOneWidget);
      expect(find.byKey(const ValueKey('wall-shopping-adults')), findsNothing);
    });

    _test('an open chore board makes way for a child of eight who chooses '
        'their name in it', (t) async {
      final c = await pumpWall(t);
      await t.tap(find.text(_en.boardOpenToday));
      await t.pumpAndSettle();
      expect(find.byType(TaskBoardDetailBody), findsOneWidget);
      expect(_simple, findsNothing);

      await _choose(t, _anna);

      expect(acting(c), _anna);
      expect(find.byType(TaskBoardDetailBody), findsNothing);
      expect(_simple, findsOneWidget);
    });

    _test('an open shopping list makes way for a child of eight too', (
      t,
    ) async {
      final c = await pumpWall(t, shopping: true);
      await t.tap(find.text(_en.boardShoppingList));
      await t.pumpAndSettle();
      expect(find.byType(ShoppingBody), findsOneWidget);

      await _choose(t, _anna);

      expect(acting(c), _anna);
      expect(find.byType(ShoppingBody), findsNothing);
      expect(_simple, findsOneWidget);
      // With the list on, the card to it is in the simple view.
      expect(find.byKey(const ValueKey('kid-simple-shopping')), findsOneWidget);
    });

    _test('an open detail stays when a child of thirteen or an adult chooses '
        'their name', (t) async {
      final c = await pumpWall(t);
      await t.tap(find.text(_en.boardOpenToday));
      await t.pumpAndSettle();

      await _choose(t, _ben);
      expect(acting(c), _ben);
      expect(find.byType(TaskBoardDetailBody), findsOneWidget);

      await _choose(t, guardianId);
      expect(acting(c), guardianId);
      expect(find.byType(TaskBoardDetailBody), findsOneWidget);
      expect(_simple, findsNothing);
    });
  });

  group('the family\'s switches', () {
    // Settings the app cannot read are not a reason to hide the child's days.
    _test('a failing settings read keeps the days and the shopping card', (
      t,
    ) async {
      final container = await pumpApp(
        t,
        locale: const Locale('en'),
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(
              current: device(
                deviceClass: DeviceClass.shared,
                register: UiRegister.kid,
              ),
              members: _members,
            ),
            shopping: FakeShoppingRepository([item('i1', 'Milk')]),
          ),
          householdSettingsRepositoryProvider.overrideWithValue(
            _FailingSettings(),
          ),
        ],
      );
      _running = container;
      await _choose(t, _anna);

      expect(_dayButtons, findsNWidgets(4));
      expect(find.byKey(const ValueKey('kid-simple-shopping')), findsOneWidget);
    });
  });
}

/// Settings the device cannot read.
class _FailingSettings implements HouseholdSettingsRepository {
  @override
  Future<Result<List<SettingEntry>>> all() async => const Err(NetworkFailure());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
