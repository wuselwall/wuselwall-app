import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart' show BoardFrame;
import 'package:wuselwall/features/board/ui/board_zones.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/tradition_starters.dart';
import 'package:wuselwall/features/calendar/ui/event_editor_page.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/application/birthday_providers.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/application/today_tradition_provider.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';
import 'package:wuselwall/features/wusel/ui/board_wusel.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fakes.dart';

// Kalender → Neue Tradition, the morning line on a tradition's day, Wusel's wave for a
// countdown at "Morgen!" or "Heute!" and the birthdays in the board's day names
// (specs/27). Test data only.

final _de = AppLocalizationsDe();

/// Today at 09:30, so the calendar's own "today" and the app clock agree.
DateTime _todayMorning() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 9, 30);
}

/// The first [weekday] on or after [from].
DateTime _next(DateTime from, int weekday) =>
    DateTime(from.year, from.month, from.day + (weekday - from.weekday) % 7);

Future<FakeCalendarRepository> _calendarTab(
  WidgetTester t, {
  bool supported = true,
  Locale locale = const Locale('de'),
}) async {
  final cal = FakeCalendarRepository();
  await pumpApp(
    t,
    overrides: [
      ...baseOverrides(
        identity: FakeIdentityRepository(current: device()),
        now: _todayMorning(),
      ),
      if (!supported) lighterDaySupportedProvider.overrideWith((ref) => false),
    ],
    calendar: cal,
    locale: locale,
  );
  await openTab(t, lookupAppLocalizations(locale).calendarTitle);
  return cal;
}

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

Member _member(String id, String name, {DateTime? birthday, int order = 0}) =>
    Member(
      id: id,
      displayName: name,
      color: const Color(0xFF2E7D6B),
      role: Role.member,
      active: true,
      sortOrder: order,
      birthday: birthday,
    );

/// The week of Mon 12 Oct 2026 without holidays; today is Wed 14 Oct.
WeekBoard _board() => WeekBoard.fromJson({
  'week_start': '2026-10-12',
  'today': '2026-10-14',
  'generated_at': '2026-10-14T14:05:00',
  'settings': {
    'day_parts': ['12:00', '17:00'],
    'member_label': 'name',
  },
  'members': [
    {'id': 'paul', 'display_name': 'Paul', 'color': '#D9622B', 'kind': 'child'},
  ],
  'presence': <Object>[],
  'timetables': <Object>[],
  'days': [
    for (var i = 0; i < 7; i++)
      {
        'date': '2026-10-${(12 + i).toString().padLeft(2, '0')}',
        'events': <Object>[],
        'busy_until': <Object>[],
        'school': <Object>[],
        'meal': null,
        'holiday': null,
      },
  ],
  'open_tasks': <Object>[],
  'shopping_count': 0,
});

Widget _kiosk(List<Override> overrides, Widget child, {double height = 72}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.kiosk, Shade.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 1280, height: height, child: child),
          ),
        ),
      ),
    );

class _Day extends NightNotifier {
  @override
  bool build() => false;
}

void main() {
  group('Kalender → Neue Tradition', () {
    testWidgets('offers the six starters of specs/27 and the family\'s own', (
      t,
    ) async {
      await _calendarTab(t);
      await _tap(t, find.byTooltip(_de.calendarNewTradition));
      for (final name in [
        'Spieleabend',
        'Pizza-Freitag',
        'Filmabend',
        'Sonntagsfrühstück',
        'Vorlesezeit',
        'Ausflugstag',
        _de.traditionStarterOwn,
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('Jeden Freitag, 18:00'), findsOneWidget);
      expect(find.text('Jeden Sonntag, ganztägig'), findsOneWidget);
    });

    testWidgets(
      'Pizza-Freitag opens the editor as a weekly whole-family tradition with its meal',
      (t) async {
        final cal = await _calendarTab(t);
        await _tap(t, find.byTooltip(_de.calendarNewTradition));
        await _tap(t, find.text('Pizza-Freitag'));

        expect(find.byType(EventEditorPage), findsOneWidget);
        expect(
          find.widgetWithText(AppBar, _de.calendarNewTradition),
          findsOneWidget,
        );
        // The meal shows in the editor, so it can be changed before saving.
        expect(find.widgetWithText(TextField, 'Pizza'), findsOneWidget);

        await _tap(t, find.widgetWithText(FilledButton, _de.save));
        final saved = cal.saved.single;
        final friday = _next(_todayMorning(), DateTime.friday);
        expect(saved.title, 'Pizza-Freitag');
        expect(saved.tradition, isTrue);
        expect(saved.iconKey, 'pizza');
        expect(saved.rrule, 'FREQ=WEEKLY;BYDAY=FR');
        expect(saved.importance, Importance.key);
        expect(saved.isAllDay, isFalse);
        expect(
          saved.startsAt,
          DateTime(friday.year, friday.month, friday.day, 18),
        );
        expect(
          saved.endsAt,
          DateTime(friday.year, friday.month, friday.day, 19),
        );
        expect(saved.attendeeIds, [
          for (final m in testMembers)
            if (m.active) m.id,
        ]);
        expect(saved.traditionMeal?.freeText, 'Pizza');
        expect(saved.traditionMeal?.slot, 'dinner');
      },
    );

    testWidgets('Ausflugstag is all day on Sunday, without a meal', (t) async {
      final cal = await _calendarTab(t);
      await _tap(t, find.byTooltip(_de.calendarNewTradition));
      await _tap(t, find.text('Ausflugstag'));
      await _tap(t, find.widgetWithText(FilledButton, _de.save));
      final saved = cal.saved.single;
      final sunday = _next(_todayMorning(), DateTime.sunday);
      expect(saved.isAllDay, isTrue);
      expect(saved.startDate, sunday);
      expect(saved.endDate, sunday);
      expect(saved.rrule, 'FREQ=WEEKLY;BYDAY=SU');
      expect(saved.iconKey, 'hiking');
      expect(saved.traditionMeal, isNull);
    });

    testWidgets('the family\'s own starts without a name and is a tradition', (
      t,
    ) async {
      final cal = await _calendarTab(t);
      await _tap(t, find.byTooltip(_de.calendarNewTradition));
      await _tap(t, find.text(_de.traditionStarterOwn));
      await t.enterText(find.byType(TextField).first, 'Waffelsonntag');
      await t.pump();
      await _tap(t, find.widgetWithText(FilledButton, _de.save));
      final saved = cal.saved.single;
      expect(saved.title, 'Waffelsonntag');
      expect(saved.tradition, isTrue);
      expect(saved.iconKey, isNull);
      expect(saved.rrule, startsWith('FREQ=WEEKLY;BYDAY='));
    });

    testWidgets('an older server shows no Neue Tradition', (t) async {
      await _calendarTab(t, supported: false);
      expect(find.byTooltip(_de.calendarNewTradition), findsNothing);
      expect(
        find.widgetWithText(FloatingActionButton, _de.calendarNewEvent),
        findsOneWidget,
      );
    });

    for (final lang in ['en', 'fr', 'es']) {
      testWidgets('the starters have their own names in $lang', (t) async {
        final l10n = lookupAppLocalizations(Locale(lang));
        await _calendarTab(t, locale: Locale(lang));
        await _tap(t, find.byTooltip(l10n.calendarNewTradition));
        expect(find.text(l10n.traditionStarterGameNight), findsOneWidget);
        expect(find.text(l10n.traditionStarterDayOut), findsOneWidget);
        expect(find.text(l10n.traditionStarterOwn), findsOneWidget);
        expect(l10n.traditionStarterGameNight, isNot('Spieleabend'));
        expect(t.takeException(), isNull);
      });
    }

    test('a starter begins on its weekday, on or after the day given', () {
      // Wednesday 14 Oct 2026.
      final wednesday = DateTime(2026, 10, 14);
      expect(
        TraditionStarter.gameNight.firstDay(wednesday),
        DateTime(2026, 10, 16),
      );
      expect(TraditionStarter.storyTime.firstDay(wednesday), wednesday);
      expect(
        TraditionStarter.sundayBreakfast.firstDay(wednesday),
        DateTime(2026, 10, 18),
      );
      // Across the October clock change.
      final t = TraditionStarter.sundayBreakfast.template(
        title: 'x',
        from: DateTime(2026, 10, 19),
      );
      expect(t.start, DateTime(2026, 10, 25, 9));
      expect(t.end, DateTime(2026, 10, 25, 10, 30));
    });
  });

  group('birthdays on the board\'s day names', () {
    final paul = _member('paul', 'Paul', birthday: DateTime(2018, 10, 16));

    test('birthdaysOn finds the day, 29 February on 1 March', () {
      final leap = _member('lea', 'Lea', birthday: DateTime(2016, 2, 29));
      expect(birthdaysOn(DateTime(2026, 10, 16), [paul, leap]), [paul]);
      expect(birthdaysOn(DateTime(2026, 3, 1), [paul, leap]), [leap]);
      expect(birthdaysOn(DateTime(2028, 2, 29), [paul, leap]), [leap]);
      expect(birthdaysOn(DateTime(2026, 10, 15), [paul, leap]), isEmpty);
    });

    test('the switch is on unless the household turned it off', () {
      expect(birthdaysShown(const LighterDay()), isTrue);
      expect(
        birthdaysShown(
          const LighterDay(occasionSwitches: {'ambience.birthdays': 'auto'}),
        ),
        isTrue,
      );
      expect(
        birthdaysShown(
          const LighterDay(occasionSwitches: {'ambience.birthdays': false}),
        ),
        isFalse,
      );
    });

    test('a birthday makes the row taller, like a holiday', () {
      expect(DayHeaderRow.heightOf(_board()), DayHeaderRow.height);
      expect(
        DayHeaderRow.heightOf(_board(), birthdays: true),
        DayHeaderRow.holidayHeight,
      );
    });

    Future<void> pumpHeader(WidgetTester t, LighterDay day) async {
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final board = _board();
      await t.pumpWidget(
        _kiosk(
          [
            nowProvider.overrideWithValue(DateTime(2026, 10, 14, 14, 5)),
            membersProvider.overrideWith((ref) async => [paul]),
            lighterDayProvider.overrideWith((ref) => day),
          ],
          DayHeaderRow(
            frame: BoardFrame(
              board: board,
              geometry: const BoardGeometry(canvasWidth: 1280, todayIndex: 2),
              night: false,
            ),
          ),
        ),
      );
      await t.pump();
    }

    testWidgets('the day says "Paul wird 8" under its date', (t) async {
      await pumpHeader(t, const LighterDay());
      expect(find.text('Paul wird 8'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Freitag.*Paul wird 8')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('switched off, the day names stay plain', (t) async {
      await pumpHeader(
        t,
        const LighterDay(occasionSwitches: {'ambience.birthdays': false}),
      );
      expect(find.text('Paul wird 8'), findsNothing);
    });
  });

  group('the wall\'s Wusel', () {
    final today = DateTime(2026, 10, 14);

    Countdown zoo(int inDays) => Countdown(
      kind: CountdownKind.event,
      date: DateTime(today.year, today.month, today.day + inDays),
      title: 'Zoo',
    );

    Future<void> pumpWusel(
      WidgetTester t, {
      required DateTime now,
      String? tradition,
      List<Countdown> countdowns = const [],
    }) async {
      await t.pumpWidget(
        _kiosk([
          nowProvider.overrideWithValue(now),
          ritualTodayProvider.overrideWithValue(today),
          nightProvider.overrideWith(_Day.new),
          nightHoursProvider.overrideWith((ref) => NightHours.standard),
          ambienceProvider.overrideWith(
            (ref) => const Ambience(phase: SkyPhase.day),
          ),
          lighterDayProvider.overrideWith((ref) => const LighterDay()),
          uiRegisterProvider.overrideWithValue(UiRegister.kiosk),
          wuselTuftsProvider.overrideWith((ref) => const [Color(0xFF2E7D6B)]),
          wuselFrontTuftProvider.overrideWith((ref) => null),
          todayTraditionProvider.overrideWith((ref) => tradition),
          countdownsProvider.overrideWith((ref) => countdowns),
        ], const BoardWusel(stale: false)),
      );
      await t.pump();
    }

    WuselPose? pose(WidgetTester t) =>
        t.widgetList<Wusel>(find.byType(Wusel)).singleOrNull?.pose;

    Future<void> unmount(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(minutes: 2));
    }

    // 6:10 is the morning's first half hour; on the 15th the wall's line is the first
    // variant (WuselLines.stable picks by the day of the month).
    testWidgets('the morning names today\'s tradition', (t) async {
      await pumpWusel(
        t,
        now: DateTime(2026, 10, 15, 6, 10),
        tradition: 'Spieleabend',
      );
      expect(find.text('Heute ist Spieleabend!'), findsOneWidget);
      expect(pose(t), WuselPose.wave);
      await unmount(t);
    });

    testWidgets('without a tradition the morning greets everyone', (t) async {
      await pumpWusel(t, now: DateTime(2026, 10, 15, 6, 10));
      expect(find.text(_de.wuselWallMorning1), findsOneWidget);
      await unmount(t);
    });

    testWidgets('a countdown at Morgen! makes the one corner Wusel wave', (
      t,
    ) async {
      await pumpWusel(t, now: DateTime(2026, 10, 14, 11), countdowns: [zoo(1)]);
      expect(find.byType(Wusel), findsOneWidget);
      expect(pose(t), WuselPose.wave);
      await unmount(t);
    });

    testWidgets('a countdown further away leaves Wusel at rest', (t) async {
      await pumpWusel(t, now: DateTime(2026, 10, 14, 11), countdowns: [zoo(3)]);
      expect(pose(t), WuselPose.idle);
      await unmount(t);
    });

    test('waveFor takes the nearest at tomorrow or today only', () {
      expect(waveFor([zoo(0)], today)?.title, 'Zoo');
      expect(waveFor([zoo(1), zoo(2)], today), isNotNull);
      expect(waveFor([zoo(2)], today), isNull);
      expect(waveFor(const [], today), isNull);
    });
  });
}
