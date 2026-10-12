import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

const guardianId = 'p-guardian';
const kidId = 'p-kid';

final testMembers = [
  const Member(
    id: guardianId,
    displayName: 'Papa',
    color: Color(0xFF2E7D6B),
    role: Role.guardian,
    active: true,
  ),
  const Member(
    id: kidId,
    displayName: 'Anna',
    color: Color(0xFFFF8800),
    role: Role.member,
    active: true,
  ),
];

DeviceInfo device({
  DeviceClass deviceClass = DeviceClass.personal,
  UiRegister register = UiRegister.adult,
  String? profileId = guardianId,
}) => DeviceInfo(
  deviceId: 'd1',
  householdId: 'h1',
  label: 'Test',
  deviceClass: deviceClass,
  register: register,
  profileId: deviceClass == DeviceClass.personal ? profileId : null,
  revoked: false,
  guardianVerifiedUntil: null,
);

/// In-memory identity backend. Records what the UI asked for.
class FakeIdentityRepository implements IdentityRepository {
  FakeIdentityRepository({
    this.current,
    this.pinResult = const PinWrong(8),
    this.mfa = MfaState.none,
    this.profile,
    this.enrolResult = const Err(ValidationFailure(code: 'code_invalid')),
  });

  DeviceInfo? current;
  MfaState mfa;
  GuardianProfile? profile;
  Result<void> enrolResult;
  final registeredLabels = <String>[];
  final mfaCodes = <String>[];
  final createdCodes = <String>[];
  PinResult pinResult;
  final pinAttempts = <String>[];
  var signedOut = false;

  @override
  Future<Result<DeviceInfo?>> currentDevice() async => Ok(current);

  @override
  Future<Result<List<Member>>> members() async => Ok(testMembers);

  @override
  Future<Result<PinResult>> verifyPin({
    required String profileId,
    required String pin,
  }) async {
    pinAttempts.add(pin);
    return Ok(pinResult);
  }

  @override
  Future<void> signOut() async => signedOut = true;

  @override
  Future<Result<List<DeviceEntry>>> devices() async => const Ok([]);

  @override
  Future<Result<void>> signIn(String email, String password) async =>
      const Err(AuthFailure(code: 'invalid_credentials'));

  @override
  Future<Result<void>> enrolDevice(String code) async => enrolResult;

  @override
  MfaState mfaState() => mfa;

  @override
  Future<Result<GuardianProfile?>> myProfile() async => Ok(profile);

  @override
  Future<Result<DeviceInfo>> registerPersonalDevice(String label) async {
    registeredLabels.add(label);
    current = device();
    profile = null;
    return Ok(current!);
  }

  @override
  Future<Result<void>> totpChallenge(String code) async {
    mfaCodes.add(code);
    mfa = MfaState.satisfied;
    return const Ok(null);
  }

  @override
  Future<Result<String?>> totpFactorId() async => const Ok(null);

  @override
  Future<Result<EnrolmentCode>> createEnrolmentCode({
    required String? actor,
    required String label,
    required DeviceClass deviceClass,
    required UiRegister register,
  }) async {
    createdCodes.add(label);
    return Ok(EnrolmentCode(code: 'ABCD2345', expiresAt: DateTime(2030)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeShoppingRepository implements ShoppingRepository {
  FakeShoppingRepository(this.list);

  List<ShoppingItem> list;
  final toggles = <({String? actor, String id})>[];

  @override
  Future<Result<List<ShoppingItem>>> items() async => Ok(list);

  @override
  Future<Result<ShoppingSnapshot>> snapshot() async => Ok(
    ShoppingSnapshot(
      items: list,
      lists: (await lists()).valueOrNull!,
      categories: const [],
      catalog: const [],
    ),
  );

  /// Applies the batch with the app's projection; ticks are recorded as [toggles].
  @override
  Future<Result<ApplyResult>> apply({
    required String? actor,
    required List<ShoppingOp> ops,
  }) async {
    for (final op in ops.whereType<CheckItemOp>()) {
      toggles.add((actor: op.actor, id: op.itemId));
    }
    final view = projectShopping((await snapshot()).valueOrNull!, ops);
    list = [for (final i in view.items) i.copyWith(pending: false)];
    return Ok(
      ApplyResult(
        results: [
          for (final op in ops) OpResult(opId: op.opId, status: 'applied'),
        ],
        items: list,
      ),
    );
  }

  @override
  Future<Result<List<ShoppingList>>> lists() async => const Ok([
    ShoppingList(id: 'l1', name: 'Supermarkt', isDefault: true, openCount: 0),
  ]);

  @override
  Future<Result<List<ShoppingCategory>>> categories() async => const Ok([]);

  @override
  Future<Result<List<CatalogEntry>>> catalog() async => const Ok([]);

  @override
  Future<Result<void>> toggle({
    required String? actor,
    required String itemId,
  }) async {
    toggles.add((actor: actor, id: itemId));
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ShoppingItem item(String id, String name, {bool checked = false}) =>
    ShoppingItem(
      id: id,
      name: name,
      quantity: null,
      checked: checked,
      createdAt: DateTime(2026, 10, 11),
    );

List<Override> baseOverrides({
  required FakeIdentityRepository identity,
  FakeShoppingRepository? shopping,
  bool signedIn = true,
}) => [
  appConfigProvider.overrideWithValue(
    const AppConfig(
      environment: 'test',
      supabaseUrl: 'http://localhost',
      supabasePublishableKey: 'key',
    ),
  ),
  sessionUserIdProvider.overrideWithValue(signedIn ? 'user-1' : null),
  identityRepositoryProvider.overrideWithValue(identity),
  if (shopping != null) shoppingRepositoryProvider.overrideWithValue(shopping),
  shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
  connectivityProvider.overrideWith((ref) => Stream.value(true)),
  householdInvalidationsProvider.overrideWith(
    (ref, id) => const Stream<Invalidation>.empty(),
  ),
  // Daytime, and no boundary timer outliving the widget tree.
  nightProvider.overrideWith(DayNight.new),
];

class DayNight extends NightNotifier {
  @override
  bool build() => false;
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required List<Override> overrides,
  Locale locale = const Locale('de'),
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearLocalesTestValue();
  });

  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WuselWallApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
