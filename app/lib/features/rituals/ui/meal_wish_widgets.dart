import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/data/rituals_repository.dart';
import 'package:wuselwall/features/rituals/domain/ritual_models.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// Whether [member] may wish a meal (`meals.wishes`: children, everyone or off).
bool mayWish(LighterDay day, Member member) =>
    switch (day.value('meals.wishes')) {
      'off' => false,
      'everyone' => true,
      _ => member.isChild,
    };

/// "Dein Wunschessen" on the child's day (specs/27): the wish as it stands, or the
/// invitation to make one. A wish not planned yet simply waits; it is never declined.
class KidWishCard extends ConsumerWidget {
  const KidWishCard({required this.member, super.key});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (!mayWish(ref.watch(lighterDayProvider), member)) {
      return const SizedBox.shrink();
    }
    final wishes = [
      for (final w in ref.watch(mealWishesProvider).value ?? const <MealWish>[])
        if (w.profileId == member.id) w,
    ];
    final open = wishes.where((w) => !w.planned).firstOrNull;
    final planned = wishes.where((w) => w.planned).firstOrNull;
    final today = ref.watch(ritualTodayProvider);
    final String text;
    if (planned != null &&
        planned.plannedOn != null &&
        !planned.plannedOn!.isBefore(today)) {
      text = l10n.kidWishPlanned(
        planned.title,
        MaterialLocalizations.of(context).formatFullDate(planned.plannedOn!),
      );
    } else if (open != null) {
      text = l10n.kidWishWaiting(open.title);
    } else {
      text = l10n.kidWishInvite;
    }
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space3),
      child: KidCard(
        onTap: () => unawaited(showWishPicker(context, ref, member.id)),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, size: 40),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.kidWishTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(text, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            Text(
              open == null ? l10n.kidWishMake : l10n.kidWishChange,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The wish picker: the family's recipes as big buttons, or a few words of one's own.
Future<void> showWishPicker(
  BuildContext context,
  WidgetRef ref,
  String actor,
) async {
  final choice = await showModalBottomSheet<({String? recipeId, String? text})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _WishPicker(),
  );
  if (choice == null || !context.mounted) return;
  final result = await ref
      .read(ritualsRepositoryProvider)
      .setWish(actor: actor, recipeId: choice.recipeId, freeText: choice.text);
  ref.invalidate(mealWishesProvider);
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      context.showMessage(context.l10n.kidWishSent);
    case Err(:final failure):
      context.showFailure(failure);
  }
}

class _WishPicker extends ConsumerStatefulWidget {
  const _WishPicker();

  @override
  ConsumerState<_WishPicker> createState() => _WishPickerState();
}

class _WishPickerState extends ConsumerState<_WishPicker> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.space4,
        right: Tokens.space4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.space4,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.wishPickerTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Tokens.space3),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                for (final r in recipes.take(24))
                  ActionChip(
                    label: Text(r.title),
                    onPressed: () =>
                        Navigator.of(context).pop((recipeId: r.id, text: null)),
                  ),
              ],
            ),
            const SizedBox(height: Tokens.space4),
            TextField(
              key: const ValueKey('wish-text'),
              controller: _text,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.wishPickerOwn,
                hintText: l10n.wishPickerOwnHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            FilledButton(
              onPressed: _text.text.trim().isEmpty
                  ? null
                  : () =>
                        Navigator.of(context)
                            .pop((recipeId: null, text: _text.text.trim())),
              child: Text(l10n.wishPickerSend),
            ),
          ],
        ),
      ),
    );
  }
}

/// The planner's wishes (specs/27): a chip per open wish above the week. A tap puts it
/// on a day of the shown week; a guardian may remove one, and the child's card then
/// simply invites a new wish.
class MealWishTray extends ConsumerWidget {
  const MealWishTray({required this.weekStart, super.key});

  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final wishes = [
      for (final w in ref.watch(mealWishesProvider).value ?? const <MealWish>[])
        if (!w.planned) w,
    ];
    if (wishes.isEmpty) return const SizedBox.shrink();
    final members = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        0,
        Tokens.space4,
        Tokens.space2,
      ),
      child: Row(
        children: [
          Text(
            l10n.mealsWishesTray,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                for (final w in wishes)
                  _WishChip(
                    wish: w,
                    member: members[w.profileId],
                    weekStart: weekStart,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WishChip extends ConsumerWidget {
  const _WishChip({
    required this.wish,
    required this.member,
    required this.weekStart,
  });

  final MealWish wish;
  final Member? member;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final m = member;
    final colors = m == null ? null : context.ww.member(m.color);
    return InputChip(
      avatar: colors == null
          ? null
          : CircleAvatar(
              backgroundColor: colors.ink,
              foregroundColor: colors.onInk,
              child: Text(m!.initial),
            ),
      label: Text(l10n.mealsWishChip(m?.displayName ?? '', wish.title)),
      tooltip: l10n.mealsWishPlan,
      onPressed: () => unawaited(_plan(context, ref)),
      onDeleted: () => unawaited(_remove(context, ref)),
      deleteButtonTooltipMessage: l10n.mealsWishRemove,
    );
  }

  Future<void> _plan(BuildContext context, WidgetRef ref) async {
    final picked = await showDialog<(DateTime, String)>(
      context: context,
      builder: (_) => _PlanDialog(weekStart: weekStart),
    );
    if (picked == null || !context.mounted) return;
    final result = await ref
        .read(ritualsRepositoryProvider)
        .planWish(
          actor: ref.read(actingProfileProvider),
          id: wish.id,
          onDate: picked.$1,
          slot: picked.$2,
        );
    ref
      ..invalidate(mealWishesProvider)
      ..invalidate(mealEntriesProvider(weekStart));
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(ritualsRepositoryProvider)
        .withdrawWish(actor: ref.read(actingProfileProvider), id: wish.id);
    ref.invalidate(mealWishesProvider);
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }
}

class _PlanDialog extends StatefulWidget {
  const _PlanDialog({required this.weekStart});

  final DateTime weekStart;

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late DateTime _day = widget.weekStart;
  String _slot = 'dinner';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final loc = MaterialLocalizations.of(context);
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(
          widget.weekStart.year,
          widget.weekStart.month,
          widget.weekStart.day + i,
        ),
    ];
    return AlertDialog(
      title: Text(l10n.mealsWishPlan),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<DateTime>(
            value: _day,
            isExpanded: true,
            items: [
              for (final d in days)
                DropdownMenuItem(value: d, child: Text(loc.formatFullDate(d))),
            ],
            onChanged: (d) => setState(() => _day = d ?? _day),
          ),
          const SizedBox(height: Tokens.space3),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'lunch', label: Text(l10n.mealsSlotLunch)),
              ButtonSegment(value: 'dinner', label: Text(l10n.mealsSlotDinner)),
            ],
            selected: {_slot},
            onSelectionChanged: (s) => setState(() => _slot = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_day, _slot)),
          child: Text(l10n.mealsWishPlan),
        ),
      ],
    );
  }
}

/// On Today, for grown-ups: the wishes waiting to be planned, quietly, with the way to
/// the meal plan. Not a notification (specs/27).
class TodayWishCard extends ConsumerWidget {
  const TodayWishCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final wishes = [
      for (final w in ref.watch(mealWishesProvider).value ?? const <MealWish>[])
        if (!w.planned) w,
    ];
    if (wishes.isEmpty) return const SizedBox.shrink();
    final names = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m.displayName,
    };
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star_rounded),
        title: Text(l10n.mealsWishesTray),
        subtitle: Text(
          [
            for (final w in wishes)
              l10n.mealsWishChip(names[w.profileId] ?? '', w.title),
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ref.read(homeTabProvider.notifier).select(HomeTab.meals),
      ),
    );
  }
}
