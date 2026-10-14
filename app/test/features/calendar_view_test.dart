import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/calendar_board.dart';

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
    status: EventStatus.confirmed,
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

/// The first day of this week's columns is the Monday; offsets count from there.
DateTime dayOfThisWeek(int offset) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day + offset);
}

/// The plain text of every [Text] whose content contains [needle], plain or rich.
Finder textWith(String needle) => find.byWidgetPredicate(
  (w) =>
      w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').contains(needle),
);

void main() {
  testWidgets('a presence band across two days renders its label once', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      calendar: FakeCalendarRepository([
        occ(
          title: 'Dienst',
          day: dayOfThisWeek(1),
          lastDay: dayOfThisWeek(2),
          attendees: const [guardianId],
          presence: PresenceState.working,
        ),
      ]),
    );
    await openTab(t, 'Kalender');

    expect(find.byType(PresenceBandView), findsOneWidget);
    expect(find.text('Dienst'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a multi-day all-day chip renders once', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      calendar: FakeCalendarRepository([
        occ(
          title: 'Ferien am See',
          day: dayOfThisWeek(0),
          lastDay: dayOfThisWeek(3),
        ),
      ]),
    );
    await openTab(t, 'Kalender');

    expect(find.text('Ferien am See'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a 30-minute block shows its time and title in one Text', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      calendar: FakeCalendarRepository([
        occ(
          title: 'Klavier',
          day: dayOfThisWeek(0),
          from: const TimeOfDay(hour: 16, minute: 0),
          to: const TimeOfDay(hour: 16, minute: 30),
          attendees: const [guardianId],
        ),
      ]),
    );
    await openTab(t, 'Kalender');

    final block = textWith('Klavier');
    expect(block, findsOneWidget);
    expect(plainText(t, block), contains('16:00'));
    expect(plainText(t, block), contains('Klavier'));
  });

  testWidgets('a phone-width week view lays out without exceptions', (t) async {
    await pumpApp(
      t,
      size: const Size(390, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      calendar: FakeCalendarRepository([
        occ(
          title: 'Klavierstunde mit Frau Berger',
          day: dayOfThisWeek(0),
          from: const TimeOfDay(hour: 16, minute: 0),
          to: const TimeOfDay(hour: 16, minute: 30),
          attendees: const [guardianId],
        ),
        occ(
          title: 'Elternabend',
          day: dayOfThisWeek(2),
          lastDay: dayOfThisWeek(3),
          attendees: const [kidId],
        ),
        occ(
          title: 'Dienst',
          day: dayOfThisWeek(4),
          lastDay: dayOfThisWeek(6),
          attendees: const [guardianId],
          presence: PresenceState.working,
        ),
      ]),
    );
    await openTab(t, 'Kalender');

    expect(t.takeException(), isNull);
    expect(find.text('Elternabend'), findsOneWidget);
    // Too narrow for a title: the block shows its first attendee's initial.
    expect(find.text('P'), findsWidgets);
  });

  testWidgets('the grid opens at 07:00 when the first appointment is later', (
    t,
  ) async {
    await pumpApp(
      t,
      // Short enough that the 16-hour grid scrolls.
      size: const Size(1000, 600),
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
      ]),
    );
    await openTab(t, 'Kalender');

    // The grid starts at 06:00, one row of 52 px per hour: 07:00 is 52 px down.
    final grid = t.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CalendarBoard),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    expect(grid.position.pixels, 52.0);
  });
}

/// The text a Text widget found by [finder] shows, plain.
String plainText(WidgetTester t, Finder finder) {
  final w = t.widget<Text>(finder);
  return w.data ?? w.textSpan!.toPlainText();
}
