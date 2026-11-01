import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/data/shopping_mode_store.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/match_correction.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_mode.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

export 'package:wuselwall/features/shopping/domain/shopping_mode.dart';

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

/// The words this household taught the app (Einstellungen > Einkaufen > Gelernte Wörter),
/// newest first. Refetched on the `shopping` topic, which the server broadcasts after a
/// correction is made or forgotten.
final matchCorrectionsProvider =
    FutureProvider.autoDispose<List<MatchCorrection>>((ref) async {
      final household = ref.watch(
        deviceProvider.select((d) => d.value?.householdId),
      );
      if (household != null) {
        refreshOnInvalidation(ref, householdId: household, topic: 'shopping');
      }
      return (await ref.watch(shoppingRepositoryProvider).matchCorrections())
          .unwrap();
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

/// Tiles for the picker. Pinned tiles come first, most bought first, then by name. After
/// them, with no query the household's most recent purchases, then its most bought; with
/// one, prefix beats word-start beats substring, ties broken by purchases (pinned
/// matches ahead of the others of the same score).
///
/// [iconKeyFor] is the matcher's fallback (specs/29): it answers the picture a typed
/// name means, and a tile with that picture ranks after the substring matches. So
/// "Tomatten" or "Rüebli" finds the family's "Tomaten" or "Karotten". It is asked only
/// for queries of three characters or more.
List<CatalogEntry> rankTiles(
  List<CatalogEntry> catalog,
  String query, {
  int limit = 24,
  String? Function(String query)? iconKeyFor,
}) {
  final q = fold(query.trim());
  int byBought(CatalogEntry a, CatalogEntry b) =>
      b.purchaseCount.compareTo(a.purchaseCount);
  int byPinned(CatalogEntry a, CatalogEntry b) {
    final byCount = byBought(a, b);
    return byCount != 0 ? byCount : a.foldedName.compareTo(b.foldedName);
  }

  if (q.isEmpty) {
    final pinned = catalog.where((c) => c.pinned).toList()..sort(byPinned);
    final rest = catalog.where((c) => !c.pinned).toList();
    final byFrequency = [...rest]..sort(byBought);
    final recent = rest.where((c) => c.lastPurchasedAt != null).toList()
      ..sort((a, b) => b.lastPurchasedAt!.compareTo(a.lastPurchasedAt!));
    final seen = <String>{};
    return [
      for (final c in [...pinned, ...recent.take(8), ...byFrequency])
        if (seen.add(c.id)) c,
    ].take(limit).toList();
  }
  final iconKey = iconKeyFor != null && q.length >= 3
      ? iconKeyFor(query.trim())
      : null;
  int? score(CatalogEntry c) {
    final name = c.foldedName;
    if (name.startsWith(q)) return 0;
    if (name.split(RegExp(r'[\s\-/]+')).any((w) => w.startsWith(q))) return 1;
    if (name.contains(q)) return 2;
    if (iconKey != null && c.iconKey == iconKey) return 3;
    return null;
  }

  final scored =
      [
        for (final c in catalog)
          if (score(c) case final s?) (s, c),
      ]..sort((a, b) {
        final byScore = a.$1.compareTo(b.$1);
        if (byScore != 0) return byScore;
        if (a.$2.pinned != b.$2.pinned) return a.$2.pinned ? -1 : 1;
        return byBought(a.$2, b.$2);
      });
  return [for (final s in scored.take(limit)) s.$2];
}

/// The mode of this device, kept across restarts (the last one chosen). It is
/// [ShoppingMode.plan] until the stored value has been read, and a choice made before
/// that wins over it.
final shoppingModeProvider =
    NotifierProvider<ShoppingModeNotifier, ShoppingMode>(
      ShoppingModeNotifier.new,
    );

class ShoppingModeNotifier extends Notifier<ShoppingMode> {
  bool _chosen = false;

  @override
  ShoppingMode build() {
    final store = ref.read(shoppingModeStoreProvider);
    unawaited(
      store.read().then((mode) {
        if (!_chosen && ref.mounted) state = mode;
      }),
    );
    return ShoppingMode.plan;
  }

  /// Applies [mode] at once and keeps it for the next start.
  void select(ShoppingMode mode) {
    _chosen = true;
    state = mode;
    unawaited(ref.read(shoppingModeStoreProvider).write(mode));
  }
}
