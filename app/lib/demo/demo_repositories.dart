import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_english.dart';
import 'package:wuselwall/demo/demo_external_calendars.dart';
import 'package:wuselwall/features/account/data/account_admin_repository.dart';
import 'package:wuselwall/features/account/domain/member_security.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/household/data/household_leave_repository.dart';
import 'package:wuselwall/features/household/data/household_onboarding_repository.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

/// In-memory stand-ins for the backend, used only by `lib/main_demo.dart` to take
/// the screenshots of the user documentation. The PIN is 123456; nothing leaves the page.
class DemoIdentityRepository implements IdentityRepository {
  DemoIdentityRepository({required this.device});

  final DeviceInfo? device;
  final _members = [...DemoData.members];

  @override
  Future<Result<DeviceInfo?>> currentDevice() async => Ok(device);

  @override
  Future<Result<List<Member>>> members() async => Ok(List.of(_members));

  @override
  Future<Result<List<DeviceEntry>>> devices() async => Ok(DemoData.devices);

  @override
  Future<Result<void>> signIn(String email, String password) async =>
      const Ok(null);

  @override
  Future<Result<void>> sendEmailCode(
    String email, {
    required String locale,
  }) async => const Ok(null);

  @override
  Future<Result<bool>> verifyEmailCode(String email, String code) async =>
      const Ok(false);

  @override
  Future<Result<void>> setPassword(String password) async => const Ok(null);

  @override
  bool hasPassword() => true;

  @override
  Future<Result<void>> markSignInChoice(String choice) async => const Ok(null);

  @override
  Future<void> signOut() async {}

  @override
  MfaState mfaState() => MfaState.none;

  @override
  Future<Result<GuardianProfile?>> myProfile() async => const Ok(null);

  @override
  Future<Result<String?>> totpFactorId() async => const Ok(null);

  @override
  Future<Result<void>> setPin({required String pin}) async => const Ok(null);

  @override
  Future<Result<void>> enrolDevice(String code) async =>
      const Err(ValidationFailure(code: 'code_invalid'));

  @override
  Future<Result<void>> addMember({
    required String? actor,
    required String name,
    required String colorHex,
  }) async {
    _members.add(
      Member(
        id: 'p-${_members.length}',
        displayName: name,
        color: parseHexColor(colorHex),
        role: Role.member,
        active: true,
      ),
    );
    return const Ok(null);
  }

  @override
  Future<Result<EnrolmentCode>> createEnrolmentCode({
    required String? actor,
    required String label,
    required DeviceClass deviceClass,
    required UiRegister register,
  }) async => Ok(
    EnrolmentCode(code: 'K7MQ4XWB', expiresAt: DateTime(2026, 10, 11, 9, 10)),
  );

  @override
  Future<Result<PinResult>> verifyPin({
    required String profileId,
    required String pin,
  }) async => Ok(
    pin == '123456'
        ? PinVerified(DateTime.now().add(const Duration(minutes: 15)))
        : const PinWrong(8),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not part of the demo',
  );
}

class DemoShoppingRepository implements ShoppingRepository {
  final _items = DemoData.items();
  final _lists = [
    for (final (id, name, def) in DemoData.lists)
      (id: id, name: name, isDefault: def),
  ];
  var _next = 0;

  @override
  Future<Result<List<ShoppingItem>>> items() async => Ok(List.of(_items));

  /// The two meals of the demo week that put the pasta on the list.
  @override
  Future<Result<List<ShoppingItemMeal>>> itemMeals(String itemId) async {
    final item = _items.where((i) => i.id == itemId).firstOrNull;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final meals = {
      'demo-src-nudel': ShoppingItemMeal(
        mealEntryId: 'demo-src-nudel',
        onDate: DateTime(monday.year, monday.month, monday.day + 1),
        title: demoText('Nudelauflauf'),
      ),
      'demo-src-pesto': ShoppingItemMeal(
        mealEntryId: 'demo-src-pesto',
        onDate: DateTime(monday.year, monday.month, monday.day + 5),
        title: demoText('Nudeln mit Pesto'),
      ),
    };
    return Ok([
      for (final id in item?.sourceMealEntryIds ?? const <String>[]) ?meals[id],
    ]);
  }

  @override
  Future<Result<ShoppingSnapshot>> snapshot() async => Ok(
    ShoppingSnapshot(
      items: List.of(_items),
      lists: (await lists()).valueOrNull!,
      categories: DemoData.categories(),
      catalog: DemoData.catalogue(),
    ),
  );

  /// The outbox's batch, applied with the app's own projection.
  @override
  Future<Result<ApplyResult>> apply({
    required String? actor,
    required List<ShoppingOp> ops,
  }) async {
    final view = projectShopping((await snapshot()).valueOrNull!, ops);
    _items
      ..clear()
      ..addAll([for (final i in view.items) i.copyWith(pending: false)]);
    return Ok(
      ApplyResult(
        results: [
          for (final op in ops) OpResult(opId: op.opId, status: 'applied'),
        ],
        items: List.of(_items),
      ),
    );
  }

  @override
  Future<Result<List<ShoppingList>>> lists() async => Ok([
    for (final l in _lists)
      ShoppingList(
        id: l.id,
        name: l.name,
        isDefault: l.isDefault,
        openCount: _items
            .where((it) => it.listId == l.id && !it.checked)
            .length,
      ),
  ]);

  @override
  Future<Result<List<ShoppingCategory>>> categories() async =>
      Ok(DemoData.categories());

  @override
  Future<Result<List<CatalogEntry>>> catalog() async =>
      Ok(DemoData.catalogue());

  @override
  Future<Result<List<ShoppingTrip>>> trips(String listId) async =>
      Ok(listId == 'l-super' ? DemoData.trips() : const []);

  @override
  Future<Result<List<TripItem>>> tripItems(String tripId) async =>
      Ok(DemoData.tripItems(tripId));

  @override
  Future<Result<String>> add({
    required String? actor,
    required String name,
    String? quantity,
    String? listId,
  }) async {
    final list = listId ?? 'l-super';
    final key = name.toLowerCase();
    final i = _items.indexWhere(
      (it) => it.listId == list && !it.checked && it.name.toLowerCase() == key,
    );
    if (i >= 0) {
      final it = _items[i];
      _items[i] = _copy(it, count: it.count + 1);
      return Ok(it.id);
    }
    final known = DemoData.catalogue().where(
      (c) => c.listId == list && c.name.toLowerCase() == key,
    );
    final id = 'n-${_next++}';
    _items.add(
      ShoppingItem(
        id: id,
        name: known.isEmpty ? name : known.first.name,
        quantity: quantity,
        checked: false,
        createdAt: DateTime.now(),
        listId: list,
        categoryId: known.isEmpty ? null : known.first.categoryId,
        addedBy: actor ?? DemoData.papa,
      ),
    );
    return Ok(id);
  }

  @override
  Future<Result<void>> toggle({
    required String? actor,
    required String itemId,
  }) async {
    final i = _items.indexWhere((it) => it.id == itemId);
    if (i >= 0) _items[i] = _copy(_items[i], checked: !_items[i].checked);
    return const Ok(null);
  }

  @override
  Future<Result<void>> adjustCount({
    required String? actor,
    required String itemId,
    required int delta,
  }) async {
    final i = _items.indexWhere((it) => it.id == itemId);
    if (i >= 0) {
      final count = _items[i].count + delta;
      count <= 0
          ? _items.removeAt(i)
          : _items[i] = _copy(_items[i], count: count);
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> setSpec({
    required String? actor,
    required String itemId,
    required String? text,
  }) async {
    final i = _items.indexWhere((it) => it.id == itemId);
    if (i >= 0) {
      _items[i] = _copy(
        _items[i],
        quantity: (text ?? '').isEmpty ? null : text,
        clearQuantity: (text ?? '').isEmpty,
      );
    }
    return const Ok(null);
  }

  @override
  Future<Result<String>> createList({
    required String? actor,
    required String name,
    required String kind,
  }) async {
    final id = 'l-${_lists.length}';
    _lists.add((id: id, name: name, isDefault: false));
    return Ok(id);
  }

  @override
  Future<Result<ShoppingFinishResult>> finish({
    required String? actor,
    String? listId,
  }) async {
    final list = listId ?? 'l-super';
    final done = _items.where((i) => i.listId == list && i.checked).length;
    _items.removeWhere((i) => i.listId == list && i.checked);
    return Ok(ShoppingFinishResult(bought: done, carriedOver: _items.length));
  }

  ShoppingItem _copy(
    ShoppingItem it, {
    int? count,
    bool? checked,
    String? quantity,
    bool clearQuantity = false,
  }) => ShoppingItem(
    id: it.id,
    name: it.name,
    quantity: clearQuantity ? null : (quantity ?? it.quantity),
    checked: checked ?? it.checked,
    createdAt: it.createdAt,
    listId: it.listId,
    categoryId: it.categoryId,
    addedBy: it.addedBy,
    count: count ?? it.count,
    sourceMealEntryIds: it.sourceMealEntryIds,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not part of the demo',
  );
}

typedef _Definition = ({
  String key,
  SettingScope scope,
  SettingType type,
  Object? defaultValue,
  Map<String, dynamic> constraints,
  bool selfService,
});

/// The catalogue of specs/21 with its curated defaults, as a household that changed
/// nothing sees it (`api.settings` without overrides).
const _catalogue = <_Definition>[
  (
    key: 'household.region',
    scope: SettingScope.household,
    type: SettingType.region,
    defaultValue: null,
    constraints: {'nullable': true},
    selfService: false,
  ),
  (
    key: 'board.member_label',
    scope: SettingScope.household,
    type: SettingType.enumeration,
    defaultValue: 'name',
    constraints: {
      'values': ['name', 'initial'],
    },
    selfService: false,
  ),
  (
    key: 'member.completion_sound',
    scope: SettingScope.member,
    type: SettingType.boolean,
    defaultValue: true,
    constraints: {},
    selfService: true,
  ),
  (
    key: 'tasks.points.duty_default',
    scope: SettingScope.household,
    type: SettingType.integer,
    defaultValue: 1,
    constraints: {'min': 0, 'max': 3},
    selfService: false,
  ),
  (
    key: 'tasks.points.bonus_default',
    scope: SettingScope.household,
    type: SettingType.integer,
    defaultValue: 5,
    constraints: {'min': 1, 'max': 50},
    selfService: false,
  ),
  (
    key: 'tasks.kind_default',
    scope: SettingScope.household,
    type: SettingType.enumeration,
    defaultValue: 'duty',
    constraints: {
      'values': ['duty', 'bonus'],
    },
    selfService: false,
  ),
  (
    key: 'tasks.verification_default',
    scope: SettingScope.household,
    type: SettingType.boolean,
    defaultValue: false,
    constraints: {},
    selfService: false,
  ),
  (
    key: 'tasks.jokers_per_month',
    scope: SettingScope.household,
    type: SettingType.integer,
    defaultValue: 1,
    constraints: {'min': 0, 'max': 5, 'per_member': true},
    selfService: false,
  ),
  (
    key: 'tasks.reward_approval_default',
    scope: SettingScope.household,
    type: SettingType.enumeration,
    defaultValue: 'required',
    constraints: {
      'values': ['required', 'self_serve'],
    },
    selfService: false,
  ),
  (
    key: 'calendar.members_edit_own_events',
    scope: SettingScope.household,
    type: SettingType.boolean,
    defaultValue: true,
    constraints: {},
    selfService: false,
  ),
  (
    key: 'calendar.key_default',
    scope: SettingScope.household,
    type: SettingType.enumeration,
    defaultValue: 'whole_family',
    constraints: {
      'values': ['whole_family', 'all', 'none'],
    },
    selfService: false,
  ),
  (
    key: 'calendar.tentative_nudge',
    scope: SettingScope.member,
    type: SettingType.time,
    defaultValue: '19:00',
    constraints: {},
    selfService: true,
  ),
  (
    key: 'school.members_report_changes',
    scope: SettingScope.household,
    type: SettingType.boolean,
    defaultValue: false,
    constraints: {},
    selfService: false,
  ),
  (
    key: 'school.equipment_hint',
    scope: SettingScope.household,
    type: SettingType.boolean,
    defaultValue: true,
    constraints: {},
    selfService: false,
  ),
  (
    key: 'meals.warm_meal.school_day',
    scope: SettingScope.household,
    type: SettingType.enumeration,
    defaultValue: 'dinner',
    constraints: {
      'values': ['lunch', 'dinner'],
    },
    selfService: false,
  ),
  (
    key: 'meals.warm_meal.free_day',
    scope: SettingScope.household,
    type: SettingType.enumeration,
    defaultValue: 'lunch',
    constraints: {
      'values': ['lunch', 'dinner'],
    },
    selfService: false,
  ),
  (
    key: 'meals.away_means_not_eating',
    scope: SettingScope.household,
    type: SettingType.boolean,
    defaultValue: true,
    constraints: {},
    selfService: false,
  ),
  (
    key: 'meals.care_lunch_cutoff',
    scope: SettingScope.household,
    type: SettingType.time,
    defaultValue: '14:00',
    constraints: {},
    selfService: false,
  ),
  (
    key: 'board.rollover',
    scope: SettingScope.household,
    type: SettingType.weekdayTime,
    defaultValue: {'weekday': 6, 'time': '12:00'},
    constraints: {},
    selfService: false,
  ),
  (
    key: 'board.day_parts',
    scope: SettingScope.household,
    type: SettingType.times,
    defaultValue: ['12:00', '17:00'],
    constraints: {},
    selfService: false,
  ),
  (
    key: 'device.night_hours',
    scope: SettingScope.device,
    type: SettingType.timeRange,
    defaultValue: {'from': '21:00', 'to': '06:00'},
    constraints: {},
    selfService: false,
  ),
  (
    key: 'device.idle_revert_seconds',
    scope: SettingScope.device,
    type: SettingType.integer,
    defaultValue: 60,
    constraints: {'min': 30, 'max': 300},
    selfService: false,
  ),
  (
    key: 'notify.morning_summary',
    scope: SettingScope.member,
    type: SettingType.time,
    defaultValue: '07:00',
    constraints: {'nullable': true},
    selfService: true,
  ),
  (
    key: 'notify.event_reminder',
    scope: SettingScope.member,
    type: SettingType.integer,
    defaultValue: null,
    constraints: {'min': 5, 'max': 120, 'nullable': true},
    selfService: true,
  ),
  (
    key: 'notify.packing_reminder',
    scope: SettingScope.member,
    type: SettingType.time,
    defaultValue: '19:00',
    constraints: {'nullable': true},
    selfService: true,
  ),
  (
    key: 'notify.task_verified',
    scope: SettingScope.member,
    type: SettingType.boolean,
    defaultValue: false,
    constraints: {},
    selfService: true,
  ),
  (
    key: 'notify.redemption_request',
    scope: SettingScope.member,
    type: SettingType.boolean,
    defaultValue: false,
    constraints: {},
    selfService: true,
  ),
];

/// The household-level rows of [_catalogue], sorted by key, as `api.settings` returns them.
List<SettingEntry> demoSettingCatalogue() => [
  for (final d in _catalogue)
    SettingEntry(
      key: d.key,
      scope: d.scope,
      type: d.type,
      constraints: d.constraints,
      selfService: d.selfService,
      defaultValue: d.defaultValue,
      value: d.defaultValue,
      isDefault: true,
    ),
]..sort((a, b) => a.key.compareTo(b.key));

/// In-memory household settings: a set or reset changes the rows the page shows.
class DemoHouseholdSettingsRepository implements HouseholdSettingsRepository {
  DemoHouseholdSettingsRepository() : _rows = demoSettingCatalogue();

  final List<SettingEntry> _rows;

  @override
  Future<Result<List<SettingEntry>>> all() async => Ok(List.of(_rows));

  @override
  Future<Result<void>> set({
    required String? actor,
    required String key,
    required Object? value,
    String? profileId,
    String? deviceId,
  }) async {
    final definition = _rows.firstWhere(
      (e) => e.key == key && e.profileId == null && e.deviceId == null,
    );
    _rows.removeWhere(
      (e) => e.key == key && e.profileId == profileId && e.deviceId == deviceId,
    );
    _rows.add(
      SettingEntry(
        key: key,
        scope: definition.scope,
        type: definition.type,
        constraints: definition.constraints,
        selfService: definition.selfService,
        defaultValue: definition.defaultValue,
        value: value,
        isDefault: false,
        profileId: profileId,
        deviceId: deviceId,
      ),
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> reset({
    required String? actor,
    required String key,
    String? profileId,
    String? deviceId,
  }) async {
    _rows.removeWhere(
      (e) => e.key == key && e.profileId == profileId && e.deviceId == deviceId,
    );
    return const Ok(null);
  }
}

/// The reference household's calendar for the screenshots: a few weekly items and this
/// week's one-offs, generated for whatever window is asked. Saves and deletes change an
/// in-memory list only; recurrence and overrides are not modelled in the demo.
class DemoCalendarRepository implements CalendarRepository {
  DemoCalendarRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _saved = <CalendarEvent>[];
  final _deleted = <String>{};

  /// Changes to single occurrences, keyed by event id and original start instant.
  final _overrides = <String, _DemoOverride>{};
  var _nextId = 1;

  @override
  Future<Result<OccurrenceWindow>> occurrences(
    DateTime from,
    DateTime to,
  ) async {
    final first = dateOnly(from);
    final last = dateOnly(to);
    final monday = _monday(_clock());
    // An event saved in this session replaces the built-in item of the same id.
    final savedIds = {for (final e in _saved) e.id};
    final out = <Occurrence>[];

    for (final item in _weekly) {
      if (savedIds.contains(item.id) || _deleted.contains(item.id)) continue;
      for (var d = first; !d.isAfter(last); d = _addDays(d, 1)) {
        if (d.weekday != item.weekday) continue;
        out.addAll(_visible(item.occurrence(d, recurring: true)));
      }
    }
    for (final item in _oneOffs) {
      if (savedIds.contains(item.id) || _deleted.contains(item.id)) continue;
      final start = _addDays(monday, item.firstDay);
      final end = _addDays(monday, item.lastDay);
      if (end.isBefore(first) || start.isAfter(last)) continue;
      out.addAll(_visible(item.occurrence(start, end)));
    }
    for (final event in _saved) {
      if (_deleted.contains(event.id)) continue;
      out.addAll(_expand(event, first, last).expand(_visible));
    }
    out.addAll(demoImportedOccurrences(monday, first, last));
    out.sort((a, b) => a.start.compareTo(b.start));
    return Ok(OccurrenceWindow(timezone: 'Europe/Berlin', occurrences: out));
  }

  @override
  Future<Result<CalendarEvent>> event(String id) async {
    final saved = _saved.where((e) => e.id == id).firstOrNull;
    if (saved != null) return Ok(saved);
    for (final item in _weekly) {
      if (item.id == id) return Ok(item.event(_monday(_clock())));
    }
    for (final item in _oneOffs) {
      if (item.id == id) return Ok(item.event(_monday(_clock())));
    }
    return const Err(NotFoundFailure(code: 'event_not_found'));
  }

  @override
  Future<Result<String>> save({
    required String? actor,
    required CalendarEvent event,
  }) async {
    final id = event.id ?? 'demo-${_nextId++}';
    final stored = CalendarEvent(
      id: id,
      title: event.title,
      description: event.description,
      kind: event.kind,
      isAllDay: event.isAllDay,
      presenceState: event.presenceState,
      status: event.status,
      importance: event.importance,
      startsAt: event.startsAt,
      endsAt: event.endsAt,
      startDate: event.startDate,
      endDate: event.endDate,
      rrule: event.rrule,
      rdates: event.rdates,
      exdates: event.exdates,
      attendeeIds: event.attendeeIds,
      location: event.location,
    );
    _deleted.remove(id);
    _saved
      ..removeWhere((e) => e.id == id)
      ..add(stored);
    return Ok(id);
  }

  @override
  Future<Result<void>> delete({
    required String? actor,
    required String id,
  }) async {
    _saved.removeWhere((e) => e.id == id);
    _deleted.add(id);
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
    _overrides[_overrideKey(eventId, recurrenceId)] = _DemoOverride(
      cancelled: cancelled,
      patch: patch,
    );
    return Ok('demo-override-${_nextId++}');
  }

  @override
  Future<Result<void>> deleteOverride({
    required String? actor,
    required String eventId,
    required DateTime recurrenceId,
  }) async {
    _overrides.remove(_overrideKey(eventId, recurrenceId));
    return const Ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not part of the demo',
  );

  /// Applies the override of [o], if any: a cancelled occurrence is gone.
  List<Occurrence> _visible(Occurrence o) {
    final recurrenceId = o.recurrenceId;
    final override = recurrenceId == null
        ? null
        : _overrides[_overrideKey(o.eventId, recurrenceId)];
    if (override == null) return [o];
    if (override.cancelled) return const [];
    return [_patched(o, override.patch)];
  }

  /// The occurrences of a saved event between [first] and [last] (local dates). A
  /// single event is one occurrence; a series follows its rule, its rota days and
  /// its start day, which is always included.
  List<Occurrence> _expand(CalendarEvent e, DateTime first, DateTime last) {
    final startDay = e.startDate ?? dateOnly(e.startsAt!.toLocal());
    if (!e.isRecurring) {
      final occurrence = _occurrenceFor(e, startDay, recurring: false);
      if (occurrence.localEndDate.isBefore(first) ||
          occurrence.localStartDate.isAfter(last)) {
        return const [];
      }
      return [occurrence];
    }
    final rdates = {for (final d in e.rdates) dateOnly(d)};
    final rule = e.rrule ?? '';
    return [
      for (var d = first; !d.isAfter(last); d = _addDays(d, 1))
        if (!d.isBefore(startDay) &&
            (d == startDay ||
                rdates.contains(d) ||
                _ruleMatches(rule, startDay, d)))
          _occurrenceFor(e, d, recurring: true),
    ];
  }

  Occurrence _occurrenceFor(
    CalendarEvent e,
    DateTime day, {
    required bool recurring,
  }) {
    final timed = !e.isAllDay;
    final startsAt = e.startsAt?.toLocal();
    final endsAt = e.endsAt?.toLocal();
    final time = timed ? TimeOfDay.fromDateTime(startsAt!) : null;
    final spanDays = timed
        ? 0
        : dateOnly(e.endDate!).difference(dateOnly(e.startDate!)).inDays;
    final start = timed
        ? DateTime(day.year, day.month, day.day, time!.hour, time.minute)
        : day;
    final end = timed
        ? start.add(endsAt!.difference(startsAt!))
        : DateTime(day.year, day.month, day.day + spanDays + 1);
    final lastDay = timed
        ? dateOnly(end)
        : DateTime(day.year, day.month, day.day + spanDays);
    return Occurrence(
      id: recurring ? '${e.id}|${isoDate(day)}' : '${e.id}|single',
      eventId: e.id!,
      recurrenceId: recurring
          ? (timed ? start : DateTime(day.year, day.month, day.day))
          : null,
      calendarId: _demoCalendar,
      title: e.title,
      location: e.location,
      description: e.description,
      kind: e.kind,
      presenceState: e.presenceState,
      status: e.status,
      importance: e.importance ?? Importance.normal,
      allDay: !timed,
      start: timed ? start : day,
      end: end,
      localStartDate: dateOnly(day),
      localEndDate: lastDay,
      localStarts: time,
      localEnds: timed ? TimeOfDay.fromDateTime(endsAt!) : null,
      attendeeIds: e.attendeeIds,
      isRecurring: recurring,
    );
  }

  /// The demo's reading of the rule subset: daily, weekly (with every-2-weeks) and
  /// monthly on the same day of month.
  bool _ruleMatches(String rule, DateTime start, DateTime d) {
    final parts = {
      for (final p in rule.split(';'))
        if (p.contains('=')) p.split('=').first: p.split('=').last,
    };
    switch (parts['FREQ']) {
      case 'DAILY':
        return true;
      case 'WEEKLY':
        final days = (parts['BYDAY'] ?? _codes[start.weekday - 1]).split(',');
        if (!days.contains(_codes[d.weekday - 1])) return false;
        final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
        final weeks = (_utcDays(_monday(d)) - _utcDays(_monday(start))) ~/ 7;
        return weeks % interval == 0;
      case 'MONTHLY':
        return d.day == start.day;
      default:
        return false;
    }
  }

  /// [o] with an override's title, place, status and (timed) times applied.
  Occurrence _patched(Occurrence o, Map<String, dynamic> patch) {
    final start = patch['starts_at'] == null
        ? o.start
        : DateTime.parse(patch['starts_at'] as String).toLocal();
    final end = patch['ends_at'] == null
        ? o.end
        : DateTime.parse(patch['ends_at'] as String).toLocal();
    return Occurrence(
      id: o.id,
      eventId: o.eventId,
      recurrenceId: o.recurrenceId,
      calendarId: o.calendarId,
      title: patch['title'] as String? ?? o.title,
      location: patch.containsKey('location')
          ? patch['location'] as String?
          : o.location,
      description: o.description,
      kind: o.kind,
      presenceState: o.presenceState,
      status: patch['status'] == null
          ? o.status
          : EventStatus.parse(patch['status'] as String),
      importance: o.importance,
      allDay: o.allDay,
      start: start,
      end: end,
      localStartDate: o.allDay ? o.localStartDate : dateOnly(start),
      localEndDate: o.allDay ? o.localEndDate : dateOnly(end),
      localStarts: o.allDay ? null : TimeOfDay.fromDateTime(start),
      localEnds: o.allDay ? null : TimeOfDay.fromDateTime(end),
      attendeeIds: o.attendeeIds,
      isRecurring: o.isRecurring,
      isOverride: true,
    );
  }
}

class _DemoOverride {
  const _DemoOverride({required this.cancelled, required this.patch});

  final bool cancelled;
  final Map<String, dynamic> patch;
}

String _overrideKey(String eventId, DateTime recurrenceId) =>
    '$eventId|${recurrenceId.toUtc().toIso8601String()}';

const _codes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// Whole days since the epoch for a local date, unaffected by summer time.
int _utcDays(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

DateTime _monday(DateTime now) =>
    DateTime(now.year, now.month, now.day - (now.weekday - DateTime.monday));

DateTime _addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

const _demoCalendar = 'demo-calendar';

/// A weekly demo item: the same weekday every week.
class _Weekly {
  const _Weekly({
    required this.id,
    required this.title,
    required this.weekday,
    required this.start,
    required this.end,
    required this.attendees,
    this.presence,
    this.location,
  });

  final String id;
  final String title;
  final int weekday;
  final TimeOfDay start;
  final TimeOfDay end;
  final List<String> attendees;
  final PresenceState? presence;
  final String? location;

  Occurrence occurrence(DateTime day, {required bool recurring}) => Occurrence(
    id: '$id|${isoDate(day)}',
    eventId: id,
    recurrenceId: DateTime(
      day.year,
      day.month,
      day.day,
      start.hour,
      start.minute,
    ),
    calendarId: _demoCalendar,
    title: title,
    location: location,
    kind: presence == null ? EventKind.appointment : EventKind.presence,
    presenceState: presence,
    status: EventStatus.confirmed,
    importance: Importance.normal,
    allDay: false,
    start: DateTime(day.year, day.month, day.day, start.hour, start.minute),
    end: DateTime(day.year, day.month, day.day, end.hour, end.minute),
    localStartDate: day,
    localEndDate: day,
    localStarts: start,
    localEnds: end,
    attendeeIds: attendees,
    isRecurring: recurring,
  );

  CalendarEvent event(DateTime monday) {
    final day = _addDays(monday, weekday - DateTime.monday);
    return CalendarEvent(
      id: id,
      title: title,
      kind: presence == null ? EventKind.appointment : EventKind.presence,
      presenceState: presence,
      isAllDay: false,
      startsAt: DateTime(
        day.year,
        day.month,
        day.day,
        start.hour,
        start.minute,
      ),
      endsAt: DateTime(day.year, day.month, day.day, end.hour, end.minute),
      rrule: 'FREQ=WEEKLY;BYDAY=${_byDay[weekday]}',
      attendeeIds: attendees,
      location: location,
    );
  }

  static const _byDay = {
    1: 'MO',
    2: 'TU',
    3: 'WE',
    4: 'TH',
    5: 'FR',
    6: 'SA',
    7: 'SU',
  };
}

/// A one-off of this week, from Monday offset [firstDay] to [lastDay] (inclusive).
class _OneOff {
  const _OneOff({
    required this.id,
    required this.title,
    required this.firstDay,
    required this.lastDay,
    required this.attendees,
    this.start,
    this.end,
    this.presence,
    this.tentative = false,
  });

  final String id;
  final String title;
  final int firstDay;
  final int lastDay;
  final List<String> attendees;

  /// Null: all day.
  final TimeOfDay? start;
  final TimeOfDay? end;
  final PresenceState? presence;
  final bool tentative;

  Occurrence occurrence(DateTime first, DateTime last) {
    final timed = start != null && end != null;
    return Occurrence(
      id: '$id|${isoDate(first)}',
      eventId: id,
      calendarId: _demoCalendar,
      title: title,
      kind: presence == null ? EventKind.appointment : EventKind.presence,
      presenceState: presence,
      status: tentative ? EventStatus.tentative : EventStatus.confirmed,
      importance: Importance.normal,
      allDay: !timed,
      start: timed
          ? DateTime(
              first.year,
              first.month,
              first.day,
              start!.hour,
              start!.minute,
            )
          : first,
      end: timed
          ? DateTime(last.year, last.month, last.day, end!.hour, end!.minute)
          : DateTime(last.year, last.month, last.day + 1),
      localStartDate: first,
      localEndDate: last,
      localStarts: start,
      localEnds: end,
      attendeeIds: attendees,
    );
  }

  CalendarEvent event(DateTime monday) {
    final first = _addDays(monday, firstDay);
    final last = _addDays(monday, lastDay);
    final timed = start != null && end != null;
    return CalendarEvent(
      id: id,
      title: title,
      kind: presence == null ? EventKind.appointment : EventKind.presence,
      presenceState: presence,
      status: tentative ? EventStatus.tentative : EventStatus.confirmed,
      isAllDay: !timed,
      startsAt: timed
          ? DateTime(
              first.year,
              first.month,
              first.day,
              start!.hour,
              start!.minute,
            )
          : null,
      endsAt: timed
          ? DateTime(last.year, last.month, last.day, end!.hour, end!.minute)
          : null,
      startDate: timed ? null : first,
      endDate: timed ? null : last,
      attendeeIds: attendees,
    );
  }
}

const _allFour = [
  DemoData.papa,
  DemoData.mama,
  DemoData.daughter,
  DemoData.son,
];

// Getters, not finals: the titles follow the language the demo runs in.
List<_Weekly> get _weekly => [
  _Weekly(
    id: 'e-turnen',
    title: demoText('Turnen'),
    weekday: DateTime.monday,
    start: const TimeOfDay(hour: 15, minute: 0),
    end: const TimeOfDay(hour: 16, minute: 0),
    attendees: const [DemoData.son],
    location: demoText('TSV-Halle'),
  ),
  _Weekly(
    id: 'e-klavier',
    title: demoText('Klavier'),
    weekday: DateTime.thursday,
    start: const TimeOfDay(hour: 15, minute: 30),
    end: const TimeOfDay(hour: 16, minute: 0),
    attendees: const [DemoData.daughter],
  ),
  _Weekly(
    id: 'e-dienst-mo',
    title: demoText('Dienst'),
    weekday: DateTime.monday,
    start: const TimeOfDay(hour: 8, minute: 30),
    end: const TimeOfDay(hour: 14, minute: 0),
    attendees: const [DemoData.mama],
    presence: PresenceState.working,
  ),
  _Weekly(
    id: 'e-dienst-mi',
    title: demoText('Dienst'),
    weekday: DateTime.wednesday,
    start: const TimeOfDay(hour: 8, minute: 30),
    end: const TimeOfDay(hour: 14, minute: 0),
    attendees: const [DemoData.mama],
    presence: PresenceState.working,
  ),
];

List<_OneOff> get _oneOffs => [
  _OneOff(
    id: 'e-berlin',
    title: demoText('Dienstreise Berlin'),
    firstDay: 3,
    lastDay: 4,
    attendees: const [DemoData.papa],
    presence: PresenceState.travel,
  ),
  _OneOff(
    id: 'e-fotografin',
    title: demoText('Fotografin in der Schule'),
    firstDay: 3,
    lastDay: 3,
    attendees: const [DemoData.daughter],
  ),
  _OneOff(
    id: 'e-elternabend',
    title: demoText('Elternabend'),
    firstDay: 2,
    lastDay: 2,
    attendees: const [DemoData.mama],
    start: const TimeOfDay(hour: 19, minute: 30),
    end: const TimeOfDay(hour: 21, minute: 0),
  ),
  _OneOff(
    id: 'e-grillen',
    title: demoText('Grillen bei Webers'),
    firstDay: 5,
    lastDay: 5,
    attendees: _allFour,
    start: const TimeOfDay(hour: 16, minute: 0),
    end: const TimeOfDay(hour: 20, minute: 0),
    tentative: true,
  ),
];

/// Starting a family, for the demo: the account already has its household, so H1 never
/// shows; creating or adding people succeeds without writing anything.
class DemoHouseholdOnboardingRepository
    implements HouseholdOnboardingRepository {
  /// false: a signed-in account without a family, the H1 screen (scenario `newfamily`).
  const DemoHouseholdOnboardingRepository({this.hasHousehold = true});

  final bool hasHousehold;

  @override
  Future<Result<Account>> account() async => Ok(
    hasHousehold
        ? const Account(
            userId: 'demo-user',
            email: 'thomas@example.org',
            hasHousehold: true,
            creation: HouseholdCreation.code,
            householdId: 'h1',
            householdName: 'Becker',
            profileId: 'p-thomas',
            givenName: 'Thomas',
            fullName: 'Thomas Becker',
          )
        : const Account(
            userId: 'demo-user',
            email: 'thomas@example.org',
            hasHousehold: false,
            creation: HouseholdCreation.code,
          ),
  );

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
  }) async => const Ok(null);

  @override
  Future<Result<void>> addMembers(List<NewMember> members) async =>
      const Ok(null);

  @override
  Future<Result<void>> completeExamples() async => const Ok(null);
}

/// Deleting the account and resetting a second factor in the demo: each call succeeds and
/// nothing is stored. The demo account is an e-mail account, and its re-sign-in is always fresh.
class DemoAccountAdminRepository implements AccountAdminRepository {
  @override
  bool hasRecentSignIn() => true;

  @override
  Future<Result<void>> deleteAccount() async => const Ok(null);

  @override
  Future<Result<void>> resetMfa({
    required String actorProfileId,
    required String profileId,
  }) async => const Ok(null);

  @override
  Future<Result<List<MemberSecurity>>> memberSecurity(
    String actorProfileId,
  ) async => const Ok([
    MemberSecurity(profileId: DemoData.papa, hasAccount: true, hasMfa: true),
    MemberSecurity(profileId: DemoData.mama, hasAccount: true, hasMfa: true),
  ]);
}

/// Leaving, deleting and restoring a family in the demo: each call succeeds and nothing is
/// stored; the demo session stays signed in.
class DemoHouseholdLeaveRepository implements HouseholdLeaveRepository {
  @override
  Future<Result<void>> leaveFamily({required String profileId}) async =>
      const Ok(null);

  @override
  Future<Result<DateTime>> deleteFamily({
    required String profileId,
    required String confirmName,
  }) async => Ok(DateTime(2026, 10, 29));

  @override
  Future<Result<void>> restoreFamily() async => const Ok(null);

  @override
  Future<Result<void>> startAfresh() async => const Ok(null);
}
