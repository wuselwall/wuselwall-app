import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/calendar_page.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';
import 'package:wuselwall/features/today/domain/notice.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';
import 'package:wuselwall/l10n/generated/app_localizations_en.dart';
import 'package:wuselwall/l10n/generated/app_localizations_es.dart';
import 'package:wuselwall/l10n/generated/app_localizations_fr.dart';

import '../support/fake_getting_started.dart';
import '../support/fake_notices.dart';
import '../support/fakes.dart';

final _de = AppLocalizationsDe();
final _notice = AppNotice(
  key: 'join:ios-layout',
  kind: NoticeKind.join,
  name: 'Julia',
  at: DateTime(2026, 10, 15, 9),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('AtkinsonHyperlegibleNext');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(
        rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$weight.ttf'),
      );
    }
    await loader.load();
  });

  testWidgets(
    'iPhone defaults to Day and keeps an explicit view after resize and tab changes',
    (t) async {
      final container = await pumpApp(
        t,
        size: const Size(390, 844),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      await openTab(t, 'Kalender');

      expect(
        Theme.of(t.element(find.byType(CalendarPage))).platform,
        TargetPlatform.iOS,
      );
      expect(container.read(calendarViewProvider).mode, CalendarMode.day);

      await t.tap(find.byTooltip(_de.calendarChooseView));
      await t.pumpAndSettle();
      await _chooseMode(t, _de.calendarThreeDays);
      expect(container.read(calendarViewProvider).mode, CalendarMode.threeDays);

      container.read(homeTabProvider.notifier).select(HomeTab.shopping);
      await t.pumpAndSettle();
      container.read(homeTabProvider.notifier).select(HomeTab.calendar);
      t.view.physicalSize = const Size(1024, 768);
      await t.pumpAndSettle();
      expect(container.read(calendarViewProvider).mode, CalendarMode.threeDays);
      expect(
        Theme.of(t.element(find.byType(CalendarPage))).platform,
        TargetPlatform.iOS,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final width in [768.0, 1024.0]) {
    testWidgets('iPad ${width.toInt()}dp defaults to Week', (t) async {
      final container = await pumpApp(
        t,
        size: Size(width, 1024),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
      );
      await openTab(t, 'Kalender');
      expect(
        Theme.of(t.element(find.byType(CalendarPage))).platform,
        TargetPlatform.iOS,
      );
      expect(container.read(calendarViewProvider).mode, CalendarMode.week);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  for (final sample in <(Locale, String)>[
    (const Locale('de'), AppLocalizationsDe().todayAllDay),
    (const Locale('en'), AppLocalizationsEn().todayAllDay),
    (const Locale('fr'), AppLocalizationsFr().todayAllDay),
    (const Locale('es'), AppLocalizationsEs().todayAllDay),
  ]) {
    testWidgets(
      'iOS Today labels remain readable at 1.5 scale in ${sample.$1.languageCode}',
      (t) async {
        t.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpApp(
          t,
          locale: sample.$1,
          size: const Size(390, 844),
          overrides: baseOverrides(
            identity: FakeIdentityRepository(current: device()),
          ),
          calendar: FakeCalendarRepository([
            _todayEvent(
              title: 'Timed meeting',
              start: const TimeOfDay(hour: 16, minute: 0),
            ),
            _todayEvent(title: 'All-day visit', allDay: true),
          ]),
        );

        final time = find.text('16:00');
        final allDay = find.text(sample.$2);
        expect(time, findsOneWidget);
        expect(_lineCount(t, time), 1);
        expect(
          t.renderObject<RenderParagraph>(time).size.width,
          greaterThan(56),
        );
        expect(allDay, findsOneWidget);
        expect(_lineCount(t, allDay), inInclusiveRange(1, 2));
        expect(
          t.renderObject<RenderParagraph>(allDay).size.height,
          greaterThan(20),
        );
        expect(t.widget<Text>(allDay).maxLines, isNull);
        expect(t.widget<Text>(allDay).overflow, isNull);
        expect(find.text('Timed meeting'), findsOneWidget);
        expect(find.text('All-day visit'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'narrow iPhone stacks Today card actions below readable messages',
    (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(
        t,
        size: const Size(390, 844),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        notices: FakeNoticesRepository([_notice]),
        gettingStarted: FakeGettingStartedRepository(const [
          GettingStartedItem(item: StartItem.wallDisplay, done: false),
        ]),
      );

      final noticeMessage = find.text(_de.todayNoticeJoined('Julia'));
      final noticeAction = find.text(_de.todayNoticeMembers);
      final dismissAction = find.text(_de.todayNoticeDismiss);
      expect(_lineCount(t, noticeMessage), greaterThanOrEqualTo(1));
      expect(t.widget<Text>(noticeMessage).maxLines, isNull);
      expect(
        t.getTopLeft(noticeAction).dy,
        greaterThan(t.getBottomLeft(noticeMessage).dy),
      );
      expect(
        t.getTopLeft(dismissAction).dy,
        greaterThan(t.getBottomLeft(noticeMessage).dy),
      );

      final itemLabel = find.text(_de.todayStartWallDisplay);
      final itemAction = find.text(_de.todayStartNotNeeded);
      expect(t.widget<Text>(itemLabel).maxLines, isNull);
      expect(
        t.getTopLeft(itemAction).dy,
        greaterThan(t.getTopLeft(itemLabel).dy),
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('wide iPad keeps Today cards compact and readable', (t) async {
    await pumpApp(
      t,
      size: const Size(1024, 768),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      notices: FakeNoticesRepository([_notice]),
      gettingStarted: FakeGettingStartedRepository(const [
        GettingStartedItem(item: StartItem.wallDisplay, done: false),
      ]),
    );

    final message = find.text(_de.todayNoticeJoined('Julia'));
    final noticeAction = find.text(_de.todayNoticeMembers);
    final dismissAction = find.text(_de.todayNoticeDismiss);
    expect(t.getCenter(noticeAction).dy, closeTo(t.getCenter(message).dy, 24));
    expect(t.getCenter(dismissAction).dy, closeTo(t.getCenter(message).dy, 24));

    final itemLabel = find.text(_de.todayStartWallDisplay);
    final itemAction = find.text(_de.todayStartNotNeeded);
    expect(t.getCenter(itemAction).dy, closeTo(t.getCenter(itemLabel).dy, 24));
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
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

int _lineCount(WidgetTester tester, Finder finder) =>
    _laidOutText(tester, finder).lineCount;

({int lineCount, double laidOutHeight}) _laidOutText(
  WidgetTester tester,
  Finder finder,
) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textAlign: paragraph.textAlign,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.size.width);
  final result = (
    lineCount: painter.computeLineMetrics().length,
    laidOutHeight: painter.height,
  );
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(result.laidOutHeight, lessThanOrEqualTo(paragraph.size.height + 0.5));
  painter.dispose();
  return result;
}

Occurrence _todayEvent({
  required String title,
  TimeOfDay? start,
  bool allDay = false,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final end = start == null
      ? today.add(const Duration(days: 1))
      : DateTime(
          today.year,
          today.month,
          today.day,
          start.hour + 1,
          start.minute,
        );
  return Occurrence(
    id: title,
    eventId: title,
    calendarId: 'calendar',
    title: title,
    kind: EventKind.appointment,
    status: EventStatus.confirmed,
    importance: Importance.normal,
    allDay: allDay,
    start: start == null
        ? today
        : DateTime(
            today.year,
            today.month,
            today.day,
            start.hour,
            start.minute,
          ),
    end: end,
    localStartDate: today,
    localEndDate: today,
    localStarts: start,
    localEnds: start == null
        ? null
        : TimeOfDay(hour: start.hour + 1, minute: start.minute),
  );
}
