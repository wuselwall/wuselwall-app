import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/cache/read_cache_store.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// Reads the server through the [ReadCacheStore]: every good answer is kept, and when
/// the server cannot be reached the last one stands in (ADR-006: "extend the read
/// cache", never a sync engine). Only [NetworkFailure] falls back; an answer the server
/// did give — not allowed, not found — is never papered over with an old one.
///
/// The cache must never be the reason a read fails: a store that cannot be opened or an
/// answer that no longer parses (the app was updated) counts as "nothing stored".
class ReadCache {
  ReadCache({
    required this._store,
    required this._scope,
    this._onStale,
    this._onFresh,
    this._now = DateTime.now,
  });

  final ReadCacheStore _store;

  /// Whose answers these are: the signed-in account, or null while there is none (then
  /// nothing is stored and nothing is served).
  final String? Function() _scope;
  final void Function(String key, DateTime fetchedAt)? _onStale;
  final void Function(String key)? _onFresh;
  final DateTime Function() _now;

  /// Runs [fetch] and parses its JSON. A good answer is stored under [key]; a network
  /// failure returns the stored one instead, if there is any.
  ///
  /// With [patience], a fetch that has not answered by then gives way to the stored
  /// answer as well (a server that is switched off does not refuse, it stays silent).
  /// The fetch keeps running and its answer is stored when it comes.
  Future<Result<T>> through<T>(
    String key, {
    required Future<Object?> Function() fetch,
    required T Function(Object? json) parse,
    Duration? patience,
  }) async {
    final scope = _account();
    if (scope == null) return Result.guard(() async => parse(await fetch()));

    final live = Result.guard(() async {
      final json = await fetch();
      final value = parse(json);
      // Not for an account that signed out or changed while the request was under way.
      if (_account() == scope) {
        await _guarded(() => _store.write(scope, key, json, _now()));
        _onFresh?.call(key);
      }
      return value;
    });

    if (patience != null) {
      final waited = Completer<Result<T>?>();
      final timer = Timer(patience, () {
        if (!waited.isCompleted) waited.complete(null);
      });
      unawaited(
        live.then((result) {
          timer.cancel();
          if (!waited.isCompleted) waited.complete(result);
        }),
      );
      final first = await waited.future;
      if (first == null) {
        final stored = await _stored(scope, key, parse);
        if (stored != null) return Ok(stored);
      }
    }

    final result = await live;
    if (result case Err(failure: NetworkFailure())) {
      final stored = await _stored(scope, key, parse);
      if (stored != null) return Ok(stored);
    }
    return result;
  }

  /// The stored answer under [key] without asking the server, for a screen that shows
  /// it while the first fetch is under way.
  Future<({T value, DateTime fetchedAt})?> peek<T>(
    String key,
    T Function(Object? json) parse,
  ) async {
    final scope = _account();
    if (scope == null) return null;
    final entry = await _guarded(() => _store.read(scope, key));
    if (entry == null) return null;
    try {
      return (value: parse(entry.json), fetchedAt: entry.fetchedAt);
    } on Object {
      return null;
    }
  }

  Future<T?> _stored<T>(
    String scope,
    String key,
    T Function(Object? json) parse,
  ) async {
    if (_account() != scope) return null;
    final entry = await _guarded(() => _store.read(scope, key));
    if (entry == null) return null;
    final T value;
    try {
      value = parse(entry.json);
    } on Object {
      return null;
    }
    _onStale?.call(key, entry.fetchedAt);
    return value;
  }

  /// The account now belongs to [householdId]. Answers stored for another family (the
  /// account left one and joined the next) are forgotten.
  Future<void> bindHousehold(String householdId) async {
    final scope = _account();
    if (scope == null) return;
    await _guarded(() async {
      final bound = await _store.read(scope, _householdKey);
      if (bound?.json == householdId) return;
      await _store.clearScope(scope, keep: const {currentDeviceKey});
      await _store.write(scope, _householdKey, householdId, _now());
    });
  }

  /// Forgets everything stored: signed out, removed from the family, or leaving the
  /// server.
  Future<void> clear() => _guarded(_store.clear);

  /// No account while there is no client to ask (before the app is configured).
  String? _account() {
    try {
      return _scope();
    } on Object {
      return null;
    }
  }

  Future<T?> _guarded<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error, stackTrace) {
      logError('Read cache', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  static const _householdKey = '_household';

  /// The key of `api.current_device()`: the one answer [bindHousehold] keeps, because
  /// it is the answer that just named the family.
  static const currentDeviceKey = 'current-device';
}

/// The reads that were answered from the cache and not by the server since: key and the
/// time the stored answer was fetched. Empty while everything on screen is live.
class StaleReads extends Notifier<Map<String, DateTime>> {
  /// A good answer while old ones are on screen means the server is back. Everything is
  /// then fetched again ([cacheRecoveryProvider]), at most this often: a read that keeps
  /// failing while others succeed must not make them all refetch in a loop.
  static const recoverEvery = Duration(seconds: 30);

  DateTime? _recoveredAt;

  @override
  Map<String, DateTime> build() => const {};

  void stale(String key, DateTime fetchedAt) {
    if (state[key] == fetchedAt) return;
    state = {...state, key: fetchedAt};
  }

  void fresh(String key) {
    if (state.isEmpty) return;
    final now = DateTime.now();
    final last = _recoveredAt;
    if (last == null || now.difference(last) >= recoverEvery) {
      _recoveredAt = now;
      // Every mark goes: what still cannot be fetched is marked again by its refetch,
      // and a mark whose screen is gone would otherwise stay for ever.
      state = const {};
      ref.read(cacheRecoveryProvider.notifier).recovered();
    } else if (state.containsKey(key)) {
      state = {...state}..remove(key);
    }
  }

  void reset() {
    if (state.isNotEmpty) state = const {};
  }
}

final staleReadsProvider = NotifierProvider<StaleReads, Map<String, DateTime>>(
  StaleReads.new,
);

/// Counts the times the server answered again after stored answers had been shown.
/// Whoever shows such an answer refetches on a change (the household channel turns it
/// into an invalidation of every topic).
class CacheRecovery extends Notifier<int> {
  @override
  int build() => 0;

  void recovered() => state++;
}

final cacheRecoveryProvider = NotifierProvider<CacheRecovery, int>(
  CacheRecovery.new,
);

/// Since when the oldest stored answer on screen dates, or null while everything is
/// live: the "last updated" marker of the screens that show cached data (FR-8.10).
final staleSinceProvider = Provider<DateTime?>((ref) {
  DateTime? oldest;
  for (final at in ref.watch(staleReadsProvider).values) {
    if (oldest == null || at.isBefore(oldest)) oldest = at;
  }
  return oldest;
});

final readCacheProvider = Provider<ReadCache>((ref) {
  final store = ref.watch(readCacheStoreProvider);
  final cache = ReadCache(
    store: store,
    scope: () => ref.read(sessionUserIdProvider),
    onStale: (key, at) => ref.read(staleReadsProvider.notifier).stale(key, at),
    onFresh: (key) => ref.read(staleReadsProvider.notifier).fresh(key),
  );
  // Signed out, or another account signs in: nothing of the last one stays on the
  // device. A token refresh that fails for lack of network does not sign out.
  ref.listen(sessionUserIdProvider, (previous, next) {
    if (previous == null || previous == next) return;
    ref.read(staleReadsProvider.notifier).reset();
    unawaited(cache.clear());
  });
  return cache;
});
