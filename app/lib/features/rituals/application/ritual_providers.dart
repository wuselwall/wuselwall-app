import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// Today's date, changing once a day rather than with every tick of the clock.
final ritualTodayProvider = Provider<DateTime>(
  (ref) => ref.watch(nowProvider.select(DateUtils.dateOnly)),
);

/// How far ahead Vorfreude looks (`rituals.countdown_days`, specs/27).
final countdownHorizonProvider = Provider.autoDispose<int>((ref) {
  final v = ref.watch(lighterDayProvider).value('rituals.countdown_days');
  return v is num ? v.toInt() : 14;
});

/// The occurrences of the next [countdownHorizonProvider] days: the source of the
/// marked events and the homecomings.
final _horizonOccurrencesProvider = Provider.autoDispose<List<Occurrence>>((
  ref,
) {
  final today = ref.watch(ritualTodayProvider);
  final days = ref.watch(countdownHorizonProvider);
  // Travel that began before today still counts down to the way home.
  final window = (
    from: today.subtract(const Duration(days: 14)),
    to: today.add(Duration(days: days)),
  );
  return ref.watch(occurrencesProvider(window)).value?.occurrences ??
      const <Occurrence>[];
});

/// Everything the family looks forward to, nearest first (specs/27 "Vorfreude"). While
/// the sources load it is what has loaded so far, never an error on the wall.
final countdownsProvider = Provider.autoDispose<List<Countdown>>((ref) {
  final day = ref.watch(lighterDayProvider);
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final holidays =
      ref.watch(schoolDataProvider).value?.holidays ?? const <HolidayRecord>[];
  return countdowns(
    today: ref.watch(ritualTodayProvider),
    horizonDays: ref.watch(countdownHorizonProvider),
    members: members,
    occurrences: ref.watch(_horizonOccurrencesProvider),
    holidays: holidays,
    homecomings: day.value('rituals.countdown_return') != false,
    ferien: day.value('ambience.ferien') != false,
  );
});

/// The active members whose birthday is today, in board order.
final birthdaysTodayMembersProvider = Provider.autoDispose<List<Member>>((ref) {
  final today = ref.watch(ritualTodayProvider);
  final members = [
    for (final m in ref.watch(membersProvider).value ?? const <Member>[])
      if (m.active &&
          m.birthday != null &&
          nextBirthday(m.birthday!, today) == today)
        m,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return members;
});

/// Today's first or last day of the school holidays, for the sky's ribbon.
final ferienEdgeTodayProvider = Provider.autoDispose<FerienEdge?>((ref) {
  final today = ref.watch(ritualTodayProvider);
  for (final h
      in ref.watch(schoolDataProvider).value?.holidays ??
          const <HolidayRecord>[]) {
    if (h.kind != 'holiday') continue;
    if (DateUtils.isSameDay(h.startsOn, today)) return FerienEdge.first;
    if (DateUtils.isSameDay(h.endsOn, today)) return FerienEdge.last;
  }
  return null;
});
