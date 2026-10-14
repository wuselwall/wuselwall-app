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
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/data/board_repository.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/data/sign_in_methods_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/domain/sign_in_method.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

import 'fake_meals.dart';
import 'fake_school.dart';
import 'fake_tasks.dart';

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
    isChild: true,
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
  FakeShoppingRepository(this.list, {this.mealsByItem = const {}});

  List<ShoppingItem> list;
  final toggles = <({String? actor, String id})>[];

  /// The meals behind each item id, for the item's sheet.
  final Map<String, List<ShoppingItemMeal>> mealsByItem;

  @override
  Future<Result<List<ShoppingItem>>> items() async => Ok(list);

  @override
  Future<Result<List<ShoppingItemMeal>>> itemMeals(String itemId) async =>
      Ok(mealsByItem[itemId] ?? const []);

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

/// Apple and Google without platform sheets. Offers nothing unless told to.
class FakeSignInMethods implements SignInMethodsRepository {
  FakeSignInMethods({
    this.offered = const [],
    this.linkable = const {},
    List<SignInMethod>? linked,
    this.signInResult = const Ok(null),
  }) : linked = linked ?? [];

  List<SignInProvider> offered;
  Set<SignInProvider> linkable;
  List<SignInMethod> linked;
  Result<void> signInResult;
  final signIns = <SignInProvider>[];
  final links = <SignInProvider>[];
  final unlinked = <String>[];
  final redirectErrors = StreamController<Failure>.broadcast();

  @override
  List<SignInProvider> available() => offered;

  @override
  bool canLink(SignInProvider provider) => linkable.contains(provider);

  @override
  Future<Result<void>> signIn(SignInProvider provider) async {
    signIns.add(provider);
    return signInResult;
  }

  @override
  Stream<Failure> authErrors() => redirectErrors.stream;

  @override
  Future<Result<List<SignInMethod>>> methods() async => Ok([...linked]);

  @override
  Future<Result<bool>> link(SignInProvider provider) async {
    links.add(provider);
    linked.add(
      SignInMethod(
        identityId: 'identity-${provider.name}',
        provider: provider.kind,
      ),
    );
    return const Ok(true);
  }

  @override
  Future<Result<void>> unlink(String identityId) async {
    unlinked.add(identityId);
    linked.removeWhere((m) => m.identityId == identityId);
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// An empty week board for this week: no members, events or presence. Enough for the
/// kiosk home to draw its zones without reaching Supabase.
WeekBoard emptyWeekBoard([DateTime? now]) {
  final today = now ?? DateTime.now();
  final monday = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));
  String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return WeekBoard.fromJson({
    'week_start': ymd(monday),
    'today': ymd(today),
    'generated_at': today.toUtc().toIso8601String(),
    'members': <Map<String, dynamic>>[],
    'presence': <Map<String, dynamic>>[],
    'timetables': <Map<String, dynamic>>[],
    'days': [
      for (var i = 0; i < 7; i++)
        {
          'date': ymd(monday.add(Duration(days: i))),
          'events': <Map<String, dynamic>>[],
          'busy_until': <Map<String, dynamic>>[],
          'school': <Map<String, dynamic>>[],
        },
    ],
    'open_tasks': <Map<String, dynamic>>[],
    'shopping_count': 0,
  });
}

/// Serves [board] (by default an empty week board) for the kiosk home.
class FakeBoardRepository implements BoardRepository {
  FakeBoardRepository([WeekBoard? board]) : board = board ?? emptyWeekBoard();

  WeekBoard board;

  @override
  Future<Result<WeekBoard>> week({DateTime? weekStart}) async => Ok(board);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Serves the occurrences it was given that fall inside the asked window; empty by
/// default, so a test that does not care about the calendar does not reach Supabase.
/// In-memory calendar. Records every write with its actor, so tests can assert the
/// `p_event` and the override calls the editor makes.
class FakeCalendarRepository implements CalendarRepository {
  FakeCalendarRepository([
    List<Occurrence> items = const [],
    Map<String, CalendarEvent> events = const {},
  ]) : items = [...items],
       events = {...events};

  final List<Occurrence> items;

  /// The events the editor can load, by id.
  final Map<String, CalendarEvent> events;

  /// The events the editor has saved, in order.
  final saved = <CalendarEvent>[];

  /// The actor of each save, in the same order as [saved].
  final savedActors = <String?>[];

  final overrides =
      <
        ({
          String eventId,
          DateTime recurrenceId,
          bool cancelled,
          Map<String, dynamic> patch,
        })
      >[];

  final deleted = <String>[];

  @override
  Future<Result<OccurrenceWindow>> occurrences(
    DateTime from,
    DateTime to,
  ) async => Ok(
    OccurrenceWindow(
      timezone: 'Europe/Berlin',
      occurrences: [
        for (final o in items)
          if (!o.localEndDate.isBefore(dateOnly(from)) &&
              !o.localStartDate.isAfter(dateOnly(to)))
            o,
      ],
    ),
  );

  @override
  Future<Result<CalendarEvent>> event(String id) async {
    final event = events[id];
    return event == null
        ? const Err(NotFoundFailure(code: 'event_not_found'))
        : Ok(event);
  }

  @override
  Future<Result<String>> save({
    required String? actor,
    required CalendarEvent event,
  }) async {
    saved.add(event);
    savedActors.add(actor);
    return Ok(event.id ?? 'new-event');
  }

  @override
  Future<Result<void>> delete({
    required String? actor,
    required String id,
  }) async {
    deleted.add(id);
    return const Ok(null);
  }

  @override
  Future<Result<String>> saveOverride({
    required String? actor,
    required String eventId,
    required DateTime recurrenceId,
    bool cancelled = false,
    Map<String, dynamic> patch = const {},
  }) async {
    overrides.add((
      eventId: eventId,
      recurrenceId: recurrenceId,
      cancelled: cancelled,
      patch: patch,
    ));
    return Ok('override-${overrides.length}');
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
  FakeSignInMethods? signInMethods,
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
  signInMethodsRepositoryProvider.overrideWithValue(
    signInMethods ?? FakeSignInMethods(),
  ),
  if (shopping != null) shoppingRepositoryProvider.overrideWithValue(shopping),
  shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
  connectivityProvider.overrideWith((ref) => Stream.value(true)),
  householdInvalidationsProvider.overrideWith(
    (ref, id) => const Stream<Invalidation>.empty(),
  ),
  // Daytime, and no boundary timer outliving the widget tree.
  nightProvider.overrideWith(DayNight.new),
  // One tick, not a per-second stream: the kiosk clock would keep pumpAndSettle busy.
  clockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
];

class DayNight extends NightNotifier {
  @override
  bool build() => false;
}

/// Pumps the app with [overrides] plus a board backend: [board] when given, otherwise
/// an empty week board, so no test reaches Supabase through the kiosk home.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  required List<Override> overrides,
  Locale locale = const Locale('de'),
  FakeBoardRepository? board,
  FakeCalendarRepository? calendar,
  FakeTasksApi? tasks,
  FakeMealsRepository? meals,
  FakeSchoolRepository? school,
  Size size = const Size(1000, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = [locale];
  // Reduced motion: the board's repeating "next up" pulse would otherwise keep
  // pumpAndSettle from ever settling. Motion itself is not under test here.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearLocalesTestValue();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  final container = ProviderContainer(
    overrides: [
      ...overrides,
      boardRepositoryProvider.overrideWithValue(board ?? FakeBoardRepository()),
      calendarRepositoryProvider.overrideWithValue(
        calendar ?? FakeCalendarRepository(),
      ),
      // The tasks repository runs on a fake `api` layer when a test asks for one.
      if (tasks != null) apiClientProvider.overrideWithValue(tasks),
      mealsRepositoryProvider.overrideWithValue(meals ?? FakeMealsRepository()),
      schoolRepositoryProvider.overrideWithValue(
        school ?? FakeSchoolRepository(),
      ),
    ],
  );
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

/// Unmounts the app and disposes its container inside the test. The kiosk board keeps
/// a timer in its container (the midnight refresh), and Flutter checks for pending
/// timers before the container's own teardown runs.
Future<void> unmountApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
}
