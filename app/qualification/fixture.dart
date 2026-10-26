// Shared by host tests, the browser-only qualification entry point and native tests.
// The production entry point never imports this file.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/appearance.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/l10n/app_language.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/core/server/setup_store.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/demo/demo_clock.dart';
import 'package:wuselwall/demo/demo_notifications.dart';
import 'package:wuselwall/demo/demo_overrides.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/application/external_calendar_providers.dart';
import 'package:wuselwall/features/calendar/data/feed_repository.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart'
    as meals;
import 'package:wuselwall/features/school/application/school_providers.dart'
    as school;
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/setup/ui/server_choice_page.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';

import 'inventory.g.dart';
import 'route_fixtures.dart';

final qualificationTime = DateTime.parse(qualificationClock);
final qualificationDay = DateUtils.dateOnly(qualificationTime);

class _FixedNight extends NightNotifier {
  @override
  bool build() => true;
}

class _Calendar extends CalendarViewNotifier {
  _Calendar({this.mode = CalendarMode.day});
  final CalendarMode mode;
  @override
  void setResponsiveMode(CalendarMode responsive) {
    if (mode != CalendarMode.month) super.setResponsiveMode(responsive);
  }

  @override
  CalendarView build() => CalendarView(mode: mode, anchor: qualificationDay);
  @override
  void today() =>
      state = CalendarView(mode: state.mode, anchor: qualificationDay);
}

class _MealsWeek extends meals.MealsWeekNotifier {
  @override
  DateTime build() => meals.mondayOf(qualificationTime);
  @override
  void today() => state = build();
}

class _SchoolWeek extends school.SelectedWeekNotifier {
  @override
  DateTime build() => school.mondayOf(qualificationTime);
  @override
  void thisWeek() => state = build();
}

class _InitialTab extends HomeTabNotifier {
  _InitialTab(this.tab);
  final HomeTab tab;
  @override
  HomeTab build() => tab;
}

Widget qualificationApp({
  String? stateId,
  required String scenario,
  required Locale locale,
  required String shade,
  String tab = 'today',
  bool advanced = false,
}) {
  DemoClock.fixedNow = qualificationTime;
  StillMode.enabled = true;
  if (scenario == 'server') {
    // Use the bootstrap themes/delegates with explicit locale and shade so the
    // native OS language does not require a device restart for each test case.
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: locale,
      supportedLocales: appLocales,
      localizationsDelegates: localizationsDelegates,
      theme: AppTheme.build(UiRegister.adult, Shade.light),
      darkTheme: AppTheme.build(UiRegister.adult, Shade.dark),
      themeMode: shade == 'light' ? ThemeMode.light : ThemeMode.dark,
      home: ServerChoicePage(
        canScan: true,
        onAddress: (_) async => ServerProblem.unreachable,
        onDemo: () {},
      ),
    );
  }
  return ProviderScope(
    // Error fixtures must stay in their named error state, rather than retrying
    // with real-time backoff and intermittently showing a loading spinner.
    retry: (_, _) => null,
    overrides: [
      ...demoOverrides(
        scenario: scenario,
        locales: [locale],
        config: scenario == 'withserver'
            ? AppConfig(
                environment: 'qualification',
                supabaseUrl: 'https://example.org',
                supabasePublishableKey: 'demo',
                server: ServerInfo(
                  supabaseUrl: Uri.parse('https://example.org'),
                  publishableKey: 'demo',
                  apiVersion: 1,
                  minAppVersion: '1.0.0',
                ),
              )
            : null,
        appearance: MemoryAppearanceStore(
          shade == 'light' ? ThemeMode.light : ThemeMode.dark,
        ),
        language: MemoryAppLanguageStore(locale),
        settingsView: MemorySettingsViewStore(
          advanced ? SettingsView.advanced : SettingsView.basic,
        ),
        night: shade == 'night' ? _FixedNight.new : null,
      ),
      setupStoreProvider.overrideWithValue(QualificationSetupStore()),
      feedRepositoryProvider.overrideWith(
        (ref) => QualificationFeedRepository(),
      ),
      if (qualificationFixtureRoutes.containsKey(stateId))
        routerProvider.overrideWith((ref) {
          final router = qualificationFixtureRouter(stateId!);
          ref.onDispose(router.dispose);
          return router;
        }),
      if (stateId == 'invite-pending')
        sessionStateProvider.overrideWith(
          (ref) async => NeedsHousehold(qualificationAccount()),
        ),
      if (stateId == 'splash-error')
        sessionStateProvider.overrideWith(
          (ref) async => throw qualificationNetworkFailure,
        ),
      shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
      calendarViewProvider.overrideWith(
        () => _Calendar(
          mode: stateId == 'calendar-month'
              ? CalendarMode.month
              : CalendarMode.day,
        ),
      ),
      if (stateId == 'recipes-empty')
        meals.recipesProvider.overrideWith((ref) async => []),
      if (stateId == 'recipes-error')
        meals.recipesProvider.overrideWith(
          (ref) async => throw qualificationNetworkFailure,
        ),
      if (stateId == 'external-calendars-empty')
        externalCalendarsProvider.overrideWith((ref) async => []),
      meals.mealsWeekProvider.overrideWith(_MealsWeek.new),
      school.selectedWeekProvider.overrideWith(_SchoolWeek.new),
      clockProvider.overrideWith((ref) => Stream.value(qualificationTime)),
      nowProvider.overrideWithValue(qualificationTime),
      homeTabProvider.overrideWith(
        () => _InitialTab(HomeTab.values.byName(tab)),
      ),
      connectivityProvider.overrideWith(
        (ref) => Stream.value(
          ![
            'setup-offline',
            'sign-in-offline',
            'shopping-offline',
          ].contains(stateId),
        ),
      ),
      notificationSchedulerProvider.overrideWithValue(
        const DemoNotificationScheduler(),
      ),
    ],
    child: const WuselWallApp(),
  );
}
