import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/board/data/board_repository.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

/// What the wall shows: the last good board, when it was fetched, and the failure of
/// the latest attempt if it failed. A wall display that shows yesterday's slightly
/// stale plan is better than one showing an error (specs/09 "Freshness and failure"),
/// so a failure never replaces a board that is already on screen.
class BoardSnapshot {
  const BoardSnapshot({this.board, this.fetchedAt, this.failure});

  final WeekBoard? board;
  final DateTime? fetchedAt;
  final Failure? failure;

  /// A board is on screen but the latest refresh failed.
  bool get isStale => board != null && failure != null;
}

/// Topics whose invalidation changes something on the board.
const boardTopics = {
  'board',
  'calendar',
  'school',
  'meals',
  'tasks',
  'shopping',
  'members',
  'settings',
};

/// The kiosk week board. Live through Realtime invalidations, with a full refetch every
/// five minutes as belt and braces and one just after midnight, when "today" moves.
class BoardNotifier extends Notifier<BoardSnapshot> {
  static const refetchEvery = Duration(minutes: 5);

  bool _inFlight = false;
  bool _again = false;

  @override
  BoardSnapshot build() {
    final householdId = ref.watch(
      deviceProvider.select((d) => d.value?.householdId),
    );
    if (householdId != null) {
      ref.listen(householdInvalidationsProvider(householdId), (_, next) {
        final topic = next.value?.topic;
        if (topic != null && boardTopics.contains(topic)) unawaited(refresh());
      });
    }

    final periodic = Timer.periodic(refetchEvery, (_) => unawaited(refresh()));
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    final daily = Timer(midnight.difference(now), ref.invalidateSelf);
    ref.onDispose(() {
      periodic.cancel();
      daily.cancel();
    });

    Future.microtask(refresh);
    return const BoardSnapshot();
  }

  /// Fetches the board now. Calls during a fetch coalesce into one more fetch.
  Future<void> refresh() async {
    if (_inFlight) {
      _again = true;
      return;
    }
    _inFlight = true;
    try {
      do {
        _again = false;
        final result = await ref.read(boardRepositoryProvider).week();
        if (!ref.mounted) return;
        state = switch (result) {
          Ok(:final value) => BoardSnapshot(
            board: value,
            fetchedAt: DateTime.now(),
          ),
          Err(:final failure) => BoardSnapshot(
            board: state.board,
            fetchedAt: state.fetchedAt,
            failure: failure,
          ),
        };
      } while (_again);
    } finally {
      _inFlight = false;
    }
  }
}

final boardProvider = NotifierProvider<BoardNotifier, BoardSnapshot>(
  BoardNotifier.new,
);

/// The wall clock, ticking every second: the header clock, the "als Nächstes"
/// countdown and "aktualisiert vor 4 s". Overridden in tests with a fixed time.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

/// [clockProvider]'s current value, or the real time before its first tick.
final nowProvider = Provider<DateTime>(
  (ref) => ref.watch(clockProvider).value ?? DateTime.now(),
);
