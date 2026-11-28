import 'package:wuselwall/core/text/fold.dart';

final _space = RegExp(r'\s+');
final _wordBreak = RegExp(r'[^a-z0-9]+');

/// The words of a typed [query], folded ([fold]): what every search of the app looks
/// for. Empty for a query of blanks.
List<String> searchTerms(String query) => [
  for (final term in fold(query.trim()).split(_space))
    if (term.isNotEmpty) term,
];

/// How well [fields] answer [terms], lower is better; null when one of the terms is in
/// none of them. Case, umlauts and accents do not matter.
///
/// Every term has to be found somewhere. Where counts: an earlier field beats a later
/// one (pass the title first), and within a field its beginning beats the start of one
/// of its words, which beats the middle of a word ("arzt" still finds "Zahnarzt"). The
/// `search` Edge Function ranks appointments by the same rule (`_shared/search.ts`).
int? searchRank(List<String> terms, List<String?> fields) {
  if (terms.isEmpty) return null;
  // A missing field keeps its place: a note is a note whether or not there is a place.
  final folded = [
    for (final field in fields) field == null ? '' : fold(field.trim()),
  ];
  var total = 0;
  for (final term in terms) {
    int? best;
    for (final (i, field) in folded.indexed) {
      if (field.isEmpty) continue;
      final kind = _kind(term, field);
      if (kind == null) continue;
      final score = i * 3 + kind;
      if (best == null || score < best) best = score;
      if (kind == 0) break;
    }
    if (best == null) return null;
    total += best;
  }
  return total;
}

/// 0: [field] starts with [term]; 1: one of its words does; 2: it is inside a word.
int? _kind(String term, String field) {
  final at = field.indexOf(term);
  if (at < 0) return null;
  if (at == 0) return 0;
  for (final word in field.split(_wordBreak)) {
    if (word.startsWith(term)) return 1;
  }
  return 2;
}

/// The [items] that answer [query], best first; items that answer equally well keep
/// their order. [fields] names what is searched in an item, the title first. An empty
/// query finds nothing.
List<T> searchIn<T>(
  String query,
  Iterable<T> items,
  List<String?> Function(T item) fields, {
  int? limit,
}) {
  final terms = searchTerms(query);
  if (terms.isEmpty) return const [];
  final hits = <(int, int, T)>[];
  for (final (i, item) in items.indexed) {
    final rank = searchRank(terms, fields(item));
    if (rank != null) hits.add((rank, i, item));
  }
  hits.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
  });
  return [for (final hit in limit == null ? hits : hits.take(limit)) hit.$3];
}
