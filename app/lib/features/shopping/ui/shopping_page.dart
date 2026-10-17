import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';

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

  Future<void> _edit(ShoppingItem item) async {
    final categories = (ref.read(shoppingCategoriesProvider).value ?? const [])
        .where((c) => c.listId == item.listId)
        .toList();
    final result = await showDialog<_ItemEdit>(
      context: context,
      builder: (_) => _EditItemDialog(item: item, categories: categories),
    );
    if (result == null) return;
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
    final bought = onList.where((i) => i.checked).length;
    await _sync.finish(actor: _actor, listId: list.id);
    if (mounted) {
      context.showMessage(
        l10n.shoppingFinished(bought, onList.length - bought),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Read once for the list's taps, which may still be sent after this page has gone.
    final sync = _sync;
    final actor = _actor;
    final kiosk = ref.watch(uiRegisterProvider) == UiRegister.kiosk;
    final current = ref.watch(currentListProvider);
    final pending = ref.watch(shoppingPendingProvider);
    ref.listen(shoppingSyncProvider.select((s) => s.rejection), (_, next) {
      if (next != null && mounted) context.showFailure(next.failure);
    });

    return AsyncValueView<ShoppingList?>(
      value: current,
      onRetry: _refresh,
      data: (list) {
        if (list == null) return Center(child: Text(l10n.shoppingEmpty));
        final all = ref.watch(shoppingItemsProvider);
        final items = all.whenData(
          (v) =>
              v.where((i) => i.listId == null || i.listId == list.id).toList(),
        );
        return Column(
          children: [
            if (!kiosk)
              _ListSwitcher(
                selected: list.id,
                onNew: _newList,
                onDefault: () => _run(
                  () => _repo.setDefaultList(actor: _actor, listId: list.id),
                ),
              ),
            if (pending > 0) _PendingBanner(count: pending),
            _TilePicker(
              list: list,
              items: items.value ?? const [],
              search: _search,
              showSearch: !kiosk,
              busy: _busy,
              onAdd: (name) => _addName(name, list),
              onLongPress: (name) => _addAndEdit(name, list),
            ),
            const Divider(height: 1),
            Expanded(
              child: AsyncValueView<List<ShoppingItem>>(
                value: items,
                onRetry: _refresh,
                data: (open) => open.isEmpty
                    ? Center(child: Text(l10n.shoppingEmpty))
                    : _ItemList(
                        items: open,
                        listId: list.id,
                        // Bound now, not read later: a tick still settling is sent even
                        // when this page is already leaving (see _ItemListState.dispose).
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
                      ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Tokens.space4),
                child: Row(
                  children: [
                    if (!kiosk)
                      IconButton(
                        tooltip: l10n.shoppingHistory,
                        onPressed: () => context.push(Routes.shoppingHistory),
                        icon: const Icon(Icons.history),
                      ),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            !(items.value?.any((i) => i.checked) ?? false)
                            ? null
                            : () => _finish(list),
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: Text(l10n.shoppingFinish),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    required this.onDefault,
  });

  final String selected;
  final VoidCallback onNew;
  final VoidCallback onDefault;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lists = ref.watch(shoppingListsProvider).value ?? const [];
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space4,
          vertical: Tokens.space2,
        ),
        children: [
          for (final l in lists)
            Padding(
              padding: const EdgeInsets.only(right: Tokens.space2),
              child: GestureDetector(
                onLongPress: l.id == selected && !l.isDefault
                    ? onDefault
                    : null,
                child: ChoiceChip(
                  selected: l.id == selected,
                  avatar: l.isDefault ? const Icon(Icons.star, size: 18) : null,
                  label: Text(
                    l.openCount == 0 ? l.name : '${l.name} · ${l.openCount}',
                  ),
                  onSelected: (_) =>
                      ref.read(selectedListIdProvider.notifier).select(l.id),
                ),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: Text(l10n.shoppingNewList),
            onPressed: onNew,
          ),
        ],
      ),
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
  @override
  void initState() {
    super.initState();
    widget.search.addListener(_changed);
  }

  @override
  void dispose() {
    widget.search.removeListener(_changed);
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
      for (final t in tiles)
        _Tile(
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
      if (query.isNotEmpty && !exact)
        _Tile(
          width: width,
          picture: const Icon(Icons.add_circle_outline, size: 28),
          label: l10n.shoppingCreateTile(query),
          count: 0,
          onTap: widget.busy ? null : () => widget.onAdd(query),
          onLongPress: () => widget.onLongPress(query),
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
              TextField(
                controller: widget.search,
                decoration: InputDecoration(
                  labelText: l10n.shoppingSearchHint,
                  prefixIcon: const Icon(Icons.search),
                ),
                textInputAction: TextInputAction.done,
                // Enter adds the top hit, else the typed name as a new item.
                onSubmitted: (value) =>
                    widget.onAdd(tiles.isNotEmpty ? tiles.first.name : value),
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

class _Tile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onList = count > 0;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        color: onList ? scheme.primaryContainer : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: count > 1,
                  label: Text('$count×'),
                  child: picture,
                ),
                const SizedBox(height: Tokens.space1),
                // Flutter cannot hyphenate: a single long word ("Toilettenpapier")
                // shrinks to fit rather than breaking mid-word; phrases wrap.
                if (label.trim().contains(' '))
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  )
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
              ],
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
  });

  final List<ShoppingItem> items;
  final String listId;
  final void Function(ShoppingItem) onToggle;
  final void Function(ShoppingItem) onLess;
  final void Function(ShoppingItem) onEdit;

  @override
  ConsumerState<_ItemList> createState() => _ItemListState();
}

class _ItemListState extends ConsumerState<_ItemList> {
  /// How long the list stays still after the last tick. Ticks in this window stay in place,
  /// ticked, so a quick run down the list cannot land on a row that just moved up.
  static const _quiet = Duration(milliseconds: 800);

  /// Ticked but not yet sent: still listed where they were, shown ticked. Tapping one again
  /// unticks it before the list moves.
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
      // Skip what another device has meanwhile ticked: sending again would untick it.
      final now = widget.items.where((i) => i.id == item.id);
      if (now.isNotEmpty && !now.first.checked) widget.onToggle(item);
    }
  }

  void _tap(ShoppingItem item) {
    // Unticking a ticked item in the trolley is sent at once: it is rare and it is a
    // deliberate act there.
    if (item.checked) {
      widget.onToggle(item);
      return;
    }
    setState(() {
      if (_ticked.remove(item.id) == null) _ticked[item.id] = item;
    });
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
    // Items ticked in this window are still unchecked in the data, so they stay in `open`.
    final open = widget.items.where((i) => !i.checked).toList();
    final trolley = widget.items.where((i) => i.checked).toList();

    Widget tile(ShoppingItem i) => _ItemTile(
      item: i,
      checked: i.checked || _ticked.containsKey(i.id),
      adder: members[i.addedBy],
      onToggle: () => _tap(i),
      onLess: () => widget.onLess(i),
      onEdit: () => widget.onEdit(i),
    );

    final known = categories.map((c) => c.id).toSet();
    final groups = <Widget>[];
    for (final c in categories) {
      final inGroup = open.where((i) => i.categoryId == c.id).toList();
      if (inGroup.isEmpty) continue;
      groups
        ..add(_Header(categoryLabel(l10n, c)))
        ..addAll(inGroup.map(tile));
    }
    final loose = open.where((i) => !known.contains(i.categoryId)).toList();
    if (loose.isNotEmpty) {
      groups
        ..add(_Header(l10n.shoppingUncategorised))
        ..addAll(loose.map(tile));
    }

    return ListView(
      children: [
        ...groups,
        if (trolley.isNotEmpty)
          ExpansionTile(
            title: Text(l10n.shoppingInTrolley(trolley.length)),
            children: trolley.map(tile).toList(),
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
    child: Text(label, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.checked,
    required this.adder,
    required this.onToggle,
    required this.onLess,
    required this.onEdit,
  });

  final ShoppingItem item;

  /// Shown ticked: the item's own state, or a tick still settling (see _ItemList).
  final bool checked;
  final Member? adder;
  final VoidCallback onToggle;
  final VoidCallback onLess;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = checked
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Theme.of(context).disabledColor,
          )
        : null;
    final detail = [
      if (item.count > 1) '${item.count} ×',
      ?item.quantity,
    ].join(' · ');

    // Tick targets are at least 56 high: this is used one-handed, in a coat.
    // For screen readers the row is one checkbox named after the item; who added it
    // is a hint after the name, not a label before it.
    return Semantics(
      checked: checked,
      value: item.pending ? l10n.shoppingItemPending : null,
      hint: adder == null ? null : l10n.shoppingAddedBy(adder!.displayName),
      child: ListTile(
        minTileHeight: 56,
        onTap: onToggle,
        onLongPress: onEdit,
        leading: ExcludeSemantics(
          child: Checkbox(value: checked, onChanged: (_) => onToggle()),
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
              ExcludeSemantics(
                child: Tooltip(
                  message: l10n.shoppingAddedBy(adder!.displayName),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: adder!.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            if (item.count > 1 && !checked)
              IconButton(
                tooltip: l10n.shoppingRemoveOne,
                onPressed: onLess,
                icon: const Icon(Icons.remove_circle_outline),
              ),
          ],
        ),
      ),
    );
  }
}

typedef _ItemEdit = ({String spec, String? categoryId});

class _EditItemDialog extends ConsumerStatefulWidget {
  const _EditItemDialog({required this.item, required this.categories});

  final ShoppingItem item;
  final List<ShoppingCategory> categories;

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
            initialValue: widget.categories.any((c) => c.id == _category)
                ? _category
                : null,
            decoration: InputDecoration(labelText: l10n.shoppingCategory),
            items: [
              DropdownMenuItem<String?>(
                child: Text(l10n.shoppingUncategorised),
              ),
              for (final c in widget.categories)
                DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(categoryLabel(l10n, c)),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            spec: _spec.text.trim(),
            categoryId: _category,
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
