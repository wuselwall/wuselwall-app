import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/text/fold.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/domain/meal_suggestions.dart';
import 'package:wuselwall/features/meals/ui/meals_format.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/data/rituals_repository.dart';
import 'package:wuselwall/features/rituals/domain/meal_icons.dart';
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
                    _WithPicture(
                      iconKey: w.iconKey,
                      child: Text(
                        l10n.kidWishPlanned(w.title, _when(context, w, today)),
                        style: body,
                      ),
                    ),
                  for (final w in open) ...[
                    _WithPicture(
                      iconKey: w.iconKey,
                      child: Text(l10n.kidWishWaiting(w.title), style: body),
                    ),
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

/// What the picker hands back: a recipe, or a few words with an optional picture.
typedef WishChoice = ({String? recipeId, String? text, String? iconKey});

/// The wish picker (specs/27): the meals the family cooks most, the family's recipes with
/// their pictures (all of them, with a search), or a few words of one's own with a
/// picture. [wishId] names the open wish this choice changes; without it the choice is a
/// new wish.
Future<void> showWishPicker(
  BuildContext context,
  WidgetRef ref,
  String actor, {
  String? wishId,
}) async {
  final choice = await showModalBottomSheet<WishChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const WishPicker(),
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
        iconKey: choice.iconKey,
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

/// The picker's sheet; pops a [WishChoice].
class WishPicker extends ConsumerStatefulWidget {
  const WishPicker({super.key});

  /// From this many recipes on, the picker offers a search.
  static const searchFrom = 7;

  @override
  ConsumerState<WishPicker> createState() => _WishPickerState();
}

class _WishPickerState extends ConsumerState<WishPicker> {
  final _search = TextEditingController();
  final _text = TextEditingController();
  String? _icon;

  @override
  void dispose() {
    _search.dispose();
    _text.dispose();
    super.dispose();
  }

  void _pick(WishChoice choice) => Navigator.of(context).pop(choice);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    // "Oft bei uns": the meal suggestions of the meal editor (FR-3.8), first.
    final often = suggestMeals(
      ref.watch(mealHistoryProvider).value ?? const <MealHistoryEntry>[],
      ref.watch(ritualTodayProvider),
    ).often;
    final query = fold(_search.text.trim());
    final matches = query.isEmpty
        ? recipes
        : [
            for (final r in recipes)
              if (fold(r.title).contains(query)) r,
          ];
    final heading = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final text = _text.text.trim();

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
            if (often.isNotEmpty) ...[
              const SizedBox(height: Tokens.space3),
              Text(l10n.mealsUxSuggestOften, style: heading),
              const SizedBox(height: Tokens.space2),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final m in often)
                    DishTile(
                      key: ValueKey('wish-often-${m.title}'),
                      title: m.title,
                      iconKey: m.iconKey,
                      onTap: () => _pick(
                        m.recipeId != null
                            ? (recipeId: m.recipeId, text: null, iconKey: null)
                            : (
                                recipeId: null,
                                text: m.title,
                                iconKey: m.iconKey,
                              ),
                      ),
                    ),
                ],
              ),
            ],
            if (recipes.isNotEmpty) ...[
              const SizedBox(height: Tokens.space4),
              Text(l10n.wishPickerRecipes, style: heading),
              if (recipes.length >= WishPicker.searchFrom) ...[
                const SizedBox(height: Tokens.space2),
                TextField(
                  key: const ValueKey('wish-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: l10n.wishPickerSearch,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: Tokens.space2),
              if (matches.isEmpty)
                Text(l10n.wishPickerNoMatch, style: theme.textTheme.bodyLarge)
              else
                Wrap(
                  spacing: Tokens.space2,
                  runSpacing: Tokens.space2,
                  children: [
                    for (final r in matches)
                      DishTile(
                        key: ValueKey('wish-recipe-${r.id}'),
                        title: r.title,
                        iconKey: r.iconKey,
                        onTap: () =>
                            _pick((recipeId: r.id, text: null, iconKey: null)),
                      ),
                  ],
                ),
            ],
            const SizedBox(height: Tokens.space4),
            Text(l10n.wishPickerOwn, style: heading),
            const SizedBox(height: Tokens.space2),
            TextField(
              key: const ValueKey('wish-text'),
              controller: _text,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l10n.wishPickerOwnHint),
              onChanged: (_) => setState(() {}),
            ),
            Text(l10n.wishPickerIcon, style: theme.textTheme.labelLarge),
            const SizedBox(height: Tokens.space2),
            Wrap(
              spacing: Tokens.space1,
              runSpacing: Tokens.space1,
              children: [
                for (final key in mealIconKeys)
                  _IconChoice(
                    iconKey: key,
                    selected: _icon == key,
                    onTap: () =>
                        setState(() => _icon = _icon == key ? null : key),
                  ),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            FilledButton(
              key: const ValueKey('wish-send'),
              onPressed: text.isEmpty
                  ? null
                  : () => _pick((recipeId: null, text: text, iconKey: _icon)),
              child: Text(l10n.wishPickerSend),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dish to wish for: its picture and its name, a big target for small fingers.
class DishTile extends StatelessWidget {
  const DishTile({
    required this.title,
    required this.onTap,
    this.iconKey,
    super.key,
  });

  final String title;
  final String? iconKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final picture = mealIconAsset(iconKey);
    return SizedBox(
      width: 112,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space2),
            child: Column(
              children: [
                if (picture != null)
                  EmojiPicture(picture, size: 40)
                else
                  Icon(
                    Icons.restaurant,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                const SizedBox(height: Tokens.space1),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One picture to go with a wish of one's own words.
class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.iconKey,
    required this.selected,
    required this.onTap,
  });

  final String iconKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = mealIconName(context.l10n, iconKey);
    return Tooltip(
      message: name,
      child: Semantics(
        button: true,
        selected: selected,
        label: name,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('wish-icon-$iconKey'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected ? scheme.primaryContainer : null,
              border: Border.all(
                color: selected ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: EmojiPicture(mealIconAsset(iconKey)!, size: 36),
          ),
        ),
      ),
    );
  }
}

/// [child] with the wish's picture before it, when it has one.
class _WithPicture extends StatelessWidget {
  const _WithPicture({required this.iconKey, required this.child});

  final String? iconKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final picture = mealIconAsset(iconKey);
    if (picture == null) return child;
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space1),
      child: Row(
        children: [
          EmojiPicture(picture, size: 32),
          const SizedBox(width: Tokens.space2),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The planner's wishes (specs/27): a chip per open wish above the week, with its
/// picture, and "von letzter Woche" on one that has waited since an earlier week. A tap
/// puts it on a day of the shown week; a guardian may remove one, and the child's card
/// then simply invites a new wish. When the family lets everyone wish
/// (`meals.wishes`), the grown-up at the planner wishes here too, with the same picker.
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
    final members = {
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        m.id: m,
    };
    final day = ref.watch(lighterDayProvider);
    final acting = members[ref.watch(actingProfileProvider)];
    // The server decides who may wish (api.meal_wish_set); this only offers it.
    final canWish = acting != null && mayWish(day, acting);
    if (wishes.isEmpty && !canWish) return const SizedBox.shrink();
    final mine = [
      for (final w in wishes)
        if (w.profileId == acting?.id) w,
    ];
    final atLimit = mine.length >= wishLimit(day);
    final today = ref.watch(ritualTodayProvider);
    final lastMonday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1) - 7,
    );
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
                    since: !w.earlierWeek
                        ? null
                        : w.wishedOn == null ||
                              !w.wishedOn!.isBefore(lastMonday)
                        ? l10n.mealsWishEarlier
                        : l10n.mealsWishOlder,
                  ),
                if (canWish)
                  ActionChip(
                    key: const ValueKey('wish-mine'),
                    avatar: const Icon(Icons.star_outline_rounded),
                    label: Text(
                      atLimit ? l10n.mealsWishMineChange : l10n.mealsWishMine,
                    ),
                    onPressed: () => unawaited(
                      showWishPicker(
                        context,
                        ref,
                        acting.id,
                        // At the limit the newest of one's own wishes changes.
                        wishId: atLimit ? mine.last.id : null,
                      ),
                    ),
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
    this.since,
  });

  final MealWish wish;
  final Member? member;
  final DateTime weekStart;

  /// "von letzter Woche" for a wish that has waited since an earlier week.
  final String? since;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final m = member;
    final colors = m == null ? null : context.ww.member(m.color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ActionChip(
            avatar: colors == null
                ? null
                : CircleAvatar(
                    backgroundColor: colors.ink,
                    foregroundColor: colors.onInk,
                    child: Text(m!.initial),
                  ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l10n.mealsWishChip(
                            m?.displayName ?? '',
                            wish.title,
                          ),
                        ),
                        if (since != null)
                          TextSpan(
                            text: ' · $since',
                            style: TextStyle(
                              color: context.ww.ink2,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (mealIconAsset(wish.iconKey) case final picture?) ...[
                  const SizedBox(width: Tokens.space1),
                  EmojiPicture(picture, size: 20),
                ],
              ],
            ),
            tooltip: l10n.mealsWishPlan,
            onPressed: () => unawaited(_plan(context, ref)),
          ),
        ),
        // Separate controls keep the remove action outside the plan action's node.
        if (_mayRemove(ref))
          Semantics(
            container: true,
            label: wish.title,
            child: IconButton(
              tooltip: l10n.mealsWishRemove,
              onPressed: () => unawaited(_remove(context, ref)),
              icon: const Icon(Icons.cancel_outlined),
            ),
          ),
      ],
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

    final wisher = ref
        .watch(membersProvider)
        .value
        ?.where((m) => m.id == widget.wish.profileId)
        .firstOrNull;

    // The dialog names the wish and who wished it: a date and two meals alone do not
    // say what is being planned (round-3 review H-3).
    return AlertDialog(
      title: Text(l10n.mealsWishPlanTitle(widget.wish.title)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wisher != null) ...[
            Text(
              l10n.mealsWishedBy(wisher.displayName),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.ww.ink2),
            ),
            const SizedBox(height: Tokens.space2),
          ],
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
