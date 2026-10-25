import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  final pending = <Completer<Result<ShoppingSnapshot>>>[];

  @override
  Future<Result<ShoppingSnapshot>> snapshot() {
    if (!delay) return super.snapshot();
    final result = Completer<Result<ShoppingSnapshot>>();
    pending.add(result);
    return result.future;
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
    events.add(const Invalidation('members'));
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
}
