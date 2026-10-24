import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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

/// The languages with a written deck. French and Spanish come later (Q53): until then
/// the Tischfrage stays away on a device in those languages.
const tableQuestionLanguages = {'de', 'en'};

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

/// A number from [text] that is the same on every device and every run (unlike
/// `String.hashCode`, which Dart does not promise to keep).
int stableSeed(String text) =>
    text.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x3fffffff);

/// The household's walk through its questions: one fixed shuffle per household, so
/// every device shows the same question in the same meal and none repeats before the
/// deck is through (specs/27).
List<TableQuestion> householdShuffle(
  List<TableQuestion> questions,
  String householdId,
) {
  final sorted = [...questions]..sort((a, b) => a.key.compareTo(b.key));
  return sorted..shuffle(math.Random(stableSeed(householdId)));
}

/// The question for the meal window [window] (a running count, see [mealWindowIndex]),
/// [skip] questions further on for this device's "Andere Frage".
TableQuestion? questionFor(
  List<TableQuestion> shuffled,
  int window, {
  int skip = 0,
}) => shuffled.isEmpty ? null : shuffled[(window + skip) % shuffled.length];

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
