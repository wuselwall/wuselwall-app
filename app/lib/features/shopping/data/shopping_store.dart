import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

/// The shopping list's local state (specs/07#offline): the last server snapshot, a
/// cache that can always be fetched again, and the outbox, the one thing on the device
/// that is not reconstructible. Both belong to one household; switching households
/// empties the store.
abstract interface class ShoppingStore {
  Future<ShoppingSnapshot?> readSnapshot(String householdId);
  Future<void> writeSnapshot(String householdId, ShoppingSnapshot snapshot);
  Future<List<ShoppingOp>> readOutbox(String householdId);
  Future<void> append(String householdId, ShoppingOp op);
  Future<void> remove(Iterable<String> opIds);
}

/// Holds nothing across restarts: the web build (always online, on the laptop), the
/// demo build and tests.
class MemoryShoppingStore implements ShoppingStore {
  String? _household;
  ShoppingSnapshot? _snapshot;
  final _outbox = <ShoppingOp>[];

  void _scope(String householdId) {
    if (_household == householdId) return;
    _household = householdId;
    _snapshot = null;
    _outbox.clear();
  }

  @override
  Future<ShoppingSnapshot?> readSnapshot(String householdId) async {
    _scope(householdId);
    return _snapshot;
  }

  @override
  Future<void> writeSnapshot(
    String householdId,
    ShoppingSnapshot snapshot,
  ) async {
    _scope(householdId);
    _snapshot = snapshot;
  }

  @override
  Future<List<ShoppingOp>> readOutbox(String householdId) async {
    _scope(householdId);
    return List.of(_outbox);
  }

  @override
  Future<void> append(String householdId, ShoppingOp op) async {
    _scope(householdId);
    _outbox.add(op);
  }

  @override
  Future<void> remove(Iterable<String> opIds) async {
    final gone = opIds.toSet();
    _outbox.removeWhere((op) => gone.contains(op.opId));
  }
}

/// SQLite through drift, on the phones and tablets. Two tables and plain SQL; the
/// payloads are the JSON the server speaks, so there is no second schema to keep in step.
class DriftShoppingStore implements ShoppingStore {
  DriftShoppingStore(QueryExecutor executor)
    : _db = _ShoppingDatabase(executor);

  final _ShoppingDatabase _db;

  Future<void> close() => _db.close();

  /// Drops everything that belongs to another household.
  Future<void> _scope(String householdId) async {
    await _db.customStatement('delete from snapshot where household_id <> ?', [
      householdId,
    ]);
    await _db.customStatement('delete from outbox where household_id <> ?', [
      householdId,
    ]);
  }

  @override
  Future<ShoppingSnapshot?> readSnapshot(String householdId) async {
    await _scope(householdId);
    final row = await _db
        .customSelect('select json from snapshot where id = 1')
        .getSingleOrNull();
    if (row == null) return null;
    return ShoppingSnapshot.fromJson(
      jsonDecode(row.read<String>('json')) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> writeSnapshot(
    String householdId,
    ShoppingSnapshot snapshot,
  ) => _db.customStatement(
    'insert or replace into snapshot (id, household_id, json) values (1, ?, ?)',
    [householdId, jsonEncode(snapshot.toJson())],
  );

  @override
  Future<List<ShoppingOp>> readOutbox(String householdId) async {
    await _scope(householdId);
    final rows = await _db
        .customSelect('select json from outbox order by seq')
        .get();
    return [
      for (final r in rows)
        ShoppingOp.fromJson(
          jsonDecode(r.read<String>('json')) as Map<String, dynamic>,
        ),
    ];
  }

  @override
  Future<void> append(String householdId, ShoppingOp op) => _db.customStatement(
    'insert or ignore into outbox (op_id, household_id, json) values (?, ?, ?)',
    [op.opId, householdId, jsonEncode(op.toJson())],
  );

  @override
  Future<void> remove(Iterable<String> opIds) => _db.transaction(() async {
    for (final id in opIds) {
      await _db.customStatement('delete from outbox where op_id = ?', [id]);
    }
  });
}

class _ShoppingDatabase extends GeneratedDatabase {
  _ShoppingDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'create table snapshot (id integer primary key check (id = 1), '
        'household_id text not null, json text not null)',
      );
      await customStatement(
        'create table outbox (seq integer primary key autoincrement, '
        'op_id text not null unique, household_id text not null, json text not null)',
      );
    },
  );
}

/// SQLite on the phones and tablets; memory in the browser, where the laptop is online
/// and a reload is cheap (specs/07#offline).
final shoppingStoreProvider = Provider<ShoppingStore>((ref) {
  if (kIsWeb) return MemoryShoppingStore();
  final store = DriftShoppingStore(driftDatabase(name: 'wuselwall_shopping'));
  ref.onDispose(store.close);
  return store;
});
