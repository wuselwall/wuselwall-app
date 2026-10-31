import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:wuselwall/core/text/fold.dart';

/// One suggestion of the starter catalogue: a name in popularity order, the seeded
/// category key it belongs to and the picture's key (null when there is none yet).
class StarterItem {
  StarterItem({required this.name, required this.category, this.icon})
    : folded = fold(name);

  factory StarterItem.fromJson(Map<String, dynamic> json) => StarterItem(
    name: json['name'] as String,
    category: json['category'] as String,
    icon: json['icon'] as String?,
  );

  final String name;
  final String category;
  final String? icon;

  /// [name] as `fold` writes it: what tiles and open items are compared by.
  final String folded;
}

/// The bundled starter catalogue (`assets/matching/starter.json`, rendered by
/// scripts/starter.mjs from dictionary/starter.txt): per kind of list and language tag,
/// the full list of suggestions in popularity order.
class StarterCatalog {
  const StarterCatalog(this._items);

  factory StarterCatalog.parse(String source) {
    final kinds =
        (jsonDecode(source) as Map<String, dynamic>)['kinds']
            as Map<String, dynamic>;
    return StarterCatalog({
      for (final MapEntry(key: kind, value: body) in kinds.entries)
        kind: {
          for (final MapEntry(key: tag, value: list)
              in ((body as Map<String, dynamic>)['items']
                      as Map<String, dynamic>)
                  .entries)
            tag: [
              for (final item in list as List<dynamic>)
                StarterItem.fromJson(item as Map<String, dynamic>),
            ],
        },
    });
  }

  static const empty = StarterCatalog({});

  final Map<String, Map<String, List<StarterItem>>> _items;

  /// The suggestions for a list of [kind] in the language [tag]; German when the
  /// bundle has none for the tag, nothing for an unknown kind.
  List<StarterItem> items(String kind, String tag) {
    final byTag = _items[kind];
    return byTag?[tag] ?? byTag?['de'] ?? const [];
  }
}

Future<StarterCatalog>? _loaded;

/// Loads the bundled catalogue once; later calls share the same future. A failed load
/// is forgotten (the next call tries again) and shows no suggestions.
Future<StarterCatalog> loadStarterCatalog() {
  final future = _loaded ??= rootBundle
      .loadString('assets/matching/starter.json')
      .then(StarterCatalog.parse);
  return future.catchError((Object _) {
    if (identical(_loaded, future)) _loaded = null;
    return StarterCatalog.empty;
  });
}

/// How the catalogue is loaded. The tests replace it (`test/flutter_test_config.dart`):
/// reading the bundle is real I/O that finishes whenever the event loop gets to it, so
/// a test that does not care about suggestions would see them appear at random.
Future<StarterCatalog> Function() starterCatalogLoader = loadStarterCatalog;
