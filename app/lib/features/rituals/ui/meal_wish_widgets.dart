import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/meals_format.dart';
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

/// Whether this household's server has meal wishes at all: it announces a lighter day
/// and its settings carry `meals.wishes`. Against an older server nobody is invited to
/// wish only for the write to fail.
final wishesAvailableProvider = Provider.autoDispose<bool>(
  (ref) =>
      ref.watch(lighterDaySupportedProvider) &&
      ref.watch(lighterDayProvider).values.containsKey('meals.wishes'),
);

/// How many wishes a member may have open at once (`meals.wishes_per_week`).
int wishLimit(LighterDay day) {
  final v = day.value('meals.wishes_per_week');
  return v is num && v >= 1 ? v.toInt() : 1;
}

/// "Dein Wunschessen" on the child's day (specs/27): each open wish with the way to
/// change or take it back, a planned one with its day, and the invitation while there
/// is room for another. A wish not planned yet simply waits; it is never declined.
class KidWishCard extends ConsumerWidget {
  const KidWishCard({required this.member, super.key});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final day = ref.watch(lighterDayProvider);
    if (!ref.watch(wishesAvailableProvider) || !mayWish(day, member)) {
      return const SizedBox.shrink();
    }
    final today = ref.watch(ritualTodayProvider);
    final wishes = [
      for (final w in ref.watch(mealWishesProvider).value ?? const <MealWish>[])
        if (w.profileId == member.id) w,
    ];
    final open = [
      for (final w in wishes)
        if (!w.planned) w,
    ];
    final planned = [
      for (final w in wishes)
        if (w.planned && w.plannedOn != null && !w.plannedOn!.isBefore(today))
          w,
    ]..sort((a, b) => a.plannedOn!.compareTo(b.plannedOn!));
    final room = open.length < wishLimit(day);
    void wish({String? change}) =>
        unawaited(showWishPicker(context, ref, member.id, wishId: change));
    final body = theme.textTheme.bodyLarge;
    final action = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space3),
      child: KidCard(
        // With nothing open the whole card invites; otherwise its buttons speak.
        onTap: open.isEmpty && room ? wish : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  for (final w in planned)
                    Text(
                      l10n.kidWishPlanned(w.title, _when(context, w, today)),
                      style: body,
                    ),
                  for (final w in open) ...[
                    Text(l10n.kidWishWaiting(w.title), style: body),
                    Wrap(
                      spacing: Tokens.space2,
                      children: [
                        TextButton(
                          onPressed: () => wish(change: w.id),
                          child: Text(l10n.kidWishChange, style: action),
                        ),
                        TextButton(
                          onPressed: () =>
                              unawaited(_withdraw(context, member.id, w)),
                          child: Text(l10n.kidWishWithdraw),
                        ),
                      ],
                    ),
                  ],
                  if (room && open.isEmpty && planned.isEmpty)
                    Text(l10n.kidWishInvite, style: body),
                  if (room)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: wish,
                        child: Text(
                          open.isEmpty && planned.isEmpty
                              ? l10n.kidWishMake
                              : l10n.kidWishAnother,
                          style: action,
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

  /// "am Donnerstag": the weekday within the coming week, the date beyond it.
  static String _when(BuildContext context, MealWish w, DateTime today) {
    final on = w.plannedOn!;
    return on.difference(today).inDays < 7
        ? context.weekdayLong(on)
        : context.fullDate(on);
  }

  Future<void> _withdraw(BuildContext context, String actor, MealWish w) async {
    final container = ProviderScope.containerOf(context);
    final result = await container
        .read(ritualsRepositoryProvider)
        .withdrawWish(actor: actor, id: w.id);
    container.invalidate(mealWishesProvider);
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }
}

/// The wish picker: the family's recipes as big buttons, or a few words of one's own.
/// [wishId] names the open wish this choice changes; without it the choice is a new wish.
Future<void> showWishPicker(
  BuildContext context,
  WidgetRef ref,
  String actor, {
  String? wishId,
}) async {
  final choice = await showModalBottomSheet<({String? recipeId, String? text})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _WishPicker(),
  );
  if (choice == null || !context.mounted) return;
  // The container, not the ref: the child's page may be gone when the server answers.
  final container = ProviderScope.containerOf(context);
  final result = await container
      .read(ritualsRepositoryProvider)
      .setWish(
        actor: actor,
        recipeId: choice.recipeId,
        freeText: choice.text,
        wishId: wishId,
      );
  container.invalidate(mealWishesProvider);
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
    if (!ref.watch(wishesAvailableProvider)) return const SizedBox.shrink();
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
      // Removing someone else's wish is a guardian's (api.meal_wish_withdraw).
      onDeleted: _mayRemove(ref)
          ? () => unawaited(_remove(context, ref))
          : null,
      deleteButtonTooltipMessage: l10n.mealsWishRemove,
    );
  }

  bool _mayRemove(WidgetRef ref) {
    final acting = ref.watch(actingProfileProvider);
    if (acting == wish.profileId) return true;
    return ref
            .watch(membersProvider)
            .value
            ?.where((m) => m.id == acting)
            .firstOrNull
            ?.isGuardian ??
        false;
  }

  Future<void> _plan(BuildContext context, WidgetRef ref) async {
    final picked = await showDialog<PlannedWish>(
      context: context,
      builder: (_) => WishPlanDialog(wish: wish, weekStart: weekStart),
    );
    if (picked == null || !context.mounted) return;
    final container = ProviderScope.containerOf(context);
    final result = await container
        .read(ritualsRepositoryProvider)
        .planWish(
          actor: container.read(actingProfileProvider),
          id: wish.id,
          onDate: picked.day,
          slot: picked.slot.name,
          replace: picked.replace,
        );
    container
      ..invalidate(mealWishesProvider)
      ..invalidate(mealEntriesProvider(weekStart));
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context);
    final result = await container
        .read(ritualsRepositoryProvider)
        .withdrawWish(
          actor: container.read(actingProfileProvider),
          id: wish.id,
        );
    container.invalidate(mealWishesProvider);
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }
}

/// Where a wish goes: a day, a meal, and whether the meal already there gives way.
typedef PlannedWish = ({DateTime day, PlanSlot slot, bool replace});

/// The days of the week from [weekStart] a wish can still go on: today and later. A
/// week that is wholly past keeps all its days, so the dialog is never empty.
List<DateTime> wishPlanDays(DateTime weekStart, DateTime today) {
  final days = [
    for (var i = 0; i < 7; i++)
      DateTime(weekStart.year, weekStart.month, weekStart.day + i),
  ];
  final ahead = [
    for (final d in days)
      if (!d.isBefore(today)) d,
  ];
  return ahead.isEmpty ? days : ahead;
}

/// Picks a day and a meal for [wish], showing what each meal of that day already has.
/// Putting a wish where a meal is planned asks first; nothing is replaced by surprise.
class WishPlanDialog extends ConsumerStatefulWidget {
  const WishPlanDialog({
    required this.wish,
    required this.weekStart,
    super.key,
  });

  final MealWish wish;
  final DateTime weekStart;

  @override
  ConsumerState<WishPlanDialog> createState() => _WishPlanDialogState();
}

class _WishPlanDialogState extends ConsumerState<WishPlanDialog> {
  DateTime? _day;
  PlanSlot? _slot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = wishPlanDays(widget.weekStart, ref.watch(ritualTodayProvider));
    final day = _day ?? days.first;
    final slot = _slot ?? _freeOrWarm(day);
    final entries =
        ref.watch(mealEntriesProvider(widget.weekStart)).value ??
        const <MealEntry>[];
    String? dish(PlanSlot s) => entryAt(entries, day, s)?.title;

    return AlertDialog(
      title: Text(l10n.mealsWishPlan),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<DateTime>(
            value: day,
            isExpanded: true,
            items: [
              for (final d in days)
                DropdownMenuItem(value: d, child: Text(context.fullDate(d))),
            ],
            onChanged: (d) => setState(() {
              _day = d ?? _day;
              _slot = null;
            }),
          ),
          const SizedBox(height: Tokens.space3),
          for (final s in const [PlanSlot.lunch, PlanSlot.dinner])
            ListTile(
              key: ValueKey('wish-slot-${s.name}'),
              selected: s == slot,
              leading: Icon(
                s == slot
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(context.planSlotLabel(s)),
              subtitle: Text(dish(s) ?? l10n.mealsWishSlotFree),
              onTap: () => setState(() => _slot = s),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => unawaited(_submit(context, day, slot, dish(slot))),
          child: Text(l10n.mealsWishPlan),
        ),
      ],
    );
  }

  /// The meal a wish most likely goes to: the day's warm meal, unless it is taken and
  /// the other one is free.
  PlanSlot _freeOrWarm(DateTime day) {
    final warm = ref.watch(warmSlotProvider(day));
    final entries =
        ref.watch(mealEntriesProvider(widget.weekStart)).value ??
        const <MealEntry>[];
    final other = warm == PlanSlot.lunch ? PlanSlot.dinner : PlanSlot.lunch;
    final warmTaken = entryAt(entries, day, warm)?.title != null;
    final otherFree = entryAt(entries, day, other)?.title == null;
    return warmTaken && otherFree ? other : warm;
  }

  Future<void> _submit(
    BuildContext context,
    DateTime day,
    PlanSlot slot,
    String? taken,
  ) async {
    if (taken != null) {
      final l10n = context.l10n;
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.mealsWishReplaceTitle),
          content: Text(
            l10n.mealsWishReplaceBody(
              taken,
              context.planSlotLabel(slot),
              context.fullDate(day),
              widget.wish.title,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.mealsWishReplace),
            ),
          ],
        ),
      );
      if (replace != true || !context.mounted) return;
    }
    Navigator.of(context)
        .pop<PlannedWish>((day: day, slot: slot, replace: taken != null));
  }
}

/// On Today, for grown-ups: the wishes waiting to be planned, quietly, with the way to
/// the meal plan. Not a notification (specs/27).
class TodayWishCard extends ConsumerWidget {
  const TodayWishCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (!ref.watch(wishesAvailableProvider)) return const SizedBox.shrink();
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
