import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/confetti.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/ui/text_prompt.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// The shared lists: pick a list, tap tiles to add, tick off while shopping, finish the
/// trip. Every item change goes through the offline outbox and shows at once; creating a
/// list and moving the default need the network (specs/07#offline).
class ShoppingBody extends ConsumerStatefulWidget {
  const ShoppingBody({super.key});

  @override
  ConsumerState<ShoppingBody> createState() => _ShoppingBodyState();
}

class _ShoppingBodyState extends ConsumerState<ShoppingBody> {
  final _search = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String? get _actor => ref.read(actingProfileProvider);
  ShoppingRepository get _repo => ref.read(shoppingRepositoryProvider);
  ShoppingSync get _sync => ref.read(shoppingSyncProvider.notifier);

  void _refresh() => unawaited(_sync.sync());

  /// For the online-only writes: lists and the default.
  Future<T?> _run<T>(Future<Result<T>> Function() action) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return null;
    setState(() => _busy = false);
    return result.when(
      ok: (value) {
        _refresh();
        return value;
      },
      err: (failure) {
        context.showFailure(failure);
        return null;
      },
    );
  }

  Future<void> _addName(String name, ShoppingList list) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _search.clear();
    await _sync.add(actor: _actor, listId: list.id, name: trimmed);
  }

  /// Long press on a tile: edit the item if it is on the list, else add it first.
  Future<void> _addAndEdit(String name, ShoppingList list) async {
    ShoppingItem? open() => (ref.read(shoppingItemsProvider).value ?? const [])
        .where(
          (i) =>
              i.listId == list.id &&
              !i.checked &&
              fold(i.name) == fold(name.trim()),
        )
        .firstOrNull;
    if (open() == null) {
      await _sync.add(actor: _actor, listId: list.id, name: name.trim());
    }
    final item = open();
    if (item != null && mounted) await _edit(item);
  }

  /// Long press on a tile: the item's note, or the tile itself (its name; "Nicht mehr
  /// vorschlagen"). A typed name that is no tile yet goes straight to the note.
  Future<void> _tileSheet(String name, ShoppingList list) async {
    final l10n = context.l10n;
    final tile = (ref.read(shoppingCatalogProvider).value ?? const [])
        .where((c) => c.listId == list.id && c.foldedName == fold(name))
        .firstOrNull;
    if (tile == null) return _addAndEdit(name, list);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                tile.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              key: const ValueKey('tile-add-edit'),
              leading: const Icon(Icons.edit_note),
              title: Text(l10n.shoppingTileAddEdit),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              key: const ValueKey('tile-rename'),
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(l10n.shoppingTileRename),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              key: const ValueKey('tile-forget'),
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(l10n.shoppingTileForget),
              subtitle: Text(l10n.shoppingTileForgetHelp),
              onTap: () => Navigator.pop(context, 'forget'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'edit':
        await _addAndEdit(name, list);
      case 'rename':
        final newName = await askText(
          context,
          title: l10n.shoppingTileRename,
          label: l10n.shoppingListName,
          initial: tile.name,
          maxLength: 120,
          fieldKey: const ValueKey('tile-name'),
        );
        final trimmed = newName?.trim() ?? '';
        if (trimmed.isEmpty || trimmed == tile.name || !mounted) return;
        await _run(
          () => _repo.updateCatalogItem(
            actor: _actor,
            itemId: tile.id,
            name: trimmed,
          ),
        );
      case 'forget':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l10n.shoppingTileForgetConfirm(tile.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.shoppingTileForget),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        if (!await ensureGuardian(context, ref) || !mounted) return;
        await _run(
          () => _repo.deleteCatalogItem(actor: _actor, itemId: tile.id),
        );
      default:
        return;
    }
  }

  Future<void> _edit(ShoppingItem item) async {
    final categories = (ref.read(shoppingCategoriesProvider).value ?? const [])
        .where((c) => c.listId == item.listId)
        .toList();
    final result = await showDialog<_ItemEdit>(
      context: context,
      builder: (_) => _EditItemDialog(
        item: item,
        categories: categories,
        canRemove: _canRemove,
      ),
    );
    if (result == null) return;
    if (result.remove) {
      _remove(item);
      return;
    }
    if (result.spec != (item.quantity ?? '')) {
      await _sync.setSpec(actor: _actor, itemId: item.id, text: result.spec);
    }
    if (result.categoryId != item.categoryId) {
      await _sync.setCategory(
        actor: _actor,
        itemId: item.id,
        categoryId: result.categoryId,
      );
    }
  }

  /// Adults take an item off the list; the children's register has no destructive
  /// action (specs/09), and the wall none at all.
  bool get _canRemove => ref.read(uiRegisterProvider) == UiRegister.adult;

  /// Takes [item] off the list, by a swipe or from its dialog (specs/09 "Gestures").
  /// It leaves the screen at once and goes to the server once its undo has passed, so
  /// an undo never has to rebuild it (who added it, the meals it came from).
  void _remove(ShoppingItem item) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Captured: the removal is sent even when this page has gone meanwhile.
    final sync = _sync;
    final actor = _actor;
    final removing = ref.read(_removingProvider.notifier)..add(item.id);
    var undone = false;
    messenger.hideCurrentSnackBar();
    final snack = messenger.showSnackBar(
      SnackBar(
        // It must close by itself: the removal is sent when it does. A screen
        // reader gets longer to reach the undo.
        persist: false,
        duration: Duration(
          seconds: MediaQuery.accessibleNavigationOf(context) ? 10 : 5,
        ),
        content: Text(l10n.shoppingItemRemoved(item.name)),
        action: SnackBarAction(
          label: l10n.shoppingUndo,
          onPressed: () {
            undone = true;
            removing.remove(item.id);
          },
        ),
      ),
    );
    unawaited(
      snack.closed.then((_) async {
        if (undone) return;
        // At zero the item is removed (specs/07 "count").
        await sync.adjustCount(
          actor: actor,
          itemId: item.id,
          delta: -item.count,
        );
        removing.remove(item.id);
      }),
    );
  }

  Future<void> _newList() async {
    final result = await showDialog<({String name, String kind})>(
      context: context,
      builder: (_) => const _NewListDialog(),
    );
    if (result == null) return;
    final id = await _run(
      () =>
          _repo.createList(actor: _actor, name: result.name, kind: result.kind),
    );
    if (id != null) ref.read(selectedListIdProvider.notifier).select(id);
  }

  /// The trip that bought [bought] on [listId] is done (specs/26 "Celebrations"): on a
  /// grown-up's phone a small, short burst over the list and a light haptic, never a
  /// sound. Once per trip, however it ends: the last item ticked, then the trip
  /// finished, is one moment. The burst asks [motionAllowed]; the haptic the night and
  /// `device.sounds`.
  void _celebrateTrip(String listId, Iterable<String> bought) {
    if (ref.read(uiRegisterProvider) != UiRegister.adult || bought.isEmpty) {
      return;
    }
    final celebration = ref.read(celebrationProvider);
    if (!celebration.claimMoment(Celebration.tripOf(listId, bought))) return;
    final ww = context.ww;
    showConfetti(
      context,
      colors: [
        for (final c in ref.read(wuselTuftsProvider)) ww.member(c).ink,
        ww.points,
      ],
      count: 24,
      duration: tripBurst,
    );
    unawaited(celebration.shoppingTrip());
  }

  Future<void> _finish(ShoppingList list) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.shoppingFinishConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.shoppingFinish),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final onList = (ref.read(shoppingItemsProvider).value ?? const [])
        .where((i) => i.listId == list.id)
        .toList();
    final bought = [
      for (final i in onList)
        if (i.checked) i.id,
    ];
    await _sync.finish(actor: _actor, listId: list.id);
    if (mounted) {
      context.showMessage(
        l10n.shoppingFinished(bought.length, onList.length - bought.length),
      );
      _celebrateTrip(list.id, bought);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kiosk = ref.watch(uiRegisterProvider) == UiRegister.kiosk;
    final current = ref.watch(currentListProvider);
    // Capture while mounted: pending ticks flush even when this page leaves.
    final sync = _sync;
    final actor = _actor;
    final pending = ref.watch(shoppingPendingProvider);
    ref.listen(shoppingSyncProvider.select((s) => s.rejection), (_, next) {
      if (next != null && mounted) context.showFailure(next.failure);
    });

    return AsyncValueView<ShoppingList?>(
      value: current,
      onRetry: _refresh,
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
        final all = ref.watch(shoppingItemsProvider);
        final removing = ref.watch(_removingProvider);
        final items = all.whenData(
          (v) => v
              .where((i) => i.listId == null || i.listId == list.id)
              .where((i) => !removing.contains(i.id))
              .toList(),
        );
        final hasTiles = (ref.watch(shoppingCatalogProvider).value ?? const [])
            .any((c) => c.listId == list.id);
        // A4: one explicit traversal order for the whole body (lists, search,
        // catalogue, items, finish, then whatever sits outside this widget), instead
        // of whatever ambient order the nested scrollables would otherwise produce.
        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Column(
            children: [
              if (!kiosk)
                _ListSwitcher(
                  selected: list.id,
                  onNew: _newList,
                  onEdit: () =>
                      context.push(Routes.shoppingListEdit, extra: list.id),
                ),
              if (pending > 0) _PendingBanner(count: pending),
              // A5: the picker and the item list share one scrollable instead of the
              // picker taking a fixed natural height and the list getting whatever is
              // left over — at 200% text on a 320 px phone that leftover was ~0 px, so
              // the list was unreachable even though nothing was actually lost.
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _TilePicker(
                        key: const ValueKey('shopping-tiles'),
                        list: list,
                        items: items.value ?? const [],
                        search: _search,
                        showSearch: !kiosk,
                        busy: _busy,
                        onAdd: (name) => _addName(name, list),
                        onLongPress: (name) => _tileSheet(name, list),
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider(height: 1)),
                    // An empty list takes the rest of the screen, its line centred
                    // there; the tiles above are the way to add the first item. Wusel
                    // peeks here (specs/25), never among the tiles themselves.
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
                          onRetry: _refresh,
                          data: (open) => _ItemList(
                            items: open,
                            listId: list.id,
                            onToggle: (i) => sync.check(
                              actor: actor,
                              itemId: i.id,
                              checked: !i.checked,
                            ),
                            onLess: (i) => _sync.adjustCount(
                              actor: _actor,
                              itemId: i.id,
                              delta: -1,
                            ),
                            onEdit: _edit,
                            onRemove: _canRemove ? _remove : null,
                            onTripDone: (bought) =>
                                _celebrateTrip(list.id, bought),
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
                      Expanded(
                        child: FocusTraversalOrder(
                          order: const NumericFocusOrder(901),
                          child: FilledButton.icon(
                            onPressed:
                                !(items.value?.any((i) => i.checked) ?? false)
                                ? null
                                : () => _finish(list),
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: Text(l10n.shoppingFinish),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown honestly rather than implied away: iOS sends nothing while the app is closed,
/// so changes made offline wait until it is next opened with a connection.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space4,
          vertical: Tokens.space2,
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 20,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: Tokens.space2),
            Expanded(
              child: Text(
                context.l10n.shoppingPending(count),
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
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
    final lists = ref.watch(shoppingListsProvider).value ?? const [];
    final touch = ref
        .watch(uiRegisterProvider)
        .touchTarget
        .clamp(48.0, double.infinity);
    return SizedBox(
      // A6: tall enough for the touch target plus the row's own padding — the chips
      // used to be capped at 40 px by this box regardless of their own minimum.
      height: touch + Tokens.space2 * 2,
      child: Row(
        children: [
          Expanded(
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
    return MergeSemantics(
      child: Semantics(
        onLongPress: widget.onLongPress,
        child: GestureDetector(
          excludeFromSemantics: true,
          onLongPress: widget.onLongPress,
          child: _FocusRing(
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
    return _FocusRing(
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

/// A visible keyboard-focus ring at 3:1 contrast or better against the surrounding
/// ground (WCAG 1.4.11). Listens to a [FocusNode] already owned by the wrapped
/// control instead of adding a focus stop of its own, and paints over the child
/// instead of reserving border space, so it never changes the child's layout size
/// (important here: several of these sit inside a `SliverList` that forces an exact
/// cross-axis extent on them).
class _FocusRing extends StatelessWidget {
  const _FocusRing({
    required this.focusNode,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final FocusNode focusNode;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final ringColor = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) => Stack(
        fit: StackFit.passthrough,
        children: [
          child!,
          if (focusNode.hasFocus)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(color: ringColor, width: 2.5),
                  ),
                ),
              ),
            ),
        ],
      ),
      child: child,
    );
  }
}

/// Recents and frequents before any input; typing narrows them; "neu anlegen" closes
/// the loop for names the catalogue does not know. On the wall there is no search field.
class _TilePicker extends ConsumerStatefulWidget {
  const _TilePicker({
    required this.list,
    required this.items,
    required this.search,
    required this.showSearch,
    required this.busy,
    required this.onAdd,
    required this.onLongPress,
    super.key,
  });

  final ShoppingList list;
  final List<ShoppingItem> items;
  final TextEditingController search;
  final bool showSearch;
  final bool busy;
  final void Function(String name) onAdd;
  final void Function(String name) onLongPress;

  @override
  ConsumerState<_TilePicker> createState() => _TilePickerState();
}

class _TilePickerState extends ConsumerState<_TilePicker> {
  final _searchFocus = FocusNode(debugLabel: 'shopping-search');

  @override
  void initState() {
    super.initState();
    widget.search.addListener(_changed);
  }

  @override
  void dispose() {
    widget.search.removeListener(_changed);
    _searchFocus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kiosk = ref.watch(uiRegisterProvider) == UiRegister.kiosk;
    final catalog = (ref.watch(shoppingCatalogProvider).value ?? const [])
        .where((c) => c.listId == widget.list.id)
        .toList();
    final categories = {
      for (final c
          in ref.watch(shoppingCategoriesProvider).value ??
              const <ShoppingCategory>[])
        c.id: c,
    };
    final query = widget.search.text.trim();
    final tiles = rankTiles(catalog, query);
    final folded = fold(query);
    final exact = tiles.any((t) => t.foldedName == folded);
    final width = kiosk ? 148.0 : 104.0;

    int countOf(String foldedName) => widget.items
        .where((i) => !i.checked && fold(i.name) == foldedName)
        .map((i) => i.count)
        .fold(0, (a, b) => a + b);

    final tileWidgets = <Widget>[
      for (final (i, t) in tiles.indexed)
        FocusTraversalOrder(
          order: NumericFocusOrder(200 + i.toDouble()),
          child: _Tile(
            width: width,
            picture: switch (shoppingIconAsset(t.iconKey)) {
              final asset? => Image.asset(
                asset,
                width: kiosk ? 40 : 32,
                height: kiosk ? 40 : 32,
                // The tile's label names the item; the picture adds nothing for a screen reader.
                excludeFromSemantics: true,
              ),
              null => Icon(categoryIcon(categories[t.categoryId]), size: 28),
            },
            label: t.name,
            count: countOf(t.foldedName),
            onTap: widget.busy ? null : () => widget.onAdd(t.name),
            onLongPress: () => widget.onLongPress(t.name),
          ),
        ),
      if (query.isNotEmpty && !exact)
        FocusTraversalOrder(
          order: NumericFocusOrder(200 + tiles.length.toDouble()),
          child: _Tile(
            width: width,
            picture: const Icon(Icons.add_circle_outline, size: 28),
            label: l10n.shoppingCreateTile(query),
            count: 0,
            onTap: widget.busy ? null : () => widget.onAdd(query),
            onLongPress: () => widget.onLongPress(query),
          ),
        ),
    ];

    // Full width, so the picker lines up with the list below it instead of being
    // centred by the parent Column.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showSearch)
              FocusTraversalOrder(
                order: const NumericFocusOrder(100),
                child: _FocusRing(
                  focusNode: _searchFocus,
                  child: TextField(
                    controller: widget.search,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      labelText: l10n.shoppingSearchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.done,
                    // Enter adds the top hit, else the typed name as a new item, and
                    // keeps the keyboard focus here instead of letting it fall to the
                    // document (A4): "done" unfocuses by default before onSubmitted runs.
                    onSubmitted: (value) {
                      widget.onAdd(tiles.isNotEmpty ? tiles.first.name : value);
                      _searchFocus.requestFocus();
                    },
                  ),
                ),
              ),
            const SizedBox(height: Tokens.space2),
            if (tiles.isEmpty && query.isEmpty)
              Text(
                l10n.shoppingTilesEmpty,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (kiosk)
              // On the wall the list is the point: one row of tiles that scrolls sideways,
              // all as tall as the tallest, instead of a block that pushes the list away.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: Tokens.space2,
                    children: tileWidgets,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 176),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: Tokens.space2,
                    runSpacing: Tokens.space2,
                    children: tileWidgets,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.width,
    required this.picture,
    required this.label,
    required this.count,
    required this.onTap,
    required this.onLongPress,
  });

  final double width;
  final Widget picture;
  final String label;
  final int count;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  late final _focusNode = FocusNode(
    debugLabel: 'shopping-tile:${widget.label}',
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // A4: off-screen catalogue tiles took keyboard focus without scrolling into view.
  void _onFocusChange(bool focused) {
    if (focused) {
      Scrollable.ensureVisible(context, alignment: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onList = widget.count > 0;
    return SizedBox(
      width: widget.width,
      child: _FocusRing(
        focusNode: _focusNode,
        child: Card(
          margin: EdgeInsets.zero,
          color: onList ? scheme.primaryContainer : null,
          child: InkWell(
            focusNode: _focusNode,
            onFocusChange: _onFocusChange,
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    isLabelVisible: widget.count > 1,
                    label: Text('${widget.count}×'),
                    child: widget.picture,
                  ),
                  const SizedBox(height: Tokens.space1),
                  // Flutter cannot hyphenate: a single long word ("Toilettenpapier")
                  // shrinks to fit rather than breaking mid-word; phrases wrap.
                  if (widget.label.trim().contains(' '))
                    Text(
                      widget.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelMedium,
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

class _ItemList extends ConsumerStatefulWidget {
  const _ItemList({
    required this.items,
    required this.listId,
    required this.onToggle,
    required this.onLess,
    required this.onEdit,
    required this.onTripDone,
    this.onRemove,
  });

  final List<ShoppingItem> items;
  final String listId;
  final void Function(ShoppingItem) onToggle;
  final void Function(ShoppingItem) onLess;
  final void Function(ShoppingItem) onEdit;

  /// A swipe towards the start takes an item off; null where nobody may.
  final void Function(ShoppingItem)? onRemove;

  /// The last open item was just ticked: every item on the list is bought.
  final void Function(Iterable<String> bought) onTripDone;

  @override
  ConsumerState<_ItemList> createState() => _ItemListState();
}

class _ItemListState extends ConsumerState<_ItemList> {
  static const _quiet = Duration(milliseconds: 800);
  final Map<String, ShoppingItem> _ticked = {};
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    _sendTicks();
    super.dispose();
  }

  void _sendTicks() {
    final pending = _ticked.values.toList();
    _ticked.clear();
    for (final item in pending) {
      // A concurrent tick must not be toggled back by this device.
      final now = widget.items.where((i) => i.id == item.id);
      if (now.isNotEmpty && !now.first.checked) widget.onToggle(item);
    }
  }

  void _tap(ShoppingItem item) {
    if (item.checked) {
      widget.onToggle(item);
      return;
    }
    setState(() {
      if (_ticked.remove(item.id) == null) _ticked[item.id] = item;
    });
    // The tick shows at once and is sent a moment later; the trip's end shows with it.
    if (_ticked.containsKey(item.id) &&
        widget.items.every((i) => i.checked || _ticked.containsKey(i.id))) {
      widget.onTripDone([for (final i in widget.items) i.id]);
    }
    _settle?.cancel();
    if (_ticked.isNotEmpty) {
      _settle = Timer(_quiet, () {
        if (mounted) setState(_sendTicks);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = [
      for (final c
          in ref.watch(shoppingCategoriesProvider).value ??
              const <ShoppingCategory>[])
        if (c.listId == widget.listId) c,
    ];
    final members = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final open = widget.items.where((i) => !i.checked).toList();
    final trolley = widget.items.where((i) => i.checked).toList();

    final scheme = Theme.of(context).colorScheme;
    Widget tile(ShoppingItem i) {
      final remove = widget.onRemove;
      final row = _ItemTile(
        item: i,
        checked: i.checked || _ticked.containsKey(i.id),
        adder: members[i.addedBy],
        onToggle: () => _tap(i),
        onLess: () => widget.onLess(i),
        onEdit: () => widget.onEdit(i),
        onRemove: remove == null ? null : () => remove(i),
      );
      if (remove == null) return row;
      return Dismissible(
        key: ValueKey('shopping-remove-${i.id}'),
        direction: DismissDirection.endToStart,
        background: ColoredBox(
          color: scheme.errorContainer,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: Tokens.space4),
              child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
            ),
          ),
        ),
        onDismissed: (_) => remove(i),
        child: row,
      );
    }

    // A4: items and the trolley share one traversal order with the rest of the page
    // instead of whatever order this nested list would otherwise produce.
    var order = 300;
    Widget orderedTile(ShoppingItem i) => FocusTraversalOrder(
      order: NumericFocusOrder((order++).toDouble()),
      child: tile(i),
    );

    final known = categories.map((c) => c.id).toSet();
    final groups = <Widget>[];
    for (final c in categories) {
      final inGroup = open.where((i) => i.categoryId == c.id).toList();
      if (inGroup.isEmpty) continue;
      groups
        ..add(_Header(categoryLabel(l10n, c)))
        ..addAll(inGroup.map(orderedTile));
    }
    final loose = open.where((i) => !known.contains(i.categoryId)).toList();
    if (loose.isNotEmpty) {
      groups
        ..add(_Header(l10n.shoppingUncategorised))
        ..addAll(loose.map(orderedTile));
    }

    return ListView(
      // The picker and the item list share one outer scrollable (A5): this list is
      // sized by its content here instead of scrolling independently.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ...groups,
        if (trolley.isNotEmpty)
          FocusTraversalOrder(
            order: NumericFocusOrder((order++).toDouble()),
            child: ExpansionTile(
              title: Text(l10n.shoppingInTrolley(trolley.length)),
              children: trolley.map(orderedTile).toList(),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Tokens.space4,
      Tokens.space4,
      Tokens.space4,
      Tokens.space1,
    ),
    child: Semantics(
      header: true,
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

class _ItemTile extends StatefulWidget {
  const _ItemTile({
    required this.item,
    required this.checked,
    required this.adder,
    required this.onToggle,
    required this.onLess,
    required this.onEdit,
    this.onRemove,
  });

  final ShoppingItem item;
  final bool checked;
  final Member? adder;
  final VoidCallback onToggle;
  final VoidCallback onLess;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  late final _focusNode = FocusNode(
    debugLabel: 'shopping-item:${widget.item.name}',
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // A4: off-screen items took keyboard focus without scrolling into view.
  void _onFocusChange(bool focused) {
    if (focused) {
      Scrollable.ensureVisible(context, alignment: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;
    final adder = widget.adder;
    final style = widget.checked
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : null;
    final detail = [
      if (item.count > 1) '${item.count} ×',
      ?item.quantity,
    ].join(' · ');

    // Tick targets are at least 56 high: this is used one-handed, in a coat.
    // For screen readers the row is one checkbox named after the item; who added it
    // is a hint after the name, not a label before it.
    // Screen readers remove through the row's custom action; the decrement
    // button stays a sibling so interactive controls are never nested.
    final remove = widget.onRemove;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            customSemanticsActions: remove == null
                ? null
                : {
                    CustomSemanticsAction(label: l10n.shoppingRemoveItem):
                        remove,
                  },
            checked: widget.checked,
            value: item.pending ? l10n.shoppingItemPending : null,
            hint: adder == null
                ? null
                : l10n.shoppingAddedBy(adder.displayName),
            child: _FocusRing(
              focusNode: _focusNode,
              borderRadius: BorderRadius.zero,
              child: ListTile(
                minTileHeight: 56,
                focusNode: _focusNode,
                onFocusChange: _onFocusChange,
                onTap: widget.onToggle,
                onLongPress: widget.onEdit,
                leading: ExcludeSemantics(
                  // A4: the row itself is the one tab stop (Space/Enter already toggle
                  // it); without this the checkbox was a second, redundant stop.
                  child: ExcludeFocusTraversal(
                    child: Checkbox(
                      value: widget.checked,
                      onChanged: (_) => widget.onToggle(),
                    ),
                  ),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(item.name, style: style)),
                    if (item.sourceMealEntryIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: Tokens.space2),
                        child: ExcludeSemantics(
                          child: Tooltip(
                            message: l10n.mealsUxFromMealPlan,
                            child: Icon(
                              Icons.restaurant_menu,
                              size: 18,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: detail.isEmpty ? null : Text(detail, style: style),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.pending)
                      Padding(
                        padding: const EdgeInsets.only(right: Tokens.space2),
                        child: ExcludeSemantics(
                          child: Tooltip(
                            message: l10n.shoppingItemPending,
                            child: Icon(
                              Icons.cloud_upload_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                    if (adder != null)
                      Semantics(
                        label: l10n.shoppingAddedBy(adder.displayName),
                        child: ExcludeSemantics(
                          child: Tooltip(
                            message: l10n.shoppingAddedBy(adder.displayName),
                            child: Container(
                              width: 18,
                              height: 18,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: context.ww.member(adder.color).ink,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                adder.initial,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  color: context.ww.member(adder.color).onInk,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (item.count > 1 && !widget.checked)
          Semantics(
            container: true,
            label: item.name,
            child: IconButton(
              tooltip: l10n.shoppingRemoveOne,
              onPressed: widget.onLess,
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ),
      ],
    );
  }
}

typedef _ItemEdit = ({String spec, String? categoryId, bool remove});

class _EditItemDialog extends ConsumerStatefulWidget {
  const _EditItemDialog({
    required this.item,
    required this.categories,
    required this.canRemove,
  });

  final ShoppingItem item;
  final List<ShoppingCategory> categories;

  /// Offers "Entfernen", the way to take an item off without a swipe.
  final bool canRemove;

  @override
  ConsumerState<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends ConsumerState<_EditItemDialog> {
  late final _spec = TextEditingController(text: widget.item.quantity);
  late String? _category = widget.item.categoryId;

  @override
  void dispose() {
    _spec.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Online only: while loading or when the request fails, no meal lines.
    final meals =
        ref.watch(shoppingItemMealsProvider(widget.item.id)).value ??
        const <ShoppingItemMeal>[];
    return AlertDialog(
      title: Text(widget.item.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _spec,
            autofocus: true,
            maxLength: 40,
            decoration: InputDecoration(labelText: l10n.shoppingSpecHint),
          ),
          const SizedBox(height: Tokens.space4),
          DropdownButtonFormField<String?>(
            // A long category name ellipsizes instead of overflowing a phone's
            // dialog.
            isExpanded: true,
            initialValue: widget.categories.any((c) => c.id == _category)
                ? _category
                : null,
            decoration: InputDecoration(labelText: l10n.shoppingCategory),
            items: [
              DropdownMenuItem<String?>(
                child: Text(
                  l10n.shoppingUncategorised,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final c in widget.categories)
                DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(
                    categoryLabel(l10n, c),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          for (final meal in meals)
            if (meal.title != null)
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space2),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.mealsUxForMeal(
                      meal.title!,
                      '${context.weekdayShort(meal.onDate)} '
                      '${context.dayMonth(meal.onDate)}',
                    ),
                  ),
                ),
              ),
        ],
      ),
      actions: [
        if (widget.canRemove)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, (
              spec: '',
              categoryId: null,
              remove: true,
            )),
            child: Text(l10n.shoppingRemoveItem),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            spec: _spec.text.trim(),
            categoryId: _category,
            remove: false,
          )),
          child: Text(l10n.save),
        ),
      ],
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

/// How long the burst at the end of a shopping trip lasts (specs/26 "Celebrations").
const tripBurst = Duration(milliseconds: 600);

/// Items taken off whose undo is still on screen: hidden here, not yet sent. Outlives
/// the page, so they stay hidden when it comes back before the undo has passed.
class _Removing extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String id) => state = {...state, id};

  void remove(String id) => state = {...state}..remove(id);
}

final _removingProvider = NotifierProvider<_Removing, Set<String>>(
  _Removing.new,
);
