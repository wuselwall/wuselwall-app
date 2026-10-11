import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The kiosk's night variant runs from 21:00 to 06:00 local time (docs/09).
bool isNightAt(DateTime time) => time.hour >= 21 || time.hour < 6;

/// The next 06:00 or 21:00 strictly after [time].
DateTime nextNightBoundary(DateTime time) {
  for (var day = 0; day < 2; day++) {
    for (final hour in const [6, 21]) {
      final candidate = DateTime(time.year, time.month, time.day + day, hour);
      if (candidate.isAfter(time)) return candidate;
    }
  }
  throw StateError('unreachable');
}

/// Whether it is night now. Rebuilds itself at the next boundary rather than polling.
class NightNotifier extends Notifier<bool> {
  @override
  bool build() {
    final now = DateTime.now();
    final timer = Timer(
      nextNightBoundary(now).difference(now),
      ref.invalidateSelf,
    );
    ref.onDispose(timer.cancel);
    return isNightAt(now);
  }
}

final nightProvider = NotifierProvider<NightNotifier, bool>(NightNotifier.new);
