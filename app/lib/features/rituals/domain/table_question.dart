import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';

/// One question for the table (specs/27 "Tischfrage"): bundled with the app, or the
/// family's own. Nothing about its answers is ever stored.
@immutable
class TableQuestion {
  const TableQuestion({
    required this.key,
    required this.text,
    this.category = 'own',
    this.deck = 'family',
    this.answer,
    this.authorId,
  });

  /// `de:q-0042` for a bundled question, the row id for the family's own.
  final String key;
  final String text;

  /// silly, today, imagine, memories, us, riddle, thanks; `own` for the family's.
  final String category;

  /// `family` (fine for a five-year-old) or `older` (8 and over).
  final String deck;

  /// A riddle's answer, shown behind a tap.
  final String? answer;

  /// Who asked: the family's own questions show "Frage von Jack".
  final String? authorId;

  bool get isOwn => category == 'own';
}

/// The languages with a written deck (Q53: German and English carry about 150 questions,
/// French and Spanish 50). On a device in any other language the Tischfrage stays away.
const tableQuestionLanguages = {'de', 'en', 'fr', 'es'};

/// Reads a bundled deck (`assets/table_questions/<lang>.json`).
List<TableQuestion> parseDeck(String json) {
  final doc = jsonDecode(json) as Map<String, dynamic>;
  final lang = doc['language'] as String;
  return [
    for (final q in (doc['questions'] as List).cast<Map<String, dynamic>>())
      TableQuestion(
        key: '$lang:${q['id']}',
        text: q['text'] as String,
        category: q['category'] as String,
        deck: q['deck'] as String,
        answer: q['answer'] as String?,
      ),
  ];
}

const _two32 = 0x100000000;

/// [a] times [b] modulo 2^32, for 32-bit [a] and [b], without a product past 2^53: the
/// web's numbers compute it exactly too.
int _mul32(int a, int b) =>
    ((a * (b >> 16)) % _two32 * 65536 + a * (b & 0xffff)) % _two32;

/// FNV-1a (32 bit) over the UTF-8 bytes of [text]: the same number on every platform,
/// the web included, and in every run (unlike `String.hashCode`, which Dart does not
/// promise to keep, or `Random(seed)`, whose sequence it does not promise either).
int fnv1a32(String text) {
  var h = 0x811c9dc5;
  for (final byte in utf8.encode(text)) {
    h = _mul32(h ^ byte, 16777619);
  }
  return h;
}

/// A question's rank: [fnv1a32] with MurmurHash3's finaliser, so keys that differ only
/// in their last characters (`q-0041`, `q-0042`) still land far apart.
int questionRank(String text) {
  var h = fnv1a32(text);
  h ^= h >> 16;
  h = _mul32(h, 0x85ebca6b);
  h ^= h >> 13;
  h = _mul32(h, 0xc2b2ae35);
  h ^= h >> 16;
  return h;
}

/// The household's order of its questions for one walk ([cycle]): every question ranked
/// by its own hash of household, question and walk. So every device ranks alike, hiding
/// a question leaves the others in their order, and a new question slots in without
/// reshuffling the rest (specs/27).
List<TableQuestion> householdShuffle(
  List<TableQuestion> questions,
  String householdId, {
  int cycle = 0,
}) {
  final ranked =
      [
        for (final q in questions)
          (questionRank('$householdId|$cycle|${q.key}'), q),
      ]..sort((a, b) {
        final byRank = a.$1.compareTo(b.$1);
        return byRank != 0 ? byRank : a.$2.key.compareTo(b.$2.key);
      });
  return [for (final (_, q) in ranked) q];
}

/// The question at position [window] of an already ranked list, [skip] further on.
TableQuestion? questionFor(
  List<TableQuestion> shuffled,
  int window, {
  int skip = 0,
}) => shuffled.isEmpty ? null : shuffled[(window + skip) % shuffled.length];

/// The household's question for the meal window [window] (a running count, see
/// [mealWindowIndex]), [skip] questions further on for this device's "Andere Frage".
///
/// The windows are cut into walks of [cycleLength] windows: the size of the bundled deck
/// for the household's ages, which neither hiding a question nor adding one changes, so
/// the walk keeps its place. Each walk ranks the [deck] afresh and steps through it, one
/// question a window, so none repeats before the deck is through. Hiding the question
/// of the moment brings the next one forward, the rest keep their order, and a
/// family's own questions add to the walk's length. Without a bundled deck the walk is
/// as long as the deck.
TableQuestion? householdQuestion(
  List<TableQuestion> deck,
  String householdId,
  int window, {
  int? cycleLength,
  int skip = 0,
}) {
  if (deck.isEmpty) return null;
  final length = cycleLength == null || cycleLength < 1
      ? deck.length
      : cycleLength;
  final w = window + skip;
  final ranked = householdShuffle(deck, householdId, cycle: w ~/ length);
  return questionFor(ranked, w % length);
}

/// The running number of a meal window, counted from 1 January 2024: one a day when the
/// Tischfrage belongs to the warm meal only, two (lunch and dinner) otherwise. Stepping by
/// one through the shuffle is what lets every question come round before any repeats.
int mealWindowIndex(DateTime day, {required bool dinner, bool twoADay = true}) {
  final days = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(2024)).inDays;
  return twoADay ? days * 2 + (dinner ? 1 : 0) : days;
}

/// The household's deck for one language: the bundled questions of the household's
/// ages (`older` adds the 8+ ones), minus the ones it hid, and its own questions.
List<TableQuestion> householdDeck({
  required List<TableQuestion> bundled,
  required List<FamilyQuestion> family,
  required bool older,
}) {
  final hidden = {
    for (final q in family)
      if (q.hiddenKey != null) q.hiddenKey!,
  };
  return [
    for (final q in bundled)
      if ((older || q.deck == 'family') && !hidden.contains(q.key)) q,
    for (final q in family)
      if (q.text != null)
        TableQuestion(key: q.id, text: q.text!, authorId: q.createdBy),
  ];
}

/// The length of the household's walk ([householdQuestion]): the bundled questions for
/// its ages, hidden ones included, so hiding one or adding one of its own keeps the walk
/// in place; the deck's own size when nothing is bundled.
int tableCycleLength({
  required List<TableQuestion> bundled,
  required bool older,
  required int deckSize,
}) {
  final n = older
      ? bundled.length
      : bundled.where((q) => q.deck == 'family').length;
  return n > 0 ? n : deckSize;
}

/// The meal the table question belongs to right now: its window, the household's
/// questions and the length of the household's walk through them ([householdQuestion]).
typedef TableMoment = ({
  int window,
  bool dinner,
  List<TableQuestion> questions,
  String householdId,
  int cycleLength,
});

/// Minutes after midnight of a `HH:mm` value; null for anything else, so a malformed
/// setting falls back to its default instead of breaking the screen.
int? minutesOfDay(Object? hhmm) {
  if (hhmm is! String) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
  if (m == null) return null;
  final hours = int.parse(m[1]!);
  final minutes = int.parse(m[2]!);
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

/// Whether [now] (minutes after midnight) lies in the `time_range` [range], each end
/// falling back to [from] and [to] when missing or malformed. A window that ends before
/// it starts runs past midnight. Returns how many days ago the window began (0, or 1
/// after midnight), or null outside it.
int? tableWindowStart(
  Object? range,
  int now, {
  required String from,
  required String to,
}) {
  final r = range is Map ? range : const <String, Object?>{};
  final a = minutesOfDay(r['from']) ?? minutesOfDay(from)!;
  final b = minutesOfDay(r['to']) ?? minutesOfDay(to)!;
  if (a == b) return null;
  if (a < b) return now >= a && now < b ? 0 : null;
  if (now >= a) return 0;
  return now < b ? 1 : null;
}

/// The Tischfrage's moment at [now] (specs/27): null outside the meal windows, when
/// [mode] is `off`, or with nothing to ask. With `warm_meal` (the default) only the
/// window of that day's warm meal counts, and [warmIsDinner] says which one it is;
/// `main_meals` asks at both.
TableMoment? tableMomentAt({
  required DateTime now,
  required Object? mode,
  required Object? lunch,
  required Object? dinner,
  required bool Function(DateTime day) warmIsDinner,
  required List<TableQuestion> deck,
  required String householdId,
  int? cycleLength,
}) {
  if (mode == 'off' || deck.isEmpty) return null;
  final minutes = now.hour * 60 + now.minute;
  final atLunch = tableWindowStart(lunch, minutes, from: '11:30', to: '13:30');
  final atDinner = tableWindowStart(
    dinner,
    minutes,
    from: '17:30',
    to: '19:30',
  );
  final isDinner = atDinner != null;
  final back = atDinner ?? atLunch;
  if (back == null) return null;
  // The meal belongs to the day its window began, also after midnight.
  final day = DateTime(now.year, now.month, now.day - back);
  // `main_meals` asks at lunch and dinner; anything else follows the warm meal.
  final warmOnly = (mode ?? 'warm_meal') == 'warm_meal';
  if (warmOnly && warmIsDinner(day) != isDinner) return null;
  return (
    window: mealWindowIndex(day, dinner: isDinner, twoADay: !warmOnly),
    dinner: isDinner,
    questions: deck,
    householdId: householdId,
    cycleLength: cycleLength ?? deck.length,
  );
}
