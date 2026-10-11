import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// The active list, kept live: a change on any device re-fetches within a moment
/// (NFR-5). Fetching again, rather than patching, means a missed message can never
/// leave the list wrong.
final shoppingItemsProvider = FutureProvider.autoDispose<List<ShoppingItem>>((
  ref,
) async {
  final household = ref.watch(deviceProvider).value?.householdId;
  if (household != null) {
    refreshOnInvalidation(ref, householdId: household, topic: 'shopping');
  }
  return (await ref.watch(shoppingRepositoryProvider).items()).unwrap();
});
