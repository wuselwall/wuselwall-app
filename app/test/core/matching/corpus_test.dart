import 'dart:io';

import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:wuselwall/core/matching/dictionary.dart';
import 'package:wuselwall/core/matching/matcher.dart';
import 'package:wuselwall/core/matching/quantity_parser.dart';
import 'package:wuselwall/core/text/fold.dart';

/// The acceptance test of specs/29: every line of dictionary/corpus.txt through the layered
/// matcher, against the floor per domain, and against the legacy SQL algorithm (the words of
/// app.catalog_icon_for and app.meal_icon_for, regex-extracted from their migrations) so a
/// change to the dictionary or the layers shows what it adds. The misses are printed, not
/// hidden: they are the work list for the dictionary.
void main() {
  // Floors are the measured accuracy minus a small margin; raise them as the dictionary grows,
  // never lower them without a corpus line that explains why.
  const floors = {
    'shopping': 0.93,
    'meals': 0.90,
    'events': 0.90,
    'tasks': 0.90,
  };

  late MatchDictionaries dictionaries;
  late Map<String, List<CorpusLine>> corpus;

  setUpAll(() {
    dictionaries = MatchDictionaries.parse(
      File('assets/matching/dictionary.json').readAsStringSync(),
    );
    corpus = readCorpus(File('../dictionary/corpus.txt').readAsStringSync());
  });

  test('the corpus has the four domains and enough hard lines', () {
    expect(corpus.keys, containsAll(['shopping', 'meals', 'events', 'tasks']));
    final total = corpus.values.fold<int>(0, (n, l) => n + l.length);
    expect(
      total,
      greaterThanOrEqualTo(400),
      reason: 'about 500 lines, specs/29',
    );
  });

  for (final domain in ['shopping', 'meals', 'events', 'tasks']) {
    test('$domain: the layered matcher clears its floor', () {
      final matcher = Matcher(dictionaries.byDomain[domain]!);
      final lines = corpus[domain]!;
      final byLayer = <String, int>{};
      final misses = <String>[];
      var hits = 0;
      for (final line in lines) {
        final m = matcher.match(line.text);
        final got = m?.key ?? '-';
        if (got == line.expected) {
          hits++;
          byLayer.update(
            m?.layer.name ?? 'unknown',
            (n) => n + 1,
            ifAbsent: () => 1,
          );
        } else {
          misses.add(
            '  ${line.text.padRight(32)} expected ${line.expected.padRight(14)} '
            'got $got${m == null ? '' : ' (${m.layer.name}: ${m.matchedWord})'}',
          );
        }
      }
      final accuracy = hits / lines.length;
      // ignore: avoid_print
      print(
        '$domain: $hits/${lines.length} = ${(accuracy * 100).toStringAsFixed(1)} % '
        'by layer $byLayer\n${misses.join('\n')}',
      );
      expect(accuracy, greaterThanOrEqualTo(floors[domain]!));
    });
  }

  test('shopping: the layers beat the legacy SQL algorithm', () {
    final legacy = legacyWords(
      '../supabase/migrations/20261015120000_catalog_icons.sql',
      'app.catalog_icon_for',
    );
    final matcher = Matcher(dictionaries.byDomain['shopping']!);
    final (legacyHits, newHits) = compare(
      corpus['shopping']!,
      (t) => legacyCatalogIcon(legacy, t),
      (t) => matcher.match(t)?.key,
    );
    expect(newHits, greaterThan(legacyHits));
  });

  test('meals: the layers beat the legacy SQL algorithm', () {
    final legacy = legacyWords(
      '../supabase/migrations/20261025130000_rituals_wishes_story.sql',
      'app.meal_icon_for',
    );
    final matcher = Matcher(
      dictionaries.byDomain['meals']!,
      stripQuantity: false,
    );
    final (legacyHits, newHits) = compare(
      corpus['meals']!,
      (t) => legacyMealIcon(legacy, t),
      (t) => matcher.match(t)?.key,
    );
    expect(newHits, greaterThan(legacyHits));
  });
}

class CorpusLine {
  const CorpusLine(this.text, this.expected);
  final String text;

  /// A key, or '-' for "must stay unknown".
  final String expected;
}

/// `[domain]` sections of `text => key   # note` lines.
Map<String, List<CorpusLine>> readCorpus(String source) {
  final out = <String, List<CorpusLine>>{};
  String? domain;
  for (final raw in source.split('\n')) {
    final line = raw.replaceFirst(RegExp(r'\s+#.*$'), '').trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final section = RegExp(r'^\[(\w+)\]$').firstMatch(line);
    if (section != null) {
      domain = section.group(1);
      continue;
    }
    final parts = line.split('=>');
    if (parts.length != 2 || domain == null) {
      throw FormatException('corpus line not understood: $raw');
    }
    out
        .putIfAbsent(domain, () => [])
        .add(CorpusLine(parts[0].trim(), parts[1].trim()));
  }
  return out;
}

(int, int) compare(
  List<CorpusLine> lines,
  String? Function(String) legacy,
  String? Function(String) current,
) {
  var legacyHits = 0;
  var newHits = 0;
  for (final line in lines) {
    if ((legacy(line.text) ?? '-') == line.expected) legacyHits++;
    if ((current(line.text) ?? '-') == line.expected) newHits++;
  }
  // ignore: avoid_print
  print('legacy $legacyHits vs layered $newHits of ${lines.length}');
  return (legacyHits, newHits);
}

/// The ('word', 'key') pairs of one SQL function's `values` list.
List<(String, String)> legacyWords(String path, String function) {
  final sql = File(path).readAsStringSync();
  final start = sql.indexOf('function $function');
  final end = sql.indexOf(r'$$;', start);
  final body = sql.substring(start, end);
  return RegExp(r"\('([^']+)', '([^']+)'\)")
      .allMatches(body)
      .map((m) => (m.group(1)!, m.group(2)!))
      .toList();
}

/// app.catalog_icon_for: the whole folded name, then its last word, then the longest word
/// (three letters or more) the last word ends with. The name arrives without its quantity, as
/// the catalogue stores it.
String? legacyCatalogIcon(List<(String, String)> words, String text) {
  final whole = fold(parseShoppingItem(text)?.name ?? text).trim();
  final last = whole.replaceFirst(RegExp(r'^.*[\s/-]'), '');
  (int, int, int, String)? best; // (whole, last, length, key), highest wins
  for (final (word, key) in words) {
    final isWhole = word == whole;
    final isLast = word == last;
    final isSuffix = word.length >= 3 && last.endsWith(word);
    if (!isWhole && !isLast && !isSuffix) continue;
    final rank = (isWhole ? 1 : 0, isLast ? 1 : 0, word.length, key);
    if (best == null || _higher(rank, best)) best = rank;
  }
  return best?.$4;
}

/// app.meal_icon_for: the whole folded title at position 0, then each word in order; an exact
/// word wins over a suffix of four letters or more; earlier positions win.
String? legacyMealIcon(List<(String, String)> words, String text) {
  final folded = fold(text);
  final parts = <(String, int)>[(folded.trim(), 0)];
  var pos = 0;
  for (final w in folded.split(RegExp('[^a-z0-9-]+'))) {
    pos++;
    if (w.isNotEmpty) parts.add((w, pos));
  }
  (int, int, int, String)? best; // (-pos, exact, length, key)
  for (final (t, p) in parts) {
    for (final (word, key) in words) {
      final exact = word == t;
      final suffix = word.length >= 4 && p > 0 && t.endsWith(word);
      if (!exact && !suffix) continue;
      final rank = (-p, exact ? 1 : 0, word.length, key);
      if (best == null || _higher(rank, best)) best = rank;
    }
  }
  return best?.$4;
}

bool _higher((int, int, int, String) a, (int, int, int, String) b) {
  if (a.$1 != b.$1) return a.$1 > b.$1;
  if (a.$2 != b.$2) return a.$2 > b.$2;
  return a.$3 > b.$3;
}
