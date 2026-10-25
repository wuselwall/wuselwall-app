import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/calendar_layout.dart';
import 'package:wuselwall/features/calendar/ui/event_editor_page.dart';
import 'package:wuselwall/features/calendar/ui/event_template_page.dart';

import '../support/fakes.dart';

/// A test occurrence: timed when [from] and [to] are given, else all day. Spans
/// [lastDay] when it is later than [day].
Occurrence occ({
  required String title,
  required DateTime day,
  TimeOfDay? from,
  TimeOfDay? to,
  DateTime? lastDay,
  List<String> attendees = const [],
  PresenceState? presence,
  bool tentative = false,
}) {
  final d = dateOnly(day);
  final last = dateOnly(lastDay ?? day);
  final timed = from != null && to != null;
  return Occurrence(
    id: '$title|${isoDate(d)}',
    eventId: 'e-$title',
    calendarId: 'cal',
    title: title,
    kind: presence == null ? EventKind.appointment : EventKind.presence,
    presenceState: presence,
    status: tentative ? EventStatus.tentative : EventStatus.confirmed,
    importance: Importance.normal,
    allDay: !timed,
    start: timed ? DateTime(d.year, d.month, d.day, from.hour, from.minute) : d,
    end: timed
        ? DateTime(last.year, last.month, last.day, to.hour, to.minute)
        : DateTime(last.year, last.month, last.day + 1),
    localStartDate: d,
    localEndDate: last,
    localStarts: from,
    localEnds: to,
    attendeeIds: attendees,
  );
}

/// Monday of the current week, local midnight.
DateTime thisMonday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(today.year, today.month, today.day - (today.weekday - 1));
}

DateTime dayOfThisWeek(int offset) {
  final m = thisMonday();
  return DateTime(m.year, m.month, m.day + offset);
}

void main() {
  group('Occurrence JSON', () {
    test('a timed appointment keeps its instants and wall clock', () {
      final o = Occurrence.fromJson({
        'id': 'ev-1|2026-10-14T14:00:00Z',
        'event_id': 'ev-1',
        'recurrence_id': '2026-10-14T14:00:00Z',
        'calendar_id': 'cal-1',
        'title': 'Turnen',
        'location': 'TSV-Halle',
        'description': null,
        'kind': 'appointment',
        'presence_state': null,
        'status': 'confirmed',
        'importance': 'normal',
        'all_day': false,
        'start': '2026-10-14T14:00:00Z',
        'end': '2026-10-14T15:00:00Z',
        'local_start_date': '2026-10-14',
        'local_end_date': '2026-10-14',
        'local_starts': '16:00',
        'local_ends': '17:00',
        'attendee_ids': ['p-1', 'p-2'],
        'is_recurring': true,
        'is_override': false,
      });
      expect(o.eventId, 'ev-1');
      expect(o.start, DateTime.parse('2026-10-14T14:00:00Z').toLocal());
      expect(o.end, DateTime.parse('2026-10-14T15:00:00Z').toLocal());
      expect(o.localStartDate, DateTime(2026, 10, 14));
      expect(o.localStarts, const TimeOfDay(hour: 16, minute: 0));
      expect(o.localEnds, const TimeOfDay(hour: 17, minute: 0));
      expect(o.attendeeIds, ['p-1', 'p-2']);
      expect(o.isRecurring, isTrue);
      expect(o.isPresence, isFalse);
      expect(o.isTentative, isFalse);
      expect(o.recurrenceId, isNotNull);
    });

    test('a tentative all-day presence round-trips its state and dates', () {
      final o = Occurrence.fromJson({
        'id': 'ev-2|single',
        'event_id': 'ev-2',
        'recurrence_id': null,
        'calendar_id': 'cal-1',
        'title': 'Dienstreise Berlin',
        'location': null,
        'description': null,
        'kind': 'presence',
        'presence_state': 'home_office',
        'status': 'tentative',
        'importance': 'key',
        'all_day': true,
        'start': '2026-10-15T00:00:00+02:00',
        'end': '2026-10-17T00:00:00+02:00',
        'local_start_date': '2026-10-15',
        'local_end_date': '2026-10-16',
        'local_starts': null,
        'local_ends': null,
        'attendee_ids': <String>[],
      });
      expect(o.isPresence, isTrue);
      expect(o.presenceState, PresenceState.homeOffice);
      expect(o.isTentative, isTrue);
      expect(o.isKey, isTrue);
      expect(o.allDay, isTrue);
      expect(o.localStarts, isNull);
      expect(o.localEndDate, DateTime(2026, 10, 16));
      expect(o.coversDay(DateTime(2026, 10, 16, 9)), isTrue);
      expect(o.coversDay(DateTime(2026, 10, 17)), isFalse);
    });
  });

  group('CalendarEvent JSON', () {
    test('fromJson reads an api.events row, dates and arrays included', () {
      final e = CalendarEvent.fromJson({
        'id': 'ev-3',
        'calendar_id': 'cal-1',
        'title': 'Elternabend',
        'description': null,
        'location': 'Aula',
        'kind': 'appointment',
        'presence_state': null,
        'status': 'confirmed',
        'importance': 'key',
        'is_all_day': false,
        'starts_at': '2026-10-14T17:30:00Z',
        'ends_at': '2026-10-14T19:00:00Z',
        'start_date': null,
        'end_date': null,
        'timezone': 'Europe/Berlin',
        'rrule': 'FREQ=WEEKLY;BYDAY=WE',
        'rdates': ['2026-10-21'],
        'exdates': ['2026-10-28'],
        'uid': 'ev-3@wuselwall.app',
        'sequence': 2,
        'attendee_ids': ['p-1'],
      });
      expect(e.importance, Importance.key);
      expect(e.startsAt, DateTime.parse('2026-10-14T17:30:00Z'));
      expect(e.rdates, [DateTime(2026, 10, 21)]);
      expect(e.exdates, [DateTime(2026, 10, 28)]);
      expect(e.isRecurring, isTrue);
      expect(e.sequence, 2);
    });

    test('toJson gives the p_event keys of api.event_save', () {
      final json = CalendarEvent(
        title: 'Grillen bei Webers',
        kind: EventKind.appointment,
        isAllDay: false,
        status: EventStatus.tentative,
        startsAt: DateTime.utc(2026, 10, 17, 14),
        endsAt: DateTime.utc(2026, 10, 17, 18),
        attendeeIds: const ['p-1', 'p-2'],
      ).toJson();
      expect(json.keys.toSet(), {
        'title',
        'description',
        'location',
        'kind',
        'presence_state',
        'status',
        'is_all_day',
        'starts_at',
        'ends_at',
        'start_date',
        'end_date',
        'rrule',
        'rdates',
        'exdates',
        'attendee_ids',
        // A lighter day (specs/27); an older server ignores them.
        'icon_key',
        'countdown',
        'tradition',
      });
      expect(json['status'], 'tentative');
      expect(json['starts_at'], '2026-10-17T14:00:00.000Z');
      expect(json['start_date'], isNull);
      expect(json['rdates'], isEmpty);
    });

    test('toJson of an all-day presence sends dates, state and no times', () {
      final json = CalendarEvent(
        id: 'ev-9',
        title: 'Dienstreise Berlin',
        kind: EventKind.presence,
        presenceState: PresenceState.travel,
        isAllDay: true,
        startDate: DateTime(2026, 10, 15),
        endDate: DateTime(2026, 10, 16),
        importance: Importance.key,
        timezone: 'Europe/Berlin',
        attendeeIds: const ['p-1'],
      ).toJson();
      expect(json['id'], 'ev-9');
      expect(json['kind'], 'presence');
      expect(json['presence_state'], 'travel');
      expect(json['is_all_day'], isTrue);
      expect(json['start_date'], '2026-10-15');
      expect(json['end_date'], '2026-10-16');
      expect(json['starts_at'], isNull);
      expect(json['importance'], 'key');
      expect(json['timezone'], 'Europe/Berlin');
    });

    test(
      'a new event without an importance leaves the default to the server',
      () {
        final json = CalendarEvent(
          title: 'Zahnarzt',
          kind: EventKind.appointment,
          isAllDay: true,
          startDate: DateTime(2026, 10, 20),
          endDate: DateTime(2026, 10, 20),
        ).toJson();
        expect(json.containsKey('importance'), isFalse);
        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('calendar_id'), isFalse);
      },
    );
  });

  test('OccurrenceWindow reads busy_until per member and day', () {
    final w = OccurrenceWindow.fromJson({
      'timezone': 'Europe/Berlin',
      'occurrences': <Map<String, dynamic>>[],
      'busy_until': [
        {'profile_id': 'p-1', 'on_date': '2026-10-14', 'until': '17:00:00'},
      ],
    });
    expect(w.timezone, 'Europe/Berlin');
    expect(w.busyUntil, {
      (profileId: 'p-1', date: DateTime(2026, 10, 14)): const TimeOfDay(
        hour: 17,
        minute: 0,
      ),
    });
  });

  group('day blocks', () {
    test('overlapping appointments share the column side by side', () {
      final day = dayOfThisWeek(0);
      final blocks = timedBlocksOn(day, [
        occ(
          title: 'A',
          day: day,
          from: const TimeOfDay(hour: 10, minute: 0),
          to: const TimeOfDay(hour: 11, minute: 0),
        ),
        occ(
          title: 'B',
          day: day,
          from: const TimeOfDay(hour: 10, minute: 30),
          to: const TimeOfDay(hour: 12, minute: 0),
        ),
        occ(
          title: 'C',
          day: day,
          from: const TimeOfDay(hour: 13, minute: 0),
          to: const TimeOfDay(hour: 14, minute: 0),
        ),
      ]);
      final byTitle = {for (final b in blocks) b.occurrence.title: b};
      expect(byTitle['A']!.lanes, 2);
      expect(byTitle['B']!.lanes, 2);
      expect(byTitle['A']!.lane, isNot(byTitle['B']!.lane));
      expect(byTitle['C']!.lanes, 1);
      expect(byTitle['C']!.lane, 0);
    });

    test('presence, all-day and out-of-grid items are not timed blocks', () {
      final day = dayOfThisWeek(1);
      final blocks = timedBlocksOn(day, [
        occ(
          title: 'Dienst',
          day: day,
          from: const TimeOfDay(hour: 8, minute: 30),
          to: const TimeOfDay(hour: 14, minute: 0),
          presence: PresenceState.working,
        ),
        occ(title: 'Ganztägig', day: day),
        occ(
          title: 'Spät',
          day: day,
          from: const TimeOfDay(hour: 23, minute: 0),
          to: const TimeOfDay(hour: 23, minute: 30),
        ),
      ]);
      expect(blocks, isEmpty);
    });
  });

  group('calendar in the app', () {
    for (final language in ['de', 'en']) {
      for (final width in [390.0, 1348.0]) {
        testWidgets('calendar header uses one bar at $width in $language', (
          t,
        ) async {
          final l10n = lookupAppLocalizations(Locale(language));
          final container = await pumpApp(
            t,
            locale: Locale(language),
            size: Size(width, 844),
            overrides: baseOverrides(
              identity: FakeIdentityRepository(current: device()),
            ),
          );
          await openTab(t, l10n.calendarTitle);
          final appBar = find.byType(AppBar);
          expect(t.widget<AppBar>(appBar).bottom, isNull);
          expect(
            t.getSize(appBar).height,
            Theme.of(t.element(appBar)).appBarTheme.toolbarHeight,
          );
          final previous = find.byTooltip(l10n.calendarPrevious);
          final next = find.byTooltip(l10n.calendarNext);
          final settings = find.byTooltip(l10n.settingsTitle);
          expect(
            t.getCenter(previous).dy,
            closeTo(t.getCenter(settings).dy, 1),
          );
          expect(t.getCenter(next).dy, closeTo(t.getCenter(settings).dy, 1));
          if (width < 900) {
            final picker = find.byTooltip(l10n.calendarChooseView);
            expect(
              t.getCenter(picker).dy,
              closeTo(t.getCenter(settings).dy, 1),
            );
            await t.tap(picker);
            await t.pumpAndSettle();
          } else {
            expect(
              t.getCenter(find.byType(SegmentedButton<CalendarMode>)).dy,
              closeTo(t.getCenter(settings).dy, 1),
            );
          }
          final threeDays = find.text(l10n.calendarThreeDays);
          await t.tap(
            width < 900
                ? find.ancestor(
                    of: threeDays,
                    matching: find.byType(CheckedPopupMenuItem<CalendarMode>),
                  )
                : threeDays,
          );
          await t.pumpAndSettle();
          final initial = container.read(calendarViewProvider);
          expect(initial.mode, CalendarMode.threeDays);
          await t.tap(next);
          await t.pumpAndSettle();
          expect(
            container.read(calendarViewProvider).anchor,
            DateTime(
              initial.anchor.year,
              initial.anchor.month,
              initial.anchor.day + 3,
            ),
          );
          await t.tap(previous);
          await t.pumpAndSettle();
          expect(container.read(calendarViewProvider).anchor, initial.anchor);
          if (width < 900) {
            await t.tap(
              find.descendant(
                of: appBar,
                matching: find.byTooltip(l10n.calendarToday),
              ),
            );
          } else {
            await t.tap(
              find.descendant(
                of: appBar,
                matching: find.text(l10n.calendarToday),
              ),
            );
          }
          await t.pumpAndSettle();
          expect(
            container.read(calendarViewProvider).anchor,
            dateOnly(DateTime.now()),
          );
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets(
      'the week view shows a timed event, an all-day chip and a presence band',
      (t) async {
        await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
          calendar: FakeCalendarRepository([
            occ(
              title: 'Turnen',
              day: dayOfThisWeek(0),
              from: const TimeOfDay(hour: 15, minute: 0),
              to: const TimeOfDay(hour: 16, minute: 0),
              attendees: const [guardianId],
            ),
            occ(
              title: 'Fotografin in der Schule',
              day: dayOfThisWeek(3),
              attendees: const [kidId],
            ),
            occ(
              title: 'Dienst',
              day: dayOfThisWeek(2),
              from: const TimeOfDay(hour: 8, minute: 30),
              to: const TimeOfDay(hour: 14, minute: 0),
              attendees: const [guardianId],
              presence: PresenceState.working,
            ),
          ]),
        );
        await openTab(t, 'Kalender');

        expect(find.text('Turnen'), findsOneWidget);
        expect(find.text('Fotografin in der Schule'), findsOneWidget);
        expect(find.text('Dienst'), findsOneWidget);
        expect(find.byType(PresenceBandView), findsOneWidget);
        expect(find.text('Kalender'), findsWidgets);
      },
    );

    testWidgets('an empty window says nothing is planned', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      await openTab(t, 'Kalender');
      expect(find.text('Nichts geplant'), findsOneWidget);
    });

    testWidgets('the navigation bar switches between calendar and shopping', (
      t,
    ) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          shopping: FakeShoppingRepository([item('1', 'Milch')]),
        ),
      );
      await openTab(t, 'Kalender');
      final bar = find.byType(NavigationBar);
      expect(bar, findsOneWidget);
      expect(find.text('Milch'), findsNothing);

      await t.tap(find.descendant(of: bar, matching: find.text('Einkauf')));
      await t.pumpAndSettle();
      expect(find.text('Milch'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await t.tap(find.descendant(of: bar, matching: find.text('Kalender')));
      await t.pumpAndSettle();
      expect(find.text('Milch'), findsNothing);
      expect(
        find.widgetWithText(FloatingActionButton, 'Neuer Termin'),
        findsOneWidget,
      );
    });

    testWidgets(
      'the new-event button opens the editor, a block opens it with its title',
      (t) async {
        await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
          calendar: FakeCalendarRepository([
            occ(
              title: 'Turnen',
              day: dayOfThisWeek(0),
              from: const TimeOfDay(hour: 15, minute: 0),
              to: const TimeOfDay(hour: 16, minute: 0),
            ),
          ]),
        );
        await openTab(t, 'Kalender');

        await t.tap(find.text('Turnen'));
        await t.pumpAndSettle();
        expect(find.byType(EventEditorPage), findsOneWidget);
        expect(
          find.widgetWithText(AppBar, 'Termin bearbeiten'),
          findsOneWidget,
        );

        await t.tap(find.byType(BackButton));
        await t.pumpAndSettle();
        // Neuer Termin starts on its tiles; Ohne Vorlage opens the empty editor.
        await t.tap(find.widgetWithText(FloatingActionButton, 'Neuer Termin'));
        await t.pumpAndSettle();
        expect(find.byType(EventTemplatePage), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('event-template-blank')));
        await t.pumpAndSettle();
        expect(find.byType(EventEditorPage), findsOneWidget);
        expect(find.widgetWithText(AppBar, 'Neuer Termin'), findsOneWidget);
      },
    );
  });
}
