import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/ui/text_prompt.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/ui/settings_view_switch.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/application/shopping_sync.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/ui/shopping_labels.dart';

/// "Liste bearbeiten" (specs/16 step 10.3): the name and the default; under Advanced the
/// categories in walking order (drag, add, rename, remove) and deleting the list. The
/// structure is online only (ADR-006): every change goes to the server at once and the
/// mirror refetches. Removing things is a guardian action; the rest is open to the family.
class ShoppingListEditPage extends ConsumerStatefulWidget {
  const ShoppingListEditPage({required this.listId, super.key});

  final String listId;

  @override
  ConsumerState<ShoppingListEditPage> createState() =>
      _ShoppingListEditPageState();
}

class _ShoppingListEditPageState extends ConsumerState<ShoppingListEditPage> {
  final _name = TextEditingController();
  var _nameSeeded = false;
  var _busy = false;

  /// The order on screen while a drag's write is in flight.
  List<ShoppingCategory>? _dragged;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _actor => ref.read(actingProfileProvider);
  ShoppingRepository get _repo => ref.read(shoppingRepositoryProvider);

  Future<bool> _run(
    Future<Result<Object?>> Function() action, {
    bool guardian = false,
  }) async {
    if (guardian && (!await ensureGuardian(context, ref) || !mounted)) {
      return false;
    }
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return false;
    await ref.read(shoppingSyncProvider.notifier).sync();
    if (!mounted) return false;
    setState(() => _busy = false);
    return result.when(
      ok: (_) => true,
      err: (failure) {
        context.showFailure(failure);
        return false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = (ref.watch(shoppingListsProvider).value ?? const [])
        .where((l) => l.id == widget.listId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shoppingEditList),
        leading: BackButton(onPressed: () => context.pop()),
        actions: const [SettingsViewSwitch()],
      ),
      body: ContentWidth(
        child: list == null
            ? Center(child: Text(l10n.errorNotFound))
            : _body(context, list),
      ),
    );
  }

  Widget _body(BuildContext context, ShoppingList list) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final advanced = ref.watch(showAdvancedSettingsProvider);
    if (!_nameSeeded) {
      _name.text = list.name;
      _nameSeeded = true;
    }
    final nameChanged = _name.text.trim() != list.name;
    final fromServer =
        (ref.watch(shoppingCategoriesProvider).value ?? const [])
            .where((c) => c.listId == list.id)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final categories = _dragged ?? fromServer;

    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        TextField(
          key: const ValueKey('list-name'),
          controller: _name,
          enabled: !_busy,
          maxLength: 40,
          decoration: InputDecoration(labelText: l10n.shoppingListName),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _saveName(list),
        ),
        if (nameChanged)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const ValueKey('list-save-name'),
              onPressed: _busy ? null : () => _saveName(list),
              child: Text(l10n.save),
            ),
          ),
        const SizedBox(height: Tokens.space2),
        SwitchListTile(
          key: const ValueKey('list-default'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.shoppingListDefault),
          subtitle: Text(l10n.shoppingListDefaultHelp),
          value: list.isDefault,
          // The default is chosen, not unchosen: another list takes it over.
          onChanged: list.isDefault || _busy
              ? null
              : (_) => _run(
                  () => _repo.setDefaultList(actor: _actor, listId: list.id),
                ),
        ),
        if (advanced) ...[
          const SizedBox(height: Tokens.space6),
          Text(l10n.shoppingCategories, style: theme.textTheme.titleMedium),
          Text(l10n.shoppingCategoriesHelp, style: theme.textTheme.bodySmall),
          const SizedBox(height: Tokens.space2),
          ReorderableListView(
            key: const ValueKey('list-categories'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) => _reorder(list, categories, from, to),
            children: [
              for (final (i, c) in categories.indexed)
                ListTile(
                  key: ValueKey('category-${c.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(categoryIcon(c)),
                  title: Text(categoryLabel(l10n, c)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('category-rename-${c.id}'),
                        tooltip: l10n.shoppingCategoryRename,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: _busy ? null : () => _rename(list, c),
                      ),
                      IconButton(
                        key: ValueKey('category-delete-${c.id}'),
                        tooltip: l10n.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _busy ? null : () => _deleteCategory(c),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: Tooltip(
                          message: l10n.memberReorderHandle,
                          child: const Padding(
                            padding: EdgeInsets.all(Tokens.space2),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          TextButton.icon(
            key: const ValueKey('category-add'),
            onPressed: _busy ? null : () => _rename(list, null),
            icon: const Icon(Icons.add),
            label: Text(l10n.shoppingCategoryAdd),
          ),
          const SizedBox(height: Tokens.space6),
          if (!list.isDefault)
            ListTile(
              key: const ValueKey('list-delete'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l10n.shoppingListDelete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: _busy ? null : () => _deleteList(list),
            )
          else
            Text(l10n.shoppingErrListDefault, style: theme.textTheme.bodySmall),
        ] else
          const MoreSettingsHint(),
      ],
    );
  }

  Future<void> _saveName(ShoppingList list) async {
    final name = _name.text.trim();
    if (name.isEmpty || name == list.name) return;
    final ok = await _run(
      () => _repo.renameList(actor: _actor, listId: list.id, name: name),
    );
    if (ok && mounted) context.showMessage(context.l10n.savedMessage);
  }

  Future<void> _reorder(
    ShoppingList list,
    List<ShoppingCategory> current,
    int from,
    int to,
  ) async {
    final next = List.of(current);
    final moved = next.removeAt(from);
    next.insert(to, moved);
    setState(() => _dragged = next);
    await _run(
      () => _repo.reorderCategories(
        actor: _actor,
        listId: list.id,
        categoryIds: [for (final c in next) c.id],
      ),
    );
    if (mounted) setState(() => _dragged = null);
  }

  /// A new category ([category] null) or a new name for one.
  Future<void> _rename(ShoppingList list, ShoppingCategory? category) async {
    final l10n = context.l10n;
    final name = await askText(
      context,
      title: category == null
          ? l10n.shoppingCategoryAdd
          : l10n.shoppingCategoryRename,
      label: l10n.shoppingCategoryName,
      initial: category == null ? null : categoryLabel(l10n, category),
      fieldKey: const ValueKey('category-name'),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    await _run(
      () => _repo.saveCategory(
        actor: _actor,
        listId: list.id,
        categoryId: category?.id,
        name: trimmed,
      ),
    );
  }

  Future<void> _deleteCategory(ShoppingCategory c) async {
    final l10n = context.l10n;
    final ok = await _confirm(
      l10n.shoppingCategoryDeleteConfirm(categoryLabel(l10n, c)),
      l10n.delete,
    );
    if (!ok || !mounted) return;
    await _run(
      () => _repo.deleteCategory(actor: _actor, categoryId: c.id),
      guardian: true,
    );
  }

  Future<void> _deleteList(ShoppingList list) async {
    final l10n = context.l10n;
    final ok = await _confirm(
      l10n.shoppingListDeleteConfirm(list.name),
      l10n.shoppingListDelete,
    );
    if (!ok || !mounted) return;
    final done = await _run(
      () => _repo.deleteList(actor: _actor, listId: list.id),
      guardian: true,
    );
    if (done && mounted) {
      ref.read(selectedListIdProvider.notifier).select(null);
      context.go(Routes.home);
    }
  }

  Future<bool> _confirm(String body, String action) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
