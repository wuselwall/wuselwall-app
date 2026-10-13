import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/meals_format.dart';

/// The preview of what the week's recipes would put on the list (specs/07: mandatory).
/// Nothing is written until "Hinzufügen". Items already on the list start unticked.
/// Returns the number of items added, or null when the sheet was closed.
Future<int?> showShoppingPreview(
  BuildContext context, {
  required DateTime from,
  required DateTime to,
  required List<MealEntry> entries,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _ShoppingPreviewSheet(from: from, to: to, entries: entries),
);

/// The preview for one date range, fetched when the sheet opens.
final _previewProvider = FutureProvider.autoDispose
    .family<List<MealShoppingItem>, (DateTime, DateTime)>((ref, range) async {
      final actor = ref.watch(actingProfileProvider);
      return (await ref
              .watch(mealsRepositoryProvider)
              .shoppingPreview(actor: actor, from: range.$1, to: range.$2))
          .unwrap();
    });

class _ShoppingPreviewSheet extends ConsumerStatefulWidget {
  const _ShoppingPreviewSheet({
    required this.from,
    required this.to,
    required this.entries,
  });

  final DateTime from;
  final DateTime to;
  final List<MealEntry> entries;

  @override
  ConsumerState<_ShoppingPreviewSheet> createState() =>
      _ShoppingPreviewSheetState();
}

class _ShoppingPreviewSheetState extends ConsumerState<_ShoppingPreviewSheet> {
  /// The keys to add. Null until the preview arrives, then: everything not already on
  /// the list.
  Set<String>? _checked;
  bool _busy = false;

  Future<void> _add() async {
    final checked = _checked;
    if (checked == null || checked.isEmpty) return;
    setState(() => _busy = true);
    final result = await ref
        .read(mealsRepositoryProvider)
        .shoppingGenerate(
          actor: ref.read(actingProfileProvider),
          from: widget.from,
          to: widget.to,
          keys: checked.toList(),
        );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        ref.invalidate(mealEntriesProvider(mondayOf(widget.from)));
        Navigator.of(context).pop(value);
      case Err(:final failure):
        setState(() => _busy = false);
        context.showFailure(failure);
    }
  }

  /// "Mi Kürbissuppe, Do Nudelauflauf" for the meals an item comes from.
  String _mealsOf(BuildContext context, MealShoppingItem item) {
    final meals = [
      for (final id in item.mealEntryIds)
        for (final e in widget.entries)
          if (e.id == id && e.hasDish)
            '${context.weekdayShort(e.onDate)} ${e.title}',
    ];
    return meals.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final theme = Theme.of(context);
    final preview = ref.watch(_previewProvider((widget.from, widget.to)));
    // Initialised here, not in the list's builder: the button's label reads it too.
    final loaded = preview.value;
    if (loaded != null) {
      _checked ??= {
        for (final i in loaded)
          if (!i.alreadyOnList) i.key,
      };
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.mealsPreviewTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    l10n.mealsWeekRange(
                      context.dayMonth(widget.from),
                      context.dayMonth(widget.to),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: ww.ink2),
                  ),
                ],
              ),
            ),
            Flexible(
              child: AsyncValueView(
                value: preview,
                onRetry: () =>
                    ref.invalidate(_previewProvider((widget.from, widget.to))),
                data: (items) {
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(Tokens.space6),
                      child: Text(
                        l10n.mealsPreviewEmpty,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final checked = _checked!;
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in items)
                        CheckboxListTile(
                          value: checked.contains(item.key),
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                  if (v == true) {
                                    checked.add(item.key);
                                  } else {
                                    checked.remove(item.key);
                                  }
                                }),
                          title: Text(item.name),
                          subtitle: Text(
                            [
                              context.quantityText(item.quantity, item.unit),
                              if (_mealsOf(context, item) case final meals
                                  when meals.isNotEmpty)
                                l10n.mealsPreviewFor(meals),
                            ].where((s) => s.isNotEmpty).join(' · '),
                          ),
                          secondary: item.alreadyOnList
                              ? Text(
                                  l10n.mealsPreviewOnList,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: ww.ink2,
                                  ),
                                )
                              : null,
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Tokens.space4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: Tokens.space2),
                  FilledButton(
                    onPressed: _busy || (_checked ?? const {}).isEmpty
                        ? null
                        : _add,
                    child: Text(l10n.mealsPreviewAdd(_checked?.length ?? 0)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
