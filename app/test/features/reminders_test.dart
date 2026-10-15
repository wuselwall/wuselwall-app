import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';
import 'package:wuselwall/features/reminders/domain/reminder_plan.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_notifications.dart';
import '../support/fake_tasks.dart';
import '../support/fakes.dart';

final _de = AppLocalizationsDe();

/// A timed or all-day appointment in the calendar's shape.
Occurrence occ({
  required String title,
  required DateTime day,
  TimeOfDay? from,
  List<String> attendees = const [],
  bool presence = false,
  bool allDay = false,
  EventStatus status = EventStatus.confirmed,
}) {
  final d = dateOnly(day);
  final timed = from != null && !allDay;
  return Occurrence(
    id: '$title|${isoDate(d)}',
    eventId: 'e-$title',
    calendarId: 'cal',
    title: title,
    kind: presence ? EventKind.presence : EventKind.appointment,
    status: status,
    importance: Importance.normal,
    allDay: !timed,
    start: timed ? DateTime(d.year, d.month, d.day, from.hour, from.minute) : d,
    end: timed
        ? DateTime(d.year, d.month, d.day, from.hour, from.minute + 30)
        : DateTime(d.year, d.month, d.day + 1),
    localStartDate: d,
    localEndDate: d,
    localStarts: timed ? from : null,
    attendeeIds: attendees,
  );
}

/// An open chore due on [day] for [assignee].
TaskInstance chore(String title, DateTime day, String assignee) => TaskInstance(
  id: title,
  title: title,
  kind: TaskKind.duty,
  points: 1,
  dueOn: day,
  opensOn: day,
  closesOn: day,
  status: InstanceStatus.open,
  completionCount: 0,
  requiresVerification: false,
  assignedProfileId: assignee,
);

/// `settings` rows as the server returns them: the morning summary on at 07:00 by
/// default, the event reminder off, unless [eventMinutes] overrides it for the guardian.
List<Map<String, dynamic>> settingRows({int? eventMinutes}) {
  Map<String, dynamic> row({
    required String key,
    required String type,
    required Object? defaultValue,
    required Object? value,
    required Map<String, dynamic> constraints,
    String? profileId,
  }) => {
    'key': key,
    'scope': 'member',
    'type': type,
    'constraints': constraints,
    'self_service': true,
    'default_value': defaultValue,
    'value': value,
    'is_default': profileId == null,
    'profile_id': profileId,
    'device_id': null,
  };
  return [
    row(
      key: 'notify.morning_summary',
      type: 'time',
      defaultValue: '07:00',
      value: '07:00',
      constraints: {'nullable': true},
    ),
    row(
      key: 'notify.event_reminder',
      type: 'integer',
      defaultValue: null,
      value: null,
      constraints: {'min': 5, 'max': 120, 'nullable': true},
    ),
    if (eventMinutes != null)
      row(
        key: 'notify.event_reminder',
        type: 'integer',
        defaultValue: null,
        value: eventMinutes,
        constraints: {'min': 5, 'max': 120, 'nullable': true},
        profileId: guardianId,
      ),
  ];
}

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset);
}

void main() {
  group('planReminders', () {
    final now = DateTime(2026, 10, 14, 6);
    final today = DateTime(2026, 10, 14);
    const seven = TimeOfDay(hour: 7, minute: 0);

    ReminderPlan plan({
      TimeOfDay? morningAt = seven,
      int? eventMinutes,
      List<Occurrence> occurrences = const [],
      List<TaskInstance> tasks = const [],
      DateTime? at,
    }) => planReminders(
      now: at ?? now,
      l10n: _de,
      actor: guardianId,
      morningAt: morningAt,
      eventMinutes: eventMinutes,
      occurrences: occurrences,
      tasks: tasks,
    );

    test(
      'the morning summary counts the day and names the first appointment',
      () {
        final result = plan(
          occurrences: [
            occ(
              title: 'Zahnarzt',
              day: today,
              from: const TimeOfDay(hour: 8, minute: 30),
              attendees: [guardianId],
            ),
            occ(
              title: 'Kino',
              day: today,
              from: const TimeOfDay(hour: 19, minute: 0),
              attendees: [kidId],
            ),
          ],
          tasks: [
            chore('Müll', today, guardianId),
            chore('Blumen', today, guardianId),
            chore('Lottas Tisch', today, kidId),
          ],
        );

        final summary = result.reminders.single;
        expect(summary.when, DateTime(2026, 10, 14, 7));
        expect(summary.title, 'Heute: 1 Termin, 2 Aufgaben');
        expect(summary.body, 'Als Erstes um 08:30: Zahnarzt');
      },
    );

    test(
      'a day with nothing gets no summary; a day with one appointment gets one',
      () {
        expect(plan().reminders, isEmpty);

        final tomorrow = DateTime(2026, 10, 15);
        final result = plan(
          occurrences: [
            occ(
              title: 'Zahnarzt',
              day: tomorrow,
              from: const TimeOfDay(hour: 9, minute: 0),
              attendees: [guardianId],
            ),
          ],
        );
        expect(result.reminders.single.when, DateTime(2026, 10, 15, 7));
        expect(result.reminders.single.title, 'Heute: 1 Termin');
      },
    );

    test('an all-day entry in the summary has no time', () {
      final result = plan(
        occurrences: [occ(title: 'Geburtstag', day: today, allDay: true)],
      );
      expect(result.reminders.single.body, 'Ganztägig: Geburtstag');
    });

    test('a switched-off summary sends no summary', () {
      final result = plan(
        morningAt: null,
        occurrences: [
          occ(
            title: 'Zahnarzt',
            day: today,
            from: const TimeOfDay(hour: 8, minute: 30),
            attendees: [guardianId],
          ),
        ],
        tasks: [chore('Müll', today, guardianId)],
      );
      expect(result.reminders, isEmpty);
    });

    test('event reminders fire minutes before the appointments of the actor and the family', () {
      final result = plan(
        morningAt: null,
        eventMinutes: 15,
        occurrences: [
          occ(
            title: 'Zahnarzt',
            day: today,
            from: const TimeOfDay(hour: 9, minute: 0),
            attendees: [guardianId],
          ),
          occ(
            title: 'Familienessen',
            day: today,
            from: const TimeOfDay(hour: 10, minute: 0),
          ),
          // Someone else's appointment, a presence entry, an all-day entry and a cancelled
          // event get nothing.
          occ(
            title: 'Kinderarzt',
            day: today,
            from: const TimeOfDay(hour: 11, minute: 0),
            attendees: [kidId],
          ),
          occ(
            title: 'Zuhause',
            day: today,
            from: const TimeOfDay(hour: 12, minute: 0),
            presence: true,
            attendees: [guardianId],
          ),
          occ(title: 'Feiertag', day: today, allDay: true),
          occ(
            title: 'Abgesagt',
            day: today,
            from: const TimeOfDay(hour: 13, minute: 0),
            attendees: [guardianId],
            status: EventStatus.cancelled,
          ),
        ],
      );

      expect(
        [for (final r in result.reminders) (r.title, r.when)],
        [
          ('Zahnarzt', DateTime(2026, 10, 14, 8, 45)),
          ('Familienessen', DateTime(2026, 10, 14, 9, 45)),
        ],
      );
      expect(result.reminders.first.body, 'Beginnt um 09:00');
    });

    test('reminders that are already past are left out', () {
      final result = plan(
        morningAt: null,
        eventMinutes: 15,
        at: DateTime(2026, 10, 14, 9, 30),
        occurrences: [
          occ(
            title: 'Früh',
            day: today,
            from: const TimeOfDay(hour: 9, minute: 0),
            attendees: [guardianId],
          ),
          occ(
            title: 'Später',
            day: today,
            from: const TimeOfDay(hour: 10, minute: 0),
            attendees: [guardianId],
          ),
        ],
      );
      expect(result.reminders.map((r) => r.title), ['Später']);
    });

    test('the plan keeps at most sixty notifications, the soonest first', () {
      final result = plan(
        morningAt: null,
        eventMinutes: 5,
        occurrences: [
          for (var m = 0; m < 70; m++)
            occ(
              title: 'T$m',
              day: DateTime(2026, 10, 15),
              from: TimeOfDay(hour: 7 + m ~/ 60, minute: m % 60),
              attendees: [guardianId],
            ),
        ],
      );
      expect(result.reminders, hasLength(maxReminders));
      expect(result.reminders.first.title, 'T0');
      final sorted = [...result.reminders]
        ..sort((a, b) => a.when.compareTo(b.when));
      expect(result.reminders, orderedEquals(sorted));
    });
  });

  group('the phone schedules and the Today row', () {
    testWidgets('nothing is scheduled without permission', (t) async {
      final notifications = FakeNotificationScheduler(granted: false);
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          notifications: notifications,
        ),
        tasks: FakeTasksApi(
          tables: {'settings': settingRows(eventMinutes: 15)},
        ),
        calendar: FakeCalendarRepository([
          occ(
            title: 'Zahnarzt',
            day: _day(1),
            from: const TimeOfDay(hour: 9, minute: 0),
            attendees: [guardianId],
          ),
        ]),
      );

      expect(notifications.active, isEmpty);
    });

    testWidgets(
      'a personal device schedules its summary and the event reminder',
      (t) async {
        final notifications = FakeNotificationScheduler();
        await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            notifications: notifications,
          ),
          tasks: FakeTasksApi(
            tables: {'settings': settingRows(eventMinutes: 15)},
          ),
          calendar: FakeCalendarRepository([
            occ(
              title: 'Zahnarzt',
              day: _day(1),
              from: const TimeOfDay(hour: 9, minute: 0),
              attendees: [guardianId],
            ),
          ]),
        );

        final tomorrow = _day(1);
        expect(
          notifications.active.map((n) => (n.title, n.when)),
          containsAll([
            (
              'Zahnarzt',
              DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 45),
            ),
            (
              _de.reminderMorningEventsOnly(1),
              DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 7),
            ),
          ]),
        );
      },
    );

    testWidgets('shared and kiosk devices never schedule', (t) async {
      final notifications = FakeNotificationScheduler();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(
            current: device(
              deviceClass: DeviceClass.kiosk,
              register: UiRegister.kiosk,
            ),
          ),
          notifications: notifications,
        ),
        tasks: FakeTasksApi(
          tables: {'settings': settingRows(eventMinutes: 15)},
        ),
        calendar: FakeCalendarRepository([
          occ(
            title: 'Zahnarzt',
            day: _day(1),
            from: const TimeOfDay(hour: 9, minute: 0),
            attendees: [guardianId],
          ),
        ]),
      );

      expect(notifications.active, isEmpty);
      await unmountApp(t, container);
    });

    testWidgets(
      'a reschedule replaces what is pending instead of adding to it',
      (t) async {
        final notifications = FakeNotificationScheduler();
        final container = await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            notifications: notifications,
          ),
          tasks: FakeTasksApi(
            tables: {'settings': settingRows(eventMinutes: 15)},
          ),
          calendar: FakeCalendarRepository([
            occ(
              title: 'Zahnarzt',
              day: _day(1),
              from: const TimeOfDay(hour: 9, minute: 0),
              attendees: [guardianId],
            ),
          ]),
        );
        final before = notifications.cancelAllCalls;
        expect(notifications.active, hasLength(2));

        container.invalidate(reminderPlanProvider);
        await t.pumpAndSettle();

        expect(notifications.cancelAllCalls, greaterThan(before));
        expect(notifications.active, hasLength(2));
      },
    );

    testWidgets('Today offers the row until it is dismissed', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          notifications: FakeNotificationScheduler(granted: false),
        ),
      );

      expect(find.text(_de.reminderStartLabel), findsOneWidget);
      await t.tap(find.text(_de.todayStartNotNeeded));
      await t.pumpAndSettle();
      expect(find.text(_de.reminderStartLabel), findsNothing);
    });

    testWidgets('tapping the row asks for permission and then schedules', (
      t,
    ) async {
      final notifications = FakeNotificationScheduler(granted: false);
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          notifications: notifications,
        ),
        tasks: FakeTasksApi(tables: {'settings': settingRows()}),
        calendar: FakeCalendarRepository([
          occ(
            title: 'Zahnarzt',
            day: _day(1),
            from: const TimeOfDay(hour: 9, minute: 0),
            attendees: [guardianId],
          ),
        ]),
      );

      await t.tap(find.text(_de.reminderStartLabel));
      await t.pumpAndSettle();

      expect(notifications.requests, 1);
      expect(find.text(_de.reminderStartLabel), findsNothing);
      expect(notifications.active, isNotEmpty);
    });

    testWidgets(
      'the row stays hidden for a member and where notifications are unavailable',
      (t) async {
        await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device(profileId: kidId)),
            notifications: FakeNotificationScheduler(granted: false),
          ),
        );
        expect(find.text(_de.reminderStartLabel), findsNothing);
      },
    );

    testWidgets(
      'Einstellungen → Erinnerungen shows the state and turns reminders on',
      (t) async {
        final notifications = FakeNotificationScheduler(granted: false);
        final container = await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            notifications: notifications,
          ),
          tasks: FakeTasksApi(tables: {'settings': settingRows()}),
        );
        container.read(routerProvider).go(Routes.reminders);
        await t.pumpAndSettle();

        expect(find.text(_de.reminderStatusOff), findsOneWidget);
        expect(find.text(_de.reminderLocalNote), findsOneWidget);
        expect(
          find.byKey(const ValueKey('setting-notify.morning_summary')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('setting-notify.event_reminder')),
          findsOneWidget,
        );

        await t.tap(
          find.widgetWithText(FilledButton, _de.reminderEnableAction),
        );
        await t.pumpAndSettle();

        expect(find.text(_de.reminderStatusOn), findsOneWidget);
        expect(notifications.requests, 1);
      },
    );
  });
}
