import 'package:flutter_riverpod/flutter_riverpod.dart';

final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final nowProvider = Provider<DateTime>(
  (ref) => ref.watch(clockProvider).value ?? DateTime.now(),
);

/// Local midnight, changing only when the device's date changes (also after resume).
final todayProvider = Provider<DateTime>(
  (ref) => ref.watch(
    nowProvider.select((now) => DateTime(now.year, now.month, now.day)),
  ),
);
