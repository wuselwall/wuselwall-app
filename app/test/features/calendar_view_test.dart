import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/calendar_board.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

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
  test(
    'calendar ranges and navigation use local calendar days across fall DST',
    () {
      final view = CalendarView(
        mode: CalendarMode.threeDays,
        anchor: DateTime(2026, 10, 24),
      );

      expect(view.from, DateTime(2026, 10, 24));
      expect(view.to, DateTime(2026, 10, 26));
      expect(view.days, [
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 26),
      ]);
      expect(view.shifted(-1).days, [
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 22),
        DateTime(2026, 10, 23),
      ]);
      expect(view.shifted(1).days, [
        DateTime(2026, 10, 27),
        DateTime(2026, 10, 28),
        DateTime(2026, 10, 29),
      ]);
      final week = CalendarView(
        mode: CalendarMode.week,
        anchor: DateTime(2026, 10, 25),
      );
      expect(week.from, DateTime(2026, 10, 19));
      expect(week.to, DateTime(2026, 10, 25));
      expect(week.days.first, DateTime(2026, 10, 19));
      expect(week.days.last, DateTime(2026, 10, 25));
    },
  );

  test(
    'calendar ranges and navigation use local calendar days across spring DST',
    () {
      final view = CalendarView(
        mode: CalendarMode.threeDays,
        anchor: DateTime(2026, 3, 28),
      );

      expect(view.from, DateTime(2026, 3, 28));
      expect(view.to, DateTime(2026, 3, 30));
      expect(view.days, [
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 29),
        DateTime(2026, 3, 30),
      ]);
      expect(view.shifted(-1).days, [
        DateTime(2026, 3, 25),
        DateTime(2026, 3, 26),
        DateTime(2026, 3, 27),
      ]);
      expect(view.shifted(1).days, [
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 2),
      ]);
      final week = CalendarView(
        mode: CalendarMode.week,
        anchor: DateTime(2026, 3, 29),
      );
      expect(week.from, DateTime(2026, 3, 23));
      expect(week.to, DateTime(2026, 3, 29));
      expect(week.days.first, DateTime(2026, 3, 23));
      expect(week.days.last, DateTime(2026, 3, 29));
    },
  );

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
    await t.tap(find.byTooltip(_de.calendarChooseView));
    await t.pumpAndSettle();
    await _chooseMode(t, _de.calendarWeek);

    expect(t.takeException(), isNull);
    expect(find.text('Elternabend'), findsOneWidget);
    // Too narrow for a title: the block shows its first attendee's initial.
    expect(find.text('P'), findsWidgets);
  });

  testWidgets(
    'a one-day chip in a phone week names itself only in its tooltip',
    (t) async {
      await pumpApp(
        t,
        size: const Size(390, 844),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        calendar: FakeCalendarRepository([
          occ(
            title: 'Fotografieren',
            day: dayOfThisWeek(1),
            attendees: const [kidId],
          ),
          occ(
            title: 'Dienst',
            day: dayOfThisWeek(0),
            attendees: const [guardianId],
            presence: PresenceState.working,
          ),
        ]),
      );
      await openTab(t, 'Kalender');
      await t.tap(find.byTooltip(_de.calendarChooseView));
      await t.pumpAndSettle();
      await _chooseMode(t, _de.calendarWeek);

      expect(t.takeException(), isNull);
      // No "Fo…" and no "Die…": the words wait in the tooltip.
      expect(textWith('Fotografieren'), findsNothing);
      expect(find.byTooltip('Fotografieren'), findsOneWidget);
      expect(find.byTooltip('Dienst'), findsOneWidget);
      // The all-day row's mark replaces the cut "ganzt…".
      expect(find.byTooltip(_de.boardAllDay), findsOneWidget);
    },
  );

  testWidgets('the day view names the day in full once, the bar short', (
    t,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await pumpApp(
      t,
      size: const Size(360, 640),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      calendar: FakeCalendarRepository([
        occ(
          title: 'Zahnarzt',
          day: today,
          from: const TimeOfDay(hour: 10, minute: 0),
          to: const TimeOfDay(hour: 11, minute: 0),
        ),
      ]),
    );
    await openTab(t, 'Kalender');
    final full = DateFormat.MMMMEEEEd('de').format(today);
    expect(find.text(full), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text(full)),
      findsNothing,
    );
  });

  testWidgets('the time grid scrolls its last hour clear of the buttons', (
    t,
  ) async {
    await pumpApp(
      t,
      size: const Size(390, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );
    await openTab(t, 'Kalender');
    final grid = find
        .descendant(
          of: find.byType(CalendarBoard),
          matching: find.byType(Scrollable),
        )
        .last;
    await t.drag(grid, const Offset(0, -3000));
    await t.pumpAndSettle();
    final lastHour = find.text('21').last;
    final label = t.getRect(lastHour);
    for (final fab in find.byType(FloatingActionButton).evaluate()) {
      expect(
        label.bottom,
        lessThanOrEqualTo(t.getRect(find.byWidget(fab.widget)).top),
      );
    }
  });

  testWidgets(
    'phone starts in Day and explicit mode survives tab changes and rotation',
    (t) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final container = await pumpApp(
        t,
        size: const Size(390, 844),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        calendar: FakeCalendarRepository([
          occ(
            title: 'Dentist appointment',
            day: today,
            from: const TimeOfDay(hour: 10, minute: 0),
            to: const TimeOfDay(hour: 11, minute: 0),
            attendees: const [guardianId],
          ),
        ]),
      );
      await openTab(t, 'Kalender');
      expect(container.read(calendarViewProvider).mode, CalendarMode.day);
      expect(find.text('Dentist appointment'), findsOneWidget);

      await t.tap(find.byTooltip(_de.calendarChooseView));
      await t.pumpAndSettle();
      await _chooseMode(t, _de.calendarThreeDays);
      expect(container.read(calendarViewProvider).mode, CalendarMode.threeDays);
      container.read(homeTabProvider.notifier).select(HomeTab.shopping);
      await t.pumpAndSettle();
      container.read(homeTabProvider.notifier).select(HomeTab.calendar);
      await t.pumpAndSettle();

      t.view.physicalSize = const Size(1000, 844);
      await t.pumpAndSettle();
      expect(container.read(calendarViewProvider).mode, CalendarMode.threeDays);
    },
  );

  testWidgets('wide calendar starts in Week', (t) async {
    final container = await pumpApp(
      t,
      size: const Size(1000, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );
    await openTab(t, 'Kalender');
    expect(container.read(calendarViewProvider).mode, CalendarMode.week);
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

final _de = AppLocalizationsDe();

/// The text a Text widget found by [finder] shows, plain.
String plainText(WidgetTester t, Finder finder) {
  final w = t.widget<Text>(finder);
  return w.data ?? w.textSpan!.toPlainText();
}

Future<void> _chooseMode(WidgetTester tester, String label) async {
  final menuItem = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) => widget is CheckedPopupMenuItem,
    ),
  );
  await tester.tap(menuItem);
  await tester.pumpAndSettle();
}
