import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/core/ui/edge_fade.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/starter_providers.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';
import 'package:wuselwall/features/shopping/ui/shopping_starter.dart';

// The pieces the shopping tab and the shopping trip page share.

/// The items of [listId] on screen: this device's view without those whose removal is
/// waiting out its undo.
AsyncValue<List<ShoppingItem>> shoppingItemsOf(WidgetRef ref, String listId) {
  final removing = ref.watch(shoppingRemovingProvider);
  return ref
      .watch(shoppingItemsProvider)
      .whenData(
        (v) => v
            .where((i) => i.listId == null || i.listId == listId)
            .where((i) => !removing.contains(i.id))
            .toList(),
      );
}

/// [source] by [order], ascending; equal positions keep their given order (a mirror
/// saved by an older app has none).
List<T> sortedBy<T>(Iterable<T> source, int Function(T) order) {
  final indexed = source.toList().indexed.toList()
    ..sort((a, b) {
      final byOrder = order(a.$2).compareTo(order(b.$2));
      return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
    });
  return [for (final (_, v) in indexed) v];
}

/// The picker in a sheet, for the item forgotten in the store. It stays open while
/// items are added; closing it (drag, back) drops the keyboard with it.
class ShoppingAddSheet extends ConsumerStatefulWidget {
  const ShoppingAddSheet({
    super.key,
    required this.list,
    required this.onAdd,
    required this.onLongPress,
  });

  final ShoppingList list;
  final void Function(String name) onAdd;
  final void Function(String name) onLongPress;

  @override
  ConsumerState<ShoppingAddSheet> createState() => _ShoppingAddSheetState();
}

class _ShoppingAddSheetState extends ConsumerState<ShoppingAddSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = shoppingItemsOf(ref, widget.list.id);
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        // Above the keyboard, which would otherwise cover the tiles.
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ShoppingTilePicker(
              list: widget.list,
              items: items.value ?? const [],
              search: _search,
              showSearch: true,
              busy: false,
              autofocus: true,
              onAdd: (name) {
                widget.onAdd(name);
                _search.clear();
              },
              onLongPress: widget.onLongPress,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown honestly rather than implied away: iOS sends nothing while the app is closed,
/// so changes made offline wait until it is next opened with a connection.
class ShoppingPendingBanner extends StatelessWidget {
  const ShoppingPendingBanner({required this.count, super.key});

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

/// A visible keyboard-focus ring at 3:1 contrast or better against the surrounding
/// ground (WCAG 1.4.11). Listens to a [FocusNode] already owned by the wrapped
/// control instead of adding a focus stop of its own, and paints over the child
/// instead of reserving border space, so it never changes the child's layout size
/// (important here: several of these sit inside a `SliverList` that forces an exact
/// cross-axis extent on them).
///
/// It shows only while the focus comes from the keyboard
/// ([FocusHighlightMode.traditional]): a tap focuses a control too, and the ring then
/// ran through a text field's label.
class ShoppingFocusRing extends StatefulWidget {
  const ShoppingFocusRing({
    super.key,
    required this.focusNode,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final FocusNode focusNode;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<ShoppingFocusRing> createState() => _ShoppingFocusRingState();
}

class _ShoppingFocusRingState extends State<ShoppingFocusRing> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_modeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_modeChanged);
    super.dispose();
  }

  void _modeChanged(FocusHighlightMode _) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: widget.focusNode,
      builder: (context, child) => Stack(
        fit: StackFit.passthrough,
        children: [
          child!,
          if (widget.focusNode.hasFocus &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('shopping-focus-ring'),
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    border: Border.all(color: ringColor, width: 2.5),
                  ),
                ),
              ),
            ),
        ],
      ),
      child: widget.child,
    );
  }
}

/// Recents and frequents before any input; typing narrows them; "neu anlegen" closes
/// the loop for names the catalogue does not know. On the wall there is no search field.
class ShoppingTilePicker extends ConsumerStatefulWidget {
  const ShoppingTilePicker({
    required this.list,
    required this.items,
    required this.search,
    required this.showSearch,
    required this.busy,
    required this.onAdd,
    required this.onLongPress,
    this.autofocus = false,
    super.key,
  });

  final ShoppingList list;
  final List<ShoppingItem> items;
  final TextEditingController search;
  final bool showSearch;
  final bool busy;
  final void Function(String name) onAdd;
  final void Function(String name) onLongPress;

  /// The search field takes the focus when the picker appears (the add sheet).
  final bool autofocus;

  @override
  ConsumerState<ShoppingTilePicker> createState() => _ShoppingTilePickerState();
}

class _ShoppingTilePickerState extends ConsumerState<ShoppingTilePicker> {
  final _searchFocus = FocusNode(debugLabel: 'shopping-search');

  @override
  void initState() {
    super.initState();
    widget.search.addListener(_changed);
    _searchFocus.addListener(_changed);
  }

  @override
  void dispose() {
    widget.search.removeListener(_changed);
    _searchFocus.removeListener(_changed);
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
    final starter = ref.watch(starterSetProvider(widget.list.id));
    final starters = starter.forPicker(
      catalog: catalog,
      shown: tiles,
      onList: widget.items,
      query: query,
    );
    final folded = fold(query);
    final exact =
        tiles.any((t) => t.foldedName == folded) ||
        starters.any((s) => s.folded == folded);

    int countOf(String foldedName) => widget.items
        .where((i) => !i.checked && fold(i.name) == foldedName)
        .map((i) => i.count)
        .fold(0, (a, b) => a + b);

    List<Widget> tilesOf(double width) => [
      for (final (i, t) in tiles.indexed)
        FocusTraversalOrder(
          order: NumericFocusOrder(200 + i.toDouble()),
          child: ShoppingTile(
            key: ValueKey('shopping-tile-${t.foldedName}'),
            width: width,
            picture: switch (shoppingIconAsset(
              starter.pictureKey(t.iconKey, t.name),
            )) {
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
            pinned: t.pinned,
            count: countOf(t.foldedName),
            onTap: widget.busy ? null : () => widget.onAdd(t.name),
            onLongPress: () => widget.onLongPress(t.name),
          ),
        ),
      ...starterTileWidgets(
        context,
        starters: starters,
        categories: categories.values.toList(),
        width: width,
        kiosk: kiosk,
        busy: widget.busy,
        orderBase: 200 + tiles.length.toDouble(),
        countOf: countOf,
        onAdd: widget.onAdd,
        onLongPress: widget.onLongPress,
      ),
      if (query.isNotEmpty && !exact)
        FocusTraversalOrder(
          order: NumericFocusOrder(200 + tiles.length.toDouble()),
          child: ShoppingTile(
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
    return LayoutBuilder(
      builder: (context, box) {
        // On the wall a fixed width in a sideways strip; elsewhere as many columns as
        // tiles of at most 120 px fit, sharing the whole width, so the grid never
        // stops short of the edge (round-3 review L-9).
        final tileWidgets = tilesOf(kiosk ? 148.0 : _tileWidth(box.maxWidth));
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
                    child: ShoppingFocusRing(
                      focusNode: _searchFocus,
                      child: TextField(
                        controller: widget.search,
                        focusNode: _searchFocus,
                        autofocus: widget.autofocus,
                        decoration: InputDecoration(
                          // A hint, not a floating label: the focus ring and a label
                          // that floats into the border do not mix.
                          hintText: l10n.shoppingSearchHint,
                          prefixIcon: const Icon(Icons.search),
                          // Enter keeps the focus here for the next item, so a phone
                          // needs its own way out of the field and its keyboard.
                          suffixIcon: _searchFocus.hasFocus || query.isNotEmpty
                              ? IconButton(
                                  key: const ValueKey('shopping-search-clear'),
                                  tooltip: l10n.shoppingSearchClear,
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    widget.search.clear();
                                    _searchFocus.unfocus();
                                  },
                                )
                              : null,
                        ),
                        textInputAction: TextInputAction.done,
                        // Enter adds the top hit, else the typed name as a new item, and
                        // keeps the keyboard focus here instead of letting it fall to the
                        // document (A4): "done" unfocuses by default before onSubmitted runs.
                        onSubmitted: (value) {
                          widget.onAdd(
                            tiles.isNotEmpty
                                ? tiles.first.name
                                : starters.isNotEmpty
                                ? starters.first.name
                                : value,
                          );
                          _searchFocus.requestFocus();
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: Tokens.space2),
                if (tiles.isEmpty && starters.isEmpty && query.isEmpty)
                  Text(
                    l10n.shoppingTilesEmpty,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else if (kiosk)
                  // On the wall the list is the point: one row of tiles that scrolls sideways,
                  // all as tall as the tallest, instead of a block that pushes the list away.
                  EdgeFade(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: Tokens.space2,
                          children: tileWidgets,
                        ),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    // 30% of the screen, between a row and a half (112) and two and a
                    // half rows (240): a short phone still shows more than one item under
                    // the tiles (round-3 review L-1), a tall one more tiles. The half row
                    // says the tiles scroll.
                    constraints: BoxConstraints(
                      maxHeight: tileGridHeight(
                        MediaQuery.sizeOf(context).height,
                      ),
                    ),
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
      },
    );
  }
}

/// The tallest the tile grid gets on a screen [screenHeight] high: 30% of it, but at
/// least 112 and at most 240 logical pixels.
double tileGridHeight(double screenHeight) =>
    (screenHeight * 0.3).clamp(112.0, 240.0);

/// The width of one catalogue tile in a [picker] of that width less its 16 px
/// margins: as many columns as tiles of at most 120 px fit (never fewer than three),
/// sharing the width with 8 px gaps.
double _tileWidth(double picker) {
  const gap = Tokens.space2;
  const most = 120.0;
  final room = picker - 2 * Tokens.space4;
  var columns = ((room + gap) / (most + gap)).ceil();
  if (columns < 3) columns = 3;
  return ((room - gap * (columns - 1)) / columns).floorToDouble();
}

class ShoppingTile extends StatefulWidget {
  const ShoppingTile({
    required this.width,
    super.key,
    required this.picture,
    required this.label,
    required this.count,
    required this.onTap,
    required this.onLongPress,
    this.pinned = false,
    this.starter = false,
  });

  final double width;
  final Widget picture;
  final String label;

  /// A pinned tile always comes first; it carries a small pin.
  final bool pinned;

  /// A suggestion of the starter catalogue, not one of the family's own tiles yet.
  final bool starter;
  final int count;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  State<ShoppingTile> createState() => _ShoppingTileState();
}

class _ShoppingTileState extends State<ShoppingTile> {
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
    // The tint says the item is on the list already and the pin that the tile is pinned;
    // the tooltip says it in words, and so does the screen reader (round-3 review L-9).
    final tile = SizedBox(
      width: widget.width,
      child: ShoppingFocusRing(
        focusNode: _focusNode,
        child: Card(
          margin: EdgeInsets.zero,
          color: onList
              ? scheme.primaryContainer
              : widget.starter
              ? scheme.surfaceContainer
              : null,
          child: InkWell(
            focusNode: _focusNode,
            onFocusChange: _onFocusChange,
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            // The picture and the label are centred across the tile's width whatever
            // the width (a laptop's tiles are twice a phone's); the pin sits in the
            // corner without taking part in that layout.
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
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
                if (widget.pinned)
                  PositionedDirectional(
                    top: Tokens.space1,
                    start: Tokens.space1,
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.push_pin,
                        size: 14,
                        color: scheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final note = [
      if (widget.pinned) context.l10n.shoppingTilePinned,
      if (widget.starter) context.l10n.shoppingTileStarter,
      if (onList) context.l10n.shoppingTileOnList,
    ].join(', ');
    if (note.isEmpty) return tile;
    // The tooltip's overlay portal starts a semantics node of its own; merged, the
    // hint lands on the tile's labelled node instead of an unlabelled one around it,
    // which iOS's accessibility audit rejects as an element without a description.
    return Tooltip(
      message: note,
      excludeFromSemantics: true,
      child: MergeSemantics(
        child: Semantics(hint: note, child: tile),
      ),
    );
  }
}

class ShoppingItemList extends ConsumerStatefulWidget {
  const ShoppingItemList({
    super.key,
    required this.items,
    required this.listId,
    required this.mode,
    required this.onToggle,
    required this.onLess,
    required this.onEdit,
    required this.onTripDone,
    this.onRemove,
  });

  final List<ShoppingItem> items;
  final String listId;

  /// Planning rows have no tick; shopping rows no "−"; null (the wall) is today's
  /// combined row.
  final ShoppingMode? mode;
  final void Function(ShoppingItem) onToggle;
  final void Function(ShoppingItem) onLess;
  final void Function(ShoppingItem) onEdit;

  /// A swipe towards the start takes an item off; null where nobody may.
  final void Function(ShoppingItem)? onRemove;

  /// The last open item was just ticked: every item on the list is bought.
  final void Function(Iterable<String> bought) onTripDone;

  @override
  ConsumerState<ShoppingItemList> createState() => _ShoppingItemListState();
}

class _ShoppingItemListState extends ConsumerState<ShoppingItemList> {
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
    // Walking order, whatever order the mirror was saved in.
    final categories = sortedBy([
      for (final c
          in ref.watch(shoppingCategoriesProvider).value ??
              const <ShoppingCategory>[])
        if (c.listId == widget.listId) c,
    ], (c) => c.sortOrder);
    final icons = {
      for (final c
          in ref.watch(shoppingCatalogProvider).value ?? const <CatalogEntry>[])
        if (c.listId == widget.listId) c.foldedName: c.iconKey,
    };
    final categoryById = {for (final c in categories) c.id: c};
    final starter = ref.watch(starterSetProvider(widget.listId));
    final planning = widget.mode == ShoppingMode.plan;
    final members = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final open = widget.items.where((i) => !i.checked).toList();
    final trolley = widget.items.where((i) => i.checked).toList();

    final scheme = Theme.of(context).colorScheme;
    Widget tile(ShoppingItem i) {
      final remove = widget.onRemove;
      // Planning: the open items are plain rows with their picture, a tap opens the
      // item; the trolley keeps its tick rows, so un-ticking stays one tap.
      final plain = planning && !i.checked;
      final row = ShoppingItemTile(
        item: i,
        checked: i.checked || _ticked.containsKey(i.id),
        adder: members[i.addedBy],
        plain: plain,
        picture: plain
            ? _itemPicture(
                i,
                starter.pictureKey(icons[fold(i.name)], i.name),
                categoryById[i.categoryId],
              )
            : null,
        showLess: widget.mode != ShoppingMode.shop,
        onToggle: plain ? () => widget.onEdit(i) : () => _tap(i),
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
        ..add(ShoppingHeader(categoryLabel(l10n, c)))
        ..addAll(inGroup.map(orderedTile));
    }
    final loose = open.where((i) => !known.contains(i.categoryId)).toList();
    if (loose.isNotEmpty) {
      groups
        ..add(ShoppingHeader(l10n.shoppingUncategorised))
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

/// An item's picture in a plain row: the catalogue tile's, else its category's icon.
Widget _itemPicture(
  ShoppingItem item,
  String? iconKey,
  ShoppingCategory? category,
) => switch (shoppingIconAsset(iconKey)) {
  final asset? => Image.asset(
    asset,
    width: 24,
    height: 24,
    excludeFromSemantics: true,
  ),
  null => ExcludeSemantics(child: Icon(categoryIcon(category), size: 24)),
};

class ShoppingHeader extends StatelessWidget {
  const ShoppingHeader(this.label, {super.key});

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

class ShoppingItemTile extends StatefulWidget {
  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.checked,
    required this.adder,
    required this.onToggle,
    required this.onLess,
    required this.onEdit,
    this.plain = false,
    this.picture,
    this.showLess = true,
    this.onRemove,
  });

  final ShoppingItem item;
  final bool checked;
  final Member? adder;

  /// A planning row: the picture instead of a checkbox; a tap is [onToggle], which the
  /// list points at the item's sheet.
  final bool plain;
  final Widget? picture;

  /// Whether a count above one offers "−" (not while shopping: noise in the aisle).
  final bool showLess;
  final VoidCallback onToggle;
  final VoidCallback onLess;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  State<ShoppingItemTile> createState() => _ShoppingItemTileState();
}

class _ShoppingItemTileState extends State<ShoppingItemTile> {
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
            color: Theme.of(context).disabledColor,
          )
        : null;
    final note = item.quantity?.trim() ?? '';
    final scheme = Theme.of(context).colorScheme;
    final state = [
      if (item.count > 1) l10n.shoppingCountTimes(item.count),
      if (item.pending) l10n.shoppingItemPending,
    ].join(', ');

    // Tick targets are at least 56 high: this is used one-handed, in a coat.
    // For screen readers the row is one checkbox named after the item; who added it
    // is a hint after the name, not a label before it.
    // Screen readers have no swipe: removing is an action of the row instead.
    final remove = widget.onRemove;
    return Semantics(
      checked: widget.plain ? null : widget.checked,
      value: state.isEmpty ? null : state,
      hint: adder == null ? null : l10n.shoppingAddedBy(adder.displayName),
      customSemanticsActions: remove == null
          ? null
          : {CustomSemanticsAction(label: l10n.shoppingRemoveItem): remove},
      child: ShoppingFocusRing(
        focusNode: _focusNode,
        borderRadius: BorderRadius.zero,
        child: ListTile(
          key: ValueKey('shopping-item-${item.id}'),
          minTileHeight: widget.plain ? 48 : 56,
          focusNode: _focusNode,
          onFocusChange: _onFocusChange,
          onTap: widget.onToggle,
          onLongPress: widget.onEdit,
          leading: widget.plain
              ? widget.picture
              : ExcludeSemantics(
                  // A4: the row itself is the one tab stop (Space/Enter already
                  // toggle it); without this the checkbox was a second, redundant
                  // stop.
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
              // The count must not be missed in the aisle: a bold pill after the name,
              // in both kinds of row. The row's semantics value carries it for a
              // screen reader.
              if (item.count > 1)
                Padding(
                  padding: const EdgeInsets.only(left: Tokens.space2),
                  child: ExcludeSemantics(
                    child: Container(
                      key: ValueKey('item-count-${item.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.space2,
                        vertical: 2,
                      ),
                      decoration: ShapeDecoration(
                        color: scheme.primaryContainer,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        '${item.count}×',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
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
          subtitle: note.isEmpty ? null : Text(note, style: style),
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
              if (item.count > 1 && !widget.checked && widget.showLess)
                IconButton(
                  tooltip: l10n.shoppingRemoveOne,
                  onPressed: widget.onLess,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How long the burst at the end of a shopping trip lasts (specs/26 "Celebrations").
const tripBurst = Duration(milliseconds: 600);

/// Items taken off whose undo is still on screen: hidden here, not yet sent. Outlives
/// the page, so they stay hidden when it comes back before the undo has passed.
class ShoppingRemoving extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String id) => state = {...state, id};

  void remove(String id) => state = {...state}..remove(id);
}

final shoppingRemovingProvider =
    NotifierProvider<ShoppingRemoving, Set<String>>(ShoppingRemoving.new);
