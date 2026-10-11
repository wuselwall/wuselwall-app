// Entry point for the user documentation's screenshots, never part of a release:
//   flutter build web -t lib/main_demo.dart
// The app runs on in-memory data (lib/demo). The scenario comes from the URL:
//   ?scenario=setup | adult | kid | kiosk   (default adult)
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
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';

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
        shoppingRepositoryProvider.overrideWithValue(DemoShoppingRepository()),
        householdInvalidationsProvider.overrideWith(
          (ref, id) => const Stream<Invalidation>.empty(),
        ),
        nightProvider.overrideWith(_Day.new),
      ],
      child: const WuselWallApp(),
    ),
  );
}
