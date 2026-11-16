import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/demo/demo_trips.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/calendar/ui/event_editor_page.dart';
import 'package:wuselwall/features/calendar/ui/event_template_page.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_page.dart';
import 'package:wuselwall/features/trips/ui/trips_page.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_trips.dart';
import '../support/fakes.dart';

final _de = AppLocalizationsDe();

final _now = DateTime(2026, 11, 11, 9, 30);

/// A server that answers and lists no trips.
AppConfig _noTrips() => AppConfig(
  environment: 'test',
  supabaseUrl: 'https://example.org',
  supabasePublishableKey: 'demo',
  server: ServerInfo(
    supabaseUrl: Uri.parse('https://example.org'),
    publishableKey: 'demo',
    apiVersion: 1,
    minAppVersion: '1.0.0',
  ),
);

Occurrence _occurrence(String title, {String? tripId}) => Occurrence(
  id: '$title|2026-11-11',
  eventId: 'e-$title',
  calendarId: 'cal',
  title: title,
  kind: EventKind.appointment,
  status: EventStatus.confirmed,
  importance: Importance.normal,
  allDay: true,
  start: DateTime(2026, 11, 11),
  end: DateTime(2026, 11, 12),
  localStartDate: DateTime(2026, 11, 11),
  localEndDate: DateTime(2026, 11, 11),
  tripId: tripId,
);

Future<ProviderContainer> _calendar(
  WidgetTester t, {
  List<Occurrence> items = const [],
  Map<String, CalendarEvent> events = const {},
  AppConfig? config,
  Size size = const Size(1000, 1200),
}) async {
  final container = await pumpApp(
    t,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device()),
      trips: FakeTripsRepository(),
      now: _now,
      appConfig: config,
    ),
    calendar: FakeCalendarRepository(items, events),
    size: size,
  );
  await openTab(t, 'Kalender');
  return container;
}

/// specs/30 "In the calendar and on the wall".
void main() {
  group('the way to Reisen', () {
    testWidgets('is a small button of the calendar on a wide screen', (
      t,
    ) async {
      await _calendar(t);
      final action = find.byKey(const ValueKey('calendar-trips'));
      expect(action, findsOneWidget);
      expect(find.byTooltip(_de.tripsTitle), findsOneWidget);
      await t.tap(action);
      await t.pumpAndSettle();
      expect(find.byType(TripsPage), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('leaves a phone its one button, the bar its room', (t) async {
      await _calendar(t, size: const Size(390, 844));
      expect(find.byKey(const ValueKey('calendar-trips')), findsNothing);
      expect(find.byTooltip(_de.calendarToday), findsWidgets);
    });

    testWidgets('is not there on a server without trips', (t) async {
      await _calendar(t, config: _noTrips());
      expect(find.byKey(const ValueKey('calendar-trips')), findsNothing);
    });
  });

  group('an appointment of a trip', () {
    testWidgets('opens the trip, an ordinary one the editor', (t) async {
      final container = await _calendar(
        t,
        items: [
          _occurrence('Sardinien', tripId: 't1'),
          _occurrence('Zahnarzt'),
        ],
        events: {
          'e-Zahnarzt': CalendarEvent(
            id: 'e-Zahnarzt',
            title: 'Zahnarzt',
            kind: EventKind.appointment,
            isAllDay: true,
            startDate: DateTime(2026, 11, 11),
            endDate: DateTime(2026, 11, 11),
          ),
        },
      );
      await t.tap(find.text('Sardinien').first);
      await t.pumpAndSettle();
      expect(find.byType(TripPage), findsOneWidget);
      expect(find.byType(EventEditorPage), findsNothing);
      container.read(routerProvider).pop();
      await t.pumpAndSettle();

      await t.tap(find.text('Zahnarzt').first);
      await t.pumpAndSettle();
      expect(find.byType(EventEditorPage), findsOneWidget);
      expect(find.byType(TripPage), findsNothing);
    });

    testWidgets('opens the editor where trips are not offered', (t) async {
      await _calendar(
        t,
        config: _noTrips(),
        items: [_occurrence('Sardinien', tripId: 't1')],
        events: {
          'e-Sardinien': const CalendarEvent(
            id: 'e-Sardinien',
            title: 'Sardinien',
            kind: EventKind.appointment,
            isAllDay: true,
            tripId: 't1',
          ),
        },
      );
      await t.tap(find.text('Sardinien').first);
      await t.pumpAndSettle();
      expect(find.byType(TripPage), findsNothing);
      // The editor answers with its notice, never with the form.
      expect(find.byKey(const ValueKey('trip-event-notice')), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-event-open')), findsNothing);
    });

    testWidgets('reached in the editor anyway shows a notice, not the form', (
      t,
    ) async {
      final container = await _calendar(
        t,
        events: {
          'e1': const CalendarEvent(
            id: 'e1',
            title: 'Sardinien',
            kind: EventKind.appointment,
            isAllDay: true,
            tripId: 't1',
          ),
        },
      );
      unawaited(
        container
            .read(routerProvider)
            .push(Routes.eventEdit, extra: const EventEditArgs(eventId: 'e1')),
      );
      await t.pumpAndSettle();
      expect(find.text(_de.tripCalendarNotice), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.widgetWithText(FilledButton, _de.save), findsNothing);

      await t.tap(find.widgetWithText(FilledButton, _de.tripCalendarOpen));
      await t.pumpAndSettle();
      expect(find.byType(TripPage), findsOneWidget);
    });
  });

  group('Neuer Termin', () {
    Future<void> open(WidgetTester t, {AppConfig? config}) async {
      final container = await _calendar(t, config: config);
      unawaited(container.read(routerProvider).push(Routes.eventNew));
      await t.pumpAndSettle();
      expect(find.byType(EventTemplatePage), findsOneWidget);
    }

    final holiday = find.byKey(
      const ValueKey('event-template-builtin-holiday'),
    );
    final plan = find.byKey(const ValueKey('event-template-trip'));

    testWidgets('offers to plan a trip beside the holiday tile', (t) async {
      await open(t);
      await t.ensureVisible(plan);
      expect(holiday, findsOneWidget);
      expect(plan, findsOneWidget);
      await t.tap(plan);
      await t.pumpAndSettle();
      expect(find.byType(TripsPage), findsOneWidget);
    });

    testWidgets('keeps the holiday template as it was', (t) async {
      await open(t);
      await t.ensureVisible(holiday);
      await t.tap(holiday);
      await t.pumpAndSettle();
      expect(find.byType(EventEditorPage), findsOneWidget);
      expect(find.byType(TripsPage), findsNothing);
    });

    testWidgets('has no such tile where trips are not offered', (t) async {
      await open(t, config: _noTrips());
      expect(plan, findsNothing);
      await t.ensureVisible(holiday);
      expect(holiday, findsOneWidget);
    });
  });

  group('Wetter und Karten in the settings', () {
    SettingsEnv env({
      bool services = true,
      bool ownOnly = false,
      bool advanced = false,
    }) => SettingsEnv(
      entries: const [],
      advanced: advanced,
      deviceClass: DeviceClass.personal,
      deviceId: 'd1',
      acting: 'p1',
      guardian: true,
      ownOnly: ownOnly,
      services: services,
    );

    bool listed(SettingsEnv e) => [
      for (final s in visibleSections(SettingsGroup.calendar, e)) ...s.items,
    ].any((i) => i is SettingTileItem && i.tile == SettingsTile.services);

    test(
      'is a row of the calendar group where the server has the services',
      () {
        expect(listed(env()), isTrue);
        expect(listed(env(advanced: true)), isTrue);
      },
    );

    test('is left out without the services and for a child', () {
      expect(listed(env(services: false)), isFalse);
      expect(listed(env(ownOnly: true)), isFalse);
    });

    testWidgets('opens its page from the calendar group', (t) async {
      final container = await _calendar(t);
      unawaited(container.read(routerProvider).push(Routes.settingsCalendar));
      await t.pumpAndSettle();
      final row = find.byKey(const ValueKey('settings-services'));
      await t.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(_de.settingsServicesTitle), findsOneWidget);
      await t.tap(row);
      await t.pumpAndSettle();
      expect(
        container.read(routerProvider).state.uri.toString(),
        Routes.servicesSettings,
      );
    });
  });

  group('the demo calendar', () {
    test('has the trips as appointments with their dates', () async {
      final today = dayOf(DateTime(2026, 11, 11, 9));
      final repo = DemoCalendarRepository(clock: () => today);
      final window = (await repo.occurrences(
        addDays(today, -7),
        addDays(today, 130),
      )).unwrap();
      final trips = {
        for (final t in demoCalendarTrips(clock: () => today)) t.id: t,
      };
      expect(trips.keys, containsAll(['trip-sardinia', 'trip-ski']));
      for (final trip in trips.values) {
        final mine = window.occurrences
            .where((o) => o.tripId == trip.id)
            .toList();
        expect(mine, hasLength(1), reason: trip.id);
        final o = mine.single;
        expect(o.eventId, trip.eventId);
        expect(o.allDay, isTrue);
        expect(o.localStartDate, trip.startsOn);
        expect(o.localEndDate, trip.endsOn);
        expect(o.iconKey, trip.iconKey);
        final fixed = trip.stage == TripStage.fixed;
        expect(o.countdown, fixed);
        expect(o.importance, fixed ? Importance.key : Importance.normal);
        expect(o.isTentative, !fixed);
      }
      final event = (await repo.event('ev-trip-sardinia')).unwrap();
      expect(event.tripId, 'trip-sardinia');
      expect(event.countdown, isTrue);
    });
  });
}
