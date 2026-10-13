import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/count_stepper.dart';
import 'package:wuselwall/features/meals/ui/meals_format.dart';

/// Opens the editor for one slot of one day. Everything except the dish saves on its
/// own, as it changes; the dish and the rest of the fields save with the button.
Future<void> showMealEditor(
  BuildContext context, {
  required DateTime date,
  required PlanSlot slot,
  MealEntry? entry,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _MealEditorSheet(date: date, slot: slot, entry: entry),
);

/// The three answers to "is this person eating": by the rule, or set by hand.
enum _Eating { automatic, yes, no }

class _MealEditorSheet extends ConsumerStatefulWidget {
  const _MealEditorSheet({
    required this.date,
    required this.slot,
    required this.entry,
  });

  final DateTime date;
  final PlanSlot slot;
  final MealEntry? entry;

  @override
  ConsumerState<_MealEditorSheet> createState() => _MealEditorSheetState();
}

class _MealEditorSheetState extends ConsumerState<_MealEditorSheet> {
  late final TextEditingController _text;
  String? _recipeId;
  int? _servings;
  String? _cook;
  TimeOfDay? _time;
  late int _guests;
  late Map<String, bool> _overrides;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _text = TextEditingController(text: e?.title ?? '');
    _recipeId = e?.recipeId;
    _servings = e?.servings;
    _cook = e?.cookProfileId;
    _time = e?.atTime;
    _guests = e?.guests ?? 0;
    _overrides = {...?e?.eatingOverrides};
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _invalidate() =>
      ref.invalidate(mealEntriesProvider(mondayOf(widget.date)));

  Future<void> _setEating(String profileId, _Eating choice) async {
    final eating = switch (choice) {
      _Eating.automatic => null,
      _Eating.yes => true,
      _Eating.no => false,
    };
    setState(() => _busy = true);
    final result = await ref
        .read(mealsRepositoryProvider)
        .setEating(
          actor: ref.read(actingProfileProvider),
          date: widget.date,
          slot: widget.slot,
          profileId: profileId,
          eating: eating,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        setState(() {
          if (eating == null) {
            _overrides.remove(profileId);
          } else {
            _overrides[profileId] = eating;
          }
        });
        _invalidate();
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _save(List<Recipe> recipes) async {
    final text = _text.text.trim();
    final recipe = recipes.where((r) => r.id == _recipeId).firstOrNull;
    final repo = ref.read(mealsRepositoryProvider);
    final actor = ref.read(actingProfileProvider);
    final entry = widget.entry;

    setState(() => _busy = true);
    final result = text.isEmpty && recipe == null
        // Nothing to show: an entry that only carries eating overrides keeps them;
        // otherwise the slot is cleared.
        ? (entry != null && entry.eatingOverrides.isNotEmpty
              ? await repo
                    .setMeal(
                      actor: actor,
                      date: widget.date,
                      slot: widget.slot,
                      guests: _guests,
                      cookProfileId: _cook,
                      time: _time,
                    )
                    .then((r) => r.map((_) {}))
              : await repo.clearMeal(
                  actor: actor,
                  date: widget.date,
                  slot: widget.slot,
                ))
        : await repo
              .setMeal(
                actor: actor,
                date: widget.date,
                slot: widget.slot,
                recipeId: recipe?.id,
                freeText: recipe == null ? text : null,
                servings: recipe == null ? null : _servings,
                cookProfileId: _cook,
                time: _time,
                guests: _guests,
              )
              .then((r) => r.map((_) {}));
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        _invalidate();
        Navigator.of(context).pop();
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final result = await ref
        .read(mealsRepositoryProvider)
        .clearMeal(
          actor: ref.read(actingProfileProvider),
          date: widget.date,
          slot: widget.slot,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        _invalidate();
        Navigator.of(context).pop();
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 18, minute: 30),
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final theme = Theme.of(context);
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final members = (ref.watch(membersProvider).value ?? const <Member>[])
        .where((m) => m.active)
        .toList();
    final recipe = recipes.where((r) => r.id == _recipeId).firstOrNull;
    final query = fold(_text.text.trim());
    final suggestions = recipe != null || query.isEmpty
        ? const <Recipe>[]
        : [
            for (final r in recipes)
              if (fold(r.title).contains(query)) r,
          ].take(5).toList();
    final isEntry = widget.entry != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            Tokens.space4,
            0,
            Tokens.space4,
            Tokens.space4 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.mealsEditTitle(context.fullDate(widget.date)),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: Tokens.space1),
              Text(
                context.planSlotLabel(widget.slot),
                style: theme.textTheme.bodyMedium?.copyWith(color: ww.ink2),
              ),
              const SizedBox(height: Tokens.space4),
              TextField(
                controller: _text,
                autofocus: !isEntry,
                decoration: InputDecoration(
                  labelText: l10n.mealsFieldLabel,
                  hintText: l10n.mealsFieldHint,
                  prefixIcon: Icon(
                    recipe == null ? Icons.edit_note : Icons.menu_book,
                  ),
                ),
                onChanged: (v) => setState(() {
                  if (recipe != null && v.trim() != recipe.title) {
                    _recipeId = null;
                  }
                }),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: Tokens.space2),
                Text(
                  l10n.mealsSuggestionHelp,
                  style: theme.textTheme.bodySmall?.copyWith(color: ww.ink2),
                ),
                for (final r in suggestions)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book),
                    title: Text(r.title),
                    onTap: () => setState(() {
                      _recipeId = r.id;
                      _text.text = r.title;
                      _text.selection = TextSelection.collapsed(
                        offset: r.title.length,
                      );
                    }),
                  ),
              ],
              if (recipe != null) ...[
                const SizedBox(height: Tokens.space3),
                CountStepper(
                  label: l10n.mealsServings,
                  value: _servings ?? recipe.servingsDefault,
                  min: 1,
                  max: 50,
                  onChanged: (v) => setState(() => _servings = v),
                ),
              ],
              const SizedBox(height: Tokens.space4),
              Text(l10n.mealsCook, style: theme.textTheme.titleSmall),
              const SizedBox(height: Tokens.space2),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  ChoiceChip(
                    label: Text(l10n.mealsCookNobody),
                    selected: _cook == null,
                    onSelected: (_) => setState(() => _cook = null),
                  ),
                  for (final m in members)
                    ChoiceChip(
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundColor: ww.member(m.color).ink,
                        child: Text(
                          m.initial,
                          style: TextStyle(
                            color: ww.member(m.color).onInk,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      label: Text(m.displayName),
                      selected: _cook == m.id,
                      onSelected: (_) => setState(() => _cook = m.id),
                    ),
                ],
              ),
              const SizedBox(height: Tokens.space4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.mealsTime,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _pickTime,
                    child: Text(
                      _time == null ? l10n.mealsTimeNone : context.time(_time!),
                    ),
                  ),
                  if (_time != null)
                    IconButton(
                      tooltip: l10n.mealsTimeNone,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _time = null),
                    ),
                ],
              ),
              CountStepper(
                label: l10n.mealsGuests,
                value: _guests,
                min: 0,
                max: 20,
                onChanged: (v) => setState(() => _guests = v),
              ),
              const SizedBox(height: Tokens.space4),
              Text(l10n.mealsEatingTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: Tokens.space1),
              Text(
                l10n.mealsEatingHelp,
                style: theme.textTheme.bodySmall?.copyWith(color: ww.ink2),
              ),
              const SizedBox(height: Tokens.space2),
              for (final m in members)
                Padding(
                  padding: const EdgeInsets.only(bottom: Tokens.space2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: ww.member(m.color).ink,
                          ),
                          const SizedBox(width: Tokens.space2),
                          Text(m.displayName),
                        ],
                      ),
                      const SizedBox(height: Tokens.space1),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_Eating>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: _Eating.automatic,
                              label: Text(l10n.mealsEatingAuto),
                            ),
                            ButtonSegment(
                              value: _Eating.yes,
                              label: Text(l10n.mealsEatingYes),
                            ),
                            ButtonSegment(
                              value: _Eating.no,
                              label: Text(l10n.mealsEatingNo),
                            ),
                          ],
                          selected: {
                            switch (_overrides[m.id]) {
                              null => _Eating.automatic,
                              true => _Eating.yes,
                              false => _Eating.no,
                            },
                          },
                          onSelectionChanged: _busy
                              ? null
                              : (s) => _setEating(m.id, s.single),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Tokens.space4),
              Row(
                children: [
                  if (isEntry)
                    TextButton.icon(
                      onPressed: _busy ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.mealsDelete),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: Tokens.space2),
                  FilledButton(
                    onPressed: _busy ? null : () => _save(recipes),
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
