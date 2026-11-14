import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/event_reminder.dart';
import 'package:wuselwall/features/calendar/ui/editor/event_draft.dart';

/// A timed draft from [start] to [end], switched to all-day.
EventDraft _allDay(DateTime start, DateTime end) =>
    EventDraft(start: start, end: end, title: 'Ferien')..setAllDay(true);

CalendarEvent _saved(EventDraft draft) =>
    draft.toEvent(attendees: const [], key: false);

void main() {
  group("an event's own reminder (specs/05)", () {
    EventDraft draft({int? reminder}) => EventDraft(
      start: DateTime(2026, 10, 14, 10),
      end: DateTime(2026, 10, 14, 11),
      title: 'Zahnarzt',
      reminderMinutes: reminder,
    );

    test('is saved with the event and read back', () {
      final event = _saved(draft(reminder: 30));
      expect(event.reminderMinutes, 30);
      expect(event.toJson()['reminder_minutes'], 30);
      expect(EventDraft.fromEvent(event).reminderMinutes, 30);
      expect(
        CalendarEvent.fromJson({
          ...event.toJson(),
          'id': 'e1',
          'reminder_minutes': 1440,
        }).reminderMinutes,
        1440,
      );
    });

    test('none is sent as null, so a cleared reminder is cleared', () {
      final json = _saved(draft()).toJson();
      expect(json.containsKey('reminder_minutes'), isTrue);
      expect(json['reminder_minutes'], isNull);
    });

    test('an all-day event carries whole days only; the choice comes back', () {
      final minutes = draft(reminder: 30)..setAllDay(true);
      expect(minutes.effectiveReminder, isNull);
      expect(_saved(minutes).reminderMinutes, isNull);
      minutes.setAllDay(false);
      expect(_saved(minutes).reminderMinutes, 30);

      final days = draft(reminder: 2 * 24 * 60)..setAllDay(true);
      expect(_saved(days).reminderMinutes, 2 * 24 * 60);
    });

    test('a presence entry carries none', () {
      final presence = draft(reminder: 30)
        ..kind = EventKind.presence
        ..presenceState = PresenceState.travel;
      expect(_saved(presence).reminderMinutes, isNull);
    });

    test('a server before the reminder sends none', () {
      final event = CalendarEvent.fromJson({
        'id': 'e1',
        'title': 'Turnen',
        'kind': 'appointment',
        'is_all_day': false,
        'starts_at': '2026-10-14T14:00:00Z',
        'ends_at': '2026-10-14T15:00:00Z',
      });
      expect(event.reminderMinutes, isNull);
    });

    test('the editor offers seven lead times, whole days for all day', () {
      expect(reminderChoicesFor(allDay: false), [
        15,
        30,
        60,
        120,
        1440,
        2880,
        10080,
      ]);
      expect(reminderChoicesFor(allDay: true), [1440, 2880, 10080]);
    });

    test('a stored lead time the list lacks is offered too', () {
      expect(reminderChoicesFor(allDay: false, current: 45), contains(45));
      expect(reminderChoicesFor(allDay: false, current: 45), hasLength(8));
      expect(reminderChoicesFor(allDay: false, current: 60), hasLength(7));
      expect(reminderChoicesFor(allDay: true, current: 4320), [
        1440,
        2880,
        4320,
        10080,
      ]);
      // Minutes never fit an all-day event.
      expect(reminderChoicesFor(allDay: true, current: 45), hasLength(3));
    });

    test('a lead time is said in its largest whole unit', () {
      expect(reminderParts(15), (unit: ReminderUnit.minutes, count: 15));
      expect(reminderParts(90), (unit: ReminderUnit.minutes, count: 90));
      expect(reminderParts(120), (unit: ReminderUnit.hours, count: 2));
      expect(reminderParts(1440), (unit: ReminderUnit.days, count: 1));
      expect(reminderParts(4320), (unit: ReminderUnit.days, count: 3));
      expect(reminderParts(10080), (unit: ReminderUnit.weeks, count: 1));
      expect(reminderParts(0), (unit: ReminderUnit.minutes, count: 0));
    });
  });

  // A timed end is an exclusive instant, an all-day end_date inclusive (specs/04).
  group('switching a timed draft to all-day keeps the days it covers', () {
    test('within one day', () {
      final event = _saved(
        _allDay(DateTime(2026, 10, 14, 10), DateTime(2026, 10, 14, 11)),
      );
      expect(event.startDate, DateTime(2026, 10, 14));
      expect(event.endDate, DateTime(2026, 10, 14));
    });

    test('ending at midnight: one day, not two', () {
      final event = _saved(
        _allDay(DateTime(2026, 10, 14, 23), DateTime(2026, 10, 15)),
      );
      expect(event.startDate, DateTime(2026, 10, 14));
      expect(event.endDate, DateTime(2026, 10, 14));
    });

    test('overnight past midnight: both days', () {
      final event = _saved(
        _allDay(DateTime(2026, 10, 14, 22), DateTime(2026, 10, 15, 2)),
      );
      expect(event.startDate, DateTime(2026, 10, 14));
      expect(event.endDate, DateTime(2026, 10, 15));
    });

    test('several days ending at midnight: up to the last full day', () {
      final event = _saved(
        _allDay(DateTime(2026, 10, 14, 10), DateTime(2026, 10, 17)),
      );
      expect(event.startDate, DateTime(2026, 10, 14));
      expect(event.endDate, DateTime(2026, 10, 16));
    });

    test('a whole day from midnight to midnight is that day', () {
      final event = _saved(
        _allDay(DateTime(2026, 10, 14), DateTime(2026, 10, 15)),
      );
      expect(event.startDate, DateTime(2026, 10, 14));
      expect(event.endDate, DateTime(2026, 10, 14));
    });

    test('across the end of daylight saving time (25 October 2026)', () {
      final event = _saved(
        _allDay(DateTime(2026, 10, 25, 23), DateTime(2026, 10, 26)),
      );
      expect(event.endDate, DateTime(2026, 10, 25));
    });
  });

  group('switching back to timed', () {
    test('restores the end it had', () {
      final draft = _allDay(DateTime(2026, 10, 14, 23), DateTime(2026, 10, 15))
        ..setAllDay(false);
      expect(draft.start, DateTime(2026, 10, 14, 23));
      expect(draft.end, DateTime(2026, 10, 15));
      expect(draft.validate(), isNull);
    });

    test('restores a multi-day end', () {
      final draft = _allDay(DateTime(2026, 10, 14, 10), DateTime(2026, 10, 17))
        ..setAllDay(false);
      expect(draft.end, DateTime(2026, 10, 17));
    });

    test('after a changed end date, keeps that date and stays valid', () {
      final draft = _allDay(DateTime(2026, 10, 14, 23), DateTime(2026, 10, 15))
        ..setEnd(DateTime(2026, 10, 16))
        ..setAllDay(false);
      expect(draft.end, DateTime(2026, 10, 16));
      expect(draft.validate(), isNull);
    });

    test('an all-day event opened for editing gets a valid timed end', () {
      final draft = EventDraft(
        start: DateTime(2026, 10, 14),
        end: DateTime(2026, 10, 14),
        isAllDay: true,
      )..setAllDay(false);
      expect(draft.end, DateTime(2026, 10, 14, 1));
    });
  });

  group('the rituals of specs/27 survive a round trip through the editor', () {
    CalendarEvent tradition({TraditionMeal? meal}) => CalendarEvent(
      id: 'e1',
      title: 'Pizza-Freitag',
      kind: EventKind.appointment,
      isAllDay: true,
      startDate: DateTime(2026, 10, 30),
      endDate: DateTime(2026, 10, 30),
      rrule: 'FREQ=WEEKLY;BYDAY=FR',
      importance: Importance.key,
      iconKey: 'pizza',
      countdown: true,
      tradition: true,
      traditionMeal: meal,
    );

    test('a tradition with its meal in words', () {
      final json = _saved(
        EventDraft.fromEvent(
          tradition(
            meal: const TraditionMeal(
              slot: 'lunch',
              freeText: 'Pizza',
              title: 'Pizza',
            ),
          ),
        ),
      ).toJson();
      expect(json['tradition'], isTrue);
      expect(json['countdown'], isTrue);
      expect(json['icon_key'], 'pizza');
      expect(json['tradition_meal'], {'slot': 'lunch', 'free_text': 'Pizza'});
    });

    test('a recipe meal stays the recipe while its words are unchanged', () {
      const meal = TraditionMeal(
        slot: 'dinner',
        recipeId: 'r1',
        freeText: 'Pfannkuchen',
        title: 'Pfannkuchen',
      );
      final draft = EventDraft.fromEvent(tradition(meal: meal));
      expect(_saved(draft).toJson()['tradition_meal'], {
        'slot': 'dinner',
        'recipe_id': 'r1',
      });
      draft.traditionMeal = 'Waffeln';
      expect(_saved(draft).toJson()['tradition_meal'], {
        'slot': 'dinner',
        'free_text': 'Waffeln',
      });
    });

    test('no meal words: the meal is cleared', () {
      final draft = EventDraft.fromEvent(
        tradition(
          meal: const TraditionMeal(slot: 'dinner', freeText: 'Pizza'),
        ),
      )..traditionMeal = '  ';
      final json = _saved(draft).toJson();
      expect(json.containsKey('tradition_meal'), isTrue);
      expect(json['tradition_meal'], isNull);
    });

    test('no longer a tradition: neither the flag nor a meal is sent', () {
      final draft = EventDraft.fromEvent(
        tradition(
          meal: const TraditionMeal(slot: 'dinner', freeText: 'Pizza'),
        ),
      )..tradition = false;
      final json = _saved(draft).toJson();
      expect(json['tradition'], isFalse);
      expect(json.containsKey('tradition_meal'), isFalse);
    });

    test('a presence entry carries no ritual, whatever the draft held', () {
      final draft = EventDraft.fromEvent(tradition())
        ..kind = EventKind.presence;
      final json = _saved(draft).toJson();
      expect(json['icon_key'], '');
      expect(json['countdown'], isFalse);
      expect(json['tradition'], isFalse);
      expect(json.containsKey('tradition_meal'), isFalse);
    });
  });
}
