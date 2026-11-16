import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/rituals/ui/countdown_widgets.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/domain/trip_today.dart';

/// A fixed trip shows once on Today: its card says the days left, so the rituals' Vorfreude
/// line there skips the trip's own calendar entry. The wall and the kids still look forward
/// to it.

final _today = DateTime(2026, 11, 15);

Occurrence _occurrence(
  String id,
  String title,
  DateTime day, {
  String? tripId,
}) => Occurrence(
  id: id,
  eventId: id,
  calendarId: 'c',
  title: title,
  kind: EventKind.appointment,
  status: EventStatus.confirmed,
  importance: Importance.normal,
  allDay: true,
  start: day,
  end: day,
  localStartDate: day,
  localEndDate: day,
  countdown: true,
  tripId: tripId,
);

Countdown _countdown(String title, DateTime day, {String? tripId}) => Countdown(
  kind: CountdownKind.event,
  date: day,
  title: title,
  iconKey: 'beach',
  tripId: tripId,
);

final _sardinia = Trip(
  id: 't1',
  title: 'Sardinien',
  stage: TripStage.fixed,
  startsOn: DateTime(2026, 11, 27),
  endsOn: DateTime(2026, 12, 6),
);

/// The card's facts for [_sardinia], as the provider would build them.
final _todayCard = TripToday.of(
  trips: [_sardinia],
  entries: const [],
  checks: const [],
  today: _today,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required List<Countdown> countdowns,
  TripToday? card,
}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ritualTodayProvider.overrideWithValue(_today),
        countdownsProvider.overrideWithValue(countdowns),
        tripTodayProvider.overrideWithValue(card),
      ],
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.adult, Shade.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  group('countdowns()', () {
    List<Countdown> events(List<Occurrence> occurrences) => countdowns(
      today: _today,
      horizonDays: 30,
      members: const [],
      occurrences: occurrences,
    );

    test('carry the trip of the calendar entry they come from', () {
      final all = events([
        _occurrence('trip', 'Sardinien', DateTime(2026, 11, 27), tripId: 't1'),
        _occurrence('zoo', 'Zoo', DateTime(2026, 11, 20)),
      ]);
      expect(all.map((c) => c.title), ['Zoo', 'Sardinien']);
      expect(all.first.tripId, isNull);
      expect(all.last.tripId, 't1');
    });

    test('birthdays and holidays have none', () {
      expect(_countdown('x', DateTime(2026, 11, 20)).tripId, isNull);
    });
  });

  group('TodayCountdown', () {
    final zoo = _countdown('Zoo', DateTime(2026, 11, 20));
    final sardinia = _countdown(
      'Sardinien',
      DateTime(2026, 11, 27),
      tripId: 't1',
    );

    testWidgets('skips the countdown of the trip its card shows', (t) async {
      expect(_todayCard, isNotNull);
      // The trip is the nearest: it would be the line, and the card says it already.
      await _pump(
        t,
        const TodayCountdown(),
        countdowns: [
          _countdown('Sardinien', DateTime(2026, 11, 18), tripId: 't1'),
          zoo,
        ],
        card: _todayCard,
      );
      expect(find.text('Sardinien'), findsNothing);
      expect(find.text('Zoo'), findsOneWidget);
    });

    testWidgets('shows nothing when that was the only one', (t) async {
      await _pump(
        t,
        const TodayCountdown(),
        countdowns: [sardinia],
        card: _todayCard,
      );
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('shows the trip when its card is not there', (t) async {
      await _pump(t, const TodayCountdown(), countdowns: [sardinia, zoo]);
      expect(find.text('Sardinien'), findsOneWidget);
      expect(find.text('Zoo'), findsNothing);
    });

    testWidgets('keeps the countdown of another trip', (t) async {
      await _pump(
        t,
        const TodayCountdown(),
        countdowns: [_countdown('Wien', DateTime(2026, 12, 20), tripId: 't2')],
        card: _todayCard,
      );
      expect(find.text('Wien'), findsOneWidget);
    });
  });

  group('the other consumers', () {
    testWidgets('the wall footer still looks forward to the trip', (t) async {
      await _pump(
        t,
        const BoardCountdowns(),
        countdowns: [
          _countdown('Sardinien', DateTime(2026, 11, 18), tripId: 't1'),
          _countdown('Zoo', DateTime(2026, 11, 20)),
        ],
        card: _todayCard,
      );
      expect(find.textContaining('Sardinien'), findsWidgets);
      expect(find.textContaining('Zoo'), findsWidgets);
    });
  });
}
