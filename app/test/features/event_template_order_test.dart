import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/matching/dictionary.dart';
import 'package:wuselwall/core/matching/matcher.dart' as wusel;
import 'package:wuselwall/core/matching/matching_providers.dart';
import 'package:wuselwall/core/text/suggest.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/event_templates.dart';
import 'package:wuselwall/features/calendar/ui/event_template_page.dart';

import '../support/fakes.dart';

// The built-in tiles of the new-event page put the family's habits first (specs/29
// feature 3). Test data only.

String? _iconOf(String title) => title.toLowerCase().contains('fussball')
    ? 'football'
    : title.toLowerCase().contains('kino')
    ? 'cinema'
    : null;

TextSuggestion _entry(String text, {int count = 1, String? iconKey}) =>
    TextSuggestion(text: text, count: count, iconKey: iconKey);

void main() {
  final general = EventStarter.general;

  group('orderBuiltInsByHabit', () {
    test('no history leaves the order alone', () {
      expect(orderBuiltInsByHabit(general, const [], _iconOf), general);
    });

    test('a picture used twice moves its tile to the front', () {
      final ordered = orderBuiltInsByHabit(general, [
        _entry('Training', count: 2, iconKey: 'football'),
      ], _iconOf);
      expect(ordered.first, EventStarter.sportsPractice);
      expect(
        ordered.skip(1).toList(),
        general.where((s) => s != EventStarter.sportsPractice).toList(),
      );
    });

    test('the appointment\'s own picture counts', () {
      final ordered = orderBuiltInsByHabit(general, [
        _entry('Irgendwas', count: 1, iconKey: 'cinema'),
        _entry('Anderes', count: 1, iconKey: 'cinema'),
      ], (_) => null);
      expect(ordered.first, EventStarter.cinema);
    });

    test('without a picture of its own the title is matched', () {
      final ordered = orderBuiltInsByHabit(general, [
        _entry('Fussballtraining', count: 3),
        _entry('Fussballspiel', count: 1),
      ], _iconOf);
      expect(ordered.first, EventStarter.sportsPractice);
    });

    test('its own picture wins over the matched title', () {
      final ordered = orderBuiltInsByHabit(general, [
        _entry('Fussballtraining', count: 5, iconKey: 'cinema'),
      ], _iconOf);
      expect(ordered.first, EventStarter.cinema);
    });

    test('one appointment is not a habit', () {
      expect(
        orderBuiltInsByHabit(general, [_entry('Kino', count: 1)], _iconOf),
        general,
      );
    });

    test('the most used comes first, ties keep the built-in order', () {
      final ordered = orderBuiltInsByHabit(general, [
        _entry('Kino', count: 2),
        _entry('Fussball', count: 2),
        _entry('Gäste', count: 4, iconKey: 'house'),
      ], _iconOf);
      expect(ordered.take(3).toList(), [
        EventStarter.guestDinner,
        EventStarter.sportsPractice, // before the cinema in the built-in order
        EventStarter.cinema,
      ]);
      expect(ordered, hasLength(general.length));
      expect(ordered.toSet(), general.toSet());
    });

    test(
      'pictures no tile has, and tiles without a picture, change nothing',
      () {
        expect(
          orderBuiltInsByHabit(general, [
            _entry('Sonstiges', count: 9, iconKey: 'unknown'),
            _entry('Arzt', count: 9),
          ], _iconOf),
          general,
        );
      },
    );
  });

  testWidgets('a family that trains often sees that tile before the others', (
    t,
  ) async {
    final cal = FakeCalendarRepository();
    cal.history = [
      for (var i = 0; i < 4; i++)
        EventHistoryRow(
          title: 'Fussballtraining',
          updatedAt: DateTime(2026, 10, 1 + i),
        ),
    ];
    final dictionary = MatchDictionary.fromJson('events', {
      'entries': [
        {
          'key': 'football',
          'categories': <String>[],
          'words': ['fussballtraining'],
        },
      ],
    });
    await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          identity: FakeIdentityRepository(current: device()),
          now: DateTime.now(),
        ),
        eventsMatcherProvider.overrideWith((ref) => wusel.Matcher(dictionary)),
      ],
      calendar: cal,
    );
    await openTab(t, 'Kalender');
    await t.tap(find.widgetWithText(FloatingActionButton, 'Neuer Termin'));
    await t.pumpAndSettle();
    expect(find.byType(EventTemplatePage), findsOneWidget);

    double top(EventStarter s) => t
        .getTopLeft(find.byKey(ValueKey('event-template-builtin-${s.name}')))
        .dy;
    double left(EventStarter s) => t
        .getTopLeft(find.byKey(ValueKey('event-template-builtin-${s.name}')))
        .dx;
    final first = EventStarter.general.first; // the cleaner, in the usual order
    expect(first, isNot(EventStarter.sportsPractice));
    final before =
        top(EventStarter.sportsPractice) < top(first) ||
        (top(EventStarter.sportsPractice) == top(first) &&
            left(EventStarter.sportsPractice) < left(first));
    expect(before, isTrue);
  });
}
