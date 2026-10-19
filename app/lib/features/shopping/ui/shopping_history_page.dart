import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

final _tripsProvider = FutureProvider.autoDispose
    .family<List<ShoppingTrip>, String>((ref, listId) async {
      return (await ref.watch(shoppingRepositoryProvider).trips(listId))
          .unwrap();
    });

final _tripItemsProvider = FutureProvider.autoDispose
    .family<List<TripItem>, String>((ref, tripId) async {
      return (await ref.watch(shoppingRepositoryProvider).tripItems(tripId))
          .unwrap();
    });

/// Finished trips of the current list, newest first. A trip is every item one
/// "Einkauf beenden" stamped together; there is no separate entity to keep in sync.
class ShoppingHistoryPage extends ConsumerWidget {
  const ShoppingHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final list = ref.watch(currentListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${l10n.shoppingHistory}${list.value == null ? '' : ' · ${list.value!.name}'}',
        ),
      ),
      body: AsyncValueView<ShoppingList?>(
        value: list,
        onRetry: () => ref.read(shoppingSyncProvider.notifier).sync(),
        data: (current) {
          if (current == null) {
            return EmptyView(message: l10n.shoppingHistoryEmpty);
          }
          return AsyncValueView<List<ShoppingTrip>>(
            value: ref.watch(_tripsProvider(current.id)),
            onRetry: () => ref.invalidate(_tripsProvider(current.id)),
            data: (trips) => trips.isEmpty
                ? EmptyView(message: l10n.shoppingHistoryEmpty)
                : ListView(
                    children: [for (final t in trips) _TripTile(trip: t)],
                  ),
          );
        },
      ),
    );
  }
}

class _TripTile extends ConsumerWidget {
  const _TripTile({required this.trip});

  final ShoppingTrip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(trip.finishedAt.toLocal());
    return ExpansionTile(
      title: Text(date),
      subtitle: Text(context.l10n.shoppingTripItems(trip.itemCount)),
      children: [
        Consumer(
          builder: (context, ref, _) {
            final items = ref.watch(_tripItemsProvider(trip.id));
            return items.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => ErrorView(error: e),
              data: (list) => Column(
                children: [
                  for (final i in list)
                    ListTile(
                      dense: true,
                      title: Text(i.name),
                      trailing: Text(
                        [
                          if (i.count > 1) '${i.count} ×',
                          ?i.quantity,
                        ].join(' '),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
