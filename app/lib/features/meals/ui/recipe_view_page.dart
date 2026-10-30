import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/count_stepper.dart';
import 'package:wuselwall/features/meals/ui/meals_format.dart';

/// One recipe: ingredients scaled to the servings chosen here, steps in large type. It is
/// read on a tablet propped against the toaster, so the steps are the biggest thing on the
/// page. [initial] is what the list opened; the live copy is read again so an edit shows.
class RecipeViewPage extends ConsumerStatefulWidget {
  const RecipeViewPage({required this.initial, super.key});

  final Recipe initial;

  @override
  ConsumerState<RecipeViewPage> createState() => _RecipeViewPageState();
}

class _RecipeViewPageState extends ConsumerState<RecipeViewPage> {
  int? _servings;

  Future<void> _delete(Recipe recipe) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.mealsRecipeDeleteConfirm(recipe.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mealsRecipeDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref
        .read(mealsRepositoryProvider)
        .deleteRecipe(actor: ref.read(actingProfileProvider), id: recipe.id);
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(recipesProvider);
        context.pop();
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final theme = Theme.of(context);
    final live = ref.watch(recipesProvider).value;
    final recipe =
        live?.where((r) => r.id == widget.initial.id).firstOrNull ??
        widget.initial;
    final servings = _servings ?? recipe.servingsDefault;
    final steps = recipe.stepLines;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            tooltip: l10n.mealsRecipeEdit,
            icon: const Icon(Icons.edit),
            onPressed: () => context.push(Routes.recipeEdit, extra: recipe),
          ),
          IconButton(
            tooltip: l10n.mealsRecipeDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(recipe),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            CountStepper(
              label: l10n.mealsServings,
              value: servings,
              min: 1,
              max: 50,
              onChanged: (v) => setState(() => _servings = v),
            ),
            if (recipe.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space2),
                child: Wrap(
                  spacing: Tokens.space2,
                  children: [for (final t in recipe.tags) Chip(label: Text(t))],
                ),
              ),
            if (recipe.sourceUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space2),
                child: SelectableText(
                  '${l10n.mealsSource}: ${recipe.sourceUrl}',
                  style: theme.textTheme.bodySmall?.copyWith(color: ww.ink2),
                ),
              ),
            const SizedBox(height: Tokens.space2),
            Text(l10n.mealsIngredients, style: theme.textTheme.titleLarge),
            const SizedBox(height: Tokens.space2),
            if (recipe.ingredients.isEmpty)
              Text(l10n.mealsNoIngredients, style: TextStyle(color: ww.ink3)),
            for (final i in recipe.ingredients)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 112,
                      child: Text(
                        context.quantityText(
                          scaleQuantity(
                            i.quantity,
                            recipe.servingsDefault,
                            servings,
                          ),
                          i.unit,
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.rawName, style: theme.textTheme.bodyLarge),
                          if (i.note != null)
                            Text(
                              i.note!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: ww.ink2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Tokens.space6),
            Text(l10n.mealsSteps, style: theme.textTheme.titleLarge),
            const SizedBox(height: Tokens.space2),
            for (final (n, step) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${n + 1}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: Tokens.space3),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          step,
                          style: const TextStyle(fontSize: 22, height: 1.4),
                        ),
                      ),
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
