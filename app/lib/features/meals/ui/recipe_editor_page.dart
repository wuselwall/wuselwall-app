import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/count_stepper.dart';
import 'package:wuselwall/features/meals/ui/meals_format.dart';

/// Creates or edits a recipe. The ingredient list is saved as one array, so its order is
/// the order the rows show; drag a row by its handle to reorder.
class RecipeEditorPage extends ConsumerStatefulWidget {
  const RecipeEditorPage({this.recipe, super.key});

  /// Null creates a recipe.
  final Recipe? recipe;

  @override
  ConsumerState<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

/// One ingredient row while it is edited. Text lives in the draft until save.
class _Draft {
  _Draft({
    required this.id,
    this.name = '',
    this.quantity = '',
    this.unit = '',
    this.note = '',
    this.catalogItemId,
  });

  final int id;
  String name;
  String quantity;
  String unit;
  String note;
  final String? catalogItemId;
}

class _RecipeEditorPageState extends ConsumerState<RecipeEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _steps;
  late final TextEditingController _tags;
  late final TextEditingController _source;
  late int _servings;
  final _ingredients = <_Draft>[];
  var _nextId = 0;
  var _titleError = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _title = TextEditingController(text: r?.title ?? '');
    _steps = TextEditingController(text: r?.steps ?? '');
    _tags = TextEditingController(text: r?.tags.join(', ') ?? '');
    _source = TextEditingController(text: r?.sourceUrl ?? '');
    _servings = r?.servingsDefault ?? 4;
    for (final i in r?.ingredients ?? const <RecipeIngredient>[]) {
      _ingredients.add(
        _Draft(
          id: _nextId++,
          name: i.rawName,
          quantity: i.quantity == null ? '' : _plain(i.quantity!),
          unit: i.unit ?? '',
          note: i.note ?? '',
          catalogItemId: i.catalogItemId,
        ),
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _steps.dispose();
    _tags.dispose();
    _source.dispose();
    super.dispose();
  }

  /// A quantity as a form field shows it: "2", "1.5".
  static String _plain(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  static String? _orNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      _ingredients.insert(newIndex, _ingredients.removeAt(oldIndex));
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    final recipe = Recipe(
      id: widget.recipe?.id ?? '',
      title: title,
      servingsDefault: _servings,
      steps: _orNull(_steps.text),
      sourceUrl: _orNull(_source.text),
      tags: [
        for (final t in _tags.text.split(','))
          if (t.trim().isNotEmpty) t.trim(),
      ],
      // A row without a name is an empty row, not an ingredient.
      ingredients: [
        for (final d in _ingredients)
          if (d.name.trim().isNotEmpty)
            RecipeIngredient(
              rawName: d.name.trim(),
              catalogItemId: d.catalogItemId,
              quantity: MealsFormat.parseQuantity(d.quantity),
              unit: _orNull(d.unit),
              note: _orNull(d.note),
            ),
      ],
    );
    setState(() => _busy = true);
    final result = await ref
        .read(mealsRepositoryProvider)
        .saveRecipe(actor: ref.read(actingProfileProvider), recipe: recipe);
    if (!mounted) return;
    setState(() => _busy = false);
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.recipe == null ? l10n.mealsRecipeNew : l10n.mealsRecipeEdit,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: l10n.mealsRecipeTitleField,
                  errorText: _titleError ? l10n.mealsRecipeTitleRequired : null,
                ),
                onChanged: (_) {
                  if (_titleError) setState(() => _titleError = false);
                },
              ),
              CountStepper(
                label: l10n.mealsServings,
                value: _servings,
                min: 1,
                max: 50,
                onChanged: (v) => setState(() => _servings = v),
              ),
              const SizedBox(height: Tokens.space4),
              Text(l10n.mealsIngredients, style: theme.textTheme.titleMedium),
              const SizedBox(height: Tokens.space2),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: _reorder,
                children: [
                  for (final (index, draft) in _ingredients.indexed)
                    _IngredientRow(
                      key: ValueKey(draft.id),
                      index: index,
                      draft: draft,
                      onRemove: () =>
                          setState(() => _ingredients.remove(draft)),
                    ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.mealsIngredientAdd),
                  onPressed: () =>
                      setState(() => _ingredients.add(_Draft(id: _nextId++))),
                ),
              ),
              const SizedBox(height: Tokens.space4),
              TextField(
                controller: _steps,
                minLines: 4,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: l10n.mealsSteps,
                  hintText: l10n.mealsStepsHint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: Tokens.space4),
              TextField(
                controller: _tags,
                decoration: InputDecoration(
                  labelText: l10n.mealsTags,
                  hintText: l10n.mealsTagsHint,
                ),
              ),
              const SizedBox(height: Tokens.space4),
              TextField(
                controller: _source,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: l10n.mealsSourceUrl),
              ),
              const SizedBox(height: Tokens.space6),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(l10n.mealsRecipeSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One ingredient: a drag handle, the name and amount, the note, a remove button.
class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.index,
    required this.draft,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _Draft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(top: 16, right: Tokens.space1),
              child: Tooltip(
                message: l10n.mealsIngredientMove,
                child: const Icon(Icons.drag_handle),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue: draft.name,
                        decoration: InputDecoration(
                          labelText: l10n.mealsIngredientName,
                        ),
                        onChanged: (v) => draft.name = v,
                      ),
                    ),
                    const SizedBox(width: Tokens.space2),
                    SizedBox(
                      width: 84,
                      child: TextFormField(
                        initialValue: draft.quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.mealsIngredientQuantity,
                        ),
                        onChanged: (v) => draft.quantity = v,
                      ),
                    ),
                    const SizedBox(width: Tokens.space2),
                    SizedBox(
                      width: 92,
                      child: TextFormField(
                        initialValue: draft.unit,
                        decoration: InputDecoration(
                          labelText: l10n.mealsIngredientUnit,
                        ),
                        onChanged: (v) => draft.unit = v,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  initialValue: draft.note,
                  decoration: InputDecoration(
                    labelText: l10n.mealsIngredientNote,
                  ),
                  onChanged: (v) => draft.note = v,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.mealsIngredientRemove,
            icon: const Icon(Icons.delete_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
