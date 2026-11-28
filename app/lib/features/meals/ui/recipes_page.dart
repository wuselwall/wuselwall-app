import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/search.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/search_field.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';

/// Every recipe, searchable by title and tag. Recipes are optional enrichment, so the
/// empty state says a dish name is enough for a meal.
class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recipes = ref.watch(recipesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mealsRecipesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.recipeEdit),
        icon: const Icon(Icons.add),
        label: Text(l10n.mealsRecipeNew),
      ),
      body: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Tokens.space4),
              child: SearchField(
                hint: l10n.mealsRecipeSearch,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: AsyncValueView(
                value: recipes,
                onRetry: () => ref.invalidate(recipesProvider),
                data: (all) {
                  if (all.isEmpty) {
                    return EmptyView(
                      message: l10n.mealsRecipesEmpty,
                      actions: [
                        FilledButton.icon(
                          onPressed: () => context.push(Routes.recipeEdit),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.mealsRecipeNew),
                        ),
                      ],
                    );
                  }
                  final shown = searchTerms(_query).isEmpty
                      ? all
                      : searchIn(_query, all, (r) => [r.title, ...r.tags]);
                  return ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = shown[i];
                      return ListTile(
                        leading: const Icon(Icons.menu_book),
                        title: Text(r.title),
                        subtitle: r.tags.isEmpty
                            ? null
                            : Text(r.tags.join(', ')),
                        onTap: () => context.push(Routes.recipeView, extra: r),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
