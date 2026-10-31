import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/shopping_actions.dart';
import 'package:wuselwall/features/shopping/ui/shopping_widgets.dart';

/// Below this width the add button shrinks to its icon, so three controls fit the bar.
const _narrowBar = 400.0;

/// The shopping trip (2026-10-31): the list as tick rows in walking order, on a screen
/// of its own — no app bar, no navigation — so the thumb has the store to itself. The
/// bar at the bottom adds a forgotten item, goes back to planning, or ends the trip.
/// The mode is kept on the device, so a phone closed in the store reopens here; leaving
/// by any way (Planen, the system back, the end of the trip) makes it planning again.
class ShoppingTripPage extends ConsumerStatefulWidget {
  const ShoppingTripPage({super.key});

  @override
  ConsumerState<ShoppingTripPage> createState() => _ShoppingTripPageState();
}

class _ShoppingTripPageState extends ConsumerState<ShoppingTripPage>
    with ShoppingActions<ShoppingTripPage> {
  /// Planning again, and off this page.
  void _leave() {
    ref.read(shoppingModeProvider.notifier).select(ShoppingMode.plan);
    context.pop();
  }

  Future<void> _finish(ShoppingList list) async {
    if (await finishTrip(list) && mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = ref.watch(currentListProvider);
    final list = current.value;
    final pending = ref.watch(shoppingPendingProvider);
    ref.listen(shoppingSyncProvider.select((s) => s.rejection), (_, next) {
      if (next != null && mounted) context.showFailure(next.failure);
    });
    final items = list == null
        ? const AsyncData<List<ShoppingItem>>([])
        : shoppingItemsOf(ref, list.id);
    final openCount = items.value?.where((i) => !i.checked).length ?? 0;
    final anyTicked = items.value?.any((i) => i.checked) ?? false;
    final touch = ref.watch(uiRegisterProvider).touchTarget;
    final narrow = MediaQuery.sizeOf(context).width < _narrowBar;
    // Captured: pending ticks flush even when this page leaves.
    final sync = this.sync;
    final actor = this.actor;

    return PopScope(
      // The system back and the swipe leave the trip like the button does.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(shoppingModeProvider.notifier).select(ShoppingMode.plan);
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ContentWidth(
            child: AsyncValueView<ShoppingList?>(
              value: current,
              onRetry: refreshList,
              data: (list) {
                if (list == null) {
                  return EmptyView(message: l10n.shoppingEmpty);
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.space4,
                        Tokens.space3,
                        Tokens.space4,
                        Tokens.space2,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.shoppingTripTitle(list.name, openCount),
                            key: const ValueKey('shopping-trip-title'),
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    if (pending > 0) ShoppingPendingBanner(count: pending),
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          if (items.value?.isEmpty ?? false)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: EmptyView(
                                message: l10n.shoppingShopEmpty,
                                scrolls: false,
                              ),
                            )
                          else
                            SliverToBoxAdapter(
                              child: AsyncValueView<List<ShoppingItem>>(
                                value: items,
                                onRetry: refreshList,
                                data: (open) => ShoppingItemList(
                                  items: open,
                                  listId: list.id,
                                  mode: ShoppingMode.shop,
                                  onToggle: (i) => sync.check(
                                    actor: actor,
                                    itemId: i.id,
                                    checked: !i.checked,
                                  ),
                                  onLess: (_) {},
                                  onEdit: editItem,
                                  onRemove: canRemove ? removeItem : null,
                                  onTripDone: (bought) =>
                                      celebrateTrip(list.id, bought),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: list == null
            ? null
            : SafeArea(
                child: ContentWidth(
                  child: Padding(
                    padding: const EdgeInsets.all(Tokens.space4),
                    child: Row(
                      spacing: Tokens.space2,
                      children: [
                        if (narrow)
                          IconButton.outlined(
                            key: const ValueKey('shopping-add-in-store'),
                            tooltip: l10n.shoppingAddInStore,
                            style: IconButton.styleFrom(
                              minimumSize: Size.square(touch < 48 ? 48 : touch),
                            ),
                            onPressed: () => unawaited(addInStore(list)),
                            icon: const Icon(Icons.add),
                          )
                        else
                          OutlinedButton.icon(
                            key: const ValueKey('shopping-add-in-store'),
                            onPressed: () => unawaited(addInStore(list)),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.shoppingAddInStore),
                          ),
                        // On a narrow phone the label alone: the icon would push the
                        // longer French and Spanish labels off the screen.
                        if (narrow)
                          TextButton(
                            key: const ValueKey('shopping-mode-plan'),
                            onPressed: _leave,
                            child: Text(l10n.shoppingModePlan),
                          )
                        else
                          TextButton.icon(
                            key: const ValueKey('shopping-mode-plan'),
                            onPressed: _leave,
                            icon: const Icon(Icons.edit_note),
                            label: Text(l10n.shoppingModePlan),
                          ),
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('shopping-finish'),
                            style: narrow
                                ? FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Tokens.space3,
                                    ),
                                  )
                                : null,
                            onPressed: anyTicked
                                ? () => unawaited(_finish(list))
                                : null,
                            // The label may take two lines on a narrow phone (the
                            // Spanish one is long) instead of running off the screen.
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: Tokens.space2,
                              children: [
                                const Icon(Icons.shopping_cart_checkout),
                                Flexible(
                                  child: Text(
                                    l10n.shoppingFinish,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
