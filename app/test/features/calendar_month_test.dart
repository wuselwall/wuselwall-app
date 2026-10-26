import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/calendar_month.dart';
import 'package:wuselwall/features/calendar/ui/calendar_month_layout.dart';
import 'package:wuselwall/features/calendar/ui/calendar_page.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_school.dart';
import '../support/fakes.dart';

final _de = AppLocalizationsDe();

/// Wednesday 14 October 2026: the month view's "today" in these tests.
final _today = DateTime(2026, 10, 14);

/// The calendar opens on [anchor] instead of the real today.
class _FixedView extends CalendarViewNotifier {
  _FixedView(this.anchor, [this.mode = CalendarMode.month]);

  final DateTime anchor;
  final CalendarMode mode;

  @override
  CalendarView build() => CalendarView(mode: mode, anchor: anchor);

  /// As chosen by hand: the viewport's default never replaces it.
  @override
  void setResponsiveMode(CalendarMode mode) {}
}

Occurrence _occ(
  String title,
  DateTime day, {
  bool key = false,
  bool tradition = false,
  String? iconKey,
  DateTime? lastDay,
  bool presence = false,
}) {
  final last = lastDay ?? day;
  return Occurrence(
    id: '$title|${isoDate(day)}',
    eventId: 'e-$title',
    calendarId: 'cal',
    title: title,
    kind: presence ? EventKind.presence : EventKind.appointment,
    status: EventStatus.confirmed,
    importance: key ? Importance.key : Importance.normal,
    allDay: true,
    start: day,
    end: DateTime(last.year, last.month, last.day + 1),
    localStartDate: day,
    localEndDate: last,
    iconKey: iconKey,
    tradition: tradition,
  );
}

/// The reference members, Anna born on 29 February 2016.
final _leapMembers = [
  testMembers.first,
  Member(
    id: kidId,
    displayName: 'Anna',
    color: testMembers.last.color,
    role: Role.member,
    active: true,
    isChild: true,
    hasAccount: false,
    birthday: DateTime(2016, 2, 29),
  ),
];

Future<ProviderContainer> _pumpMonth(
  WidgetTester t, {
  DateTime? anchor,
  List<Occurrence> items = const [],
  Map<DateTime, String>? publicHolidays = const {},
  List<HolidayRecord> holidays = const [],
  List<Member>? members,
  Size size = const Size(1400, 900),
  CalendarMode mode = CalendarMode.month,
  List<Override> extra = const [],
}) async {
  final calendar = FakeCalendarRepository(items)
    ..publicHolidays = publicHolidays;
  final container = await pumpApp(
    t,
    size: size,
    overrides: [
      ...baseOverrides(
        identity: FakeIdentityRepository(current: device(), members: members),
        now: DateTime(_today.year, _today.month, _today.day, 10),
      ),
      calendarViewProvider.overrideWith(
        () => _FixedView(anchor ?? _today, mode),
      ),
      ...extra,
    ],
    calendar: calendar,
    school: FakeSchoolRepository(data: referenceSchoolData(holidays: holidays)),
  );
  await openTab(t, _de.calendarTitle);
  return container;
}

Finder _day(DateTime d) => find.byKey(ValueKey('month-day-${isoDate(d)}'));

/// The texts inside the cell of [d].
Finder _inDay(DateTime d, String text) =>
    find.descendant(of: _day(d), matching: find.text(text));

void main() {
  group('the grid', () {
    test('six weeks from the Monday on or before the first', () {
      final days = monthGridDays(DateTime(2026, 10));
      expect(days, hasLength(42));
      expect(days.first, DateTime(2026, 9, 28));
      expect(days.last, DateTime(2026, 11, 8));
      for (var i = 0; i < 42; i += 7) {
        expect(days[i].weekday, DateTime.monday, reason: '${days[i]}');
      }
      // A month that starts on a Monday starts the grid itself.
      expect(monthGridDays(DateTime(2027, 2)).first, DateTime(2027, 2));
    });

    test('a leap February has its 29th, a common one goes on to March', () {
      final leap = monthGridDays(DateTime(2028, 2));
      expect(leap, contains(DateTime(2028, 2, 29)));
      expect(leap.first, DateTime(2028, 1, 31));
      final common = monthGridDays(DateTime(2027, 2));
      expect(common.where((d) => d.month == 2), hasLength(28));
      expect(common[28], DateTime(2027, 3));
    });

    test(
      'a month across the clock change keeps one local midnight per day',
      () {
        for (final month in [DateTime(2026, 3), DateTime(2026, 10)]) {
          final days = monthGridDays(month);
          for (var i = 0; i < days.length; i++) {
            expect(days[i].hour, 0, reason: '${days[i]}');
            if (i > 0) {
              final before = days[i - 1];
              expect(
                days[i],
                DateTime(before.year, before.month, before.day + 1),
                reason: '${days[i]}',
              );
            }
          }
        }
      },
    );

    test('the month mode spans the grid and steps by a month', () {
      final view = CalendarView(
        mode: CalendarMode.month,
        anchor: DateTime(2027, 1, 31),
      );
      expect(view.month, DateTime(2027));
      expect(view.from, DateTime(2026, 12, 28));
      expect(view.to, DateTime(2027, 2, 7));
      expect(view.days, monthGridDays(DateTime(2027)));
      // From the 31st, the next month is February, not 3 March.
      expect(view.shifted(1).month, DateTime(2027, 2));
      expect(view.shifted(-1).month, DateTime(2026, 12));
      expect(view.newEventDay(DateTime(2027, 1, 20, 9)), DateTime(2027, 1, 20));
      expect(view.newEventDay(DateTime(2026, 12, 30)), DateTime(2027));
    });

    test('a 29 February birthday shows on 1 March in other years', () {
      final plan = MonthPlan.of(
        month: DateTime(2027, 2),
        occurrences: const [],
        members: _leapMembers,
        publicHolidays: const {},
        schoolHolidays: const [],
      );
      final days = [for (final w in plan.weeks) ...w];
      final march1 = days.firstWhere((d) => d.date == DateTime(2027, 3));
      expect(march1.birthdays.map((m) => m.id), [kidId]);
      expect(days.where((d) => d.birthdays.isNotEmpty), hasLength(1));
      final leap = MonthPlan.of(
        month: DateTime(2028, 2),
        occurrences: const [],
        members: _leapMembers,
        publicHolidays: const {},
        schoolHolidays: const [],
      );
      final leapDays = [for (final w in leap.weeks) ...w];
      expect(
        leapDays.firstWhere((d) => d.birthdays.isNotEmpty).date,
        DateTime(2028, 2, 29),
      );
    });

    test('Ferien across a weekend are one band per week row', () {
      final plan = MonthPlan.of(
        month: DateTime(2026, 10),
        occurrences: const [],
        members: const [],
        publicHolidays: const {},
        schoolHolidays: [
          HolidayRecord(
            id: 'h1',
            name: 'Herbstferien',
            startsOn: DateTime(2026, 10, 15),
            endsOn: DateTime(2026, 10, 20),
          ),
          // A school's own free day is not Ferien.
          HolidayRecord(
            id: 'h2',
            name: 'Brückentag',
            startsOn: DateTime(2026, 10, 2),
            endsOn: DateTime(2026, 10, 2),
            kind: 'closure_day',
          ),
        ],
      );
      // Week 3 (12–18 Oct): Thursday to Sunday, going on; week 4: Monday, Tuesday.
      expect(plan.ferien[0], isEmpty);
      final third = plan.ferien[2].single;
      expect(
        (third.first, third.last, third.openStart, third.openEnd),
        (3, 6, false, true),
      );
      final fourth = plan.ferien[3].single;
      expect(
        (fourth.first, fourth.last, fourth.openStart, fourth.openEnd),
        (0, 1, true, false),
      );
      expect(fourth.name, 'Herbstferien');
    });

    test('key appointments and traditions are named, the rest counted', () {
      final day = DateTime(2026, 10, 14);
      final plan = MonthPlan.of(
        month: DateTime(2026, 10),
        occurrences: [
          _occ('Elternabend', day, key: true),
          _occ('Spieleabend', day, tradition: true, iconKey: 'game_die'),
          _occ('Zahnarzt', day),
          _occ('Turnen', day),
          _occ('Dienst', day, presence: true),
        ],
        members: const [],
        publicHolidays: const {},
        schoolHolidays: const [],
      );
      final d = plan.weeks[2][2];
      expect(d.date, day);
      expect(d.notable.map((o) => o.title), ['Elternabend', 'Spieleabend']);
      // Presence is no appointment: it is not counted.
      expect(d.others, 2);
    });
  });

  group('in the app', () {
    testWidgets('Monat sits in the switcher and shows the month', (t) async {
      final container = await _pumpMonth(t, mode: CalendarMode.week);
      await t.tap(find.text(_de.calendarMonth));
      await t.pumpAndSettle();
      expect(container.read(calendarViewProvider).mode, CalendarMode.month);
      expect(find.byType(CalendarMonthView), findsOneWidget);
      expect(find.text('Oktober 2026'), findsOneWidget);
      // Six rows of seven days, Monday first, with their ISO week numbers.
      expect(_day(DateTime(2026, 9, 28)), findsOneWidget);
      expect(_day(DateTime(2026, 11, 8)), findsOneWidget);
      expect(_day(DateTime(2026, 9, 27)), findsNothing);
      expect(find.bySemanticsLabel(_de.calendarWeekNumberLabel(40)), findsOne);
      expect(find.bySemanticsLabel(_de.calendarWeekNumberLabel(45)), findsOne);
      expect(t.takeException(), isNull);
    });

    testWidgets('a birthday has its cake and the age, ambience or not', (
      t,
    ) async {
      final members = [
        testMembers.first,
        Member(
          id: kidId,
          displayName: 'Paul',
          color: testMembers.last.color,
          role: Role.member,
          active: true,
          isChild: true,
          hasAccount: false,
          birthday: DateTime(2018, 10, 21),
        ),
      ];
      await _pumpMonth(
        t,
        members: members,
        extra: [
          // The household switched the birthday decoration off.
          lighterDayProvider.overrideWith(
            (ref) => const LighterDay(
              occasionSwitches: {'ambience.birthdays': false},
            ),
          ),
        ],
      );
      final birthday = DateTime(2026, 10, 21);
      expect(_inDay(birthday, 'Paul wird 8'), findsOneWidget);
      expect(
        find.descendant(of: _day(birthday), matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('21. Oktober.*Paul wird 8')),
        findsOneWidget,
      );
    });

    testWidgets('a 29 February birthday is on 1 March of 2027', (t) async {
      await _pumpMonth(t, anchor: DateTime(2027, 2, 10), members: _leapMembers);
      expect(find.text('Februar 2027'), findsOneWidget);
      expect(_inDay(DateTime(2027, 3), 'Anna wird 11'), findsOneWidget);
      expect(find.textContaining('Anna wird'), findsOneWidget);
    });

    testWidgets('Ferien are a band with their name, public holidays named', (
      t,
    ) async {
      await _pumpMonth(
        t,
        publicHolidays: {DateTime(2026, 10, 3): 'Tag der Deutschen Einheit'},
        holidays: [
          HolidayRecord(
            id: 'h1',
            name: 'Herbstferien',
            startsOn: DateTime(2026, 10, 15),
            endsOn: DateTime(2026, 10, 20),
          ),
        ],
      );
      expect(find.byKey(const ValueKey('month-ferien-band')), findsNWidgets(2));
      expect(find.text('Herbstferien'), findsNWidgets(2));
      expect(
        _inDay(DateTime(2026, 10, 3), 'Tag der Deutschen Einheit'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            '3. Oktober.*${_de.boardHolidayLabel('Tag der Deutschen Einheit')}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('16. Oktober.*${_de.calendarMonthFerien('Herbstferien')}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a server without the holidays: the family\'s own are named', (
      t,
    ) async {
      await _pumpMonth(
        t,
        publicHolidays: null,
        holidays: [
          HolidayRecord(
            id: 'p1',
            name: 'Brückentag',
            startsOn: DateTime(2026, 10, 2),
            endsOn: DateTime(2026, 10, 2),
            kind: 'public_holiday',
          ),
        ],
      );
      expect(_inDay(DateTime(2026, 10, 2), 'Brückentag'), findsOneWidget);
    });

    testWidgets('key appointments by name, the others as +n, today marked', (
      t,
    ) async {
      await _pumpMonth(
        t,
        items: [
          _occ('Elternabend', _today, key: true),
          _occ('Zahnarzt', _today),
          _occ('Turnen', _today),
        ],
      );
      expect(_inDay(_today, 'Elternabend'), findsOneWidget);
      expect(_inDay(_today, 'Zahnarzt'), findsNothing);
      expect(_inDay(_today, _de.calendarMonthMore(2)), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(
            '14. Oktober, ${_de.boardToday}, Elternabend, '
            '${_de.calendarMonthOthers(2)}',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a day opens it in the day view', (t) async {
      final container = await _pumpMonth(
        t,
        items: [_occ('Elternabend', DateTime(2026, 10, 22), key: true)],
      );
      await t.tap(_day(DateTime(2026, 10, 22)));
      await t.pumpAndSettle();
      final view = container.read(calendarViewProvider);
      expect(view.mode, CalendarMode.day);
      expect(view.anchor, DateTime(2026, 10, 22));
      expect(find.byType(CalendarMonthView), findsNothing);
      expect(find.text('Elternabend'), findsOneWidget);
    });

    testWidgets('every day is a tap target of at least 48 dp on a phone', (
      t,
    ) async {
      await _pumpMonth(t, size: const Size(360, 740));
      for (final d in monthGridDays(DateTime(2026, 10))) {
        final size = t.getSize(_day(d));
        expect(size.width, greaterThanOrEqualTo(47.99), reason: '$d');
        expect(size.height, greaterThanOrEqualTo(48), reason: '$d');
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('the narrow bar picks the month and moves by months', (
      t,
    ) async {
      final container = await _pumpMonth(
        t,
        size: const Size(390, 844),
        mode: CalendarMode.day,
      );
      await t.tap(find.byTooltip(_de.calendarChooseView));
      await t.pumpAndSettle();
      await t.tap(
        find.ancestor(
          of: find.text(_de.calendarMonth),
          matching: find.byType(CheckedPopupMenuItem<CalendarMode>),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byTooltip('Oktober 2026'), findsOneWidget);
      await t.tap(find.byTooltip(_de.calendarNext));
      await t.pumpAndSettle();
      expect(find.byTooltip('November 2026'), findsOneWidget);
      expect(_day(DateTime(2026, 10, 26)), findsOneWidget);
      await t.tap(find.byTooltip(_de.calendarPrevious));
      await t.tap(find.byTooltip(_de.calendarPrevious));
      await t.pumpAndSettle();
      expect(find.byTooltip('September 2026'), findsOneWidget);
      // The chosen month survives a trip to another tab.
      await openTab(t, _de.shoppingNavLabel);
      await openTab(t, _de.calendarTitle);
      expect(container.read(calendarViewProvider).mode, CalendarMode.month);
      expect(t.takeException(), isNull);
    });

    testWidgets('200 % text keeps the grid whole and counts what is cut', (
      t,
    ) async {
      await _pumpMonth(
        t,
        size: const Size(390, 844),
        publicHolidays: {_today: 'Ein langer Feiertagsname'},
        items: [
          _occ('Elternabend', _today, key: true),
          _occ('Sommerfest', _today, key: true),
          _occ('Zahnarzt', _today),
        ],
      );
      // Larger text once the calendar is open (the navigation bar's labels would
      // leave the screen first).
      t.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(CalendarMonthView), findsOneWidget);
      // At least the first line, the holiday (a flag in a phone's narrow column),
      // and the count of what did not fit.
      expect(
        find.descendant(of: _day(_today), matching: find.byIcon(Icons.flag)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _day(_today),
          matching: find.byKey(const ValueKey('month-more')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a phone column shows marks, never a cut word', (t) async {
      await _pumpMonth(
        t,
        size: const Size(390, 844),
        publicHolidays: {_today: 'Tag der Deutschen Einheit'},
        items: [
          _occ('Spieleabend', _today, key: true, iconKey: 'cake'),
          _occ('Elternabend', _today, key: true),
        ],
      );
      expect(t.takeException(), isNull);
      for (final word in [
        'Tag der Deutschen Einheit',
        'Spieleabend',
        'Elternabend',
      ]) {
        expect(_inDay(_today, word), findsNothing, reason: word);
      }
      expect(
        find.descendant(of: _day(_today), matching: find.byIcon(Icons.flag)),
        findsOneWidget,
      );
      // The words stay with the screen reader.
      expect(
        find.bySemanticsLabel(RegExp('Tag der Deutschen Einheit.*Spieleabend')),
        findsOneWidget,
      );
    });

    testWidgets('the floating buttons never cover the last week', (t) async {
      await _pumpMonth(t, size: const Size(390, 844));
      final lastDay = monthGridDays(DateTime(2026, 10)).last;
      final cell = t.getRect(_day(lastDay));
      final fabs = find.byType(FloatingActionButton);
      expect(fabs, findsWidgets);
      for (final fab in fabs.evaluate()) {
        final rect = t.getRect(find.byWidget(fab.widget));
        expect(cell.bottom, lessThanOrEqualTo(rect.top + 0.5));
      }
    });

    for (final language in ['de', 'en', 'fr', 'es']) {
      for (final width in [1100.0, 1200.0, 1280.0, 1366.0, 1440.0]) {
        testWidgets('the four view buttons fit a $width bar in $language', (
          t,
        ) async {
          final l10n = lookupAppLocalizations(Locale(language));
          await pumpApp(
            t,
            locale: Locale(language),
            size: Size(width, 844),
            overrides: [
              ...baseOverrides(
                identity: FakeIdentityRepository(current: device()),
              ),
              calendarViewProvider.overrideWith(() => _FixedView(_today)),
            ],
          );
          await openTab(t, l10n.calendarTitle);
          expect(find.byType(CalendarToolbar), findsOneWidget);
          expect(t.takeException(), isNull);
        });
      }
    }
  });

  for (final shade in Shade.values) {
    testWidgets('the grid in the ${shade.name} shade: ink on the Ferien band', (
      t,
    ) async {
      t.view.physicalSize = const Size(800, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final theme = AppTheme.build(UiRegister.adult, shade);
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MonthGrid(
              plan: MonthPlan.of(
                month: DateTime(2026, 10),
                occurrences: [_occ('Elternabend', _today, key: true)],
                members: _leapMembers,
                publicHolidays: {DateTime(2026, 10, 3): 'Feiertag'},
                schoolHolidays: [
                  HolidayRecord(
                    id: 'h1',
                    name: 'Herbstferien',
                    startsOn: DateTime(2026, 10, 15),
                    endsOn: DateTime(2026, 10, 20),
                  ),
                ],
              ),
              members: _leapMembers,
              today: _today,
              onOpenDay: (_) {},
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      final ww = theme.extension<WwColors>()!;
      for (final label in t.widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('month-ferien-band')),
          matching: find.byType(Text),
        ),
      )) {
        expect(label.style?.color, theme.colorScheme.onSurface);
        expect(label.style?.color, isNot(ww.ink3));
      }
    });
  }
}
