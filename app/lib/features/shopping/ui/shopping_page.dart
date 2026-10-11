import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';

/// The shared list: add, tick, finish. Offline use, the catalogue and the tile picker
/// are M1.1.
class ShoppingBody extends ConsumerStatefulWidget {
  const ShoppingBody({super.key});

  @override
  ConsumerState<ShoppingBody> createState() => _ShoppingBodyState();
}

class _ShoppingBodyState extends ConsumerState<ShoppingBody> {
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  String? get _actor => ref.read(actingProfileProvider);

  Future<void> _run(Future<Result<Object?>> Function() action) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      ok: (_) => ref.invalidate(shoppingItemsProvider),
      err: context.showFailure,
    );
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final quantity = _quantity.text.trim();
    await _run(
      () => ref
          .read(shoppingRepositoryProvider)
          .add(
            actor: _actor,
            name: name,
            quantity: quantity.isEmpty ? null : quantity,
          ),
    );
    if (!mounted) return;
    _name.clear();
    _quantity.clear();
  }

  Future<void> _finish() async {
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

    setState(() => _busy = true);
    final result = await ref
        .read(shoppingRepositoryProvider)
        .finish(actor: _actor);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      ok: (trip) {
        ref.invalidate(shoppingItemsProvider);
        context.showMessage(
          l10n.shoppingFinished(trip.bought, trip.carriedOver),
        );
      },
      err: context.showFailure,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = ref.watch(shoppingItemsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.shoppingAddHint),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: Tokens.space2),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _quantity,
                  decoration: InputDecoration(
                    labelText: l10n.shoppingQuantityHint,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: Tokens.space2),
              IconButton.filled(
                tooltip: l10n.shoppingAddHint,
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<ShoppingItem>>(
            value: items,
            onRetry: () => ref.invalidate(shoppingItemsProvider),
            data: (list) => list.isEmpty
                ? Center(child: Text(l10n.shoppingEmpty))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) => _ItemTile(
                      item: list[i],
                      onToggle: () => _run(
                        () => ref
                            .read(shoppingRepositoryProvider)
                            .toggle(actor: _actor, itemId: list[i].id),
                      ),
                    ),
                  ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy || (items.value?.isEmpty ?? true)
                    ? null
                    : _finish,
                icon: const Icon(Icons.shopping_cart_checkout),
                label: Text(l10n.shoppingFinish),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onToggle});

  final ShoppingItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final style = item.checked
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Theme.of(context).disabledColor,
          )
        : null;
    return CheckboxListTile(
      value: item.checked,
      onChanged: (_) => onToggle(),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(item.name, style: style),
      secondary: item.quantity == null
          ? null
          : Text(item.quantity!, style: style),
    );
  }
}
