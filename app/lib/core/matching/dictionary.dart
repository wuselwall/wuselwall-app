import 'dart:convert';

import 'package:wuselwall/core/matching/normalize.dart';

/// One thing the dictionary knows ("milk"), with the categories it belongs to and
/// every word or phrase that names it, in all the languages we ship.
class DictionaryEntry {
  const DictionaryEntry({
    required this.key,
    required this.categories,
    required this.words,
  });

  /// The picture in `assets/emoji/<domain>/`, or a `@name` for words that have none and
  /// only carry a category (the tile then shows the category's icon).
  final String key;
  final List<String> categories;

  /// Normalised words and phrases ("milch", "creme fraiche").
  final List<String> words;

  bool get hasPicture => !key.startsWith('@');
}

/// The entries of one domain (shopping, meals) plus the lookups the matcher needs,
/// built once so a match never scans the entry list.
class MatchDictionary {
  MatchDictionary._(
    this.domain,
    this.entries,
    this.byPhrase,
    this.singleWordsByLength,
    this.singleWords,
  );

  /// [json] is the domain object: `{"entries": [{"key", "categories", "words"}]}`.
  /// The words are normalised again here, so a hand-edited file cannot break matching.
  factory MatchDictionary.fromJson(String domain, Map<String, Object?> json) {
    final entries = <DictionaryEntry>[];
    for (final raw in (json['entries'] as List<Object?>? ?? const [])) {
      final map = raw as Map<String, Object?>;
      final words = <String>{};
      for (final w in (map['words'] as List<Object?>? ?? const [])) {
        final n = normalizeText(w as String);
        if (n.isNotEmpty) words.add(n);
      }
      entries.add(
        DictionaryEntry(
          key: map['key'] as String,
          categories: [
            for (final c in (map['categories'] as List<Object?>? ?? const []))
              c as String,
          ],
          words: words.toList(),
        ),
      );
    }

    final byPhrase = <String, DictionaryEntry>{};
    final singles = <String>{};
    for (final entry in entries) {
      for (final w in entry.words) {
        // A word two entries share belongs to the one listed first.
        byPhrase.putIfAbsent(w, () => entry);
        if (!w.contains(' ')) singles.add(w);
      }
    }
    final byLength = <int, List<String>>{};
    for (final w in singles) {
      byLength.putIfAbsent(w.length, () => []).add(w);
    }
    return MatchDictionary._(domain, entries, byPhrase, byLength, singles);
  }

  final String domain;
  final List<DictionaryEntry> entries;

  /// Normalised word or phrase (may contain spaces) to its entry.
  final Map<String, DictionaryEntry> byPhrase;

  /// Single-token words by length, so the fuzzy layer only looks at near lengths.
  final Map<int, List<String>> singleWordsByLength;
  final Set<String> singleWords;
}

/// Every domain of the bundled `assets/matching/dictionary.json`.
class MatchDictionaries {
  const MatchDictionaries(this.byDomain);

  final Map<String, MatchDictionary> byDomain;

  /// Reads `{"version": 1, "domains": {"shopping": {"entries": [...]}, ...}}`.
  static MatchDictionaries parse(String jsonText) {
    final root = jsonDecode(jsonText) as Map<String, Object?>;
    final domains = root['domains'] as Map<String, Object?>? ?? const {};
    return MatchDictionaries({
      for (final e in domains.entries)
        e.key: MatchDictionary.fromJson(e.key, e.value as Map<String, Object?>),
    });
  }
}
