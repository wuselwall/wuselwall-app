// Shared by host tests, the browser-only qualification entry point and native tests.
// The production entry point never imports this file.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/app.dart';
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
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/demo/demo_clock.dart';
import 'package:wuselwall/demo/demo_notifications.dart';
import 'package:wuselwall/demo/demo_overrides.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart'
    as meals;
import 'package:wuselwall/features/school/application/school_providers.dart'
    as school;
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/setup/ui/server_choice_page.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';

import 'inventory.g.dart';

final qualificationTime = DateTime.parse(qualificationClock);
final qualificationDay = DateUtils.dateOnly(qualificationTime);

class _FixedNight extends NightNotifier {
  @override
  bool build() => true;
}

class _Calendar extends CalendarViewNotifier {
  @override
  CalendarView build() =>
      CalendarView(mode: CalendarMode.day, anchor: qualificationDay);
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
      shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
      calendarViewProvider.overrideWith(_Calendar.new),
      meals.mealsWeekProvider.overrideWith(_MealsWeek.new),
      school.selectedWeekProvider.overrideWith(_SchoolWeek.new),
      clockProvider.overrideWith((ref) => Stream.value(qualificationTime)),
      nowProvider.overrideWithValue(qualificationTime),
      homeTabProvider.overrideWith(
        () => _InitialTab(HomeTab.values.byName(tab)),
      ),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
      notificationSchedulerProvider.overrideWithValue(
        const DemoNotificationScheduler(),
      ),
    ],
    child: const WuselWallApp(),
  );
}
