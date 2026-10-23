import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';

/// Reads `api.shopping_*` views, writes through `api.shopping_*` functions. Every write
/// names the acting profile; the server validates it against the device.
///
/// Item changes and finishing a trip go through the outbox and [apply]
/// (specs/07#offline); creating a list and moving the default stay online-only.
class ShoppingRepository {
  const ShoppingRepository(this._api);

  final ApiClient _api;

  /// Open items of every list; the app filters by list.
  Future<Result<List<ShoppingItem>>> items() => _api.select(
    'shopping_items',
    parse: ShoppingItem.fromJson,
    build: (q) => q.order('checked').order('created_at'),
  );

  /// The meals behind one item (FR-3.7). Online only: the item's sheet shows none when
  /// this fails, so it never blocks the list.
  Future<Result<List<ShoppingItemMeal>>> itemMeals(String itemId) =>
      _api.select(
        'shopping_item_meals',
        parse: ShoppingItemMeal.fromJson,
        build: (q) => q.eq('item_id', itemId).order('on_date'),
      );

  Future<Result<List<ShoppingList>>> lists() => _api.select(
    'shopping_lists',
    parse: ShoppingList.fromJson,
    build: (q) => q.order('sort_order'),
  );

  Future<Result<List<ShoppingCategory>>> categories() => _api.select(
    'shopping_categories',
    parse: ShoppingCategory.fromJson,
    build: (q) => q.order('sort_order'),
  );

  Future<Result<List<CatalogEntry>>> catalog() => _api.select(
    'shopping_catalog',
    parse: CatalogEntry.fromJson,
    build: (q) => q.order('purchase_count', ascending: false),
  );

  /// Everything the list screen shows, fetched together: the outbox's mirror.
  Future<Result<ShoppingSnapshot>> snapshot() async {
    final (items, lists, categories, catalog) = await (
      this.items(),
      this.lists(),
      this.categories(),
      this.catalog(),
    ).wait;
    for (final r in [items, lists, categories, catalog]) {
      if (r case Err(:final failure)) return Err(failure);
    }
    return Ok(
      ShoppingSnapshot(
        items: items.valueOrNull!,
        lists: lists.valueOrNull!,
        categories: categories.valueOrNull!,
        catalog: catalog.valueOrNull!,
      ),
    );
  }

  /// Sends a batch of the outbox to `api.shopping_apply`. [actor] establishes the
  /// device; each op carries its own acting profile.
  Future<Result<ApplyResult>> apply({
    required String? actor,
    required List<ShoppingOp> ops,
  }) => _api.rpc(
    'shopping_apply',
    params: {
      'p_actor': actor,
      'p_ops': [for (final op in ops) op.toJson()],
    },
    parse: (json) => ApplyResult.fromJson(json! as Map<String, dynamic>),
  );

  Future<Result<List<ShoppingTrip>>> trips(String listId) => _api.select(
    'shopping_trips',
    parse: ShoppingTrip.fromJson,
    build: (q) => q
        .eq('list_id', listId)
        .order('finished_at', ascending: false)
        .limit(50),
  );

  Future<Result<List<TripItem>>> tripItems(String tripId) => _api.select(
    'shopping_trip_items',
    parse: TripItem.fromJson,
    build: (q) => q.eq('trip_id', tripId).order('name'),
  );

  /// Adds [name] to [listId] (the default list when null). A name that is already open
  /// on the list raises its count instead. Returns the item's id.
  Future<Result<String>> add({
    required String? actor,
    required String name,
    String? quantity,
    String? listId,
  }) => _api.rpc(
    'shopping_add_item',
    params: {
      'p_actor': actor,
      'p_name': name,
      'p_quantity': quantity,
      'p_list': listId,
    },
    parse: (id) => id! as String,
  );

  Future<Result<void>> toggle({
    required String? actor,
    required String itemId,
  }) => _api.rpc(
    'shopping_toggle_item',
    params: {'p_actor': actor, 'p_item': itemId},
    parse: (_) {},
  );

  /// +1 or -1; reaching zero removes the item.
  Future<Result<void>> adjustCount({
    required String? actor,
    required String itemId,
    required int delta,
  }) => _api.rpc(
    'shopping_adjust_count',
    params: {'p_actor': actor, 'p_item': itemId, 'p_delta': delta},
    parse: (_) {},
  );

  Future<Result<void>> setSpec({
    required String? actor,
    required String itemId,
    required String? text,
  }) => _api.rpc(
    'shopping_set_item_spec',
    params: {'p_actor': actor, 'p_item': itemId, 'p_text': text},
    parse: (_) {},
  );

  Future<Result<void>> setCategory({
    required String? actor,
    required String itemId,
    required String? categoryId,
  }) => _api.rpc(
    'shopping_set_category',
    params: {'p_actor': actor, 'p_item': itemId, 'p_category': categoryId},
    parse: (_) {},
  );

  /// [kind] seeds the categories: `supermarket`, `drugstore`, `hardware` or `other`.
  Future<Result<String>> createList({
    required String? actor,
    required String name,
    required String kind,
  }) => _api.rpc(
    'shopping_list_create',
    params: {'p_actor': actor, 'p_name': name, 'p_kind': kind},
    parse: (id) => id! as String,
  );

  Future<Result<void>> setDefaultList({
    required String? actor,
    required String listId,
  }) => _api.rpc(
    'shopping_list_set_default',
    params: {'p_actor': actor, 'p_list': listId},
    parse: (_) {},
  );

  Future<Result<void>> renameList({
    required String? actor,
    required String listId,
    required String name,
  }) => _api.rpc(
    'shopping_list_update',
    params: {'p_actor': actor, 'p_list': listId, 'p_name': name},
    parse: (_) {},
  );

  /// Never the default list; its open items move there (guardians only).
  Future<Result<void>> deleteList({
    required String? actor,
    required String listId,
  }) => _api.rpc(
    'shopping_list_delete',
    params: {'p_actor': actor, 'p_list': listId},
    parse: (_) {},
  );

  /// A new category at the end of the walk ([categoryId] null), or a new name for one.
  Future<Result<String>> saveCategory({
    required String? actor,
    required String listId,
    String? categoryId,
    required String name,
  }) => _api.rpc(
    'shopping_category_save',
    params: {
      'p_actor': actor,
      'p_list': listId,
      'p_category': categoryId,
      'p_name': name,
    },
    parse: (id) => id! as String,
  );

  /// Its items become uncategorised (guardians only).
  Future<Result<void>> deleteCategory({
    required String? actor,
    required String categoryId,
  }) => _api.rpc(
    'shopping_category_delete',
    params: {'p_actor': actor, 'p_category': categoryId},
    parse: (_) {},
  );

  Future<Result<void>> reorderCategories({
    required String? actor,
    required String listId,
    required List<String> categoryIds,
  }) => _api.rpc(
    'shopping_categories_reorder',
    params: {'p_actor': actor, 'p_list': listId, 'p_category_ids': categoryIds},
    parse: (_) {},
  );

  /// A tile's name and category; a null keeps the value.
  Future<Result<void>> updateCatalogItem({
    required String? actor,
    required String itemId,
    String? name,
    String? categoryId,
  }) => _api.rpc(
    'catalog_item_update',
    params: {
      'p_actor': actor,
      'p_item': itemId,
      'p_name': name,
      'p_category': categoryId,
    },
    parse: (_) {},
  );

  /// "Nicht mehr vorschlagen": the tile goes, the history keeps its text (guardians only).
  Future<Result<void>> deleteCatalogItem({
    required String? actor,
    required String itemId,
  }) => _api.rpc(
    'catalog_item_delete',
    params: {'p_actor': actor, 'p_item': itemId},
    parse: (_) {},
  );

  Future<Result<ShoppingFinishResult>> finish({
    required String? actor,
    String? listId,
  }) => _api.rpc(
    'shopping_finish',
    params: {'p_actor': actor, 'p_list': listId},
    parse: (json) =>
        ShoppingFinishResult.fromJson(json! as Map<String, dynamic>),
  );
}

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepository(ref.watch(apiClientProvider)),
);
