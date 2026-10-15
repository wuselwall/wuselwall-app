// Entry point for the user documentation's screenshots, never part of a release:
//   flutter build web -t lib/main_demo.dart
// The app runs on in-memory data (lib/demo). The scenario comes from the URL:
//   ?scenario=setup | newfamily | adult | kid | kiosk   (default adult)
// Language and light/dark follow the browser, as on a real device.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/licenses.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/demo/demo_board.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_export.dart';
import 'package:wuselwall/demo/demo_external_calendars.dart';
import 'package:wuselwall/demo/demo_getting_started.dart';
import 'package:wuselwall/demo/demo_invitations.dart';
import 'package:wuselwall/demo/demo_kid.dart';
import 'package:wuselwall/demo/demo_meals.dart';
import 'package:wuselwall/demo/demo_pairing.dart';
import 'package:wuselwall/demo/demo_region.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/demo/demo_school.dart';
import 'package:wuselwall/demo/demo_tasks.dart';
import 'package:wuselwall/features/account/application/account_admin_providers.dart';
import 'package:wuselwall/features/board/data/board_repository.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/data/external_calendars_repository.dart';
import 'package:wuselwall/features/household/data/household_leave_repository.dart';
import 'package:wuselwall/features/household/data/household_onboarding_repository.dart';
import 'package:wuselwall/features/identity/application/first_run.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/data/pairing_repository.dart';
import 'package:wuselwall/features/identity/data/sign_in_methods_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/invitations/application/invitation_providers.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/kid/data/kid_badges_repository.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/region/data/region_repository.dart';
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
  'setup' || 'newfamily' => null,
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final scenario = Uri.base.queryParameters['scenario'] ?? 'adult';

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            environment: 'demo',
            supabaseUrl: 'http://demo.invalid',
            supabasePublishableKey: 'demo',
          ),
        ),
        authStateProvider.overrideWith(
          (ref) => const Stream<AuthState>.empty(),
        ),
        sessionUserIdProvider.overrideWithValue(
          scenario == 'setup' ? null : 'demo-user',
        ),
        identityRepositoryProvider.overrideWithValue(
          DemoIdentityRepository(device: _device(scenario)),
        ),
        signInMethodsRepositoryProvider.overrideWithValue(
          DemoSignInMethodsRepository(),
        ),
        pairingRepositoryProvider.overrideWithValue(DemoPairingRepository()),
        invitationRepositoryProvider.overrideWithValue(
          DemoInvitationRepository(),
        ),
        invitationStoreProvider.overrideWithValue(DemoInvitationStore()),
        // The demo shows the share sheet's text in place; nothing is handed to the platform.
        inviteSharerProvider.overrideWithValue((_) async {}),
        // The screenshots show the wall display without its one-time checklist.
        pendingFirstRunProvider.overrideWith((ref) async => null),
        householdOnboardingRepositoryProvider.overrideWithValue(
          DemoHouseholdOnboardingRepository(
            hasHousehold: scenario != 'newfamily',
          ),
        ),
        shoppingRepositoryProvider.overrideWithValue(DemoShoppingRepository()),
        householdSettingsRepositoryProvider.overrideWithValue(
          DemoHouseholdSettingsRepository(),
        ),
        householdExportRepositoryProvider.overrideWithValue(
          DemoHouseholdExportRepository(),
        ),
        householdLeaveRepositoryProvider.overrideWithValue(
          DemoHouseholdLeaveRepository(),
        ),
        accountAdminRepositoryProvider.overrideWithValue(
          DemoAccountAdminRepository(),
        ),
        boardRepositoryProvider.overrideWithValue(DemoBoardRepository()),
        schoolRepositoryProvider.overrideWithValue(DemoSchoolRepository()),
        regionRepositoryProvider.overrideWithValue(DemoRegionRepository()),
        mealsRepositoryProvider.overrideWithValue(DemoMealsRepository()),
        calendarRepositoryProvider.overrideWithValue(DemoCalendarRepository()),
        externalCalendarsRepositoryProvider.overrideWithValue(
          DemoExternalCalendarsRepository(),
        ),
        tasksRepositoryProvider.overrideWithValue(DemoTasksRepository()),
        gettingStartedRepositoryProvider.overrideWithValue(
          DemoGettingStartedRepository(),
        ),
        kidBadgesRepositoryProvider.overrideWithValue(
          DemoKidBadgesRepository(),
        ),
        householdInvalidationsProvider.overrideWith(
          (ref, id) => const Stream<Invalidation>.empty(),
        ),
        nightProvider.overrideWith(_Day.new),
      ],
      child: const WuselWallApp(),
    ),
  );
}
