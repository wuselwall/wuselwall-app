import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/editor/event_draft.dart';

/// A timed draft from [start] to [end], switched to all-day.
EventDraft _allDay(DateTime start, DateTime end) =>
    EventDraft(start: start, end: end, title: 'Ferien')..setAllDay(true);

CalendarEvent _saved(EventDraft draft) =>
    draft.toEvent(attendees: const [], key: false);

void main() {
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
