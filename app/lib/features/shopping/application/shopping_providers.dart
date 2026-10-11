import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// Declares that a provider is live: a change on any device re-fetches within a moment
/// (NFR-5). Fetching again, rather than patching, means a missed message can never
/// leave the screen wrong.
void _live(Ref ref) {
  final household = ref.watch(deviceProvider).value?.householdId;
  if (household != null) {
    refreshOnInvalidation(ref, householdId: household, topic: 'shopping');
  }
}

/// Open items of every list.
final shoppingItemsProvider = FutureProvider.autoDispose<List<ShoppingItem>>((
  ref,
) async {
  _live(ref);
  return (await ref.watch(shoppingRepositoryProvider).items()).unwrap();
});

final shoppingListsProvider = FutureProvider.autoDispose<List<ShoppingList>>((
  ref,
) async {
  _live(ref);
  return (await ref.watch(shoppingRepositoryProvider).lists()).unwrap();
});

final shoppingCategoriesProvider =
    FutureProvider.autoDispose<List<ShoppingCategory>>((ref) async {
      _live(ref);
      return (await ref.watch(shoppingRepositoryProvider).categories())
          .unwrap();
    });

final shoppingCatalogProvider = FutureProvider.autoDispose<List<CatalogEntry>>((
  ref,
) async {
  _live(ref);
  return (await ref.watch(shoppingRepositoryProvider).catalog()).unwrap();
});

/// The list the user picked; null means the household default.
final selectedListIdProvider = NotifierProvider<SelectedListNotifier, String?>(
  SelectedListNotifier.new,
);

class SelectedListNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  // A setter-style method: Riverpod 3 notifiers expose state changes this way.
  // ignore: use_setters_to_change_properties
  void select(String? id) => state = id;
}

/// The list on screen: the picked one if it still exists, else the default.
final currentListProvider = Provider.autoDispose<AsyncValue<ShoppingList?>>((
  ref,
) {
  // The wall display only ever writes to the default list (FR-8.12).
  final kiosk = ref.watch(uiRegisterProvider) == UiRegister.kiosk;
  final selected = kiosk ? null : ref.watch(selectedListIdProvider);
  return ref.watch(shoppingListsProvider).whenData((lists) {
    if (lists.isEmpty) return null;
    return lists.firstWhere(
      (l) => l.id == selected,
      orElse: () =>
          lists.firstWhere((l) => l.isDefault, orElse: () => lists.first),
    );
  });
});

/// Tiles for the picker: with no query the household's most bought, then the most
/// recent; with one, prefix beats word-start beats substring, ties broken by purchases.
List<CatalogEntry> rankTiles(
  List<CatalogEntry> catalog,
  String query, {
  int limit = 24,
}) {
  final q = fold(query.trim());
  if (q.isEmpty) {
    final byFrequency = [...catalog]
      ..sort((a, b) => b.purchaseCount.compareTo(a.purchaseCount));
    final recent = catalog.where((c) => c.lastPurchasedAt != null).toList()
      ..sort((a, b) => b.lastPurchasedAt!.compareTo(a.lastPurchasedAt!));
    final seen = <String>{};
    return [
      for (final c in [...recent.take(8), ...byFrequency])
        if (seen.add(c.id)) c,
    ].take(limit).toList();
  }
  int? score(CatalogEntry c) {
    final name = c.foldedName;
    if (name.startsWith(q)) return 0;
    if (name.split(RegExp(r'[\s\-/]+')).any((w) => w.startsWith(q))) return 1;
    if (name.contains(q)) return 2;
    return null;
  }

  final scored =
      [
        for (final c in catalog)
          if (score(c) case final s?) (s, c),
      ]..sort((a, b) {
        final byScore = a.$1.compareTo(b.$1);
        return byScore != 0
            ? byScore
            : b.$2.purchaseCount.compareTo(a.$2.purchaseCount);
      });
  return [for (final s in scored.take(limit)) s.$2];
}
