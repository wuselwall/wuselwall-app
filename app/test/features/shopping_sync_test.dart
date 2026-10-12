import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

import '../support/fakes.dart';

/// A server with a switch: offline, losing the response after applying, rejecting
/// single ops by kind, or refusing a whole batch. It remembers op ids like
/// `app.shopping_op`, so a resent op comes back as a duplicate.
class ScriptedServer implements ShoppingRepository {
  ScriptedServer(this.rows);

  List<ShoppingItem> rows;
  bool online = true;
  bool loseNextResponse = false;
  Failure? refuseNextBatch;
  final rejectKinds = <String, String>{};
  final seen = <String>{};
  final batches = <List<String>>[];

  static const _lists = [
    ShoppingList(id: 'l1', name: 'Supermarkt', isDefault: true, openCount: 0),
  ];

  @override
  Future<Result<ShoppingSnapshot>> snapshot() async => online
      ? Ok(
          ShoppingSnapshot(
            items: rows,
            lists: _lists,
            categories: const [],
            catalog: const [],
          ),
        )
      : const Err(NetworkFailure());

  @override
  Future<Result<ApplyResult>> apply({
    required String? actor,
    required List<ShoppingOp> ops,
  }) async {
    if (!online) return const Err(NetworkFailure());
    if (refuseNextBatch case final failure?) {
      refuseNextBatch = null;
      return Err(failure);
    }
    batches.add([for (final o in ops) o.opId]);
    final results = <OpResult>[];
    final applied = <ShoppingOp>[];
    for (final op in ops) {
      if (!seen.add(op.opId)) {
        results.add(OpResult(opId: op.opId, status: 'duplicate'));
      } else if (rejectKinds[op.kind] case final code?) {
        results.add(OpResult(opId: op.opId, status: 'rejected', code: code));
      } else {
        applied.add(op);
        results.add(OpResult(opId: op.opId, status: 'applied'));
      }
    }
    final view = projectShopping(
      ShoppingSnapshot(
        items: rows,
        lists: _lists,
        categories: const [],
        catalog: const [],
      ),
      applied,
    );
    rows = [for (final i in view.items) i.copyWith(pending: false)];
    if (loseNextResponse) {
      loseNextResponse = false;
      return const Err(NetworkFailure());
    }
    return Ok(ApplyResult(results: results, items: rows));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScriptedServer server;
  late MemoryShoppingStore store;
  late StreamController<bool> network;
  late ProviderContainer container;

  ShoppingSync sync() => container.read(shoppingSyncProvider.notifier);
  ShoppingView view() => container.read(shoppingViewProvider).value!;

  Future<void> start() async {
    container = ProviderContainer(
      overrides: [
        deviceProvider.overrideWithValue(AsyncData(device())),
        shoppingRepositoryProvider.overrideWithValue(server),
        shoppingStoreProvider.overrideWithValue(store),
        connectivityProvider.overrideWith((ref) => network.stream),
        householdInvalidationsProvider.overrideWith(
          (ref, id) => const Stream<Invalidation>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(shoppingSyncProvider, (_, _) {});
    await pumpEventQueue();
  }

  setUp(() {
    server = ScriptedServer([item('m', 'Milch')]);
    store = MemoryShoppingStore();
    network = StreamController<bool>.broadcast();
    addTearDown(network.close);
  });

  test('loads the server state', () async {
    await start();
    expect(view().items.single.name, 'Milch');
    expect(view().pendingCount, 0);
  });

  test('offline, a change shows at once and waits; it is sent when the network '
      'returns', () async {
    await start();
    server.online = false;
    network.add(false);

    final id = await sync().add(actor: null, listId: 'l1', name: 'Brot');
    await sync().check(actor: null, itemId: id, checked: true);
    await pumpEventQueue();

    expect(view().pendingCount, 2);
    final brot = view().items.firstWhere((i) => i.id == id);
    expect((brot.checked, brot.pending), (true, true));
    expect(await store.readOutbox('h1'), hasLength(2));
    expect(server.rows, hasLength(1), reason: 'nothing reached the server');

    server.online = true;
    network.add(true);
    await pumpEventQueue();

    expect(view().pendingCount, 0);
    expect(await store.readOutbox('h1'), isEmpty);
    expect(server.rows.firstWhere((i) => i.id == id).checked, isTrue);
    expect(view().items.firstWhere((i) => i.id == id).pending, isFalse);
    expect(server.batches, hasLength(1), reason: 'both ops went in one batch');
  });

  test(
    'a lost response is resent and recognised: nothing is applied twice',
    () async {
      await start();
      server.loseNextResponse = true;
      await sync().adjustCount(actor: null, itemId: 'm', delta: 1);
      await pumpEventQueue();

      expect(server.rows.single.count, 2, reason: 'the server applied it');
      expect(view().pendingCount, 1, reason: 'the device did not hear so');

      await sync().sync();
      expect(view().pendingCount, 0);
      expect(server.rows.single.count, 2, reason: 'the resend was a duplicate');
      expect(view().items.single.count, 2);
    },
  );

  test('a rejected op leaves the outbox and says why', () async {
    server.rejectKinds['category'] = 'category_not_found';
    await start();
    await sync().setCategory(actor: null, itemId: 'm', categoryId: 'old');
    await sync().check(actor: null, itemId: 'm', checked: true);
    await pumpEventQueue();

    final state = container.read(shoppingSyncProvider);
    expect(state.outbox, isEmpty);
    expect(state.rejection?.failure.code, 'category_not_found');
    expect(server.rows.single.categoryId, isNull);
    expect(
      server.rows.single.checked,
      isTrue,
      reason: 'the rest still applied',
    );
  });

  test(
    'a refused batch drops its first op so the rest can go through',
    () async {
      await start();
      server.online = false;
      await sync().add(actor: 'gone', listId: 'l1', name: 'Saft');
      await sync().add(actor: 'kid', listId: 'l1', name: 'Äpfel');
      await pumpEventQueue();

      server
        ..online = true
        ..refuseNextBatch = const PermissionFailure(code: 'actor_invalid');
      await sync().sync();

      final state = container.read(shoppingSyncProvider);
      expect(state.outbox, isEmpty);
      expect(state.rejection?.failure.code, 'actor_invalid');
      expect(server.rows.map((i) => i.name), ['Milch', 'Äpfel']);
    },
  );

  test('a server without the endpoint yet keeps the outbox', () async {
    await start();
    server.refuseNextBatch = const NotFoundFailure(code: 'PGRST202');
    await sync().check(actor: null, itemId: 'm', checked: true);
    await pumpEventQueue();
    expect(container.read(shoppingSyncProvider).outbox, hasLength(1));
    expect(container.read(shoppingSyncProvider).rejection, isNull);

    await sync().sync();
    expect(container.read(shoppingSyncProvider).outbox, isEmpty);
    expect(server.rows.single.checked, isTrue);
  });

  test('an outbox left from the last run is sent on start', () async {
    await store.append(
      'h1',
      const CheckItemOp(
        opId: 'left-over',
        actor: null,
        itemId: 'm',
        checked: true,
      ),
    );
    await start();
    expect(server.rows.single.checked, isTrue);
    expect(await store.readOutbox('h1'), isEmpty);
  });

  test(
    'without a snapshot and without a network, the failure is shown',
    () async {
      server.online = false;
      await start();
      expect(container.read(shoppingViewProvider).error, isA<NetworkFailure>());
    },
  );

  test('with a mirror and without a network, the mirror is shown', () async {
    await store.writeSnapshot(
      'h1',
      ShoppingSnapshot(
        items: [item('b', 'Butter')],
        lists: ScriptedServer._lists,
        categories: const [],
        catalog: const [],
      ),
    );
    server.online = false;
    await start();
    expect(view().items.single.name, 'Butter');
  });
}
