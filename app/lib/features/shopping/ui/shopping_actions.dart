import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/core/ui/confetti.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/ui/text_prompt.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/shopping_item_sheet.dart';
import 'package:wuselwall/features/shopping/ui/shopping_widgets.dart';
import 'package:wuselwall/features/wusel/application/celebration.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// The things both the shopping tab and the shopping trip page do with a list: add by
/// name, open an item or a tile, take an item off with its undo, finish the trip. Every
/// item change goes through the offline outbox and shows at once; the tile edits need
/// the network.
mixin ShoppingActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// True while an online-only write is on its way.
  bool busy = false;

  String? get actor => ref.read(actingProfileProvider);
  ShoppingRepository get repo => ref.read(shoppingRepositoryProvider);
  ShoppingSync get sync => ref.read(shoppingSyncProvider.notifier);

  void refreshList() => unawaited(sync.sync());

  /// For the online-only writes: lists, tiles and the default.
  Future<R?> run<R>(Future<Result<R>> Function() action) async {
    setState(() => busy = true);
    final result = await action();
    if (!mounted) return null;
    setState(() => busy = false);
    return result.when(
      ok: (value) {
        refreshList();
        return value;
      },
      err: (failure) {
        context.showFailure(failure);
        return null;
      },
    );
  }

  Future<void> addName(String name, ShoppingList list) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await sync.add(actor: actor, listId: list.id, name: trimmed);
  }

  /// Long press on a tile: edit the item if it is on the list, else add it first.
  Future<void> addAndEdit(String name, ShoppingList list) async {
    ShoppingItem? open() => (ref.read(shoppingItemsProvider).value ?? const [])
        .where(
          (i) =>
              i.listId == list.id &&
              !i.checked &&
              fold(i.name) == fold(name.trim()),
        )
        .firstOrNull;
    if (open() == null) {
      await sync.add(actor: actor, listId: list.id, name: name.trim());
    }
    final item = open();
    if (item != null && mounted) await editItem(item);
  }

  /// Long press on a tile: the item's sheet, or the tile itself (its name, pinning,
  /// "Nicht mehr vorschlagen"). A typed name that is no tile yet goes straight to the
  /// item.
  Future<void> tileSheet(String name, ShoppingList list) async {
    final l10n = context.l10n;
    final tile = (ref.read(shoppingCatalogProvider).value ?? const [])
        .where((c) => c.listId == list.id && c.foldedName == fold(name))
        .firstOrNull;
    if (tile == null) return addAndEdit(name, list);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
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
                key: const ValueKey('tile-pin'),
                leading: Icon(
                  tile.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                title: Text(
                  tile.pinned ? l10n.shoppingTileUnpin : l10n.shoppingTilePin,
                ),
                subtitle: Text(l10n.shoppingTilePinHelp),
                onTap: () => Navigator.pop(context, 'pin'),
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
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'edit':
        await addAndEdit(name, list);
      case 'pin':
        await run(
          () => repo.pinCatalogItem(
            actor: actor,
            itemId: tile.id,
            pinned: !tile.pinned,
          ),
        );
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
        await run(
          () => repo.updateCatalogItem(
            actor: actor,
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
        await run(() => repo.deleteCatalogItem(actor: actor, itemId: tile.id));
      default:
        return;
    }
  }

  /// The item's sheet: count, note, category and "Entfernen".
  Future<void> editItem(ShoppingItem item) async {
    final result = await showShoppingItemSheet(
      context,
      itemId: item.id,
      canRemove: canRemove,
    );
    if (result != shoppingItemSheetRemove || !mounted) return;
    final now = (ref.read(shoppingItemsProvider).value ?? const [])
        .where((i) => i.id == item.id)
        .firstOrNull;
    removeItem(now ?? item);
  }

  /// Adults take an item off the list; the children's register has no destructive
  /// action (specs/09), and the wall none at all.
  bool get canRemove => ref.read(uiRegisterProvider) == UiRegister.adult;

  /// Takes [item] off the list, by a swipe or from its sheet (specs/09 "Gestures").
  /// It leaves the screen at once and goes to the server once its undo has passed, so
  /// an undo never has to rebuild it (who added it, the meals it came from).
  void removeItem(ShoppingItem item) {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Captured: the removal is sent even when this page has gone meanwhile.
    final sync = this.sync;
    final actor = this.actor;
    final removing = ref.read(shoppingRemovingProvider.notifier)..add(item.id);
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

  /// The trip that bought [bought] on [listId] is done (specs/26 "Celebrations"): on a
  /// grown-up's phone a small, short burst over the list and a light haptic, never a
  /// sound. Once per trip, however it ends: the last item ticked, then the trip
  /// finished, is one moment. The burst asks [motionAllowed]; the haptic the night and
  /// `device.sounds`.
  void celebrateTrip(String listId, Iterable<String> bought) {
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

  /// Asks, then ends the trip; true when it was finished. The next thing is the list
  /// for the next trip, so the mode goes back to planning.
  Future<bool> finishTrip(ShoppingList list) async {
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
    if (ok != true || !mounted) return false;
    final onList = (ref.read(shoppingItemsProvider).value ?? const [])
        .where((i) => i.listId == list.id)
        .toList();
    final bought = [
      for (final i in onList)
        if (i.checked) i.id,
    ];
    await sync.finish(actor: actor, listId: list.id);
    if (!mounted) return true;
    ref.read(shoppingModeProvider.notifier).select(ShoppingMode.plan);
    context.showMessage(
      l10n.shoppingFinished(bought.length, onList.length - bought.length),
    );
    celebrateTrip(list.id, bought);
    return true;
  }

  /// Something forgotten: the same picker as at home, in a sheet that stays open so
  /// several items can follow each other.
  Future<void> addInStore(ShoppingList list) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ShoppingAddSheet(
        list: list,
        onAdd: (name) => addName(name, list),
        onLongPress: (name) => tileSheet(name, list),
      ),
    );
    // Closing the sheet drops the field's focus, so no keyboard follows it.
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
