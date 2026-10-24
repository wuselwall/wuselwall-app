import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';

/// The title of today's family tradition ("Pizza-Freitag"), or null when today has
/// none (specs/27 "Familientraditionen"). Read from the occurrences already loaded for
/// Vorfreude (the same window, so no second request); a cancelled occurrence is no
/// tradition today. With several, the first in the calendar's order.
final todayTraditionProvider = Provider.autoDispose<String?>((ref) {
  final today = ref.watch(ritualTodayProvider);
  final window = countdownWindow(today, ref.watch(countdownHorizonProvider));
  final occurrences =
      ref.watch(occurrencesProvider(window)).value?.occurrences ??
      const <Occurrence>[];
  for (final o in occurrences) {
    if (!o.tradition || o.status == EventStatus.cancelled) continue;
    if (o.localStartDate.isAfter(today) || o.localEndDate.isBefore(today)) {
      continue;
    }
    return o.title;
  }
  return null;
});
