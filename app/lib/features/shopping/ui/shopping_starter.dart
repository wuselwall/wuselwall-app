import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/shopping/data/starter_catalog.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';
import 'package:wuselwall/features/shopping/ui/shopping_widgets.dart';

// The tiles of the starter catalogue (specs/07 "Starter catalogue"): they look like the
// family's own tiles but are not theirs yet, so a long press offers no renaming and no
// forgetting.

/// The picker's tiles for [starters], to follow the family's own. [categories] are the
/// list's, for the icon of a tile without a picture; [orderBase] is the focus order of
/// the first one.
List<Widget> starterTileWidgets(
  BuildContext context, {
  required List<StarterItem> starters,
  required List<ShoppingCategory> categories,
  required double width,
  required bool kiosk,
  required bool busy,
  required double orderBase,
  required int Function(String foldedName) countOf,
  required void Function(String name) onAdd,
  required void Function(String name) onLongPress,
}) => [
  for (final (i, s) in starters.indexed)
    FocusTraversalOrder(
      order: NumericFocusOrder(orderBase + i),
      child: ShoppingTile(
        key: ValueKey('shopping-starter-${s.folded}'),
        width: width,
        starter: true,
        picture: switch (shoppingIconAsset(s.icon)) {
          final asset? => Image.asset(
            asset,
            width: kiosk ? 40 : 32,
            height: kiosk ? 40 : 32,
            excludeFromSemantics: true,
          ),
          null => Icon(
            categoryIcon(
              categories.where((c) => c.key == s.category).firstOrNull ??
                  ShoppingCategory(
                    id: s.category,
                    listId: '',
                    key: s.category,
                    name: null,
                    sortOrder: 0,
                  ),
            ),
            size: 28,
          ),
        },
        label: s.name,
        count: countOf(s.folded),
        onTap: busy ? null : () => onAdd(s.name),
        onLongPress: () => onLongPress(s.name),
      ),
    ),
];

/// The sheet of a long press on a starter tile: add it, or add it and open the item.
/// Null when the sheet is dismissed.
Future<StarterChoice?> showStarterTileSheet(BuildContext context, String name) {
  final l10n = context.l10n;
  return showModalBottomSheet<StarterChoice>(
    context: context,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(l10n.shoppingTileStarter),
            ),
            ListTile(
              key: const ValueKey('tile-add'),
              leading: const Icon(Icons.add),
              title: Text(l10n.shoppingAddInStore),
              onTap: () => Navigator.pop(context, StarterChoice.add),
            ),
            ListTile(
              key: const ValueKey('tile-add-edit'),
              leading: const Icon(Icons.edit_note),
              title: Text(l10n.shoppingTileAddEdit),
              onTap: () => Navigator.pop(context, StarterChoice.addAndEdit),
            ),
          ],
        ),
      ),
    ),
  );
}

enum StarterChoice { add, addAndEdit }
