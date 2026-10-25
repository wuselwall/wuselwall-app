import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/data/board_repository.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';

import '../support/fakes.dart';

class _DelayedShopping extends FakeShoppingRepository {
  _DelayedShopping() : super([item('m', 'Initial')]);
  bool delay = false;
  int reads = 0;

  /// While set, `apply` waits for it: a drain that stays in flight.
  Completer<void>? applyGate;
  final pending = <Completer<Result<ShoppingSnapshot>>>[];

  @override
  Future<Result<ApplyResult>> apply({
    required String? actor,
    required List<ShoppingOp> ops,
  }) async {
    await applyGate?.future;
    // The fake reads its own snapshot to project the ops; that is not a fetch.
    _applying = true;
    final result = super.apply(actor: actor, ops: ops);
    _applying = false;
    return result;
  }

  bool _applying = false;

  @override
  Future<Result<ShoppingSnapshot>> snapshot() {
    if (!_applying) reads++;
    if (!delay) return super.snapshot();
    final result = Completer<Result<ShoppingSnapshot>>();
    pending.add(result);
    return result.future;
  }
}

/// Holds the next snapshot write until the test lets it go; later writes pass.
class _GatedStore extends MemoryShoppingStore {
  Completer<void>? holdWrite;

  @override
  Future<void> writeSnapshot(
    String householdId,
    ShoppingSnapshot snapshot,
  ) async {
    final hold = holdWrite;
    holdWrite = null;
    await hold?.future;
    return super.writeSnapshot(householdId, snapshot);
  }
}

/// Every `week()` call waits for the test to answer it, in call order.
class _ScriptedBoard extends FakeBoardRepository {
  final calls = <Completer<Result<WeekBoard>>>[];

  @override
  Future<Result<WeekBoard>> week({DateTime? weekStart}) {
    final call = Completer<Result<WeekBoard>>();
    calls.add(call);
    return call.future;
  }
}

class _CountedBoard extends FakeBoardRepository {
  int reads = 0;

  @override
  Future<Result<WeekBoard>> week({DateTime? weekStart}) {
    reads++;
    return super.week(weekStart: weekStart);
  }
}

class _DelayedBoard extends FakeBoardRepository {
  final first = Completer<Result<WeekBoard>>();
  int reads = 0;

  @override
  Future<Result<WeekBoard>> week({DateTime? weekStart}) {
    reads++;
    return reads == 1
        ? first.future
        : Future.value(const Err(NetworkFailure()));
  }
}

class _Identity extends FakeIdentityRepository {
  int reads = 0;
  @override
  Future<Result<List<Member>>> members({bool includeInactive = false}) {
    reads++;
    return super.members(includeInactive: includeInactive);
  }
}

class _Calendar extends FakeCalendarRepository {
  final windows = <({DateTime from, DateTime to})>[];
  @override
  Future<Result<OccurrenceWindow>> occurrences(
    DateTime from,
    DateTime to, {
    bool holidays = false,
  }) {
    windows.add((from: from, to: to));
    return super.occurrences(from, to, holidays: holidays);
  }
}

class _Tasks implements TasksRepository {
  final days = <DateTime>[];
  @override
  Future<Result<List<TaskInstance>>> instancesOn(DateTime day) async {
    days.add(day);
    return const Ok([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a late board response is discarded after sign-out', () async {
    final repo = _DelayedBoard();
    final c = ProviderContainer(
      overrides: [
        deviceProvider.overrideWithValue(AsyncData(device())),
        boardRepositoryProvider.overrideWithValue(repo),
        householdInvalidationsProvider.overrideWith(
          (ref, id) => const Stream<Invalidation>.empty(),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(boardProvider, (_, _) {});
    await pumpEventQueue();
    expect(repo.reads, 1);
    c.updateOverrides([
      deviceProvider.overrideWithValue(const AsyncData(null)),
      boardRepositoryProvider.overrideWithValue(repo),
      householdInvalidationsProvider.overrideWith(
        (ref, id) => const Stream<Invalidation>.empty(),
      ),
    ]);
    await pumpEventQueue();
    repo.first.complete(Ok(repo.board));
    await pumpEventQueue();
    expect(c.read(boardProvider).board, isNull);
    expect(repo.reads, 1, reason: 'signed-out devices do not fetch a board');
  });

  test('shopping refreshes coalesce and persist the latest snapshot', () async {
    final repo = _DelayedShopping();
    final store = MemoryShoppingStore();
    final c = ProviderContainer(
      overrides: [
        deviceProvider.overrideWithValue(AsyncData(device())),
        shoppingRepositoryProvider.overrideWithValue(repo),
        shoppingStoreProvider.overrideWithValue(store),
        connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
        householdInvalidationsProvider.overrideWith(
          (ref, id) => const Stream<Invalidation>.empty(),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(shoppingSyncProvider, (_, _) {});
    await pumpEventQueue();
    final initial = c.read(shoppingSyncProvider).snapshot!;
    repo.delay = true;
    final sync = c.read(shoppingSyncProvider.notifier);
    final first = sync.refresh();
    final second = sync.refresh();
    final third = sync.refresh();
    expect(repo.pending, hasLength(1));
    repo.pending[0].complete(Ok(initial.withItems([item('m', 'Old')])));
    await pumpEventQueue();
    expect(repo.pending, hasLength(2), reason: 'one follow-up for all changes');
    repo.pending[1].complete(Ok(initial.withItems([item('m', 'New')])));
    await Future.wait([first, second, third]);
    expect(c.read(shoppingSyncProvider).snapshot!.items.single.name, 'New');
    expect((await store.readSnapshot('h1'))!.items.single.name, 'New');
  });

  test('member edits refresh active and retired member caches', () async {
    final repo = _Identity();
    final events = StreamController<Invalidation>.broadcast();
    addTearDown(events.close);
    final c = ProviderContainer(
      overrides: [
        deviceProvider.overrideWithValue(AsyncData(device())),
        identityRepositoryProvider.overrideWithValue(repo),
        householdInvalidationsProvider.overrideWith((ref, id) => events.stream),
      ],
    );
    addTearDown(c.dispose);
    c.listen(membersProvider, (_, _) {});
    c.listen(allMembersProvider, (_, _) {});
    await Future.wait([
      c.read(membersProvider.future),
      c.read(allMembersProvider.future),
    ]);
    events.add(Invalidation('members'));
    await pumpEventQueue();
    expect(repo.reads, 4);
  });

  for (final topic in ['school', 'settings', 'board', '*']) {
    test('month holidays refresh on $topic changes', () async {
      final repo = _Calendar();
      final events = StreamController<Invalidation>.broadcast();
      addTearDown(events.close);
      final c = ProviderContainer(
        overrides: [
          deviceProvider.overrideWithValue(AsyncData(device())),
          calendarRepositoryProvider.overrideWithValue(repo),
          householdInvalidationsProvider.overrideWith(
            (ref, id) => events.stream,
          ),
        ],
      );
      addTearDown(c.dispose);
      final month = monthOccurrencesProvider((
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      ));
      c.listen(month, (_, _) {});
      await c.read(month.future);
      events.add(Invalidation(topic));
      await pumpEventQueue();
      expect(repo.windows, hasLength(2));
    });
  }

  test('Today refresh fetches calendar, tasks and meals again', () async {
    final repo = _Calendar();
    final tasks = _Tasks();
    var meals = 0;
    final c = ProviderContainer(
      overrides: [
        deviceProvider.overrideWithValue(AsyncData(device())),
        calendarRepositoryProvider.overrideWithValue(repo),
        tasksRepositoryProvider.overrideWithValue(tasks),
        householdSettingsProvider.overrideWith((ref) async => []),
        mealEntriesProvider.overrideWith((ref, week) async {
          meals++;
          return [];
        }),
        shoppingRepositoryProvider.overrideWithValue(
          FakeShoppingRepository([]),
        ),
        shoppingStoreProvider.overrideWithValue(MemoryShoppingStore()),
        connectivityProvider.overrideWith((ref) => const Stream<bool>.empty()),
        householdInvalidationsProvider.overrideWith(
          (ref, id) => const Stream<Invalidation>.empty(),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(todayAgendaProvider, (_, _) {});
    await c.read(todayAgendaProvider.future);
    final before = (repo.windows.length, tasks.days.length, meals);
    await refreshToday(c);
    expect(repo.windows.length, greaterThan(before.$1));
    expect(tasks.days.length, greaterThan(before.$2));
    expect(meals, greaterThan(before.$3));
  });

  test('Today and its tasks follow midnight without a server write', () async {
    final clock = StreamController<DateTime>.broadcast();
    addTearDown(clock.close);
    final repo = _Calendar();
    final tasks = _Tasks();
    final c = ProviderContainer(
      overrides: [
        deviceProvider.overrideWithValue(AsyncData(device())),
        clockProvider.overrideWith((ref) => clock.stream),
        calendarRepositoryProvider.overrideWithValue(repo),
        tasksRepositoryProvider.overrideWithValue(tasks),
        householdSettingsProvider.overrideWith((ref) async => []),
        mealEntriesProvider.overrideWith((ref, week) async => []),
        householdInvalidationsProvider.overrideWith(
          (ref, id) => const Stream<Invalidation>.empty(),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(todayAgendaProvider, (_, _) {});
    await pumpEventQueue();
    clock.add(DateTime(2026, 10, 25, 23, 59));
    await pumpEventQueue();
    expect(repo.windows.last.from, DateTime(2026, 10, 25));
    clock.add(DateTime(2026, 10, 26));
    await pumpEventQueue();
    expect(repo.windows.last.from, DateTime(2026, 10, 26));
    expect(tasks.days.last, DateTime(2026, 10, 26));
  });

  group('shopping refresh and drain', () {
    late _DelayedShopping repo;
    late _GatedStore store;
    late StreamController<Invalidation> events;
    late ProviderContainer c;

    Future<void> start() async {
      repo = _DelayedShopping();
      store = _GatedStore();
      events = StreamController<Invalidation>.broadcast();
      addTearDown(events.close);
      c = ProviderContainer(
        overrides: [
          deviceProvider.overrideWithValue(AsyncData(device())),
          shoppingRepositoryProvider.overrideWithValue(repo),
          shoppingStoreProvider.overrideWithValue(store),
          connectivityProvider.overrideWith(
            (ref) => const Stream<bool>.empty(),
          ),
          householdInvalidationsProvider.overrideWith(
            (ref, id) => events.stream,
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(shoppingSyncProvider, (_, _) {});
      await pumpEventQueue();
    }

    List<String> names() => [
      for (final i in c.read(shoppingSyncProvider).snapshot!.items) i.name,
    ];

    test('a drain finishing during the snapshot write is not undone', () async {
      await start();
      final sync = c.read(shoppingSyncProvider.notifier);
      final before = repo.reads;
      final gate = Completer<void>();
      store.holdWrite = gate;
      final held = sync.refresh();
      await pumpEventQueue();
      expect(
        repo.reads,
        before + 1,
        reason: 'the fetch is done, its write held',
      );

      await sync.add(actor: null, listId: 'l1', name: 'Brot');
      await pumpEventQueue();
      expect(c.read(shoppingSyncProvider).outbox, isEmpty);
      expect(names(), ['Initial', 'Brot']);

      gate.complete();
      await held;
      await pumpEventQueue();
      expect(names(), [
        'Initial',
        'Brot',
      ], reason: 'the pre-drain snapshot lost');
      expect(repo.reads, before + 2, reason: 'exactly one follow-up fetch');
      expect((await store.readSnapshot('h1'))!.items, hasLength(2));
    });

    test('a change announced during a drain is fetched after it', () async {
      await start();
      final sync = c.read(shoppingSyncProvider.notifier);
      final before = repo.reads;
      repo.applyGate = Completer<void>();
      await sync.add(actor: null, listId: 'l1', name: 'Brot');
      await pumpEventQueue();
      expect(c.read(shoppingSyncProvider).syncing, isTrue);

      events.add(Invalidation.all());
      await pumpEventQueue();
      expect(repo.reads, before, reason: 'no fetch while the outbox drains');

      repo.applyGate!.complete();
      await pumpEventQueue();
      expect(c.read(shoppingSyncProvider).syncing, isFalse);
      expect(
        repo.reads,
        before + 1,
        reason: 'one fetch once the drain is over',
      );
    });

    test('two invalidations in a row fetch twice', () async {
      await start();
      final before = repo.reads;
      events.add(Invalidation.all());
      await pumpEventQueue();
      events.add(Invalidation.all());
      await pumpEventQueue();
      expect(repo.reads, before + 2);
    });
  });

  group('board', () {
    DeviceInfo inHousehold(String id) => DeviceInfo(
      deviceId: 'd1',
      householdId: id,
      label: 'Test',
      deviceClass: DeviceClass.personal,
      register: UiRegister.adult,
      profileId: guardianId,
      revoked: false,
      guardianVerifiedUntil: null,
    );

    ProviderContainer boardContainer(
      BoardRepository repo, {
      Stream<Invalidation>? events,
      String household = 'h1',
    }) {
      final c = ProviderContainer(
        overrides: [
          deviceProvider.overrideWithValue(AsyncData(inHousehold(household))),
          boardRepositoryProvider.overrideWithValue(repo),
          householdInvalidationsProvider.overrideWith(
            (ref, id) => events ?? const Stream<Invalidation>.empty(),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    void switchTo(ProviderContainer c, BoardRepository repo, String id) =>
        c.updateOverrides([
          deviceProvider.overrideWithValue(AsyncData(inHousehold(id))),
          boardRepositoryProvider.overrideWithValue(repo),
          householdInvalidationsProvider.overrideWith(
            (ref, id) => const Stream<Invalidation>.empty(),
          ),
        ]);

    test('two invalidations in a row fetch the board twice', () async {
      final repo = _CountedBoard();
      final events = StreamController<Invalidation>.broadcast();
      addTearDown(events.close);
      boardContainer(
        repo,
        events: events.stream,
      ).listen(boardProvider, (_, _) {});
      await pumpEventQueue();
      final before = repo.reads;
      events.add(Invalidation.all());
      await pumpEventQueue();
      events.add(Invalidation.all());
      await pumpEventQueue();
      expect(repo.reads, before + 2);
    });

    test('a household switch discards the old household\'s late board, '
        'and the new one\'s failure stands', () async {
      final repo = _ScriptedBoard();
      final c = boardContainer(repo)..listen(boardProvider, (_, _) {});
      await pumpEventQueue();
      expect(repo.calls, hasLength(1));
      switchTo(c, repo, 'h2');
      await pumpEventQueue();
      expect(repo.calls, hasLength(2));
      repo.calls[1].complete(const Err(NetworkFailure()));
      await pumpEventQueue();
      repo.calls[0].complete(Ok(emptyWeekBoard(DateTime(2026, 10, 12))));
      await pumpEventQueue();
      final state = c.read(boardProvider);
      expect(state.board, isNull);
      expect(state.failure, isA<NetworkFailure>());
    });

    test('a household switch shows the new household\'s board, not the '
        'late old one', () async {
      final repo = _ScriptedBoard();
      final c = boardContainer(repo)..listen(boardProvider, (_, _) {});
      await pumpEventQueue();
      switchTo(c, repo, 'h2');
      await pumpEventQueue();
      final newer = emptyWeekBoard(DateTime(2026, 10, 19));
      repo.calls[1].complete(Ok(newer));
      await pumpEventQueue();
      repo.calls[0].complete(Ok(emptyWeekBoard(DateTime(2026, 10, 12))));
      await pumpEventQueue();
      final state = c.read(boardProvider);
      expect(state.board, same(newer));
      expect(state.failure, isNull);
    });

    test('the midnight rebuild keeps the board on the wall', () async {
      final repo = _ScriptedBoard();
      final c = boardContainer(repo)..listen(boardProvider, (_, _) {});
      await pumpEventQueue();
      final shown = emptyWeekBoard(DateTime(2026, 10, 25));
      repo.calls[0].complete(Ok(shown));
      await pumpEventQueue();

      // What the midnight timer does.
      c.invalidate(boardProvider);
      expect(c.read(boardProvider).board, same(shown), reason: 'no blank wall');
      await pumpEventQueue();
      expect(repo.calls, hasLength(2));

      repo.calls[1].complete(const Err(NetworkFailure()));
      await pumpEventQueue();
      final failed = c.read(boardProvider);
      expect(
        failed.board,
        same(shown),
        reason: 'a failed fetch is no error page',
      );
      expect(failed.isStale, isTrue);

      c.invalidate(boardProvider);
      await pumpEventQueue();
      final next = emptyWeekBoard(DateTime(2026, 10, 26));
      repo.calls[2].complete(Ok(next));
      await pumpEventQueue();
      expect(c.read(boardProvider).board, same(next));
      expect(c.read(boardProvider).isStale, isFalse);
    });
  });
}
