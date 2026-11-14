import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';
import 'package:wuselwall/features/reminders/domain/reminder_plan.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_getting_started.dart';
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
  int? reminderMinutes,
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
    reminderMinutes: reminderMinutes,
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
    row(
      key: 'notify.shopping_start',
      type: 'boolean',
      defaultValue: true,
      value: true,
      constraints: {},
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
      int pendingApprovals = 0,
    }) => planReminders(
      now: at ?? now,
      l10n: _de,
      actor: guardianId,
      morningAt: morningAt,
      eventMinutes: eventMinutes,
      occurrences: occurrences,
      tasks: tasks,
      pendingApprovals: pendingApprovals,
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
            chore('Emmas Tisch', today, kidId),
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

    test('only the next summary names what waits for approval', () {
      final result = plan(
        pendingApprovals: 2,
        tasks: [
          chore('Müll', today, guardianId),
          chore('Müll', DateTime(2026, 10, 15), guardianId),
        ],
      );

      expect(
        [for (final r in result.reminders) (r.title, r.body)],
        [
          (
            'Heute: 1 Aufgabe',
            'Heute steht kein Termin an. · 2 Freigaben warten',
          ),
          ('Heute: 1 Aufgabe', 'Heute steht kein Termin an.'),
        ],
      );
    });

    test(
      'approvals alone make a summary; a past morning does not take them',
      () {
        // 06:00: this morning's summary is still to come and carries them.
        final early = plan(pendingApprovals: 1).reminders.single;
        expect(early.when, DateTime(2026, 10, 14, 7));
        expect(early.title, '1 Freigabe wartet');
        expect(early.body, 'Heute steht kein Termin an.');

        // 09:00: this morning is gone, so tomorrow's summary carries them.
        final late = plan(
          pendingApprovals: 1,
          at: DateTime(2026, 10, 14, 9),
        ).reminders.single;
        expect(late.when, DateTime(2026, 10, 15, 7));

        // Nothing waits and nothing is on: no summary at all.
        expect(plan().reminders, isEmpty);
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

    test("an event's own reminder comes without the personal one", () {
      final result = plan(
        morningAt: null,
        occurrences: [
          occ(
            title: 'Zahnarzt',
            day: DateTime(2026, 10, 16),
            from: const TimeOfDay(hour: 9, minute: 0),
            attendees: [guardianId],
            reminderMinutes: 2 * 24 * 60,
          ),
          occ(
            title: 'Elternabend',
            day: DateTime(2026, 10, 15),
            from: const TimeOfDay(hour: 19, minute: 30),
            reminderMinutes: 24 * 60,
          ),
          occ(
            title: 'Turnen',
            day: today,
            from: const TimeOfDay(hour: 17, minute: 0),
            attendees: [guardianId],
            reminderMinutes: 30,
          ),
          // Without one, and with the personal reminder off: nothing.
          occ(
            title: 'Chor',
            day: today,
            from: const TimeOfDay(hour: 20, minute: 0),
            attendees: [guardianId],
          ),
          // Someone else's, a presence entry and a cancelled event stay silent.
          occ(
            title: 'Kinderarzt',
            day: today,
            from: const TimeOfDay(hour: 11, minute: 0),
            attendees: [kidId],
            reminderMinutes: 30,
          ),
          occ(
            title: 'Zuhause',
            day: today,
            from: const TimeOfDay(hour: 12, minute: 0),
            presence: true,
            attendees: [guardianId],
            reminderMinutes: 30,
          ),
          occ(
            title: 'Abgesagt',
            day: today,
            from: const TimeOfDay(hour: 13, minute: 0),
            attendees: [guardianId],
            status: EventStatus.cancelled,
            reminderMinutes: 30,
          ),
        ],
      );

      expect(
        [for (final r in result.reminders) (r.title, r.when, r.body)],
        [
          ('Zahnarzt', DateTime(2026, 10, 14, 9), 'In 2 Tagen um 09:00'),
          ('Turnen', DateTime(2026, 10, 14, 16, 30), 'Beginnt um 17:00'),
          ('Elternabend', DateTime(2026, 10, 14, 19, 30), 'Morgen um 19:30'),
        ],
      );
    });

    test("an event's own reminder replaces the personal one", () {
      final result = plan(
        morningAt: null,
        eventMinutes: 15,
        occurrences: [
          occ(
            title: 'Zahnarzt',
            day: today,
            from: const TimeOfDay(hour: 9, minute: 0),
            attendees: [guardianId],
            reminderMinutes: 120,
          ),
          occ(
            title: 'Chor',
            day: today,
            from: const TimeOfDay(hour: 20, minute: 0),
            attendees: [guardianId],
          ),
          // Its own reminder was yesterday: the personal one does not step in.
          occ(
            title: 'Fest',
            day: today,
            from: const TimeOfDay(hour: 18, minute: 0),
            attendees: [guardianId],
            reminderMinutes: 24 * 60,
          ),
        ],
      );

      expect(
        [for (final r in result.reminders) (r.title, r.when)],
        [
          ('Zahnarzt', DateTime(2026, 10, 14, 7)),
          ('Chor', DateTime(2026, 10, 14, 19, 45)),
        ],
      );
    });

    test('an all-day event reminds in the morning, whole days before', () {
      final result = plan(
        morningAt: null,
        eventMinutes: 15,
        occurrences: [
          occ(
            title: 'Geburtstagsfest',
            day: DateTime(2026, 10, 15),
            allDay: true,
            reminderMinutes: 24 * 60,
          ),
          occ(
            title: 'Schulreise',
            day: DateTime(2026, 10, 21),
            allDay: true,
            reminderMinutes: 7 * 24 * 60,
          ),
          // Minutes on an all-day event mean nothing (the server refuses them), and
          // the personal lead time never applies to one.
          occ(
            title: 'Feiertag',
            day: DateTime(2026, 10, 16),
            allDay: true,
            reminderMinutes: 30,
          ),
          occ(title: 'Ferien', day: DateTime(2026, 10, 16), allDay: true),
        ],
      );

      expect(
        [for (final r in result.reminders) (r.title, r.when, r.body)],
        [
          ('Geburtstagsfest', DateTime(2026, 10, 14, 9), 'Morgen, ganztägig'),
          ('Schulreise', DateTime(2026, 10, 14, 9), 'In 7 Tagen, ganztägig'),
        ],
      );
    });

    test('a reminder past midnight says tomorrow', () {
      final result = plan(
        morningAt: null,
        at: DateTime(2026, 10, 14, 22),
        occurrences: [
          occ(
            title: 'Nachtzug',
            day: DateTime(2026, 10, 15),
            from: const TimeOfDay(hour: 0, minute: 10),
            attendees: [guardianId],
            reminderMinutes: 15,
          ),
        ],
      );
      expect(result.reminders.single.when, DateTime(2026, 10, 14, 23, 55));
      expect(result.reminders.single.body, 'Morgen um 00:10');
    });

    test('a day before keeps the clock time across the end of summer time', () {
      // Where the clocks go back on 25 October 2026, 24 hours before 09:00 on the
      // 26th would be 10:00 on the 25th.
      final result = plan(
        morningAt: null,
        at: DateTime(2026, 10, 24, 12),
        occurrences: [
          occ(
            title: 'Zahnarzt',
            day: DateTime(2026, 10, 26),
            from: const TimeOfDay(hour: 9, minute: 0),
            attendees: [guardianId],
            reminderMinutes: 24 * 60,
          ),
        ],
      );
      expect(result.reminders.single.when, DateTime(2026, 10, 25, 9));
      expect(result.reminders.single.body, 'Morgen um 09:00');
    });

    test('an event after the planning week reminds inside it', () {
      final result = plan(
        morningAt: null,
        occurrences: [
          // Starts on day 12; a week before is day 5, inside the seven days.
          occ(
            title: 'Zahnarzt',
            day: DateTime(2026, 10, 26),
            from: const TimeOfDay(hour: 9, minute: 0),
            attendees: [guardianId],
            reminderMinutes: 7 * 24 * 60,
          ),
          // A day before day 12 is day 11: the plan of a later day takes it.
          occ(
            title: 'Elternabend',
            day: DateTime(2026, 10, 26),
            from: const TimeOfDay(hour: 19, minute: 30),
            attendees: [guardianId],
            reminderMinutes: 24 * 60,
          ),
        ],
      );
      expect(
        [for (final r in result.reminders) (r.title, r.when, r.body)],
        [('Zahnarzt', DateTime(2026, 10, 19, 9), 'In 7 Tagen um 09:00')],
      );
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

  group('packing reminder (FR-7.12)', () {
    final now = DateTime(2026, 10, 14, 6);
    const seven = TimeOfDay(hour: 19, minute: 0);

    PackList pack(int dayOffset, String id, String name, List<String> items) =>
        PackList(
          day: DateTime(2026, 10, 14 + dayOffset),
          profileId: id,
          name: name,
          items: items,
        );

    ReminderPlan plan({
      TimeOfDay? packingAt = seven,
      List<PackList> packs = const [],
      DateTime? at,
      String actor = guardianId,
    }) => planReminders(
      now: at ?? now,
      l10n: _de,
      actor: actor,
      morningAt: null,
      eventMinutes: null,
      occurrences: const [],
      tasks: const [],
      packingAt: packingAt,
      packs: packs,
    );

    test('a parent hears every child, the evening before', () {
      final p = plan(
        packs: [
          pack(1, kidId, 'Anna', ['Sportsachen']),
          pack(1, 'p-2', 'Emma', ['Schwimmsachen', 'Flöte']),
        ],
      );
      expect(p.reminders, hasLength(1));
      expect(p.reminders.single.when, DateTime(2026, 10, 14, 19));
      expect(p.reminders.single.title, 'Für morgen einpacken');
      expect(
        p.reminders.single.body,
        'Anna: Sportsachen · Emma: Schwimmsachen, Flöte',
      );
    });

    test("a child's own phone lists just the things", () {
      final p = plan(
        actor: kidId,
        packs: [
          pack(2, kidId, 'Anna', ['Sportsachen']),
        ],
      );
      expect(p.reminders.single.when, DateTime(2026, 10, 15, 19));
      expect(p.reminders.single.body, 'Sportsachen');
    });

    test('nothing to pack, switched off, or the evening gone: no reminder', () {
      expect(plan(packs: [pack(1, kidId, 'Anna', [])]).reminders, isEmpty);
      expect(
        plan(
          packingAt: null,
          packs: [
            pack(1, kidId, 'Anna', ['Sportsachen']),
          ],
        ).reminders,
        isEmpty,
      );
      final late = plan(
        at: DateTime(2026, 10, 14, 20),
        packs: [
          pack(1, kidId, 'Anna', ['Sportsachen']),
          pack(2, kidId, 'Anna', ['Turnbeutel']),
        ],
      );
      expect(late.reminders.map((r) => r.body), ['Anna: Turnbeutel']);
    });

    test('only evenings inside the plan', () {
      final p = plan(
        packs: [
          pack(7, kidId, 'Anna', ['Sportsachen']),
          pack(8, kidId, 'Anna', ['Schwimmsachen']),
        ],
      );
      // The evening of day 6 is the plan's last; day 7's is past it.
      expect(p.reminders.map((r) => r.when), [DateTime(2026, 10, 20, 19)]);
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

    testWidgets(
      "an event's own reminder is scheduled with the personal one off, also "
      'for an event of the week after',
      (t) async {
        final notifications = FakeNotificationScheduler();
        await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            notifications: notifications,
          ),
          // The event reminder of Settings → Reminders stays off.
          tasks: FakeTasksApi(tables: {'settings': settingRows()}),
          calendar: FakeCalendarRepository([
            occ(
              title: 'Zahnarzt',
              day: _day(10),
              from: const TimeOfDay(hour: 9, minute: 0),
              attendees: [guardianId],
              reminderMinutes: 7 * 24 * 60,
            ),
            occ(
              title: 'Chor',
              day: _day(1),
              from: const TimeOfDay(hour: 20, minute: 0),
              attendees: [guardianId],
            ),
          ]),
        );

        final at = _day(3);
        expect(
          [
            for (final n in notifications.active)
              if (n.title == 'Zahnarzt' || n.title == 'Chor')
                (n.title, n.when, n.body),
          ],
          [
            (
              'Zahnarzt',
              DateTime(at.year, at.month, at.day, 9),
              'In 7 Tagen um 09:00',
            ),
          ],
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

    testWidgets(
      "a guardian's next summary counts the approvals; a member's has none",
      (t) async {
        FakeTasksApi waiting() => FakeTasksApi(
          tables: {
            'settings': settingRows(),
            'task_instances': [
              instanceRow(
                id: 'i-1',
                title: 'Zimmer aufräumen',
                assignee: kidId,
                status: 'done',
                verification: true,
                completedBy: kidId,
              ),
            ],
            'reward_redemptions': [
              {
                'id': 'rd-1',
                'reward_id': 'r-movie',
                'profile_id': kidId,
                'cost_points': 5,
                'status': 'requested',
                'requested_at': '2026-10-14T07:00:00Z',
              },
            ],
          },
        );
        final guardianPhone = FakeNotificationScheduler();
        var container = await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            notifications: guardianPhone,
          ),
          tasks: waiting(),
        );
        expect(guardianPhone.active.map((n) => n.title), [
          _de.reminderMorningApprovals(2),
        ]);
        await unmountApp(t, container);

        const memberId = 'p-member';
        final memberPhone = FakeNotificationScheduler();
        container = await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(
              current: device(profileId: memberId),
              members: [
                ...testMembers,
                const Member(
                  id: memberId,
                  displayName: 'Julia',
                  color: Color(0xFF3366CC),
                  role: Role.member,
                  active: true,
                ),
              ],
            ),
            notifications: memberPhone,
          ),
          tasks: waiting(),
        );
        expect(memberPhone.active, isEmpty);
        await unmountApp(t, container);
      },
    );

    testWidgets(
      'permission keeps a stable total, denial stays open and resume rereads the OS',
      (t) async {
        final notifications = FakeNotificationScheduler(
          granted: false,
          grantOnRequest: false,
        );
        final container = await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
            notifications: notifications,
          ),
          gettingStarted: FakeGettingStartedRepository(const [
            GettingStartedItem(item: StartItem.wallDisplay, done: false),
            GettingStartedItem(item: StartItem.subscribeFeed, done: true),
          ]),
        );
        expect(find.text(_de.todayStartProgress(1, 3)), findsOneWidget);
        await t.tap(find.text(_de.reminderStartLabel));
        await t.pumpAndSettle();
        expect(find.text(_de.todayStartProgress(1, 3)), findsOneWidget);
        expect(container.read(reminderSetupProvider).value, isFalse);
        notifications.grantOnRequest = true;
        await t.tap(find.text(_de.reminderStartLabel));
        await t.pumpAndSettle();
        expect(find.text(_de.todayStartProgress(2, 3)), findsOneWidget);
        expect(container.read(reminderSetupProvider).value, isTrue);
        expect(find.text(_de.reminderStartLabel), findsOneWidget);
        // A system-settings revocation is discovered on foregrounding, without prompting.
        notifications.granted = false;
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(find.text(_de.todayStartProgress(1, 3)), findsOneWidget);
        expect(notifications.requests, 2);
        await unmountApp(t, container);
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
        // Nullable reminder controls must name what they enable, independently
        // of the adjacent time/interval control.
        final semantics = t.ensureSemantics();
        try {
          await t.pump();
          for (final toggle in find.byType(Switch).evaluate()) {
            expect(
              t.getSemantics(find.byWidget(toggle.widget)).label,
              isNotEmpty,
            );
          }
        } finally {
          semantics.dispose();
        }
        expect(
          find.byKey(const ValueKey('setting-notify.morning_summary')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('setting-notify.event_reminder')),
          findsOneWidget,
        );
        // Somebody starting to shop: on by default, the server says it (specs/07).
        expect(
          find.byKey(const ValueKey('setting-notify.shopping_start')),
          findsOneWidget,
        );
        expect(find.text(_de.settingNotifyShoppingStartTitle), findsOneWidget);

        await t.tap(
          find.widgetWithText(FilledButton, _de.reminderEnableAction),
        );
        await t.pumpAndSettle();

        expect(find.text(_de.reminderStatusOn), findsOneWidget);
        expect(notifications.requests, 1);
      },
    );

    Future<void> openSettings(
      WidgetTester t, {
      required DeviceInfo current,
      required bool available,
    }) async {
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: current),
          notifications: FakeNotificationScheduler(available: available),
        ),
      );
      container.read(routerProvider).go(Routes.settingsPersonal);
      await t.pumpAndSettle();
    }

    testWidgets('Einstellungen lists Erinnerungen on a personal phone', (
      t,
    ) async {
      await openSettings(t, current: device(), available: true);
      expect(find.text(_de.reminderSettingsTitle), findsOneWidget);
    });

    testWidgets('Einstellungen hides Erinnerungen where none can be shown', (
      t,
    ) async {
      await openSettings(t, current: device(), available: false);
      expect(find.text(_de.reminderSettingsTitle), findsNothing);
    });

    testWidgets('Einstellungen hides Erinnerungen on a shared device', (
      t,
    ) async {
      await openSettings(
        t,
        current: device(deviceClass: DeviceClass.kiosk),
        available: true,
      );
      expect(find.text(_de.reminderSettingsTitle), findsNothing);
    });
  });
}
