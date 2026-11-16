import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_windows_page.dart';

import '../support/fake_trips.dart';
import '../support/fakes.dart';

final _summer = TripWindow(
  from: DateTime(2027, 7, 3),
  to: DateTime(2027, 7, 11),
  days: 9,
  kind: WindowKind.holidays,
  name: 'Sommerferien',
  leaveDays: 5,
  partial: [
    WindowPartial(
      profileId: kidId,
      from: DateTime(2027, 7, 1),
      to: DateTime(2027, 7, 2),
    ),
  ],
  conflicts: [
    WindowConflict(
      date: DateTime(2027, 7, 5),
      title: 'Zahnarzt',
      eventId: 'e1',
      kind: 'appointment',
      profileIds: const [guardianId],
    ),
    WindowConflict(
      date: DateTime(2027, 7, 6),
      title: 'Dienstreise',
      eventId: 'e2',
      kind: 'presence',
      presenceState: 'travel',
      profileIds: const [guardianId],
    ),
    WindowConflict(
      date: DateTime(2027, 7, 7),
      title: 'Dienstreise',
      eventId: 'e2',
      kind: 'presence',
      presenceState: 'travel',
      profileIds: const [guardianId],
    ),
  ],
);

final _autumn = TripWindow(
  from: DateTime(2027, 10, 9),
  to: DateTime(2027, 10, 12),
  days: 4,
  kind: WindowKind.longWeekend,
  name: 'Kirchweih',
  leaveDays: 1,
);

const _idea = Trip(id: 't1', title: 'Sardinien', memberIds: [kidId]);

Future<ProviderContainer> _open(
  WidgetTester tester,
  FakeTripsRepository trips, {
  String path = Routes.tripWindows,
  Size size = const Size(390, 844),
}) async {
  final container = await pumpApp(
    tester,
    locale: const Locale('en'),
    size: size,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device()),
      trips: trips,
    ),
  );
  container.read(routerProvider).go(path);
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the proposed windows with what is in the way', (
    tester,
  ) async {
    final trips = FakeTripsRepository(windowList: [_summer, _autumn]);
    await _open(tester, trips);

    expect(find.text('Time windows'), findsOneWidget);
    expect(find.text('July 2027'), findsOneWidget);
    expect(find.text('October 2027'), findsOneWidget);
    expect(find.text('9 days · Sommerferien'), findsOneWidget);
    expect(find.text('5 leave days for the adults'), findsOneWidget);
    expect(find.text('Anna is free from Jul 1 already'), findsOneWidget);
    expect(find.text('Zahnarzt'), findsOneWidget);
    // A presence entry reads as the state's label, once for both days.
    expect(find.text('Travelling'), findsOneWidget);
    expect(find.text('Long weekend'), findsOneWidget);
    expect(find.text('Nothing in the way'), findsOneWidget);
    expect(trips.windowRequests.last.minDays, 4);
    expect(trips.windowRequests.last.memberIds, isEmpty);
    expect(trips.windowRequests.last.tripId, isNull);
  });

  testWidgets('the length and who travels go into the request', (tester) async {
    final trips = FakeTripsRepository(windowList: [_summer]);
    await _open(tester, trips);

    await tester.tap(find.widgetWithText(ChoiceChip, '10 days'));
    await tester.pumpAndSettle();
    expect(trips.windowRequests.last.minDays, 10);

    await tester.tap(find.widgetWithText(FilterChip, 'Anna'));
    await tester.pumpAndSettle();
    expect(trips.windowRequests.last.memberIds, [kidId]);
    expect(trips.windowRequests.last.minDays, 10);
  });

  testWidgets('without a trip: where is it nice, and a new trip', (
    tester,
  ) async {
    final trips = FakeTripsRepository(windowList: [_summer]);
    await _open(tester, trips);

    await _tap(tester, find.text('New trip in this window'));
    await tester.enterText(find.byType(TextField), 'Toskana');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = trips.savedTrips.single;
    expect(saved.title, 'Toskana');
    expect(saved.stage, TripStage.planned);
    expect(saved.startsOn, DateTime(2027, 7, 3));
    expect(saved.endsOn, DateTime(2027, 7, 11));
  });

  testWidgets('where is it nice leads to discovery with the window', (
    tester,
  ) async {
    final trips = FakeTripsRepository(windowList: [_summer]);
    await _open(tester, trips);

    await _tap(tester, find.text('Where is it nice then?'));

    expect(find.text('Where to?'), findsOneWidget);
    expect(trips.discoverRequests.last.from, DateTime(2027, 7, 3));
    expect(trips.discoverRequests.last.to, DateTime(2027, 7, 11));
  });

  testWidgets('for a trip: its members and id are asked, dates are taken', (
    tester,
  ) async {
    final trips = FakeTripsRepository(trips: [_idea], windowList: [_summer]);
    await _open(tester, trips, path: Routes.tripWindowsPath(tripId: 't1'));

    expect(trips.windowRequests.last.tripId, 't1');
    expect(trips.windowRequests.last.memberIds, [kidId]);
    expect(find.text('Where is it nice then?'), findsNothing);

    await _tap(tester, find.text('Take these dates'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = trips.savedTrips.single;
    expect(saved.id, 't1');
    expect(saved.stage, TripStage.planned);
    expect(saved.startsOn, DateTime(2027, 7, 3));
    expect(saved.endsOn, DateTime(2027, 7, 11));
    expect(find.text('The dates are in the trip now.'), findsOneWidget);
  });

  testWidgets('says where holidays come from when nothing is proposed', (
    tester,
  ) async {
    await _open(tester, FakeTripsRepository());

    expect(find.textContaining('No free stretch found'), findsOneWidget);
    expect(find.text('Region and school settings'), findsOneWidget);
  });

  testWidgets('shows a failed request with a retry', (tester) async {
    final trips = FakeTripsRepository(failure: const NetworkFailure());
    await _open(tester, trips);

    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a child device does not offer it', (tester) async {
    // The page alone, not the kid shell around it with its clocks.
    final container = ProviderContainer(
      overrides: baseOverrides(
        identity: FakeIdentityRepository(
          current: device(register: UiRegister.kid),
        ),
        trips: FakeTripsRepository(windowList: [_summer]),
      ),
    );
    addTearDown(container.dispose);
    await container.read(sessionStateProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripWindowsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trips are not available here.'), findsOneWidget);
    expect(find.text('Take these dates'), findsNothing);
  });

  for (final size in const [Size(360, 800), Size(1000, 800)]) {
    testWidgets('lays out at $size without overflow', (tester) async {
      await _open(
        tester,
        FakeTripsRepository(windowList: [_summer, _autumn]),
        size: size,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('9 days · Sommerferien'), findsOneWidget);
    });
  }
}
