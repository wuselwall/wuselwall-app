import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:wuselwall/core/connectivity/connectivity_provider.dart';
import 'package:wuselwall/core/error/error_mapper.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

/// The shopping list's offline machinery (specs/07#offline, ADR-006).
///
/// Every change is written to the outbox first and shown at once: the screen renders
/// the last server snapshot with the outbox replayed on top ([projectShopping]). The
/// outbox drains in order to `api.shopping_apply` whenever there is a change, the
/// network returns, the app resumes or another device changes the list; a lost response
/// is harmless because every op carries its idempotency key.
class ShoppingSyncState {
  const ShoppingSyncState({
    this.snapshot,
    this.outbox = const [],
    this.syncing = false,
    this.failure,
    this.rejection,
  });

  /// The server's state as last fetched; null until the first fetch or the mirror.
  final ShoppingSnapshot? snapshot;

  /// Changes not yet confirmed by the server, in the order they were made.
  final List<ShoppingOp> outbox;

  final bool syncing;

  /// Why the last fetch or drain failed, while it keeps failing.
  final Failure? failure;

  /// The last change the server refused, with a counter so the same reason twice is
  /// shown twice.
  final ({int seq, Failure failure})? rejection;

  ShoppingView? get view =>
      snapshot == null ? null : projectShopping(snapshot!, outbox);

  ShoppingSyncState copyWith({
    ShoppingSnapshot? snapshot,
    List<ShoppingOp>? outbox,
    bool? syncing,
    Failure? failure,
    bool clearFailure = false,
    ({int seq, Failure failure})? rejection,
  }) => ShoppingSyncState(
    snapshot: snapshot ?? this.snapshot,
    outbox: outbox ?? this.outbox,
    syncing: syncing ?? this.syncing,
    failure: clearFailure ? null : failure ?? this.failure,
    rejection: rejection ?? this.rejection,
  );
}

const _batchSize = 100;
const _retryDelays = [2, 5, 15, 30, 60];

class ShoppingSync extends Notifier<ShoppingSyncState> {
  final _uuid = const Uuid();
  String? _household;
  bool _draining = false;
  int _drains = 0;
  int _rejections = 0;
  int _retries = 0;
  Timer? _retry;

  ShoppingRepository get _repo => ref.read(shoppingRepositoryProvider);
  ShoppingStore get _store => ref.read(shoppingStoreProvider);

  @override
  ShoppingSyncState build() {
    final household = ref.watch(
      deviceProvider.select((d) => d.value?.householdId),
    );
    _household = household;
    _draining = false;
    _retries = 0;
    if (household == null) return const ShoppingSyncState();

    ref
      ..listen(connectivityProvider, (previous, next) {
        if (next.value == true && previous?.value != true) unawaited(sync());
      })
      ..listen(householdInvalidationsProvider(household), (_, next) {
        if (next.value?.topic == 'shopping') unawaited(refresh());
      });
    final lifecycle = AppLifecycleListener(onResume: () => unawaited(sync()));
    ref.onDispose(() {
      lifecycle.dispose();
      _retry?.cancel();
    });

    unawaited(_load(household));
    return const ShoppingSyncState();
  }

  Future<void> _load(String household) async {
    final snapshot = await _store.readSnapshot(household);
    final outbox = await _store.readOutbox(household);
    if (_household != household) return;
    state = state.copyWith(snapshot: snapshot, outbox: outbox);
    await sync();
  }

  /// Drains the outbox, then fetches the server's state.
  Future<void> sync() async {
    await _drain();
    await refresh();
  }

  /// Fetches the server's state. Skipped while a drain is in flight: its answer is
  /// fresher, and a snapshot taken half-way would show changes twice.
  Future<void> refresh() async {
    final household = _household;
    if (household == null || _draining) return;
    final drains = _drains;
    final result = await _guard(() => _repo.snapshot());
    if (_household != household || _draining || _drains != drains) return;
    switch (result) {
      case Ok(:final value):
        await _store.writeSnapshot(household, value);
        state = state.copyWith(snapshot: value, clearFailure: true);
      case Err(:final failure):
        state = state.copyWith(failure: failure);
    }
  }

  Future<void> _drain() async {
    final household = _household;
    if (household == null || _draining || state.outbox.isEmpty) return;
    _draining = true;
    _drains++;
    _retry?.cancel();
    state = state.copyWith(syncing: true);
    try {
      while (state.outbox.isNotEmpty && _household == household) {
        final batch = state.outbox.take(_batchSize).toList();
        final result = await _guard(
          () => _repo.apply(actor: batch.first.actor, ops: batch),
        );
        if (_household != household) return;
        switch (result) {
          case Ok(:final value):
            _retries = 0;
            await _settle(household, value.results, value.items);
          case Err(:final failure) when _isTransient(failure):
            state = state.copyWith(failure: failure);
            _scheduleRetry();
            return;
          case Err(:final failure):
            // The batch itself was refused (its acting profile is gone, or an op is
            // malformed). Drop the first op so the rest can go through.
            await _store.remove([batch.first.opId]);
            state = state.copyWith(
              outbox: state.outbox.skip(1).toList(),
              rejection: (seq: ++_rejections, failure: failure),
            );
        }
      }
    } finally {
      _draining = false;
      if (_household == household) state = state.copyWith(syncing: false);
    }
  }

  /// Every reported op leaves the outbox — applied, a duplicate, skipped or rejected;
  /// the items the server returned become the mirror's.
  Future<void> _settle(
    String household,
    List<OpResult> results,
    List<ShoppingItem> items,
  ) async {
    final done = {for (final r in results) r.opId};
    await _store.remove(done);
    final snapshot = state.snapshot?.withItems(items);
    if (snapshot != null) await _store.writeSnapshot(household, snapshot);
    final refused = results.where((r) => r.rejected).firstOrNull;
    state = state.copyWith(
      snapshot: snapshot,
      outbox: [
        for (final op in state.outbox)
          if (!done.contains(op.opId)) op,
      ],
      clearFailure: true,
      rejection: refused == null
          ? null
          : (
              seq: ++_rejections,
              failure: ValidationFailure(code: refused.code),
            ),
    );
  }

  /// The repository returns failures as values; this also covers a throw while it is
  /// being created, so the screen shows an error instead of loading forever.
  Future<Result<T>> _guard<T>(Future<Result<T>> Function() call) async {
    try {
      return await call();
    } on Object catch (error, stackTrace) {
      return Err(mapError(error, stackTrace));
    }
  }

  /// Worth retrying with the outbox intact. A missing endpoint (PGRST202) counts: a
  /// server without the migration yet, or a schema cache just behind it, must never
  /// cost the family their changes.
  bool _isTransient(Failure failure) =>
      failure is NetworkFailure ||
      failure is AuthFailure ||
      (failure is NotFoundFailure && failure.code == 'PGRST202') ||
      (failure is UnknownFailure && failure.code == null);

  void _scheduleRetry() {
    final delay = _retryDelays[_retries.clamp(0, _retryDelays.length - 1)];
    _retries++;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: delay), () => unawaited(sync()));
  }

  Future<void> _enqueue(ShoppingOp op) async {
    final household = _household;
    if (household == null) return;
    await _store.append(household, op);
    state = state.copyWith(outbox: [...state.outbox, op]);
    unawaited(_drain());
  }

  /// Adds [name] to [listId]; returns the new item's id, which later changes can use
  /// before the server has seen it.
  Future<String> add({
    required String? actor,
    required String listId,
    required String name,
    String? quantity,
  }) async {
    final id = _uuid.v7();
    await _enqueue(
      AddItemOp(
        opId: _uuid.v7(),
        actor: actor,
        itemId: id,
        listId: listId,
        name: name,
        quantity: quantity,
      ),
    );
    return id;
  }

  Future<void> check({
    required String? actor,
    required String itemId,
    required bool checked,
  }) => _enqueue(
    CheckItemOp(
      opId: _uuid.v7(),
      actor: actor,
      itemId: itemId,
      checked: checked,
    ),
  );

  Future<void> adjustCount({
    required String? actor,
    required String itemId,
    required int delta,
  }) => _enqueue(
    CountItemOp(opId: _uuid.v7(), actor: actor, itemId: itemId, delta: delta),
  );

  Future<void> setSpec({
    required String? actor,
    required String itemId,
    required String? text,
  }) => _enqueue(
    SpecItemOp(opId: _uuid.v7(), actor: actor, itemId: itemId, text: text),
  );

  Future<void> setCategory({
    required String? actor,
    required String itemId,
    required String? categoryId,
  }) => _enqueue(
    CategoriseItemOp(
      opId: _uuid.v7(),
      actor: actor,
      itemId: itemId,
      categoryId: categoryId,
    ),
  );

  Future<void> finish({required String? actor, required String listId}) =>
      _enqueue(
        FinishTripOp(
          opId: _uuid.v7(),
          actor: actor,
          tripId: _uuid.v7(),
          listId: listId,
        ),
      );
}

final shoppingSyncProvider = NotifierProvider<ShoppingSync, ShoppingSyncState>(
  ShoppingSync.new,
);
