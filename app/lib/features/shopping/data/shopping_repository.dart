import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// Reads `api.shopping_items`, writes through `api.shopping_*`. Every write names the
/// acting profile; the server validates it against the device.
class ShoppingRepository {
  const ShoppingRepository(this._api);

  final ApiClient _api;

  Future<Result<List<ShoppingItem>>> items() => _api.select(
    'shopping_items',
    parse: ShoppingItem.fromJson,
    build: (q) => q.order('checked').order('created_at'),
  );

  Future<Result<void>> add({
    required String? actor,
    required String name,
    String? quantity,
  }) => _api.rpc(
    'shopping_add_item',
    params: {'p_actor': actor, 'p_name': name, 'p_quantity': quantity},
    parse: (_) {},
  );

  Future<Result<void>> toggle({
    required String? actor,
    required String itemId,
  }) => _api.rpc(
    'shopping_toggle_item',
    params: {'p_actor': actor, 'p_item': itemId},
    parse: (_) {},
  );

  Future<Result<ShoppingTrip>> finish({required String? actor}) => _api.rpc(
    'shopping_finish',
    params: {'p_actor': actor},
    parse: (json) => ShoppingTrip.fromJson(json! as Map<String, dynamic>),
  );
}

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepository(ref.watch(apiClientProvider)),
);
