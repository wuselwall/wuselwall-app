import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One stored answer of the server: the JSON as it came, and when.
class CachedRead {
  const CachedRead(this.json, this.fetchedAt);

  final Object? json;
  final DateTime fetchedAt;
}

/// The last answers of the reads a restart without network still has to show (specs/09
/// "Freshness and failure"): the device's own record, the wall's week and a child's day.
/// Everything here can be fetched again; nothing is ever written back from it.
///
/// The store holds one [scope] (one signed-in account on one server) at a time: asking
/// with another scope first deletes what the previous one left, so a device that changes
/// hands never shows the other family's data.
abstract interface class ReadCacheStore {
  Future<CachedRead?> read(String scope, String key);

  Future<void> write(
    String scope,
    String key,
    Object? json,
    DateTime fetchedAt,
  );

  /// Forgets every answer of [scope] except [keep].
  Future<void> clearScope(String scope, {Set<String> keep = const {}});

  /// Forgets everything: the device is signed out or leaves its server.
  Future<void> clear();
}

/// How long an answer is worth keeping. Dated reads (a day's chores) leave one row per
/// day behind; nothing older than this is shown anyway.
const readCacheMaxAge = Duration(days: 14);

/// Holds nothing across restarts: the web build (always online, on the laptop), the
/// demo build and tests.
class MemoryReadCacheStore implements ReadCacheStore {
  String? _scope;
  final _entries = <String, CachedRead>{};

  void _use(String scope) {
    if (_scope == scope) return;
    _scope = scope;
    _entries.clear();
  }

  @override
  Future<CachedRead?> read(String scope, String key) async {
    _use(scope);
    return _entries[key];
  }

  @override
  Future<void> write(
    String scope,
    String key,
    Object? json,
    DateTime fetchedAt,
  ) async {
    _use(scope);
    // Through the encoder, as the SQLite store does: the same things are storable.
    _entries[key] = CachedRead(jsonDecode(jsonEncode(json)), fetchedAt);
    final oldest = fetchedAt.subtract(readCacheMaxAge);
    _entries.removeWhere((_, e) => e.fetchedAt.isBefore(oldest));
  }

  @override
  Future<void> clearScope(String scope, {Set<String> keep = const {}}) async {
    _use(scope);
    _entries.removeWhere((key, _) => !keep.contains(key));
  }

  @override
  Future<void> clear() async {
    _scope = null;
    _entries.clear();
  }
}

/// SQLite through drift, on the phones and tablets: one table and plain SQL, like the
/// shopping store. The payloads are the JSON the server speaks, so there is no second
/// schema to keep in step.
class DriftReadCacheStore implements ReadCacheStore {
  DriftReadCacheStore(QueryExecutor executor)
    : _db = _ReadCacheDatabase(executor);

  final _ReadCacheDatabase _db;

  Future<void> close() => _db.close();

  Future<void> _use(String scope) =>
      _db.customStatement('delete from entry where scope <> ?', [scope]);

  @override
  Future<CachedRead?> read(String scope, String key) async {
    await _use(scope);
    final row = await _db
        .customSelect(
          'select json, fetched_at from entry where key = ?',
          variables: [Variable<String>(key)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return CachedRead(
      jsonDecode(row.read<String>('json')),
      DateTime.fromMillisecondsSinceEpoch(row.read<int>('fetched_at')),
    );
  }

  @override
  Future<void> write(
    String scope,
    String key,
    Object? json,
    DateTime fetchedAt,
  ) async {
    final encoded = jsonEncode(json);
    await _db.transaction(() async {
      await _db.customStatement(
        'delete from entry where scope <> ? or fetched_at < ?',
        [scope, fetchedAt.subtract(readCacheMaxAge).millisecondsSinceEpoch],
      );
      await _db.customStatement(
        'insert or replace into entry (key, scope, json, fetched_at) '
        'values (?, ?, ?, ?)',
        [key, scope, encoded, fetchedAt.millisecondsSinceEpoch],
      );
    });
  }

  @override
  Future<void> clearScope(String scope, {Set<String> keep = const {}}) async {
    await _use(scope);
    final rows = await _db.customSelect('select key from entry').get();
    await _db.transaction(() async {
      for (final row in rows) {
        final key = row.read<String>('key');
        if (keep.contains(key)) continue;
        await _db.customStatement('delete from entry where key = ?', [key]);
      }
    });
  }

  @override
  Future<void> clear() => _db.customStatement('delete from entry');
}

class _ReadCacheDatabase extends GeneratedDatabase {
  _ReadCacheDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'create table entry (key text primary key, scope text not null, '
        'json text not null, fetched_at integer not null)',
      );
    },
  );
}

/// No plugin to open a database file with: `flutter test`.
final bool _underTest =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// SQLite on the phones and tablets; memory in the browser, where the laptop is online
/// and a reload is cheap (ADR-006).
final readCacheStoreProvider = Provider<ReadCacheStore>((ref) {
  if (kIsWeb || _underTest) return MemoryReadCacheStore();
  final store = DriftReadCacheStore(driftDatabase(name: 'wuselwall_reads'));
  ref.onDispose(store.close);
  return store;
});
