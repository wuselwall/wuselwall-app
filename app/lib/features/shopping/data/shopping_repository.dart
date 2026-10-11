import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// Reads `api.shopping_*` views, writes through `api.shopping_*` functions. Every write
/// names the acting profile; the server validates it against the device.
class ShoppingRepository {
  const ShoppingRepository(this._api);

  final ApiClient _api;

  /// Open items of every list; the app filters by list.
  Future<Result<List<ShoppingItem>>> items() => _api.select(
    'shopping_items',
    parse: ShoppingItem.fromJson,
    build: (q) => q.order('checked').order('created_at'),
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
