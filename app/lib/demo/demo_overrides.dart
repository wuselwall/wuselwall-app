// The in-memory demo household (ADR-018, decision 4): the docs' screenshots
// (lib/main_demo.dart) and the store app's "Try it without a server" run on these
// overrides. Nothing here talks to a server; nothing is kept.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/demo/demo_board.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_export.dart';
import 'package:wuselwall/demo/demo_getting_started.dart';
import 'package:wuselwall/demo/demo_kid.dart';
import 'package:wuselwall/demo/demo_meals.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/demo/demo_school.dart';
import 'package:wuselwall/demo/demo_tasks.dart';
import 'package:wuselwall/features/board/data/board_repository.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/data/sign_in_methods_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/data/kid_badges_repository.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/settings/data/household_export_repository.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';

class _Day extends NightNotifier {
  @override
  bool build() => false;
}

DeviceInfo? _device(String scenario) => switch (scenario) {
  'setup' => null,
  'kid' => const DeviceInfo(
    deviceId: 'd-2',
    householdId: 'h1',
    label: 'Kinder-iPad',
    deviceClass: DeviceClass.shared,
    register: UiRegister.kid,
    profileId: null,
    revoked: false,
    guardianVerifiedUntil: null,
  ),
  'kiosk' => const DeviceInfo(
    deviceId: 'd-3',
    householdId: 'h1',
    label: 'Küche (Wand)',
    deviceClass: DeviceClass.kiosk,
    register: UiRegister.kiosk,
    profileId: null,
    revoked: false,
    guardianVerifiedUntil: null,
  ),
  _ => const DeviceInfo(
    deviceId: 'd-1',
    householdId: 'h1',
    label: 'Lukas’ iPhone',
    deviceClass: DeviceClass.personal,
    register: UiRegister.adult,
    profileId: DemoData.papa,
    revoked: false,
    guardianVerifiedUntil: null,
  ),
};

/// Every repository and session provider replaced by its in-memory demo.
/// [scenario]: setup | adult | kid | kiosk.
List<Override> demoOverrides({String scenario = 'adult'}) => [
  appConfigProvider.overrideWithValue(
    const AppConfig(
      environment: 'demo',
      supabaseUrl: 'http://demo.invalid',
      supabasePublishableKey: 'demo',
    ),
  ),
  authStateProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
  sessionUserIdProvider.overrideWithValue(
    scenario == 'setup' ? null : 'demo-user',
  ),
  identityRepositoryProvider.overrideWithValue(
    DemoIdentityRepository(device: _device(scenario)),
  ),
  signInMethodsRepositoryProvider.overrideWithValue(
    DemoSignInMethodsRepository(),
  ),
  shoppingRepositoryProvider.overrideWithValue(DemoShoppingRepository()),
  householdSettingsRepositoryProvider.overrideWithValue(
    DemoHouseholdSettingsRepository(),
  ),
  householdExportRepositoryProvider.overrideWithValue(
    DemoHouseholdExportRepository(),
  ),
  boardRepositoryProvider.overrideWithValue(DemoBoardRepository()),
  schoolRepositoryProvider.overrideWithValue(DemoSchoolRepository()),
  mealsRepositoryProvider.overrideWithValue(DemoMealsRepository()),
  calendarRepositoryProvider.overrideWithValue(DemoCalendarRepository()),
  tasksRepositoryProvider.overrideWithValue(DemoTasksRepository()),
  gettingStartedRepositoryProvider.overrideWithValue(
    DemoGettingStartedRepository(),
  ),
  kidBadgesRepositoryProvider.overrideWithValue(DemoKidBadgesRepository()),
  householdInvalidationsProvider.overrideWith(
    (ref, id) => const Stream<Invalidation>.empty(),
  ),
  nightProvider.overrideWith(_Day.new),
];
