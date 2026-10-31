import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

/// What the list screen shows: the server's last state with this device's pending
/// changes replayed on top, so it looks the same online and offline (specs/07#offline).
/// Live: another device's change refetches within a moment (NFR-5).
final shoppingViewProvider = Provider<AsyncValue<ShoppingView>>((ref) {
  final sync = ref.watch(shoppingSyncProvider);
  final view = sync.view;
  if (view != null) return AsyncData(view);
  if (sync.failure case final failure?) {
    return AsyncError(failure, StackTrace.empty);
  }
  return const AsyncLoading();
});

/// Open items of every list.
final shoppingItemsProvider = Provider<AsyncValue<List<ShoppingItem>>>(
  (ref) => ref.watch(shoppingViewProvider).whenData((v) => v.items),
);

final shoppingListsProvider = Provider<AsyncValue<List<ShoppingList>>>(
  (ref) => ref.watch(shoppingViewProvider).whenData((v) => v.lists),
);

final shoppingCategoriesProvider = Provider<AsyncValue<List<ShoppingCategory>>>(
  (ref) => ref.watch(shoppingViewProvider).whenData((v) => v.categories),
);

final shoppingCatalogProvider = Provider<AsyncValue<List<CatalogEntry>>>(
  (ref) => ref.watch(shoppingViewProvider).whenData((v) => v.catalog),
);

/// The meals behind one item, for its sheet (FR-3.7). Online only: a failed request is
/// no meals, never an error in the sheet.
final shoppingItemMealsProvider = FutureProvider.autoDispose
    .family<List<ShoppingItemMeal>, String>((ref, itemId) async {
      final result = await ref
          .watch(shoppingRepositoryProvider)
          .itemMeals(itemId);
      return result.valueOrNull ?? const [];
    });

/// Changes made on this device that the server has not confirmed yet.
final shoppingPendingProvider = Provider<int>(
  (ref) => ref.watch(shoppingSyncProvider.select((s) => s.outbox.length)),
);

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

/// What the list screen is for right now (2026-10-31): at home editing the list, or in
/// the store ticking it off. The wall keeps one combined view and ignores this.
enum ShoppingMode { plan, shop }

/// The mode of this device for the session, in memory. It starts in [ShoppingMode.shop]
/// when the list on screen already has a ticked item (a trip is under way), else in
/// [ShoppingMode.plan]. Read first when the list has loaded, so the state is known.
final shoppingModeProvider =
    NotifierProvider<ShoppingModeNotifier, ShoppingMode>(
      ShoppingModeNotifier.new,
    );

class ShoppingModeNotifier extends Notifier<ShoppingMode> {
  @override
  ShoppingMode build() {
    final list = ref.read(currentListProvider).value;
    final items = ref.read(shoppingItemsProvider).value ?? const [];
    final ticked = items.any(
      (i) => i.checked && (i.listId == null || i.listId == list?.id),
    );
    return ticked ? ShoppingMode.shop : ShoppingMode.plan;
  }

  // A setter-style method: Riverpod 3 notifiers expose state changes this way.
  // ignore: use_setters_to_change_properties
  void select(ShoppingMode mode) => state = mode;
}
