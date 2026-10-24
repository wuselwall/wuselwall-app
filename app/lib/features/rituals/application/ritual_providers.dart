import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/rituals/data/rituals_repository.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';
import 'package:wuselwall/features/rituals/domain/table_question.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
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
  // Calendar days, not 24-hour durations: a clock change must not move the edge.
  final window = (
    from: DateTime(today.year, today.month, today.day - 14),
    to: DateTime(today.year, today.month, today.day + days),
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

/// The household's open and recently planned meal wishes; empty on a server without
/// them, so the wish cards stay away rather than showing an error.
final mealWishesProvider = FutureProvider.autoDispose<List<MealWish>>((
  ref,
) async {
  ref.watch(deviceKeyProvider);
  final householdId = ref.watch(deviceProvider).value?.householdId;
  if (householdId != null) {
    refreshOnInvalidation(ref, householdId: householdId, topic: 'meals');
  }
  final result = await ref.watch(ritualsRepositoryProvider).wishes();
  return result.valueOrNull ?? const <MealWish>[];
});

/// The family's own table questions and the bundled ones it hid.
final familyQuestionsProvider =
    FutureProvider.autoDispose<List<FamilyQuestion>>((ref) async {
      ref.watch(deviceKeyProvider);
      final householdId = ref.watch(deviceProvider).value?.householdId;
      if (householdId != null) {
        refreshOnInvalidation(ref, householdId: householdId, topic: 'meals');
      }
      final result = await ref.watch(ritualsRepositoryProvider).questions();
      return result.valueOrNull ?? const <FamilyQuestion>[];
    });

/// The look-back at the week starting on [weekStart] (a Monday); null on a server
/// without it.
final weekReviewProvider = FutureProvider.autoDispose
    .family<WeekReview?, DateTime>((ref, weekStart) async {
      ref.watch(deviceKeyProvider);
      final result = await ref
          .watch(ritualsRepositoryProvider)
          .weekReview(weekStart);
      return result.valueOrNull;
    });

/// A bundled Tischfrage deck by language; empty for a language without one (Q53).
final bundledDeckProvider = FutureProvider.family<List<TableQuestion>, String>((
  ref,
  lang,
) async {
  if (!tableQuestionLanguages.contains(lang)) return const [];
  try {
    return parseDeck(
      await rootBundle.loadString('assets/table_questions/$lang.json'),
    );
  } on Object {
    return const [];
  }
});

/// The household's questions for a device in [lang]: the bundled deck (the household's
/// choice of ages, minus what it hid) and its own questions. Their order comes from
/// [householdQuestion], per household and walk, so nothing here depends on the clock.
final householdDeckProvider = Provider.autoDispose
    .family<List<TableQuestion>, String>((ref, lang) {
      final day = ref.watch(lighterDayProvider);
      return householdDeck(
        bundled:
            ref.watch(bundledDeckProvider(lang)).value ??
            const <TableQuestion>[],
        family:
            ref.watch(familyQuestionsProvider).value ??
            const <FamilyQuestion>[],
        older: day.value('rituals.table_question_deck') == 'older',
      );
    });

/// The Tischfrage of this moment for a device in [lang] (specs/27): null outside the
/// meal windows, when the household switched it off, or in a language without a deck.
/// Every device walks the same household order. Recomputed once a minute, not with
/// every tick of the clock.
final tableMomentProvider = Provider.autoDispose.family<TableMoment?, String>((
  ref,
  lang,
) {
  final day = ref.watch(lighterDayProvider);
  final mode = day.value('rituals.table_question');
  if (mode == 'off' || !tableQuestionLanguages.contains(lang)) return null;
  final now = ref.watch(
    nowProvider.select(
      (n) => DateTime(n.year, n.month, n.day, n.hour, n.minute),
    ),
  );
  final deck = ref.watch(householdDeckProvider(lang));
  return tableMomentAt(
    now: now,
    mode: mode,
    lunch: day.value('rituals.table_question.lunch'),
    dinner: day.value('rituals.table_question.dinner'),
    warmIsDinner: (d) => ref.watch(warmSlotProvider(d)) == PlanSlot.dinner,
    deck: deck,
    householdId: ref.watch(deviceProvider).value?.householdId ?? '',
    cycleLength: tableCycleLength(
      bundled:
          ref.watch(bundledDeckProvider(lang)).value ?? const <TableQuestion>[],
      older: day.value('rituals.table_question_deck') == 'older',
      deckSize: deck.length,
    ),
  );
});

/// How many times this device pressed "Andere Frage" in a meal window. Local on
/// purpose: a shared "next" would be a write per tap (specs/27).
class TableSkipNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => const {};

  void next(int window) => state = {...state, window: (state[window] ?? 0) + 1};
}

final tableSkipProvider = NotifierProvider<TableSkipNotifier, Map<int, int>>(
  TableSkipNotifier.new,
);

/// The meal windows whose table question this device put away on Today (specs/27: "a
/// dismissible card"). Local and in memory: the next meal brings the card back.
class TableDismissNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void dismiss(int window) => state = {...state, window};
}

final tableDismissProvider = NotifierProvider<TableDismissNotifier, Set<int>>(
  TableDismissNotifier.new,
);

/// The Monday of the week the look-back is about, while its window is open; null
/// otherwise (specs/27 "Wochenrückblick"). `rituals.week_review` sets when it opens
/// (default Sunday 16:00); it stays until 10:00 the next morning. Never rotates onto
/// the wall by itself.
final weekReviewDueProvider = Provider.autoDispose<DateTime?>((ref) {
  final value = ref.watch(lighterDayProvider).value('rituals.week_review');
  if (value == null) {
    // Switched off (JSON null) or not yet loaded: the default only once loaded.
    final loaded = ref.watch(householdSettingsProvider).hasValue;
    if (loaded) return null;
  }
  final setting = value is Map
      ? value
      : const <String, Object?>{'weekday': 7, 'time': '16:00'};
  // A malformed value falls back to the default rather than breaking Today.
  final day = setting['weekday'];
  final weekday = day is num && day >= 1 && day <= 7 ? day.toInt() : 7;
  final time = minutesOfDay(setting['time']) ?? 16 * 60;
  final now = ref.watch(nowProvider);
  return weekReviewWeek(
    now,
    weekday: weekday,
    hour: time ~/ 60,
    minute: time % 60,
  );
});

/// The reviewed week's Monday when [now] falls between the opening on [weekday] at
/// [hour]:[minute] and 10:00 the next morning; else null. Opening at the weekend looks
/// back at that week; opening on a weekday looks back at the week before, so a look-back
/// on a Monday morning is not about the week that has only just begun.
DateTime? weekReviewWeek(
  DateTime now, {
  required int weekday,
  required int hour,
  required int minute,
}) {
  for (final back in const [0, 1]) {
    final day = DateTime(now.year, now.month, now.day - back);
    if (day.weekday != weekday) continue;
    final opens = DateTime(day.year, day.month, day.day, hour, minute);
    final closes = DateTime(day.year, day.month, day.day + 1, 10);
    if (!now.isBefore(opens) && now.isBefore(closes)) {
      final monday = DateTime(day.year, day.month, day.day - (day.weekday - 1));
      return day.weekday >= DateTime.saturday
          ? monday
          : DateTime(monday.year, monday.month, monday.day - 7);
    }
  }
  return null;
}
