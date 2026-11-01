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
                    // The title and, at the top end, the trip's one-time action: ending
                    // it. Up here it is out of the thumb's way, so it is never pressed
                    // by accident between two ticks; the confirm dialog stays.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.space4,
                        Tokens.space2,
                        Tokens.space4,
                        Tokens.space2,
                      ),
                      child: Row(
                        spacing: Tokens.space2,
                        children: [
                          Expanded(
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
                          // Tonal, not filled: quieter than the primary button below.
                          // It may take two thirds of the row; past that its label gives
                          // way, and the title before it.
                          Flexible(
                            flex: 2,
                            child: FilledButton.tonal(
                              key: const ValueKey('shopping-finish'),
                              style: FilledButton.styleFrom(
                                minimumSize: Size(0, touch),
                              ),
                              onPressed: anyTicked
                                  ? () => unawaited(_finish(list))
                                  : null,
                              child: _IconLabel(
                                icon: Icons.shopping_cart_checkout,
                                label: l10n.shoppingFinish,
                              ),
                            ),
                          ),
                        ],
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
        // Bottom: planning mode at the start, adding at the end as the primary button;
        // adding is the frequent action in the aisle, ending the trip the rare one.
        bottomNavigationBar: list == null
            ? null
            : SafeArea(
                child: ContentWidth(
                  child: Padding(
                    padding: const EdgeInsets.all(Tokens.space4),
                    child: Row(
                      spacing: Tokens.space2,
                      children: [
                        // The mode button gives way first: the primary button keeps
                        // its full label on a narrow phone, and the long French and
                        // Spanish mode labels ellipsise instead of overflowing.
                        Expanded(
                          // heightFactor: the bar is laid out with a loose height, and
                          // an Align without it would fill that height and squeeze
                          // the list above to nothing.
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            heightFactor: 1,
                            child: TextButton(
                              key: const ValueKey('shopping-mode-plan'),
                              // No minimum width: in its flexible slot the button
                              // shrinks to its icon and an ellipsis before anything
                              // overflows.
                              style: TextButton.styleFrom(
                                minimumSize: Size(0, touch),
                              ),
                              onPressed: _leave,
                              child: _IconLabel(
                                icon: Icons.edit_note,
                                label: l10n.shoppingModePlan,
                              ),
                            ),
                          ),
                        ),
                        FilledButton(
                          key: const ValueKey('shopping-add-in-store'),
                          style: FilledButton.styleFrom(
                            minimumSize: Size(0, touch),
                          ),
                          onPressed: () => unawaited(addInStore(list)),
                          child: _IconLabel(
                            icon: Icons.add,
                            label: l10n.shoppingAddInStore,
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

/// A button's icon and label where the label may give way (ellipsis) on a narrow
/// phone; the `.icon` constructors keep their label rigid and overflow instead.
class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: Tokens.space2,
    children: [
      Icon(icon, size: 18),
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
