import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/appearance.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/app_language.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/server/setup_store.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/account/application/account_admin_providers.dart';
import 'package:wuselwall/features/account/data/account_admin_repository.dart';
import 'package:wuselwall/features/account/domain/member_security.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/data/board_repository.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/data/external_calendars_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/household/data/household_leave_repository.dart';
import 'package:wuselwall/features/household/data/household_onboarding_repository.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/data/pairing_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/region/data/region_repository.dart';
import 'package:wuselwall/features/reminders/application/reminder_providers.dart';
import 'package:wuselwall/features/reminders/data/reminder_dismissal_store.dart';
import 'package:wuselwall/features/school/data/proposals_repository.dart';
import 'package:wuselwall/features/school/data/scan_repository.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';
import 'package:wuselwall/features/today/data/notices_repository.dart';

import 'fake_external_calendars.dart';
import 'fake_getting_started.dart';
import 'fake_invitations.dart';
import 'fake_meals.dart';
import 'fake_notices.dart';
import 'fake_notifications.dart';
import 'fake_pairing.dart';
import 'fake_region.dart';
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
  // A child has no account of their own (ADR-014).
  const Member(
    id: kidId,
    displayName: 'Anna',
    color: Color(0xFFFF8800),
    role: Role.member,
    active: true,
    isChild: true,
    hasAccount: false,
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
    List<Member>? members,
  }) : _people = List.of(members ?? testMembers);

  /// The household's people, as `members()` returns them.
  final List<Member> _people;
  DeviceInfo? current;
  MfaState mfa;
  GuardianProfile? profile;
  Result<void> enrolResult;

  /// What [signIn] answers; a failure by default, as an unknown account would.
  Result<void> signInResult = const Err(
    AuthFailure(code: 'invalid_credentials'),
  );
  final signIns = <(String, String)>[];

  /// E1/E2: the addresses a code was mailed to, and the codes checked.
  final codeRequests = <String>[];
  final codeChecks = <String>[];
  Result<void> sendCodeResult = const Ok(null);

  /// What checking a code answers: `Ok(true)` for a new account (E3 owed).
  Result<bool> verifyResult = const Ok(false);
  Result<bool> Function(String code)? verifyFor;
  final passwordsSet = <String>[];
  final choices = <String>[];
  bool passwordSet = false;
  final pins = <String>[];
  final registeredLabels = <String>[];
  final mfaCodes = <String>[];
  final createdCodes = <String>[];
  PinResult pinResult;
  final pinAttempts = <String>[];
  var signedOut = false;

  @override
  Future<Result<DeviceInfo?>> currentDevice() async => Ok(current);

  @override
  Future<Result<List<Member>>> members({bool includeInactive = false}) async =>
      Ok([
        for (final m in _people)
          if (includeInactive || m.active) m,
      ]);

  /// What the member, family and device edits asked for.
  final memberUpdates =
      <
        ({
          String id,
          String? name,
          String? colorHex,
          bool? isChild,
          String? avatarKey,
        })
      >[];
  final reorders = <List<String>>[];
  final roleChanges = <({String id, Role role})>[];
  final activeChanges = <({String id, bool active})>[];
  final householdUpdates =
      <({String? name, String? timezone, String? locale})>[];
  final deviceRenames = <({String id, String label})>[];
  HouseholdInfo household_ = const HouseholdInfo(
    id: 'h1',
    name: 'Familie Test',
    timezone: 'Europe/Berlin',
    locale: 'de-DE',
  );

  @override
  Future<Result<HouseholdInfo>> household() async => Ok(household_);

  @override
  Future<Result<void>> updateHousehold({
    required String? actor,
    String? name,
    String? timezone,
    String? locale,
  }) async {
    householdUpdates.add((name: name, timezone: timezone, locale: locale));
    household_ = HouseholdInfo(
      id: household_.id,
      name: name ?? household_.name,
      timezone: timezone ?? household_.timezone,
      locale: locale ?? household_.locale,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> renameDevice({
    required String? actor,
    required String deviceId,
    required String label,
  }) async {
    deviceRenames.add((id: deviceId, label: label));
    return const Ok(null);
  }

  @override
  Future<Result<void>> updateMember({
    required String? actor,
    required String profileId,
    String? name,
    String? colorHex,
    bool? isChild,
    String? avatarKey,
  }) async {
    memberUpdates.add((
      id: profileId,
      name: name,
      colorHex: colorHex,
      isChild: isChild,
      avatarKey: avatarKey,
    ));
    final i = _people.indexWhere((m) => m.id == profileId);
    if (i >= 0) {
      final m = _people[i];
      _people[i] = Member(
        id: m.id,
        displayName: name ?? m.displayName,
        color: colorHex == null ? m.color : parseHexColor(colorHex),
        role: m.role,
        active: m.active,
        isChild: isChild ?? m.isChild,
        sortOrder: m.sortOrder,
        hasAccount: m.hasAccount,
        avatarKey: avatarKey == null
            ? m.avatarKey
            : (avatarKey.isEmpty ? null : avatarKey),
      );
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> reorderMembers({
    required String? actor,
    required List<String> profileIds,
  }) async {
    reorders.add(profileIds);
    _people.sort((a, b) {
      final ia = profileIds.indexOf(a.id), ib = profileIds.indexOf(b.id);
      return (ia < 0 ? 1 << 20 : ia).compareTo(ib < 0 ? 1 << 20 : ib);
    });
    return const Ok(null);
  }

  @override
  Future<Result<void>> setMemberRole({
    required String? actor,
    required String profileId,
    required Role role,
  }) async {
    roleChanges.add((id: profileId, role: role));
    return const Ok(null);
  }

  @override
  Future<Result<void>> setMemberActive({
    required String? actor,
    required String profileId,
    required bool active,
  }) async {
    activeChanges.add((id: profileId, active: active));
    final i = _people.indexWhere((m) => m.id == profileId);
    if (i >= 0) {
      final m = _people[i];
      _people[i] = Member(
        id: m.id,
        displayName: m.displayName,
        color: m.color,
        role: m.role,
        active: active,
        isChild: m.isChild,
        sortOrder: m.sortOrder,
        hasAccount: m.hasAccount,
        avatarKey: m.avatarKey,
      );
    }
    return const Ok(null);
  }

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

  /// The family's devices, as the settings page lists them.
  List<DeviceEntry> devices_ = const [];

  @override
  Future<Result<List<DeviceEntry>>> devices() async => Ok(devices_);

  @override
  Future<Result<void>> signIn(String email, String password) async {
    signIns.add((email, password));
    return signInResult;
  }

  @override
  Future<Result<void>> sendEmailCode(
    String email, {
    required String locale,
  }) async {
    codeRequests.add(email);
    return sendCodeResult;
  }

  @override
  Future<Result<bool>> verifyEmailCode(String email, String code) async {
    codeChecks.add(code);
    return verifyFor?.call(code) ?? verifyResult;
  }

  @override
  Future<Result<void>> setPassword(String password) async {
    passwordsSet.add(password);
    passwordSet = true;
    return const Ok(null);
  }

  @override
  bool hasPassword() => passwordSet;

  @override
  Future<Result<void>> markSignInChoice(String choice) async {
    choices.add(choice);
    return const Ok(null);
  }

  @override
  Future<Result<void>> setPin({required String pin}) async {
    pins.add(pin);
    return const Ok(null);
  }

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

/// Starting a family. Creating a household records its arguments; on success it makes
/// [identity] Ready, as the session refresh does in the app (the test re-reads the session).
/// Records the leave, delete and restore calls; each answers with its result.
/// Deleting the account and resetting a second factor. Each deletion answers with the next of
/// [deleteResults] (the last one repeats). [recent] is what the sign-in check answers.
class FakeAccountAdminRepository implements AccountAdminRepository {
  List<Result<void>> deleteResults = [const Ok(null)];
  Result<void> resetResult = const Ok(null);
  List<MemberSecurity> security = const [];
  bool recent = false;

  var deleteCalls = 0;
  final resets = <({String actorProfileId, String profileId})>[];

  @override
  bool hasRecentSignIn() => recent;

  @override
  Future<Result<void>> deleteAccount() async {
    final i = deleteCalls < deleteResults.length
        ? deleteCalls
        : deleteResults.length - 1;
    deleteCalls++;
    return deleteResults[i];
  }

  @override
  Future<Result<void>> resetMfa({
    required String actorProfileId,
    required String profileId,
  }) async {
    resets.add((actorProfileId: actorProfileId, profileId: profileId));
    return resetResult;
  }

  @override
  Future<Result<List<MemberSecurity>>> memberSecurity(
    String actorProfileId,
  ) async => Ok(security);
}

class FakeHouseholdLeaveRepository implements HouseholdLeaveRepository {
  Result<void> leaveResult = const Ok(null);
  Result<void> deleteResult = const Ok(null);
  Result<void> restoreResult = const Ok(null);
  Result<void> startAfreshResult = const Ok(null);

  final leaves = <String>[];
  final deletes = <({String profileId, String confirmName})>[];
  var restores = 0;
  var startAfreshes = 0;

  @override
  Future<Result<void>> leaveFamily({required String profileId}) async {
    leaves.add(profileId);
    return leaveResult;
  }

  @override
  Future<Result<void>> deleteFamily({
    required String profileId,
    required String confirmName,
  }) async {
    deletes.add((profileId: profileId, confirmName: confirmName));
    return deleteResult;
  }

  @override
  Future<Result<void>> restoreFamily() async {
    restores++;
    return restoreResult;
  }

  @override
  Future<Result<void>> startAfresh() async {
    startAfreshes++;
    return startAfreshResult;
  }
}

class FakeHouseholdOnboardingRepository
    implements HouseholdOnboardingRepository {
  FakeHouseholdOnboardingRepository({
    this.accountValue = const Account(
      userId: 'user-1',
      email: 'daniel@example.org',
      hasHousehold: false,
      creation: HouseholdCreation.code,
      fullName: 'Daniel Huser',
      givenName: 'Daniel',
    ),
    this.createResult = const Ok(null),
    this.identity,
  });

  Account accountValue;
  Result<void> createResult;
  final FakeIdentityRepository? identity;

  /// The arguments of each create call, in order.
  final created =
      <
        ({
          String householdName,
          String displayName,
          String colorHex,
          String timezone,
          String locale,
          String? founderCode,
          bool seedExamples,
          String deviceLabel,
        })
      >[];
  final addedMembers = <List<NewMember>>[];
  var examplesCompleted = 0;

  @override
  Future<Result<Account>> account() async => Ok(accountValue);

  @override
  Future<Result<void>> create({
    required String householdName,
    required String displayName,
    required String colorHex,
    required String timezone,
    required String locale,
    required String? founderCode,
    required bool seedExamples,
    required String deviceLabel,
  }) async {
    created.add((
      householdName: householdName,
      displayName: displayName,
      colorHex: colorHex,
      timezone: timezone,
      locale: locale,
      founderCode: founderCode,
      seedExamples: seedExamples,
      deviceLabel: deviceLabel,
    ));
    if (createResult is Ok && identity != null) identity!.current = device();
    return createResult;
  }

  @override
  Future<Result<void>> addMembers(List<NewMember> members) async {
    addedMembers.add(members);
    return const Ok(null);
  }

  @override
  Future<Result<void>> completeExamples() async {
    examplesCompleted++;
    return const Ok(null);
  }
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
      categories: categories_,
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

  /// The lists and categories the fake serves; tests change them to see the editor.
  List<ShoppingList> lists_ = const [
    ShoppingList(id: 'l1', name: 'Supermarkt', isDefault: true, openCount: 0),
  ];
  List<ShoppingCategory> categories_ = const [];
  final renames = <({String id, String name})>[];
  final deletedLists = <String>[];
  final savedCategories = <({String listId, String? id, String name})>[];
  final deletedCategories = <String>[];
  final reorderedCategories = <List<String>>[];
  final catalogUpdates = <({String id, String? name})>[];
  final forgottenTiles = <String>[];

  @override
  Future<Result<List<ShoppingList>>> lists() async => Ok(lists_);

  @override
  Future<Result<List<ShoppingCategory>>> categories() async => Ok(categories_);

  @override
  Future<Result<void>> renameList({
    required String? actor,
    required String listId,
    required String name,
  }) async {
    renames.add((id: listId, name: name));
    lists_ = [
      for (final l in lists_)
        l.id == listId
            ? ShoppingList(
                id: l.id,
                name: name,
                isDefault: l.isDefault,
                openCount: l.openCount,
              )
            : l,
    ];
    return const Ok(null);
  }

  @override
  Future<Result<void>> deleteList({
    required String? actor,
    required String listId,
  }) async {
    deletedLists.add(listId);
    lists_ = [
      for (final l in lists_)
        if (l.id != listId) l,
    ];
    return const Ok(null);
  }

  @override
  Future<Result<String>> saveCategory({
    required String? actor,
    required String listId,
    String? categoryId,
    required String name,
  }) async {
    savedCategories.add((listId: listId, id: categoryId, name: name));
    return Ok(categoryId ?? 'c-new');
  }

  @override
  Future<Result<void>> deleteCategory({
    required String? actor,
    required String categoryId,
  }) async {
    deletedCategories.add(categoryId);
    return const Ok(null);
  }

  @override
  Future<Result<void>> reorderCategories({
    required String? actor,
    required String listId,
    required List<String> categoryIds,
  }) async {
    reorderedCategories.add(categoryIds);
    return const Ok(null);
  }

  @override
  Future<Result<void>> updateCatalogItem({
    required String? actor,
    required String itemId,
    String? name,
    String? categoryId,
  }) async {
    catalogUpdates.add((id: itemId, name: name));
    return const Ok(null);
  }

  @override
  Future<Result<void>> deleteCatalogItem({
    required String? actor,
    required String itemId,
  }) async {
    forgottenTiles.add(itemId);
    return const Ok(null);
  }

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

class EmptySetupStore extends SetupStore {
  @override
  Future<String?> read(Uri server) async => null;
  @override
  Future<void> clear() async {}
}

List<Override> baseOverrides({
  required FakeIdentityRepository identity,
  FakeShoppingRepository? shopping,
  FakeExternalCalendarsRepository? externalCalendars,
  FakeNotificationScheduler? notifications,
  FakePairingRepository? pairing,
  FakeHouseholdOnboardingRepository? household,
  FakeHouseholdLeaveRepository? leave,
  FakeAccountAdminRepository? accountAdmin,
  FakeInvitationRepository? invitations,
  MemoryInvitationStore? invitationStore,
  SetupStore? setupStore,
  AppearanceStore? appearance,
  AppLanguageStore? language,

  /// Basic, as on a new device; tests of an Advanced row pass [SettingsView.advanced].
  SettingsView settingsView = SettingsView.basic,
  SettingsViewStore? settingsViewStore,

  /// The app's configuration; a test of a server's discovery document passes one with
  /// [AppConfig.server] set.
  AppConfig? appConfig,
  bool signedIn = true,
  bool online = true,

  /// The wall clock the app reads ([nowProvider]); the real time when null.
  DateTime? now,

  /// Replaces the constant session of [signedIn], for a journey that signs in on the way.
  Override? sessionUser,
}) => [
  setupStoreProvider.overrideWithValue(setupStore ?? EmptySetupStore()),
  householdLeaveRepositoryProvider.overrideWithValue(
    leave ?? FakeHouseholdLeaveRepository(),
  ),
  accountAdminRepositoryProvider.overrideWithValue(
    accountAdmin ?? FakeAccountAdminRepository(),
  ),
  invitationRepositoryProvider.overrideWithValue(
    invitations ?? FakeInvitationRepository(),
  ),
  invitationStoreProvider.overrideWithValue(
    invitationStore ?? MemoryInvitationStore(),
  ),
  householdOnboardingRepositoryProvider.overrideWithValue(
    household ?? FakeHouseholdOnboardingRepository(identity: identity),
  ),
  pairingRepositoryProvider.overrideWithValue(
    pairing ?? FakePairingRepository(),
  ),
  // Local reminders: granted and available by default, so the Today row stays hidden in
  // tests that are not about it; the plan applies at once (no debounce).
  notificationSchedulerProvider.overrideWithValue(
    notifications ?? FakeNotificationScheduler(),
  ),
  reminderDismissalStoreProvider.overrideWithValue(
    MemoryReminderDismissalStore(),
  ),
  reminderDebounceProvider.overrideWithValue(Duration.zero),
  appearanceStoreProvider.overrideWithValue(
    appearance ?? MemoryAppearanceStore(),
  ),
  appLanguageStoreProvider.overrideWithValue(
    language ?? MemoryAppLanguageStore(),
  ),
  settingsViewStoreProvider.overrideWithValue(
    settingsViewStore ?? MemorySettingsViewStore(settingsView),
  ),
  externalCalendarsRepositoryProvider.overrideWithValue(
    externalCalendars ?? FakeExternalCalendarsRepository(),
  ),
  appConfigProvider.overrideWithValue(
    appConfig ??
        const AppConfig(
          environment: 'test',
          supabaseUrl: 'http://localhost',
          supabasePublishableKey: 'key',
        ),
  ),
  appVersionProvider.overrideWith((ref) async => '1.1.0'),
  sessionUser ??
      sessionUserIdProvider.overrideWithValue(signedIn ? 'user-1' : null),
  identityRepositoryProvider.overrideWithValue(identity),
  if (shopping != null) shoppingRepositoryProvider.overrideWithValue(shopping),
  shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
  connectivityProvider.overrideWith((ref) => Stream.value(online)),
  householdInvalidationsProvider.overrideWith(
    (ref, id) => const Stream<Invalidation>.empty(),
  ),
  // Daytime, and no boundary timer outliving the widget tree.
  nightProvider.overrideWith(DayNight.new),
  // One tick, not a per-second stream: the kiosk clock would keep pumpAndSettle busy.
  clockProvider.overrideWith((ref) => Stream.value(now ?? DateTime.now())),
  if (now != null) nowProvider.overrideWithValue(now),
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
  FakeProposalsRepository? proposals,
  FakeScanRepository? scan,
  FakeGettingStartedRepository? gettingStarted,
  FakeNoticesRepository? notices,
  FakeRegionRepository? region,
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
      // The tasks repository runs on a fake `api` layer; an empty one when a test does not
      // ask for one, so the Today tab never reaches Supabase.
      apiClientProvider.overrideWithValue(tasks ?? FakeTasksApi()),
      noticesRepositoryProvider.overrideWithValue(
        notices ?? FakeNoticesRepository(),
      ),
      gettingStartedRepositoryProvider.overrideWithValue(
        gettingStarted ?? FakeGettingStartedRepository(),
      ),
      mealsRepositoryProvider.overrideWithValue(meals ?? FakeMealsRepository()),
      schoolRepositoryProvider.overrideWithValue(
        school ?? FakeSchoolRepository(),
      ),
      proposalsRepositoryProvider.overrideWithValue(
        proposals ?? FakeProposalsRepository(),
      ),
      scanRepositoryProvider.overrideWithValue(
        scan ?? FakeScanRepository(failure: const NetworkFailure()),
      ),
      regionRepositoryProvider.overrideWithValue(
        region ?? FakeRegionRepository(),
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

/// Switches the adult home to the tab with [label] (its navigation bar label). Today is
/// the default tab, so tests about another tab start by tapping it.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
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
