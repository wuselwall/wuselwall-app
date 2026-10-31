import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/edge_fade.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/coop_handoff_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/domain/retailer_handoff.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/coop_sheet.dart';
import 'package:wuselwall/features/shopping/ui/shopping_actions.dart';
import 'package:wuselwall/features/shopping/ui/shopping_widgets.dart';

/// The shared lists: pick a list, tap tiles to add, plan the items; "Einkaufen gehen"
/// opens the shopping trip page ([Routes.shoppingTrip]), a full screen of tick rows. Every
/// item change goes through the offline outbox and shows at once; creating a list and
/// moving the default need the network (specs/07#offline). The wall keeps one combined
/// view (tiles and ticks) and never leaves it.
class ShoppingBody extends ConsumerStatefulWidget {
  const ShoppingBody({super.key});

  @override
  ConsumerState<ShoppingBody> createState() => _ShoppingBodyState();
}

class _ShoppingBodyState extends ConsumerState<ShoppingBody>
    with ShoppingActions<ShoppingBody> {
  final _search = TextEditingController();

  /// The trip page has been opened for the mode now in force (by the button, or because
  /// the device was closed in the store): it must not open twice.
  bool _tripOpened = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _newList() async {
    final result = await showDialog<({String name, String kind})>(
      context: context,
      builder: (_) => const _NewListDialog(),
    );
    if (result == null) return;
    final id = await run(
      () => repo.createList(actor: actor, name: result.name, kind: result.kind),
    );
    if (id != null) ref.read(selectedListIdProvider.notifier).select(id);
  }

  /// "Einkaufen gehen": the mode is shopping from now on, and the trip is a page of its
  /// own, without the app bar and the navigation.
  void _startShopping() {
    _tripOpened = true;
    ref.read(shoppingModeProvider.notifier).select(ShoppingMode.shop);
    unawaited(context.push<void>(Routes.shoppingTrip));
  }

  /// "An Coop senden" (specs/29): the open items of [items] go to this device's Coop
  /// list, through the Coop sheet; one line says how it went.
  Future<void> _sendToCoop(List<ShoppingItem> items) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(coopSheetLauncherProvider)(
      context,
      items: handoffItems(items),
    );
    if (outcome == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(coopOutcomeMessage(l10n, outcome))),
      );
  }

  /// The device was left in the store: the trip is where it reopens. Once, after the
  /// frame, and only while this tab is the page in front (not under the trip already).
  void _reopenTrip() {
    if (_tripOpened) return;
    _tripOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || GoRouter.maybeOf(context) == null) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      unawaited(context.push<void>(Routes.shoppingTrip));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kiosk = ref.watch(uiRegisterProvider) == UiRegister.kiosk;
    final current = ref.watch(currentListProvider);
    // Capture while mounted: pending ticks flush even when this page leaves.
    final sync = this.sync;
    final actor = this.actor;
    final pending = ref.watch(shoppingPendingProvider);
    final coop = !kiosk && ref.watch(coopHandoffAvailableProvider);
    ref.listen(shoppingSyncProvider.select((s) => s.rejection), (_, next) {
      if (next != null && mounted) context.showFailure(next.failure);
    });
    if (!kiosk) {
      if (ref.watch(shoppingModeProvider) == ShoppingMode.shop) {
        _reopenTrip();
      } else {
        _tripOpened = false;
      }
    }

    return AsyncValueView<ShoppingList?>(
      value: current,
      onRetry: refreshList,
      data: (list) {
        if (list == null) {
          return EmptyView(
            message: l10n.shoppingEmpty,
            actions: [
              if (!kiosk)
                FilledButton.icon(
                  onPressed: _newList,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.shoppingNewList),
                ),
            ],
          );
        }
        final items = shoppingItemsOf(ref, list.id);
        final hasTiles = (ref.watch(shoppingCatalogProvider).value ?? const [])
            .any((c) => c.listId == list.id);
        final anyOpen = items.value?.any((i) => !i.checked) ?? false;
        final anyTicked = items.value?.any((i) => i.checked) ?? false;
        // A4: one explicit traversal order for the whole body (lists, search,
        // catalogue, items, bottom bar, then whatever sits outside this widget),
        // instead of whatever ambient order the nested scrollables would otherwise
        // produce.
        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          // A tap on empty space drops the search field's focus (and its keyboard);
          // taps on tiles and rows win the gesture arena and are not taken.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Column(
              children: [
                if (!kiosk)
                  _ListSwitcher(
                    selected: list.id,
                    onNew: _newList,
                    onEdit: () =>
                        context.push(Routes.shoppingListEdit, extra: list.id),
                  ),
                if (pending > 0) ShoppingPendingBanner(count: pending),
                // A5: the picker and the item list share one scrollable instead of the
                // picker taking a fixed natural height and the list getting whatever
                // is left over — at 200% text on a 320 px phone that leftover was
                // ~0 px, so the list was unreachable even though nothing was lost.
                Expanded(
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(
                        child: ShoppingTilePicker(
                          key: const ValueKey('shopping-tiles'),
                          list: list,
                          items: items.value ?? const [],
                          search: _search,
                          showSearch: !kiosk,
                          busy: busy,
                          onAdd: (name) {
                            _search.clear();
                            unawaited(addName(name, list));
                          },
                          onLongPress: (name) => tileSheet(name, list),
                        ),
                      ),
                      const SliverToBoxAdapter(child: Divider(height: 1)),
                      // An empty list takes the rest of the screen, its line centred
                      // there; the tiles above are the way to add the first item.
                      // Wusel peeks here (specs/25), never among the tiles themselves.
                      if (items.value?.isEmpty ?? false)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyView(
                            message: hasTiles
                                ? l10n.shoppingEmptyTapTile
                                : l10n.shoppingEmpty,
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
                              // The wall: today's combined row (ticks and "−").
                              mode: kiosk ? null : ShoppingMode.plan,
                              onToggle: (i) => sync.check(
                                actor: actor,
                                itemId: i.id,
                                checked: !i.checked,
                              ),
                              onLess: (i) => sync.adjustCount(
                                actor: actor,
                                itemId: i.id,
                                delta: -1,
                              ),
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
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(Tokens.space4),
                    child: Row(
                      children: [
                        if (!kiosk)
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(900),
                            child: IconButton(
                              tooltip: l10n.shoppingHistory,
                              onPressed: () =>
                                  context.push(Routes.shoppingHistory),
                              icon: const Icon(Icons.history),
                            ),
                          ),
                        if (coop)
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(900.5),
                            child: IconButton(
                              key: const ValueKey('shopping-coop-send'),
                              tooltip: l10n.coopSend,
                              onPressed: () =>
                                  _sendToCoop(items.value ?? const []),
                              icon: const Icon(Icons.send_outlined),
                            ),
                          ),
                        Expanded(
                          child: FocusTraversalOrder(
                            order: const NumericFocusOrder(901),
                            child: kiosk
                                ? FilledButton.icon(
                                    onPressed: anyTicked
                                        ? () => unawaited(finishTrip(list))
                                        : null,
                                    icon: const Icon(
                                      Icons.shopping_cart_checkout,
                                    ),
                                    label: Text(l10n.shoppingFinish),
                                  )
                                : FilledButton.icon(
                                    key: const ValueKey('shopping-start'),
                                    onPressed: anyOpen ? _startShopping : null,
                                    icon: const Icon(
                                      Icons.shopping_cart_checkout,
                                    ),
                                    label: Text(l10n.shoppingStartShopping),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ListSwitcher extends ConsumerWidget {
  const _ListSwitcher({
    required this.selected,
    required this.onNew,
    required this.onEdit,
  });

  final String selected;
  final VoidCallback onNew;

  /// "Liste bearbeiten" for the selected list: the pencil, or a long press on its chip.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lists = sortedBy(
      ref.watch(shoppingListsProvider).value ?? const <ShoppingList>[],
      (l) => l.sortOrder,
    );
    final touch = ref.watch(uiRegisterProvider).touchTarget;
    return SizedBox(
      // A6: tall enough for the touch target plus the row's own padding — the chips
      // used to be capped at 40 px by this box regardless of their own minimum.
      height: touch + Tokens.space2 * 2,
      child: Row(
        children: [
          // The row fades at the edge while more chips lie beyond it, so a cut
          // chip reads as "scroll for more" (round-3 review K).
          Expanded(
            child: EdgeFade(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.space4,
                  vertical: Tokens.space2,
                ),
                children: [
                  for (final (i, l) in lists.indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: Tokens.space2),
                      child: FocusTraversalOrder(
                        order: NumericFocusOrder(i.toDouble()),
                        child: _ListChip(
                          key: ValueKey(l.id),
                          minHeight: touch,
                          onLongPress: l.id == selected ? onEdit : null,
                          selected: l.id == selected,
                          avatar: l.isDefault
                              ? const Icon(Icons.star, size: 18)
                              : null,
                          label: l.openCount == 0
                              ? l.name
                              : '${l.name} · ${l.openCount}',
                          onSelected: () => ref
                              .read(selectedListIdProvider.notifier)
                              .select(l.id),
                        ),
                      ),
                    ),
                  FocusTraversalOrder(
                    order: NumericFocusOrder(lists.length.toDouble()),
                    child: _NewListChip(
                      minHeight: touch,
                      label: l10n.shoppingNewList,
                      onPressed: onNew,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Outside the scrolling row, so it is always in reach on a phone.
          FocusTraversalOrder(
            order: NumericFocusOrder(lists.length + 1),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: Tokens.space2),
              child: IconButton(
                key: const ValueKey('edit-list'),
                tooltip: l10n.shoppingEditList,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One list's `ChoiceChip`, at least the register's touch target (A6) and with a
/// keyboard-focus ring at 3:1 contrast or better (A4) instead of Material's default
/// highlight, which measured 1.32:1 here.
class _ListChip extends StatefulWidget {
  const _ListChip({
    super.key,
    required this.minHeight,
    required this.selected,
    required this.avatar,
    required this.label,
    required this.onSelected,
    required this.onLongPress,
  });

  final double minHeight;
  final bool selected;
  final Widget? avatar;
  final String label;
  final VoidCallback onSelected;
  final VoidCallback? onLongPress;

  @override
  State<_ListChip> createState() => _ListChipState();
}

class _ListChipState extends State<_ListChip> {
  late final _focusNode = FocusNode(
    debugLabel: 'shopping-list:${widget.label}',
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: ShoppingFocusRing(
        focusNode: _focusNode,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.minHeight),
          child: ChoiceChip(
            focusNode: _focusNode,
            selected: widget.selected,
            avatar: widget.avatar,
            label: Text(widget.label),
            onSelected: (_) => widget.onSelected(),
          ),
        ),
      ),
    );
  }
}

/// The "new list" `ActionChip`, same touch target and focus ring as [_ListChip].
class _NewListChip extends StatefulWidget {
  const _NewListChip({
    required this.minHeight,
    required this.label,
    required this.onPressed,
  });

  final double minHeight;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_NewListChip> createState() => _NewListChipState();
}

class _NewListChipState extends State<_NewListChip> {
  final _focusNode = FocusNode(debugLabel: 'shopping-new-list');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShoppingFocusRing(
      focusNode: _focusNode,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.minHeight),
        child: ActionChip(
          focusNode: _focusNode,
          avatar: const Icon(Icons.add, size: 18),
          label: Text(widget.label),
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

class _NewListDialog extends StatefulWidget {
  const _NewListDialog();

  @override
  State<_NewListDialog> createState() => _NewListDialogState();
}

class _NewListDialogState extends State<_NewListDialog> {
  final _name = TextEditingController();
  String _kind = 'supermarket';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.shoppingNewList),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(labelText: l10n.shoppingListName),
          ),
          const SizedBox(height: Tokens.space4),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: InputDecoration(labelText: l10n.shoppingListKind),
            items: [
              DropdownMenuItem(
                value: 'supermarket',
                child: Text(l10n.shoppingKindSupermarket),
              ),
              DropdownMenuItem(
                value: 'drugstore',
                child: Text(l10n.shoppingKindDrugstore),
              ),
              DropdownMenuItem(
                value: 'hardware',
                child: Text(l10n.shoppingKindHardware),
              ),
              DropdownMenuItem(
                value: 'other',
                child: Text(l10n.shoppingKindOther),
              ),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, (name: name, kind: _kind));
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
