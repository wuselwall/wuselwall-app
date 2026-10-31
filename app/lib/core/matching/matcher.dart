import 'package:wuselwall/core/matching/dictionary.dart';
import 'package:wuselwall/core/matching/edit_distance.dart';
import 'package:wuselwall/core/matching/normalize.dart';
import 'package:wuselwall/core/matching/quantity_parser.dart';

/// Which layer found the match, from the surest to the loosest.
enum MatchLayer { household, phrase, word, stem, compound, fuzzy }

/// What a text was recognised as, and how it got there.
class Match {
  const Match({
    required this.key,
    required this.categories,
    required this.layer,
    required this.matchedWord,
  });

  final String key;
  final List<String> categories;
  final MatchLayer layer;

  /// The part of the text (normalised) or the dictionary word that matched.
  final String matchedWord;

  /// How far to trust it; callers can ask for confirmation below some value.
  double get confidence => switch (layer) {
    MatchLayer.household => 1.0,
    MatchLayer.phrase => 0.95,
    MatchLayer.word => 0.9,
    MatchLayer.stem => 0.8,
    MatchLayer.compound => 0.75,
    MatchLayer.fuzzy => 0.6,
  };

  @override
  String toString() => 'Match($key, ${layer.name}, "$matchedWord")';
}

/// Words that join a thing to what it is made of or for ("jus d orange", "zumo de
/// naranja"). The Romance languages put the head before them, so with one in the
/// text the head is the first word; otherwise (German, English) it is the last.
const _connectors = <String>{
  'de', 'd', 'du', 'des', 'della', 'di', 'con', 'au', 'aux', 'a', 'al', //
  'of', 'mit', 'with', 'et', 'y', 'und', 'and', //
  // German "X vom/von Y" names the thing first ("Bratwurst vom Grill"); "im", "am" and
  // "auf" introduce the place, which is the subject ("Besuch im Zoo"), so they stay out.
  'vom', 'von',
};

/// Plural and case endings tried by the stem and compound layers, longest first.
const _suffixes = <String>['ern', 'en', 'er', 'es', 's', 'n', 'e'];

/// Words that say nothing about the thing, so they are never guessed at.
const _stopwords = <String>{
  'bio', 'frisch', 'fresh', 'organic', 'gross', 'klein', 'large', 'small', //
  'neu', 'new', 'mit', 'ohne', 'with', 'without', 'the', 'le', 'la', 'les',
  'el', 'los', 'las', 'der', 'die', 'das',
};

final _digits = RegExp(r'^\d+$');

/// Finds the dictionary entry a typed name means, trying the exact ways first:
/// the household's own corrections, the whole phrase, a word in it, a word without
/// its plural ending, a word at the end of a compound, and last a near spelling.
/// The first layer that hits wins, so a loose guess never beats a sure one.
class Matcher {
  Matcher(
    this.dictionary, {
    this.householdOverrides = const {},
    this.stripQuantity = true,
  }) : _byKey = {for (final e in dictionary.entries) e.key: e};

  final MatchDictionary dictionary;

  /// Normalised phrase to dictionary key: what this household taught the app.
  final Map<String, String> householdOverrides;

  /// Drop a quantity before matching ("2 Liter Milch", "Milch 1l").
  final bool stripQuantity;

  final Map<String, DictionaryEntry> _byKey;

  Match? match(String text) {
    final name = stripQuantity ? (parseShoppingItem(text)?.name ?? text) : text;
    final n = normalizeText(name);
    final toks = tokens(n);
    if (toks.isEmpty) return null;

    final key = householdOverrides[n];
    if (key != null) {
      return Match(
        key: key,
        categories: _byKey[key]?.categories ?? const [],
        layer: MatchLayer.household,
        matchedWord: n,
      );
    }

    final whole = dictionary.byPhrase[n];
    if (whole != null) return _hit(whole, MatchLayer.phrase, n);

    // Positions in head-first order; digits never name anything.
    final connected = toks.any(_connectors.contains);
    final order = [
      for (var i = 0; i < toks.length; i++)
        if (!_digits.hasMatch(toks[i])) i,
    ];
    if (!connected) {
      order.sort((a, b) => b.compareTo(a));
    }

    return _word(toks, connected) ??
        _stem(toks, order) ??
        _compound(toks, order) ??
        _fuzzy(toks, order);
  }

  Match _hit(DictionaryEntry e, MatchLayer layer, String word) => Match(
    key: e.key,
    categories: e.categories,
    layer: layer,
    matchedWord: word,
  );

  /// The longest run of words that is a dictionary phrase, the head's side first.
  Match? _word(List<String> toks, bool connected) {
    for (var len = toks.length - 1; len >= 1; len--) {
      final starts = [for (var i = 0; i + len <= toks.length; i++) i];
      if (!connected) starts.sort((a, b) => b.compareTo(a));
      for (final i in starts) {
        final run = toks.sublist(i, i + len);
        if (run.every(_digits.hasMatch)) continue;
        final phrase = run.join(' ');
        final entry = dictionary.byPhrase[phrase];
        if (entry != null) return _hit(entry, MatchLayer.word, phrase);
      }
    }
    return null;
  }

  /// "tomates" is "tomate" with an ending.
  Match? _stem(List<String> toks, List<int> order) {
    for (final i in order) {
      final t = toks[i];
      for (final s in _suffixes) {
        if (!t.endsWith(s) || t.length - s.length < 3) continue;
        final stem = t.substring(0, t.length - s.length);
        if (dictionary.singleWords.contains(stem)) {
          return _hit(dictionary.byPhrase[stem]!, MatchLayer.stem, stem);
        }
      }
    }
    return null;
  }

  /// "vollmilch" ends in "milch": the German head is the last part.
  Match? _compound(List<String> toks, List<int> order) {
    for (final i in order) {
      final t = toks[i];
      String? best;
      for (var start = 1; start <= t.length - 4; start++) {
        final tail = t.substring(start);
        if (dictionary.singleWords.contains(tail) &&
            (best == null || tail.length > best.length)) {
          best = tail;
        }
        for (final s in _suffixes) {
          if (!tail.endsWith(s) || tail.length - s.length < 4) continue;
          final w = tail.substring(0, tail.length - s.length);
          if (dictionary.singleWords.contains(w) &&
              (best == null || w.length > best.length)) {
            best = w;
          }
        }
      }
      if (best != null) {
        return _hit(dictionary.byPhrase[best]!, MatchLayer.compound, best);
      }
    }
    return null;
  }

  /// One or two typos: "tomatten" is "tomaten".
  Match? _fuzzy(List<String> toks, List<int> order) {
    for (final i in order) {
      final t = toks[i];
      if (t.length < 5 || _stopwords.contains(t)) continue;
      final maxDist = t.length >= 9 ? 2 : 1;
      String? best;
      var bestDist = maxDist + 1;
      for (var len = t.length - maxDist; len <= t.length + maxDist; len++) {
        for (final w
            in dictionary.singleWordsByLength[len] ?? const <String>[]) {
          final d = damerauLevenshtein(t, w, max: maxDist);
          if (d > maxDist) continue;
          if (best == null ||
              d < bestDist ||
              (d == bestDist &&
                  (w.length > best.length ||
                      (w.length == best.length && w.compareTo(best) < 0)))) {
            best = w;
            bestDist = d;
          }
        }
      }
      if (best != null) {
        return _hit(dictionary.byPhrase[best]!, MatchLayer.fuzzy, best);
      }
    }
    return null;
  }
}
