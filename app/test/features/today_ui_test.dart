import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';
import 'package:wuselwall/l10n/generated/app_localizations_en.dart';
import 'package:wuselwall/l10n/generated/app_localizations_es.dart';
import 'package:wuselwall/l10n/generated/app_localizations_fr.dart';

import '../support/fake_getting_started.dart';
import '../support/fake_meals.dart';
import '../support/fake_tasks.dart';
import '../support/fakes.dart';

final _de = AppLocalizationsDe();

/// Today as a `yyyy-mm-dd` string, the form the task rows use.
String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

const _card = [
  GettingStartedItem(item: StartItem.connectTablet, done: true),
  GettingStartedItem(item: StartItem.setPin, done: true),
  GettingStartedItem(item: StartItem.wallDisplay, done: false),
  GettingStartedItem(item: StartItem.subscribeFeed, done: false),
];

void main() {
  testWidgets('Today is the default tab for an adult, and shows the agenda', (
    t,
  ) async {
    final today = _today;
    final slot = warmSlotOf(today, const []);
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      tasks: FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(
              id: 't-muell',
              title: 'Müll rausbringen',
              assignee: guardianId,
              dueOn: _ymd(today),
              points: 2,
            ),
            // Someone else's chore: not on this list.
            instanceRow(
              id: 't-anna',
              title: 'Blumen gießen',
              assignee: kidId,
              dueOn: _ymd(today),
            ),
          ],
        },
      ),
      meals: FakeMealsRepository(
        entries: [
          MealEntry(
            id: 'm-warm',
            onDate: today,
            slot: slot,
            title: 'Kartoffelsuppe',
          ),
        ],
      ),
    );

    final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    expect(find.text(_de.todayTasksTitle), findsOneWidget);
    expect(find.text('Müll rausbringen'), findsOneWidget);
    expect(find.text('Blumen gießen'), findsNothing);
    expect(
      find.text(
        _de.todayMealLine(
          slot == PlanSlot.dinner ? _de.mealsSlotDinner : _de.mealsSlotLunch,
          'Kartoffelsuppe',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(_de.todayMealTitle), findsOneWidget);
  });

  testWidgets(
    'a timed appointment stays on one readable line at 1.5 text scale',
    (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() => t.platformDispatcher.clearTextScaleFactorTestValue());
      await pumpApp(
        t,
        size: const Size(390, 844),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        calendar: FakeCalendarRepository([
          _todayEvent(start: const TimeOfDay(hour: 16, minute: 0)),
        ]),
      );

      final time = find.text('16:00');
      expect(time, findsOneWidget);
      expect(t.getSize(time).width, greaterThan(56));
      expect(find.text('Dentist appointment'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  for (final sample in <(Locale, String)>[
    (const Locale('de'), AppLocalizationsDe().todayAllDay),
    (const Locale('en'), AppLocalizationsEn().todayAllDay),
    (const Locale('fr'), AppLocalizationsFr().todayAllDay),
    (const Locale('es'), AppLocalizationsEs().todayAllDay),
  ]) {
    testWidgets('all-day appointment label fits in ${sample.$1.languageCode}', (
      t,
    ) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(
        t,
        locale: sample.$1,
        size: const Size(390, 844),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        calendar: FakeCalendarRepository([_todayEvent(allDay: true)]),
      );
      final label = find.text(sample.$2);
      expect(label, findsOneWidget);
      expect(t.getSize(label).width, greaterThan(56));
      expect(t.widget<Text>(label).maxLines, isNull);
      expect(t.widget<Text>(label).overflow, isNull);
      expect(find.text('Dentist appointment'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('the card shows its items and the progress, open items first', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      gettingStarted: FakeGettingStartedRepository(_card),
    );

    expect(find.text(_de.todayStartTitle), findsOneWidget);
    expect(find.text('2 von 4'), findsOneWidget);
    expect(find.text(_de.todayStartWallDisplay), findsOneWidget);
    expect(find.text(_de.todayStartSubscribeFeed), findsOneWidget);
    expect(find.text(_de.todayStartConnectTablet), findsOneWidget);
    expect(find.text(_de.todayStartNotNeeded), findsNWidgets(2));
  });

  testWidgets('dismissing an item calls the repository and removes it', (
    t,
  ) async {
    final repo = FakeGettingStartedRepository(_card);
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      gettingStarted: repo,
    );

    await t.tap(find.text(_de.todayStartNotNeeded).first);
    await t.pumpAndSettle();

    expect(repo.dismissed.single, (
      actor: guardianId,
      item: StartItem.wallDisplay,
    ));
    expect(find.text(_de.todayStartWallDisplay), findsNothing);
    expect(find.text('2 von 3'), findsOneWidget);
  });

  testWidgets('the card is hidden when everything is done', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      gettingStarted: FakeGettingStartedRepository(const [
        GettingStartedItem(item: StartItem.connectTablet, done: true),
        GettingStartedItem(item: StartItem.setPin, done: true),
      ]),
    );

    expect(find.text(_de.todayStartTitle), findsNothing);
  });

  testWidgets('a child never sees the card or the adult Today tab', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(
          current: device(
            deviceClass: DeviceClass.shared,
            register: UiRegister.kid,
          ),
        ),
      ),
      gettingStarted: FakeGettingStartedRepository(_card),
    );

    expect(find.text(_de.todayStartTitle), findsNothing);
    expect(find.text(_de.todayAgendaTitle), findsNothing);
    expect(find.text(_de.todayEmpty), findsNothing);
  });

  testWidgets('an empty day says one friendly line and no card', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );

    expect(find.text(_de.todayEmpty), findsOneWidget);
    expect(find.text(_de.todayStartTitle), findsNothing);
    expect(find.text(_de.todayAgendaTitle), findsNothing);
  });

  testWidgets('ticking a chore on Today sends it as the acting profile', (
    t,
  ) async {
    final tasks = FakeTasksApi(
      tables: {
        'task_instances': [
          instanceRow(
            id: 't-muell',
            title: 'Müll rausbringen',
            assignee: guardianId,
            dueOn: _ymd(_today),
          ),
        ],
      },
    );
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      tasks: tasks,
    );

    await t.tap(find.byTooltip(_de.tasksActionTick));
    await t.pumpAndSettle();

    final call = tasks.named('task_complete').single;
    expect(call.params?['p_actor'], guardianId);
    expect(find.text(_de.tasksUndo), findsOneWidget);
  });

  testWidgets('Erste Schritte in the settings brings the card back on Today', (
    t,
  ) async {
    final repo = FakeGettingStartedRepository(_card);
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      gettingStarted: repo,
    );

    await t.tap(find.byIcon(Icons.settings));
    await t.pumpAndSettle();
    await openSettingsGroup(t, SettingsGroup.help);
    await t.tap(find.text(_de.settingsGettingStarted));
    await t.pumpAndSettle();

    expect(repo.restored, [guardianId]);
    final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    expect(find.text(_de.todayStartTitle), findsOneWidget);
  });
}

Occurrence _todayEvent({TimeOfDay? start, bool allDay = false}) {
  final day = _today;
  final end = start == null
      ? day.add(const Duration(days: 1))
      : DateTime(day.year, day.month, day.day, start.hour + 1, start.minute);
  return Occurrence(
    id: 'today-event',
    eventId: 'event',
    calendarId: 'calendar',
    title: 'Dentist appointment',
    kind: EventKind.appointment,
    status: EventStatus.confirmed,
    importance: Importance.normal,
    allDay: allDay,
    start: start == null
        ? day
        : DateTime(day.year, day.month, day.day, start.hour, start.minute),
    end: end,
    localStartDate: day,
    localEndDate: day,
    localStarts: start,
    localEnds: start == null
        ? null
        : TimeOfDay(hour: start.hour + 1, minute: start.minute),
  );
}
