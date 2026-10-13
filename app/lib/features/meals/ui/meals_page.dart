import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/meal_editor_sheet.dart';
import 'package:wuselwall/features/meals/ui/meals_format.dart';
import 'package:wuselwall/features/meals/ui/shopping_preview_sheet.dart';

/// The week's navigation, in the app bar's bottom: the week before, the week after, and
/// a tap on the range to come back to this week.
class MealsToolbar extends ConsumerWidget implements PreferredSizeWidget {
  const MealsToolbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final weekStart = ref.watch(mealsWeekProvider);
    final nav = ref.read(mealsWeekProvider.notifier);
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
    );
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.mealsPrevWeek,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => nav.shift(-1),
          ),
          Expanded(
            child: InkWell(
              onTap: nav.today,
              child: Center(
                child: Text(
                  l10n.mealsWeekRange(
                    context.dayMonth(weekStart),
                    context.dayMonth(weekEnd),
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.mealsNextWeek,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => nav.shift(1),
          ),
        ],
      ),
    );
  }
}

/// The meals destination's body: the week's actions, then the seven days.
class MealsWeekBody extends ConsumerWidget {
  const MealsWeekBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final weekStart = ref.watch(mealsWeekProvider);
    final entries = ref.watch(mealEntriesProvider(weekStart));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space4,
            Tokens.space2,
            Tokens.space4,
            Tokens.space2,
          ),
          child: Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space2,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.shopping_basket),
                label: Text(l10n.mealsFillShopping),
                onPressed: entries.hasValue
                    ? () => _openPreview(context, ref, weekStart)
                    : null,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.menu_book),
                label: Text(l10n.mealsRecipes),
                onPressed: () => context.push(Routes.recipes),
              ),
            ],
          ),
        ),
        Expanded(
          child: _WeekGrid(
            weekStart: weekStart,
            // Shows the last week while a refetch runs, so a save never blanks the grid.
            entries: entries.value,
            retry: () => ref.invalidate(mealEntriesProvider(weekStart)),
            error: entries,
          ),
        ),
      ],
    );
  }

  Future<void> _openPreview(
    BuildContext context,
    WidgetRef ref,
    DateTime weekStart,
  ) async {
    final l10n = context.l10n;
    final to = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    final entries = ref.read(mealEntriesProvider(weekStart)).value ?? const [];
    final added = await showShoppingPreview(
      context,
      from: weekStart,
      to: to,
      entries: entries,
    );
    if (added != null && context.mounted) {
      context.showMessage(l10n.mealsPreviewAdded(added));
    }
  }
}

/// Seven days: columns on a laptop, rows on a phone. Same cells either way.
class _WeekGrid extends ConsumerWidget {
  const _WeekGrid({
    required this.weekStart,
    required this.entries,
    required this.retry,
    required this.error,
  });

  final DateTime weekStart;
  final List<MealEntry>? entries;
  final VoidCallback retry;
  final AsyncValue<List<MealEntry>> error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = this.entries;
    if (entries == null) {
      return AsyncValueView(
        value: error,
        onRetry: retry,
        data: (_) => const SizedBox.shrink(),
      );
    }
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          final column = (constraints.maxWidth - 2 * Tokens.space4) / 7;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(Tokens.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in days)
                  SizedBox(
                    width: column,
                    child: _DayCell(
                      date: day,
                      entries: entries,
                      weekStart: weekStart,
                    ),
                  ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(Tokens.space4),
          children: [
            for (final day in days)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space2),
                child: _DayCell(
                  date: day,
                  entries: entries,
                  weekStart: weekStart,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A meal being dragged: its day and slot.
class _MealRef {
  const _MealRef(this.date, this.slot);

  final DateTime date;
  final PlanSlot slot;
}

/// One day. The warm meal is the prominent card; the other slots show only once used,
/// and can be added from a small menu. A drop target: a dragged meal moves here, keeping
/// its slot (the server swaps when the target is taken).
class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.date,
    required this.entries,
    required this.weekStart,
  });

  final DateTime date;
  final List<MealEntry> entries;
  final DateTime weekStart;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final isToday = _sameDay(date, today);
    final warm = ref.watch(warmSlotProvider(date));
    final dayEntries = [
      for (final e in entries)
        if (_sameDay(e.onDate, date)) e,
    ];
    final warmEntry = dayEntries.where((e) => e.slot == warm).firstOrNull;
    final others = [
      for (final e in dayEntries)
        if (e.slot != warm && (e.hasDish || e.eatingOverrides.isNotEmpty)) e,
    ];
    final freeSlots = [
      for (final s in PlanSlot.values)
        if (s != warm && !others.any((e) => e.slot == s)) s,
    ];

    return DragTarget<_MealRef>(
      onWillAcceptWithDetails: (d) =>
          !(_sameDay(d.data.date, date) && d.data.slot == warm),
      onAcceptWithDetails: (d) =>
          _move(context, ref, d.data, toDate: date, toSlot: d.data.slot),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(Tokens.space2),
          decoration: BoxDecoration(
            color: hovering ? scheme.primaryContainer : null,
            border: Border.all(
              color: isToday ? scheme.primary : ww.line,
              width: isToday ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(Tokens.space3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.space1,
                  Tokens.space1,
                  Tokens.space1,
                  Tokens.space2,
                ),
                child: Text(
                  '${context.weekdayShort(date)} ${context.dayMonth(date)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isToday ? scheme.primary : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _SlotCard(
                date: date,
                slot: warm,
                entry: warmEntry,
                prominent: true,
              ),
              for (final e in others) ...[
                const SizedBox(height: Tokens.space2),
                _SlotCard(date: date, slot: e.slot, entry: e),
              ],
              if (freeSlots.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PopupMenuButton<PlanSlot>(
                    tooltip: l10n.mealsAddOther,
                    onSelected: (slot) =>
                        showMealEditor(context, date: date, slot: slot),
                    itemBuilder: (_) => [
                      for (final s in freeSlots)
                        PopupMenuItem(
                          value: s,
                          child: Text(context.planSlotLabel(s)),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.space2,
                        vertical: Tokens.space1,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 18),
                          const SizedBox(width: Tokens.space1),
                          Flexible(
                            child: Text(
                              l10n.mealsAddOther,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    _MealRef from, {
    required DateTime toDate,
    required PlanSlot toSlot,
  }) async {
    final result = await ref
        .read(mealsRepositoryProvider)
        .moveMeal(
          actor: ref.read(actingProfileProvider),
          fromDate: from.date,
          fromSlot: from.slot,
          toDate: toDate,
          toSlot: toSlot,
        );
    if (!context.mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(mealEntriesProvider(weekStart));
      case Err(:final failure):
        context.showFailure(failure);
    }
  }
}

/// A cooked meal's paper ground (specs/17: lemon reads as food on every shade).
final _dishPaper = PaperTints.tints.firstWhere((t) => t.key == 'lemon');

/// One meal: the warm one large, the others compact. Long-press drags it to another
/// day. An empty warm slot is a plain "nothing planned" card that opens the editor.
class _SlotCard extends ConsumerWidget {
  const _SlotCard({
    required this.date,
    required this.slot,
    required this.entry,
    this.prominent = false,
  });

  final DateTime date;
  final PlanSlot slot;
  final MealEntry? entry;
  final bool prominent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ww = context.ww;
    final theme = Theme.of(context);
    final entry = this.entry;
    final dish = entry?.hasDish ?? false;
    final cook = entry?.cookProfileId;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final cookName = cook == null
        ? null
        : members.where((m) => m.id == cook).firstOrNull?.displayName;

    final card = Material(
      color: dish ? ww.paper(_dishPaper) : Colors.transparent,
      borderRadius: BorderRadius.circular(Tokens.space2),
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.space2),
        onTap: () =>
            showMealEditor(context, date: date, slot: slot, entry: entry),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: prominent ? 72 : 48),
          padding: const EdgeInsets.all(Tokens.space2),
          decoration: BoxDecoration(
            border: Border.all(
              color: dish ? ww.line : ww.line.withValues(alpha: 0.6),
            ),
            borderRadius: BorderRadius.circular(Tokens.space2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.planSlotLabel(slot),
                style: theme.textTheme.labelSmall?.copyWith(color: ww.ink2),
              ),
              Text(
                entry?.title ?? l10n.mealsNothingYet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    (prominent
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: dish ? null : ww.ink3,
                        ),
              ),
              if (entry != null &&
                  (cookName != null ||
                      entry.atTime != null ||
                      entry.guests > 0))
                Text(
                  [
                    if (cookName != null) l10n.boardMealCook(cookName),
                    if (entry.atTime != null) context.time(entry.atTime!),
                    if (entry.guests > 0) l10n.boardMealGuests(entry.guests),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: ww.ink2),
                ),
            ],
          ),
        ),
      ),
    );

    if (entry == null) return card;
    return LongPressDraggable<_MealRef>(
      data: _MealRef(date, slot),
      feedback: SizedBox(
        width: 180,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(Tokens.space2),
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space2),
            child: Text(entry.title ?? '', style: theme.textTheme.titleSmall),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }
}
