import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/features/settings/application/app_locale_provider.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/data/starter_catalog.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

// The starter catalogue (specs/07 "Starter catalogue"): what a list's tiles suggest
// before the family has bought enough to fill them.

/// The tiles the picker shows at most, the family's own and the suggested ones together.
const starterTileLimit = 24;

/// The language tag the starter catalogue is keyed by: `de`, `de-CH`, `de-AT`, `en`,
/// `fr` or `es`; German for any other language.
String starterTagFor(Locale locale) => switch (locale.languageCode) {
  'en' => 'en',
  'fr' => 'fr',
  'es' => 'es',
  _ => switch (locale.countryCode?.toUpperCase()) {
    'CH' || 'LI' => 'de-CH',
    'AT' => 'de-AT',
    _ => 'de',
  },
};

/// Which starter list a list gets: `supermarket`, `drugstore` or `hardware`, told from
/// its seeded categories (the app does not know a list's kind); the default list is a
/// supermarket list whatever its categories, any other list without a hint has none.
String? starterKindOf({
  required bool isDefault,
  required Iterable<String?> categoryKeys,
}) {
  final keys = categoryKeys.toSet();
  if (keys.contains('produce')) return 'supermarket';
  if (keys.contains('care')) return 'drugstore';
  if (keys.contains('tools')) return 'hardware';
  return isDefault ? 'supermarket' : null;
}

/// The suggestions of [items] to show for [query], at most [limit], none whose folded
/// name is in [exclude]. Without a query the popularity order stands; with one, a name
/// that starts with it beats one with a word that does, beats one that contains it,
/// and equal scores keep the popularity order.
List<StarterItem> starterTiles(
  List<StarterItem> items,
  String query, {
  Set<String> exclude = const {},
  int limit = starterTileLimit,
}) {
  if (limit <= 0) return const [];
  final q = fold(query.trim());
  final candidates = [
    for (final s in items)
      if (!exclude.contains(s.folded)) s,
  ];
  if (q.isEmpty) return candidates.take(limit).toList();
  int? score(StarterItem s) {
    if (s.folded.startsWith(q)) return 0;
    if (s.folded.split(RegExp(r'[\s\-/]+')).any((w) => w.startsWith(q))) {
      return 1;
    }
    if (s.folded.contains(q)) return 2;
    return null;
  }

  final scored = <(int, int, StarterItem)>[
    for (final (i, s) in candidates.indexed)
      if (score(s) case final sc?) (sc, i, s),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return [for (final s in scored.take(limit)) s.$3];
}

/// A list's suggestions together with what the picker does with them.
class StarterSet {
  StarterSet(this.items)
    : _byFolded = {for (final s in items.reversed) s.folded: s},
      _icons = {
        for (final s in items.reversed)
          if (s.icon != null) s.folded: s.icon!,
      };

  static final empty = StarterSet(const []);

  /// In popularity order.
  final List<StarterItem> items;
  final Map<String, StarterItem> _byFolded;
  final Map<String, String> _icons;

  /// The suggestion with this folded name, if there is one.
  StarterItem? byFolded(String folded) => _byFolded[folded];

  /// The picture key of a tile or an item: its own, else the one the starter list
  /// gives its name. The server learns the new pictures later than the app.
  String? pictureKey(String? iconKey, String name) =>
      iconKey ?? _icons[fold(name)];

  /// What the picker adds after the family's own tiles [shown] (the ranked
  /// [catalog] entries of this list): without a [query] the starter items up to
  /// [starterTileLimit] in all, only while the list's catalogue has fewer entries than
  /// that and skipping what is on the list already; with one, those that match it.
  /// Names of the catalogue are never offered twice.
  List<StarterItem> forPicker({
    required List<CatalogEntry> catalog,
    required List<CatalogEntry> shown,
    required Iterable<ShoppingItem> onList,
    required String query,
  }) {
    final exclude = {for (final c in catalog) c.foldedName};
    final limit = starterTileLimit - shown.length;
    if (query.trim().isEmpty) {
      if (catalog.length >= starterTileLimit) return const [];
      exclude.addAll(onList.map((i) => fold(i.name)));
    }
    return starterTiles(items, query, exclude: exclude, limit: limit);
  }
}

final starterCatalogProvider = FutureProvider<StarterCatalog>(
  (ref) => starterCatalogLoader(),
);

/// The suggestions for a list of [kind] in the family's language, nothing while the
/// bundle loads.
final starterItemsProvider = Provider.family<List<StarterItem>, String>((
  ref,
  kind,
) {
  final catalog = ref.watch(starterCatalogProvider).value;
  if (catalog == null) return const [];
  return catalog.items(kind, starterTagFor(ref.watch(appLocaleProvider)));
});

/// The starter kind of the list [listId] (see [starterKindOf]).
final starterKindProvider = Provider.family<String?, String>((ref, listId) {
  final list = ref
      .watch(shoppingListsProvider)
      .value
      ?.where((l) => l.id == listId)
      .firstOrNull;
  if (list == null) return null;
  final categories = ref.watch(shoppingCategoriesProvider).value ?? const [];
  return starterKindOf(
    isDefault: list.isDefault,
    categoryKeys: [
      for (final c in categories)
        if (c.listId == listId) c.key,
    ],
  );
});

/// The starter suggestions of the list [listId].
final starterSetProvider = Provider.family<StarterSet, String>((ref, listId) {
  final kind = ref.watch(starterKindProvider(listId));
  if (kind == null) return StarterSet.empty;
  return StarterSet(ref.watch(starterItemsProvider(kind)));
});
