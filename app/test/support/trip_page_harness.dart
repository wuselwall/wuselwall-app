import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/app.dart' show localizationsDelegates;
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_entry_args.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_compare_page.dart';
import 'package:wuselwall/features/trips/ui/trip_entry_page.dart';

import 'fake_trips.dart';
import 'fakes.dart';

/// The trips' own pages in a small router of their own: the trip page is a stand-in text,
/// the comparison and the entry page are the real ones. [start] is the first location;
/// `router.push` reaches the others the way the app does.
class TripPageApp {
  TripPageApp(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;
}

const tripPageStandIn = 'TRIP PAGE STAND-IN';

Future<TripPageApp> pumpTripPages(
  WidgetTester tester, {
  required FakeTripsRepository trips,
  String start = '/trips/t1/compare',
  Size size = const Size(360, 800),
  double textScale = 1,
  DateTime? now,
  Locale locale = const Locale('de'),
  UiRegister register = UiRegister.adult,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device(register: register)),
      trips: trips,
      now: now ?? DateTime(2027, 7, 1, 10),
    ),
  );
  addTearDown(container.dispose);
  await container.read(sessionStateProvider.future);

  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: Routes.tripPathTemplate,
        builder: (_, _) => const Scaffold(body: Text(tripPageStandIn)),
      ),
      GoRoute(
        path: Routes.tripComparePathTemplate,
        builder: (_, state) => TripComparePage(
          tripId: state.pathParameters['id']!,
          kind: switch (state.uri.queryParameters['kind']) {
            final k? => EntryKind.parse(k),
            _ => null,
          },
        ),
      ),
      GoRoute(
        path: Routes.tripEntryPathTemplate,
        builder: (_, state) => TripEntryPage(
          tripId: state.pathParameters['id']!,
          args: state.extra is TripEntryArgs
              ? state.extra! as TripEntryArgs
              : null,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: localizationsDelegates,
        theme: AppTheme.build(UiRegister.adult, Shade.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return TripPageApp(container, router);
}
