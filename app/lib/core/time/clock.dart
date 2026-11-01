import 'package:flutter_riverpod/flutter_riverpod.dart';

final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final nowProvider = Provider<DateTime>(
  (ref) => ref.watch(clockProvider).value ?? DateTime.now(),
);

/// The current minute, for texts like "5 minutes ago" that need no second ticks.
final minuteProvider = Provider<DateTime>(
  (ref) => ref.watch(
    nowProvider.select(
      (now) => DateTime(now.year, now.month, now.day, now.hour, now.minute),
    ),
  ),
);

/// Local midnight, changing only when the device's date changes (also after resume).
final todayProvider = Provider<DateTime>(
  (ref) => ref.watch(
    nowProvider.select((now) => DateTime(now.year, now.month, now.day)),
  ),
);
