import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';
import 'package:wuselwall/features/shopping/ui/shopping_widgets.dart';

/// What the item sheet hands back when it closes: "Entfernen" was pressed.
const shoppingItemSheetRemove = 'remove';

/// Opens the sheet of the item [itemId]; the result is [shoppingItemSheetRemove] when
/// the person chose "Entfernen" (the caller takes the item off, with its undo).
Future<String?> showShoppingItemSheet(
  BuildContext context, {
  required String itemId,
  required bool canRemove,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => ShoppingItemSheet(itemId: itemId, canRemove: canRemove),
);

/// One item of the list, opened by a tap on a planning row or a long press on any row:
/// how many (a stepper that acts at once, offline too), a note, the category, and
/// "Entfernen". Everything but the note is saved the moment it is touched, so the row
/// behind the sheet changes live; the note is saved on "Fertig" or when the sheet closes.
class ShoppingItemSheet extends ConsumerStatefulWidget {
  const ShoppingItemSheet({
    required this.itemId,
    required this.canRemove,
    super.key,
  });

  final String itemId;

  /// Offers "Entfernen", the way to take an item off without a swipe (adults only).
  final bool canRemove;

  @override
  ConsumerState<ShoppingItemSheet> createState() => _ShoppingItemSheetState();
}

class _ShoppingItemSheetState extends ConsumerState<ShoppingItemSheet> {
  late final ShoppingSync _sync;
  late final String? _actor;
  late final TextEditingController _spec;
  late String _savedSpec;
  ShoppingItem? _last;

  @override
  void initState() {
    super.initState();
    // Captured while mounted: dispose queues the note even as the sheet goes.
    _sync = ref.read(shoppingSyncProvider.notifier);
    _actor = ref.read(actingProfileProvider);
    final item = _find();
    _last = item;
    _savedSpec = item?.quantity ?? '';
    _spec = TextEditingController(text: _savedSpec);
  }

  @override
  void dispose() {
    // A note typed and then dragged away is not lost.
    _saveSpec();
    _spec.dispose();
    super.dispose();
  }

  ShoppingItem? _find() => (ref.read(shoppingItemsProvider).value ?? const [])
      .where((i) => i.id == widget.itemId)
      .firstOrNull;

  void _saveSpec() {
    final text = _spec.text.trim();
    if (text == _savedSpec) return;
    _savedSpec = text;
    _sync.setSpec(actor: _actor, itemId: widget.itemId, text: text);
  }

  void _more(int by) =>
      _sync.adjustCount(actor: _actor, itemId: widget.itemId, delta: by);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final touch = ref.watch(uiRegisterProvider).touchTarget;
    // 48 px at least, the register's own target where that is larger.
    final step = touch < 48 ? 48.0 : touch;
    // The row behind may be gone meanwhile (finished on another device): the sheet keeps
    // the last it knew rather than going blank.
    final live = (ref.watch(shoppingItemsProvider).value ?? const [])
        .where((i) => i.id == widget.itemId)
        .firstOrNull;
    final item = _last = live ?? _last;
    if (item == null) return const SizedBox.shrink();
    final categories = sortedBy([
      for (final c
          in ref.watch(shoppingCategoriesProvider).value ??
              const <ShoppingCategory>[])
        if (c.listId == item.listId) c,
    ], (c) => c.sortOrder);
    final known = categories.any((c) => c.id == item.categoryId);
    // Online only: while loading or when the request fails, no meal lines.
    final meals = item.sourceMealEntryIds.isEmpty
        ? const <ShoppingItemMeal>[]
        : ref.watch(shoppingItemMealsProvider(item.id)).value ??
              const <ShoppingItemMeal>[];

    Widget chip(String key, String label, bool selected, String? categoryId) =>
        Padding(
          padding: const EdgeInsets.only(right: Tokens.space2),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: touch),
            child: ChoiceChip(
              key: ValueKey(key),
              label: Text(label),
              selected: selected,
              onSelected: (_) => _sync.setCategory(
                actor: _actor,
                itemId: item.id,
                categoryId: categoryId,
              ),
            ),
          ),
        );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          left: Tokens.space4,
          right: Tokens.space4,
          bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.space4,
        ),
        child: Column(
          key: const ValueKey('shopping-item-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(item.name, style: theme.textTheme.titleLarge),
                ),
                if (item.sourceMealEntryIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: Tokens.space2,
                    ),
                    child: ExcludeSemantics(
                      child: Tooltip(
                        message: l10n.mealsUxFromMealPlan,
                        child: Icon(
                          Icons.restaurant_menu,
                          size: 20,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            for (final meal in meals)
              if (meal.title != null)
                Padding(
                  padding: const EdgeInsets.only(top: Tokens.space1),
                  child: Text(
                    l10n.mealsUxForMeal(
                      meal.title!,
                      '${context.weekdayShort(meal.onDate)} '
                      '${context.dayMonth(meal.onDate)}',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            const SizedBox(height: Tokens.space4),
            // The count: big targets, applied at once. "−" stops at one; taking the item
            // off is the explicit button below.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('item-less'),
                  tooltip: l10n.shoppingRemoveOne,
                  constraints: BoxConstraints.tightFor(
                    width: step,
                    height: step,
                  ),
                  style: IconButton.styleFrom(minimumSize: Size(step, step)),
                  onPressed: item.count > 1 ? () => _more(-1) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 96,
                  child: Semantics(
                    liveRegion: true,
                    label: l10n.shoppingCountTimes(item.count),
                    child: ExcludeSemantics(
                      child: Text(
                        '${item.count}',
                        key: const ValueKey('item-count'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('item-more'),
                  tooltip: l10n.shoppingAddOne,
                  constraints: BoxConstraints.tightFor(
                    width: step,
                    height: step,
                  ),
                  style: IconButton.styleFrom(minimumSize: Size(step, step)),
                  onPressed: item.count < 99 ? () => _more(1) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space4),
            TextField(
              key: const ValueKey('item-note'),
              controller: _spec,
              maxLength: 40,
              decoration: InputDecoration(labelText: l10n.shoppingSpecHint),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveSpec(),
            ),
            const SizedBox(height: Tokens.space2),
            Text(l10n.shoppingCategory, style: theme.textTheme.labelLarge),
            const SizedBox(height: Tokens.space2),
            SingleChildScrollView(
              key: const ValueKey('item-category-chips'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip(
                    'item-category-none',
                    l10n.shoppingUncategorised,
                    !known,
                    null,
                  ),
                  for (final c in categories)
                    chip(
                      'item-category-${c.id}',
                      categoryLabel(l10n, c),
                      c.id == item.categoryId,
                      c.id,
                    ),
                ],
              ),
            ),
            if (item.categoryAuto)
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space2),
                child: Row(
                  key: const ValueKey('item-category-auto'),
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.auto_awesome_outlined,
                        size: 18,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: Tokens.space2),
                    Expanded(
                      child: Text(
                        l10n.shoppingCategoryAuto,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Tokens.space4),
            Row(
              children: [
                if (widget.canRemove)
                  TextButton(
                    key: const ValueKey('item-remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      minimumSize: Size(Tokens.space8, touch),
                    ),
                    onPressed: () {
                      // The item goes: its note no longer matters.
                      _savedSpec = _spec.text.trim();
                      Navigator.pop(context, shoppingItemSheetRemove);
                    },
                    child: Text(l10n.shoppingRemoveItem),
                  ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('item-done'),
                  onPressed: () {
                    _saveSpec();
                    Navigator.pop(context);
                  },
                  child: Text(l10n.shoppingItemDone),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
