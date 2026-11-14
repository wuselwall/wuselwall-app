import 'package:wuselwall/core/text/fold.dart';

/// One earlier entry a field can propose, with the number of times the family used it.
class TextSuggestion {
  const TextSuggestion({
    required this.text,
    this.count = 1,
    this.lastUsed,
    this.location,
    this.iconKey,
  });

  final String text;
  final int count;
  final DateTime? lastUsed;

  /// The place that usually went with this text (event titles).
  final String? location;

  /// The picture that usually went with this text.
  final String? iconKey;
}

/// One raw row of an earlier entry, before it is grouped into a [TextSuggestion].
class SuggestionRow {
  const SuggestionRow({
    required this.text,
    this.usedAt,
    this.location,
    this.iconKey,
  });

  final String text;
  final DateTime? usedAt;
  final String? location;
  final String? iconKey;
}

final _wordBreak = RegExp(r'[\s\-/]+');

/// The entries that start with [query], then the ones with a word that does, each
/// group by use count, recency and then alphabetically. Case, umlauts and accents do
/// not matter. An empty query proposes nothing, and an entry equal to the query is not
/// proposed (there is nothing left to take over).
List<TextSuggestion> rankSuggestions(
  String query,
  List<TextSuggestion> entries, {
  int limit = 5,
}) {
  final q = fold(query.trim());
  if (q.isEmpty || limit <= 0) return const [];
  final prefix = <(TextSuggestion, String)>[];
  final word = <(TextSuggestion, String)>[];
  for (final entry in entries) {
    final folded = fold(entry.text.trim());
    if (folded == q) continue;
    if (folded.startsWith(q)) {
      prefix.add((entry, folded));
    } else if (folded.split(_wordBreak).any((w) => w.startsWith(q))) {
      word.add((entry, folded));
    }
  }
  int order((TextSuggestion, String) a, (TextSuggestion, String) b) {
    final byCount = b.$1.count.compareTo(a.$1.count);
    if (byCount != 0) return byCount;
    final x = a.$1.lastUsed;
    final y = b.$1.lastUsed;
    if (x != null || y != null) {
      if (x == null) return 1;
      if (y == null) return -1;
      final byTime = y.compareTo(x);
      if (byTime != 0) return byTime;
    }
    return a.$2.compareTo(b.$2);
  }

  prefix.sort(order);
  word.sort(order);
  return [
    for (final e in [...prefix, ...word].take(limit)) e.$1,
  ];
}

/// Groups [rows] by their folded text: the count is the rows in the group, the text is
/// the newest row's spelling, and the location and picture are the most frequent
/// non-empty ones (a tie goes to the more recent).
List<TextSuggestion> buildSuggestions(Iterable<SuggestionRow> rows) {
  final groups = <String, List<SuggestionRow>>{};
  for (final row in rows) {
    final key = fold(row.text.trim());
    if (key.isEmpty) continue;
    (groups[key] ??= []).add(row);
  }
  return [
    for (final group in groups.values)
      () {
        final newestFirst = [...group]..sort(_newestFirst);
        return TextSuggestion(
          text: newestFirst.first.text.trim(),
          count: group.length,
          lastUsed: newestFirst
              .map((r) => r.usedAt)
              .whereType<DateTime>()
              .firstOrNull,
          location: _mostFrequent([
            for (final r in newestFirst) r.location?.trim(),
          ]),
          iconKey: _mostFrequent([for (final r in newestFirst) r.iconKey]),
        );
      }(),
  ];
}

int _newestFirst(SuggestionRow a, SuggestionRow b) {
  final x = a.usedAt;
  final y = b.usedAt;
  if (x == null && y == null) return 0;
  if (x == null) return 1;
  if (y == null) return -1;
  return y.compareTo(x);
}

/// The most frequent non-empty value of [newestFirst]; a tie goes to the one seen first.
String? _mostFrequent(List<String?> newestFirst) {
  final counts = <String, int>{};
  for (final v in newestFirst) {
    if (v == null || v.isEmpty) continue;
    counts[v] = (counts[v] ?? 0) + 1;
  }
  String? best;
  var bestCount = 0;
  for (final e in counts.entries) {
    if (e.value > bestCount) {
      best = e.key;
      bestCount = e.value;
    }
  }
  return best;
}
