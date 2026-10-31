import 'package:flutter/services.dart' show rootBundle;

import 'package:wuselwall/core/matching/dictionary.dart';

Future<MatchDictionaries>? _loaded;

/// Loads the bundled dictionary once; later calls share the same future. A failed
/// load is forgotten, so the next call tries again instead of caching the error.
Future<MatchDictionaries> loadMatchDictionaries() {
  final future = _loaded ??= rootBundle
      .loadString('assets/matching/dictionary.json')
      .then(MatchDictionaries.parse);
  future.catchError((Object _) {
    if (identical(_loaded, future)) _loaded = null;
    return MatchDictionaries(const {});
  });
  return future;
}
