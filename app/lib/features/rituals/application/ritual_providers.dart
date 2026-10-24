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

/// The meal the table question belongs to right now.
typedef TableMoment = ({
  int window,
  bool dinner,
  List<TableQuestion> questions,
});

/// Minutes after midnight of a `HH:mm` setting value.
int? _minutes(Object? hhmm) {
  if (hhmm is! String) return null;
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

bool _inRange(Object? range, int now, String from, String to) {
  final r = range is Map ? range : const <String, Object?>{};
  final a = _minutes(r['from']) ?? _minutes(from)!;
  final b = _minutes(r['to']) ?? _minutes(to)!;
  return now >= a && now < b;
}

/// The Tischfrage of this moment for a device in [lang] (specs/27): null outside the
/// meal windows, when the household switched it off, or in a language without a deck.
/// Every device walks the same household shuffle; the family's own questions are in
/// it and the ones it hid are not.
final tableMomentProvider = Provider.autoDispose.family<TableMoment?, String>((
  ref,
  lang,
) {
  final day = ref.watch(lighterDayProvider);
  final mode = day.value('rituals.table_question') ?? 'warm_meal';
  if (mode == 'off' || !tableQuestionLanguages.contains(lang)) return null;
  final now = ref.watch(nowProvider);
  final minutes = now.hour * 60 + now.minute;
  final lunch = _inRange(
    day.value('rituals.table_question.lunch'),
    minutes,
    '11:30',
    '13:30',
  );
  final dinner = _inRange(
    day.value('rituals.table_question.dinner'),
    minutes,
    '17:30',
    '19:30',
  );
  if (!lunch && !dinner) return null;
  if (mode == 'warm_meal') {
    final warm = ref.watch(warmSlotProvider(DateUtils.dateOnly(now)));
    if ((warm == PlanSlot.dinner) != dinner) return null;
  }
  final householdId = ref.watch(deviceProvider).value?.householdId ?? '';
  final older = day.value('rituals.table_question_deck') == 'older';
  final family = ref.watch(familyQuestionsProvider).value ?? const [];
  final hidden = {
    for (final q in family)
      if (q.hiddenKey != null) q.hiddenKey!,
  };
  final deck = <TableQuestion>[
    for (final q
        in ref.watch(bundledDeckProvider(lang)).value ??
            const <TableQuestion>[])
      if ((older || q.deck == 'family') && !hidden.contains(q.key)) q,
    for (final q in family)
      if (q.text != null)
        TableQuestion(key: q.id, text: q.text!, authorId: q.createdBy),
  ];
  if (deck.isEmpty) return null;
  return (
    window: mealWindowIndex(now, dinner: dinner),
    dinner: dinner,
    questions: householdShuffle(deck, householdId),
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
