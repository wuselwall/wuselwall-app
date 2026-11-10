import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/cache/read_cache.dart';
import 'package:wuselwall/core/cache/read_cache_store.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/realtime/refresh_events.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/data/board_repository.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/tasks/data/tasks_repository.dart';

import '../support/fake_tasks.dart';

/// The backend as the app meets it over HTTP: answers from [replies] by path, or no
/// network at all while [online] is false. Counts the requests it was asked.
class _Server {
  bool online = true;
  int requests = 0;
  final replies = <String, Object?>{};

  /// A status other than 200 for a path: the server answers, but refuses.
  final refusals = <String, int>{};

  late final client = MockClient((request) async {
    requests++;
    if (!online) throw http.ClientException('no network', request.url);
    final path = request.url.path;
    final headers = {'content-type': 'application/json; charset=utf-8'};
    if (refusals[path] case final status?) {
      return http.Response(
        jsonEncode({'code': '42501', 'message': 'denied'}),
        status,
        headers: headers,
        request: request,
      );
    }
    if (!replies.containsKey(path)) {
      return http.Response('{}', 404, headers: headers, request: request);
    }
    return http.Response(
      jsonEncode(replies[path]),
      200,
      headers: headers,
      request: request,
    );
  });

  late final supabase = SupabaseClient(
    'http://localhost:54321',
    'anon-key',
    httpClient: client,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
}

const _device = '/rest/v1/rpc/current_device';
const _board = '/functions/v1/board-week';
const _instances = '/rest/v1/task_instances';

Map<String, Object?> _deviceJson({
  String household = 'h1',
  bool revoked = false,
}) => {
  'device_id': 'd1',
  'household_id': household,
  'label': 'Küche',
  'class': 'kiosk',
  'register': 'kiosk',
  'profile_id': null,
  'revoked': revoked,
  'guardian_verified_until': null,
};

Map<String, Object?> _boardJson(String monday) => {
  'week_start': monday,
  'today': monday,
  'generated_at': '${monday}T08:00:00Z',
  'members': <Object?>[],
  'presence': <Object?>[],
  'timetables': <Object?>[],
  'days': [
    for (var i = 0; i < 7; i++)
      {
        'date': DateTime.parse(monday)
            .add(Duration(days: i))
            .toIso8601String()
            .substring(0, 10),
        'events': <Object?>[],
        'busy_until': <Object?>[],
        'school': <Object?>[],
      },
  ],
  'open_tasks': <Object?>[],
  'shopping_count': 0,
};

/// One run of the app: its own providers, on a [store] and a [server] that outlive it,
/// as the device's database and the family's server do across a restart.
ProviderContainer _app(
  _Server server,
  ReadCacheStore store, {
  String? user = 'user-1',
  StreamController<Invalidation>? invalidations,
}) {
  final container = ProviderContainer(
    overrides: [
      supabaseClientProvider.overrideWithValue(server.supabase),
      sessionUserIdProvider.overrideWithValue(user),
      readCacheStoreProvider.overrideWithValue(store),
      appRefreshEventsProvider.overrideWith((ref) => const Stream.empty()),
      if (invalidations != null)
        householdInvalidationsProvider.overrideWith(
          (ref, id) => invalidations.stream,
        ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lets the requests of a container run to their end.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
    await pumpEventQueue();
  }
}

void main() {
  for (final (name, make) in <(String, ReadCacheStore Function())>[
    ('memory', MemoryReadCacheStore.new),
    ('drift (SQLite)', () => DriftReadCacheStore(NativeDatabase.memory())),
  ]) {
    group('$name store', () {
      late ReadCacheStore store;
      setUp(() => store = make());
      tearDown(() async {
        if (store case final DriftReadCacheStore d) await d.close();
      });

      final at = DateTime(2026, 11, 10, 17, 5);

      test('gives back the JSON and the time it was fetched', () async {
        expect(await store.read('u1', 'board-week'), isNull);
        await store.write('u1', 'board-week', {
          'days': [1, 2],
          'name': 'Küche',
        }, at);
        final back = await store.read('u1', 'board-week');
        expect(back!.json, {
          'days': [1, 2],
          'name': 'Küche',
        });
        expect(back.fetchedAt, at);

        await store.write('u1', 'board-week', null, at);
        expect((await store.read('u1', 'board-week'))!.json, isNull);
      });

      test('another account finds nothing, and empties the store', () async {
        await store.write('u1', 'board-week', {'a': 1}, at);
        expect(await store.read('u2', 'board-week'), isNull);
        expect(
          await store.read('u1', 'board-week'),
          isNull,
          reason: 'the first account\'s answers are gone, not hidden',
        );
      });

      test('writing for another account drops the first one\'s', () async {
        await store.write('u1', 'members', [1], at);
        await store.write('u2', 'settings', [2], at);
        expect(await store.read('u2', 'members'), isNull);
        expect((await store.read('u2', 'settings'))!.json, [2]);
      });

      test('answers older than two weeks are dropped on a write', () async {
        await store.write(
          'u1',
          'task-instances:2026-10-20',
          <Object?>[],
          at.subtract(const Duration(days: 15)),
        );
        await store.write('u1', 'task-instances:2026-11-09', [1], at);
        await store.write('u1', 'task-instances:2026-11-10', [2], at);
        expect(await store.read('u1', 'task-instances:2026-10-20'), isNull);
        expect(await store.read('u1', 'task-instances:2026-11-09'), isNotNull);
      });

      test('clearScope keeps only what it is told to; clear keeps '
          'nothing', () async {
        await store.write('u1', 'current-device', {'d': 1}, at);
        await store.write('u1', 'members', [1], at);
        await store.clearScope('u1', keep: {'current-device'});
        expect(await store.read('u1', 'members'), isNull);
        expect(await store.read('u1', 'current-device'), isNotNull);
        await store.clear();
        expect(await store.read('u1', 'current-device'), isNull);
      });
    });
  }

  group('ReadCache', () {
    late MemoryReadCacheStore store;
    late List<(String, DateTime)> stale;
    late List<String> fresh;
    String? account;
    var now = DateTime(2026, 11, 10, 17, 5);

    ReadCache cache() => ReadCache(
      store: store,
      scope: () => account,
      onStale: (key, at) => stale.add((key, at)),
      onFresh: fresh.add,
      now: () => now,
    );

    setUp(() {
      store = MemoryReadCacheStore();
      stale = [];
      fresh = [];
      account = 'u1';
      now = DateTime(2026, 11, 10, 17, 5);
    });

    int parse(Object? json) => (json! as Map<String, dynamic>)['n'] as int;
    Future<Object?> offline() async => throw const NetworkFailure();

    test('a good answer is stored and stands in when the network is '
        'gone', () async {
      final first = await cache().through(
        'k',
        fetch: () async => {'n': 1},
        parse: parse,
      );
      expect(first.valueOrNull, 1);
      expect(fresh, ['k']);
      expect(stale, isEmpty);

      // The app restarts: a new cache on the same store.
      now = DateTime(2026, 11, 11, 7);
      final later = await cache().through('k', fetch: offline, parse: parse);
      expect(later.valueOrNull, 1);
      expect(stale, [('k', DateTime(2026, 11, 10, 17, 5))]);
    });

    test('with nothing stored the network failure stands', () async {
      final result = await cache().through('k', fetch: offline, parse: parse);
      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(stale, isEmpty);
    });

    test('what the server refuses is never papered over', () async {
      await cache().through('k', fetch: () async => {'n': 1}, parse: parse);
      final result = await cache().through(
        'k',
        fetch: () async => throw const PermissionFailure(),
        parse: parse,
      );
      expect(result.failureOrNull, isA<PermissionFailure>());
      expect(stale, isEmpty);
    });

    test('a stored answer the app can no longer read counts as none', () async {
      await store.write('u1', 'k', {'n': 'not a number'}, now);
      final result = await cache().through('k', fetch: offline, parse: parse);
      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(await cache().peek('k', parse), isNull);
    });

    test('signed out: nothing is stored and nothing served', () async {
      account = null;
      await cache().through('k', fetch: () async => {'n': 1}, parse: parse);
      expect(fresh, isEmpty);
      account = 'u1';
      expect(await store.read('u1', 'k'), isNull);
    });

    test('another account never gets the first one\'s answer', () async {
      await cache().through('k', fetch: () async => {'n': 1}, parse: parse);
      account = 'u2';
      final result = await cache().through('k', fetch: offline, parse: parse);
      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(await cache().peek('k', parse), isNull);
    });

    test('an answer that arrives after the account changed is not '
        'stored', () async {
      final answer = Completer<Object?>();
      final pending = cache().through(
        'k',
        fetch: () => answer.future,
        parse: parse,
      );
      account = 'u2';
      answer.complete({'n': 1});
      expect((await pending).valueOrNull, 1);
      expect(await store.read('u2', 'k'), isNull);
      expect(fresh, isEmpty);
    });

    test('peek shows the stored answer without asking', () async {
      expect(await cache().peek('k', parse), isNull);
      await cache().through('k', fetch: () async => {'n': 7}, parse: parse);
      final seen = await cache().peek('k', parse);
      expect(seen!.value, 7);
      expect(seen.fetchedAt, now);
      expect(stale, isEmpty, reason: 'looking is not serving');
    });

    test('a silent server gives way to the stored answer after the '
        'patience, and its late answer is still kept', () async {
      await cache().through('k', fetch: () async => {'n': 1}, parse: parse);
      fresh.clear();
      final answer = Completer<Object?>();
      final result = await cache().through(
        'k',
        fetch: () => answer.future,
        parse: parse,
        patience: const Duration(milliseconds: 20),
      );
      expect(result.valueOrNull, 1);
      expect(stale.single.$1, 'k');

      answer.complete({'n': 2});
      await pumpEventQueue();
      expect(fresh, ['k']);
      expect((await cache().peek('k', parse))!.value, 2);
    });

    test('a quick answer does not wait for the patience', () async {
      final result = await cache().through(
        'k',
        fetch: () async => {'n': 3},
        parse: parse,
        patience: const Duration(minutes: 1),
      );
      expect(result.valueOrNull, 3);
    });

    test('with nothing stored a silent server is waited for', () async {
      final answer = Completer<Object?>();
      final pending = cache().through(
        'k',
        fetch: () => answer.future,
        parse: parse,
        patience: const Duration(milliseconds: 10),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      answer.complete({'n': 4});
      expect((await pending).valueOrNull, 4);
    });

    test('another household under the same account starts empty', () async {
      final c = cache();
      await c.through(
        ReadCache.currentDeviceKey,
        fetch: () async => {'n': 1},
        parse: parse,
      );
      await c.bindHousehold('h1');
      await c.through('members', fetch: () async => {'n': 5}, parse: parse);
      await c.bindHousehold('h1');
      expect(await c.peek('members', parse), isNotNull);

      await c.bindHousehold('h2');
      expect(await c.peek('members', parse), isNull);
      expect(
        await c.peek(ReadCache.currentDeviceKey, parse),
        isNotNull,
        reason: 'the answer that named the new household stays',
      );
    });

    test('a store that fails never fails the read', () async {
      final broken = ReadCache(store: _BrokenStore(), scope: () => 'u1');
      final ok = await broken.through(
        'k',
        fetch: () async => {'n': 1},
        parse: parse,
      );
      expect(ok.valueOrNull, 1);
      final gone = await broken.through('k', fetch: offline, parse: parse);
      expect(gone.failureOrNull, isA<NetworkFailure>());
      expect(await broken.peek('k', parse), isNull);
      await broken.clear();
    });
  });

  group('stale reads', () {
    test('the oldest stored answer on screen dates the marker', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(staleSinceProvider), isNull);
      c.read(staleReadsProvider.notifier)
        ..stale('a', DateTime(2026, 11, 10, 17))
        ..stale('b', DateTime(2026, 11, 9, 8));
      expect(c.read(staleSinceProvider), DateTime(2026, 11, 9, 8));
    });

    test('the first good answer clears every mark and asks for one '
        'refetch of everything; the next ones only their own', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final marks = c.read(staleReadsProvider.notifier);
      marks.fresh('a');
      expect(c.read(cacheRecoveryProvider), 0, reason: 'nothing was stale');

      marks
        ..stale('a', DateTime(2026, 11, 10))
        ..stale('gone-screen', DateTime(2026, 11, 9))
        ..fresh('a');
      expect(c.read(staleReadsProvider), isEmpty);
      expect(c.read(cacheRecoveryProvider), 1);

      // One read still fails and is marked again while the others succeed: no loop.
      marks
        ..stale('b', DateTime(2026, 11, 10))
        ..fresh('a')
        ..fresh('c');
      expect(c.read(staleReadsProvider).keys, ['b']);
      expect(c.read(cacheRecoveryProvider), 1);
      marks.fresh('b');
      expect(c.read(staleReadsProvider), isEmpty);
    });
  });

  group('through the API client', () {
    late _Server server;
    late MemoryReadCacheStore store;
    setUp(() {
      server = _Server();
      store = MemoryReadCacheStore();
    });

    ApiClient api() => ApiClient(
      server.supabase,
      cache: ReadCache(store: store, scope: () => 'u1'),
    );

    test('a view, a function and an edge function all survive the '
        'network going', () async {
      server.replies[_instances] = [
        {'id': 't1'},
      ];
      server.replies[_device] = _deviceJson();
      server.replies[_board] = _boardJson('2026-11-09');

      Future<List<Object?>> readAll() async => [
        (await api().select(
          'task_instances',
          cacheKey: 'task-instances:2026-11-10',
          parse: (row) => row['id'] as String,
        )).unwrap(),
        (await api().rpc(
          'current_device',
          cacheKey: ReadCache.currentDeviceKey,
          parse: (json) => (json! as Map<String, dynamic>)['label'],
        )).unwrap(),
        (await api().function(
          'board-week',
          cacheKey: 'board-week',
          parse: (json) => (json! as Map<String, dynamic>)['week_start'],
        )).unwrap(),
      ];

      final live = await readAll();
      expect(live, [
        ['t1'],
        'Küche',
        '2026-11-09',
      ]);
      server.online = false;
      expect(await readAll(), live);
    });

    test('a read without a key is not stored', () async {
      server.replies[_instances] = [
        {'id': 't1'},
      ];
      await api().select('task_instances', parse: (row) => row['id']);
      server.online = false;
      final result = await api().select(
        'task_instances',
        parse: (row) => row['id'],
      );
      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test('another day\'s chores are not shown for today', () async {
      server.replies[_instances] = [
        instanceRow(id: 't1', title: 'Tisch decken', dueOn: '2026-11-09'),
      ];
      final tasks = TasksRepository(api());
      // Only that the read is stored under its day matters here.
      await tasks.instancesOn(DateTime(2026, 11, 9));
      expect(await store.read('u1', 'task-instances:2026-11-09'), isNotNull);
      server.online = false;
      final tomorrow = await tasks.instancesOn(DateTime(2026, 11, 10));
      expect(tomorrow.failureOrNull, isA<NetworkFailure>());
    });
  });

  group('a restart without network', () {
    late _Server server;
    late MemoryReadCacheStore store;
    setUp(() {
      server = _Server()
        ..replies[_device] = _deviceJson()
        ..replies[_board] = _boardJson('2026-11-09');
      store = MemoryReadCacheStore();
    });

    /// Starts the app and waits for the wall's first board.
    Future<ProviderContainer> start({
      String? user = 'user-1',
      StreamController<Invalidation>? invalidations,
    }) async {
      final c = _app(server, store, user: user, invalidations: invalidations)
        ..listen(sessionStateProvider, (_, _) {})
        ..listen(boardProvider, (_, _) {});
      await _settle();
      return c;
    }

    test('the wall shows its stored week, marked with the time it was '
        'fetched', () async {
      final before = DateTime.now();
      final first = await start(
        invalidations: StreamController<Invalidation>(),
      );
      expect(first.read(sessionStateProvider).value, isA<Ready>());
      expect(first.read(boardProvider).board, isNotNull);
      expect(first.read(boardProvider).isStale, isFalse);
      first.dispose();

      server.online = false;
      final second = await start(
        invalidations: StreamController<Invalidation>(),
      );
      final session = second.read(sessionStateProvider).value;
      expect(session, isA<Ready>(), reason: 'the device still knows itself');
      expect((session! as Ready).device.householdId, 'h1');

      final wall = second.read(boardProvider);
      expect(wall.board!.weekStart, DateTime(2026, 11, 9));
      expect(wall.isStale, isTrue);
      expect(wall.fetchedAt!.isBefore(before), isFalse);
      expect(
        wall.fetchedAt!.isAfter(DateTime.now()),
        isFalse,
        reason: 'the time of the stored answer, not of this start',
      );
      expect(second.read(staleSinceProvider), isNotNull);
    });

    test('nothing stored: the failure is shown, not an empty week', () async {
      server.online = false;
      final c = await start(invalidations: StreamController<Invalidation>());
      expect(c.read(sessionStateProvider).hasError, isTrue);
      expect(c.read(boardProvider).board, isNull);
      expect(c.read(staleSinceProvider), isNull);
    });

    test('the stored week is on the wall before the server has '
        'answered', () async {
      (await start(invalidations: StreamController<Invalidation>())).dispose();

      final c = _app(
        server,
        store,
        invalidations: StreamController<Invalidation>(),
      );
      // The device is known; the board request is still under way.
      c.listen(sessionStateProvider, (_, _) {});
      await _settle();
      final requests = server.requests;
      c.listen(boardProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(server.requests, requests, reason: 'not answered yet');
      expect(c.read(boardProvider).board, isNotNull);
      await _settle();
      expect(c.read(boardProvider).isStale, isFalse);
    });

    test('when the server answers again everything is fetched '
        'afresh', () async {
      (await start(invalidations: StreamController<Invalidation>())).dispose();
      server.online = false;
      final c = await start();
      expect(c.read(boardProvider).isStale, isTrue);
      // What the household channel hears: a recovery is an invalidation of everything.
      final heard = <Invalidation>[];
      c.listen(
        householdInvalidationsProvider('h1'),
        (_, next) => heard.add(next.requireValue),
      );
      await _settle();

      server
        ..online = true
        ..replies[_board] = _boardJson('2026-11-16');
      await c.read(boardProvider.notifier).refresh();
      await _settle();

      final wall = c.read(boardProvider);
      expect(wall.isStale, isFalse);
      expect(wall.board!.weekStart, DateTime(2026, 11, 16));
      expect(c.read(staleSinceProvider), isNull);
      expect(c.read(cacheRecoveryProvider), 1);
      expect(heard.where((i) => i.topic == '*'), isNotEmpty);
      expect(
        c.read(sessionStateProvider).value,
        isA<Ready>(),
        reason: 'the device was asked for again, live',
      );
    });

    test('a device removed while it was off loses what it stored', () async {
      (await start(invalidations: StreamController<Invalidation>())).dispose();
      expect(await store.read('user-1', BoardRepository.weekKey), isNotNull);

      server
        ..replies[_device] = _deviceJson(revoked: true)
        ..refusals['/rest/v1/rpc/my_account'] = 403;
      final c = _app(
        server,
        store,
        invalidations: StreamController<Invalidation>(),
      )..listen(sessionStateProvider, (_, _) {});
      await _settle();
      expect(c.read(sessionStateProvider).value, isNot(isA<Ready>()));
      expect(await store.read('user-1', BoardRepository.weekKey), isNull);
      expect(await store.read('user-1', ReadCache.currentDeviceKey), isNull);
    });

    test('a refusal by the server is not answered from the store', () async {
      (await start(invalidations: StreamController<Invalidation>())).dispose();
      server.refusals[_board] = 403;
      final c = await start(invalidations: StreamController<Invalidation>());
      // The stored week stays on the wall, as a last good board does, with the failure.
      expect(c.read(boardProvider).failure, isA<PermissionFailure>());
    });

    test('another account on the device sees nothing of the first', () async {
      (await start(invalidations: StreamController<Invalidation>())).dispose();
      server.online = false;
      final c = await start(
        user: 'user-2',
        invalidations: StreamController<Invalidation>(),
      );
      expect(c.read(sessionStateProvider).hasError, isTrue);
      expect(c.read(boardProvider).board, isNull);
      expect(await store.read('user-2', BoardRepository.weekKey), isNull);
      expect(
        await store.read('user-1', BoardRepository.weekKey),
        isNull,
        reason: 'deleted, not only hidden',
      );
    });

    test('the same account in another household starts empty', () async {
      (await start(invalidations: StreamController<Invalidation>())).dispose();
      server.replies[_device] = _deviceJson(household: 'h2');
      server.refusals[_board] = 403;
      final c = await start(invalidations: StreamController<Invalidation>());
      expect(
        (c.read(sessionStateProvider).value! as Ready).device.householdId,
        'h2',
      );
      expect(await store.read('user-1', BoardRepository.weekKey), isNull);
    });

    test('signing out forgets everything stored', () async {
      final c = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(server.supabase),
          sessionUserIdProvider.overrideWith((ref) => ref.watch(_userProvider)),
          readCacheStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(c.dispose);
      final cache = c.read(readCacheProvider);
      await cache.through('k', fetch: () async => 1, parse: (json) => json);
      expect(await store.read('user-1', 'k'), isNotNull);
      c.read(staleReadsProvider.notifier).stale('k', DateTime(2026, 11, 10));

      c.read(_userProvider.notifier).set(null);
      // The cache follows the account while it is in use.
      c.read(sessionUserIdProvider);
      await _settle();
      expect(await store.read('user-1', 'k'), isNull);
      expect(c.read(staleSinceProvider), isNull);
    });

    test('the device\'s own record is served from the store when the '
        'server stays silent', () async {
      final identity = IdentityRepository(
        ApiClient(
          server.supabase,
          cache: ReadCache(store: store, scope: () => 'user-1'),
        ),
        server.supabase.auth,
      );
      expect((await identity.currentDevice()).valueOrNull!.label, 'Küche');
      server.online = false;
      expect((await identity.currentDevice()).valueOrNull!.label, 'Küche');
    });
  });
}

class _User extends Notifier<String?> {
  @override
  String? build() => 'user-1';

  // ignore: use_setters_to_change_properties
  void set(String? id) => state = id;
}

final _userProvider = NotifierProvider<_User, String?>(_User.new);

class _BrokenStore implements ReadCacheStore {
  @override
  Future<CachedRead?> read(String scope, String key) async =>
      throw StateError('no database');

  @override
  Future<void> write(
    String scope,
    String key,
    Object? json,
    DateTime fetchedAt,
  ) async => throw StateError('no database');

  @override
  Future<void> clearScope(String scope, {Set<String> keep = const {}}) async =>
      throw StateError('no database');

  @override
  Future<void> clear() async => throw StateError('no database');
}
