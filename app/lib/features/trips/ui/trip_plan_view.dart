import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_entry_args.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/domain/trip_plan.dart';
import 'package:wuselwall/features/trips/ui/trip_entry_row.dart';
import 'package:wuselwall/features/trips/ui/trip_info_card.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';

/// The Plan tab of a trip (specs/30 "Options and the plan"): the facts, the days with what
/// is chosen or booked, and the options still open, by kind.
class TripPlanView extends ConsumerWidget {
  const TripPlanView({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(tripPlanProvider(tripId));
    return AsyncValueView<TripPlan?>(
      value: plan,
      onRetry: () => ref.invalidate(tripPlanProvider(tripId)),
      data: (plan) => plan == null
          ? const SizedBox.shrink()
          : _PlanBody(plan: plan, today: ref.watch(todayProvider)),
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({required this.plan, required this.today});

  final TripPlan plan;
  final DateTime today;

  Trip get trip => plan.trip;

  void _open(BuildContext context, TripEntry e) =>
      context.push(Routes.tripEntryPath(trip.id), extra: TripEntryArgs.edit(e));

  void _add(BuildContext context, EntryKind kind) => context.push(
    Routes.tripEntryPath(trip.id),
    extra: TripEntryArgs.seed(trip.id, kind),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final byKind = {
      for (final k in EntryKind.values)
        k: [
          for (final e in plan.options)
            if (e.kind == k) e,
        ],
    };
    final emptyKinds = [
      for (final k in EntryKind.values)
        if (byKind[k]!.isEmpty) k,
    ];

    Widget rows(Iterable<TripEntry> entries) => Column(
      children: [
        for (final e in entries)
          TripEntryRow(
            entry: e,
            currency: trip.currency,
            showChecked: e.state == EntryState.option,
            onTap: () => _open(context, e),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TripInfoCard(plan: plan),
        if (trip.hasDates)
          for (final day in plan.days)
            _DayCard(
              day: day,
              trip: trip,
              isToday: day.date == today,
              onOpen: (e) => _open(context, e),
            )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
            child: Text(
              l10n.tripPlanNoDatesHint,
              style: TextStyle(color: context.ww.ink2),
            ),
          ),
          if (plan.undated.isNotEmpty || plan.outside.isNotEmpty) ...[
            _Heading(l10n.tripPlanChosen),
            Card(child: rows([...plan.undated, ...plan.outside])),
          ],
        ],
        if (trip.hasDates && plan.undated.isNotEmpty) ...[
          _Heading(l10n.tripPlanUndated),
          Card(child: rows(plan.undated)),
        ],
        if (trip.hasDates && plan.outside.isNotEmpty) ...[
          _Heading(l10n.tripPlanOutside),
          Card(child: rows(plan.outside)),
        ],
        if (plan.options.isNotEmpty) _Heading(l10n.tripPlanOptions),
        for (final kind in EntryKind.values)
          if (byKind[kind]!.isNotEmpty)
            _OptionGroup(
              kind: kind,
              options: byKind[kind]!,
              currency: trip.currency,
              onOpen: (e) => _open(context, e),
              onAdd: () => _add(context, kind),
              onCompare: kind.comparable
                  ? () => context.push(
                      Routes.tripComparePath(trip.id, kind: kind),
                    )
                  : null,
            ),
        if (emptyKinds.isNotEmpty) ...[
          _Heading(l10n.tripPlanAddOption),
          Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space2,
            children: [
              for (final kind in emptyKinds)
                ActionChip(
                  key: ValueKey('trip-add-${kind.wire}'),
                  avatar: Icon(entryKindIcon(kind), size: 18),
                  label: Text(context.entryKind(kind)),
                  onPressed: () => _add(context, kind),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Tokens.space4, bottom: Tokens.space1),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// One day of the plan: its number and date, what happens in time order, and where the
/// family sleeps. Today is outlined.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.trip,
    required this.isToday,
    required this.onOpen,
  });

  final PlanDay day;
  final Trip trip;
  final bool isToday;
  final void Function(TripEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stay = day.stay;
    return Card(
      key: ValueKey('trip-day-${day.dayNumber}'),
      clipBehavior: Clip.antiAlias,
      shape: isToday
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: scheme.primary, width: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: isToday ? scheme.primaryContainer : context.ww.sunken,
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space3,
              vertical: Tokens.space2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.tripPlanDay(
                        day.dayNumber,
                        formatTripDay(context, day.date),
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isToday ? scheme.onPrimaryContainer : null,
                      ),
                    ),
                  ),
                ),
                if (isToday)
                  Text(
                    l10n.tripPlanToday,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
              ],
            ),
          ),
          if (day.items.isEmpty && stay == null)
            Padding(
              padding: const EdgeInsets.all(Tokens.space3),
              child: Text(
                l10n.tripPlanDayEmpty,
                style: TextStyle(color: context.ww.ink3),
              ),
            ),
          for (final item in day.items)
            TripEntryRow(
              entry: item.entry,
              currency: trip.currency,
              role: item.role,
              onTap: () => onOpen(item.entry),
            ),
          if (stay != null)
            InkWell(
              onTap: () => onOpen(stay),
              child: Padding(
                padding: const EdgeInsets.all(Tokens.space3),
                child: Row(
                  children: [
                    Icon(Icons.hotel_outlined, color: context.ww.ink2),
                    const SizedBox(width: Tokens.space3),
                    Expanded(
                      child: Text(
                        l10n.tripPlanStayTonight(stay.title),
                        style: TextStyle(color: context.ww.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The open options of one kind: how many, what they cost, and the ways to compare them or
/// add another.
class _OptionGroup extends StatelessWidget {
  const _OptionGroup({
    required this.kind,
    required this.options,
    required this.currency,
    required this.onOpen,
    required this.onAdd,
    required this.onCompare,
  });

  final EntryKind kind;
  final List<TripEntry> options;
  final String currency;
  final void Function(TripEntry entry) onOpen;
  final VoidCallback onAdd;
  final VoidCallback? onCompare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final prices = [
      for (final e in options)
        if (e.priceCents != null) e.priceCents!,
    ]..sort();
    final range = prices.isEmpty
        ? null
        : prices.first == prices.last
        ? formatTripMoney(context, prices.first, currency)
        : l10n.tripPlanPriceRange(
            formatTripMoney(context, prices.first, currency),
            formatTripMoney(context, prices.last, currency),
          );
    return Card(
      key: ValueKey('trip-options-${kind.wire}'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.space3,
              Tokens.space3,
              Tokens.space3,
              Tokens.space1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    context.entryKinds(kind),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  [
                    l10n.tripPlanOptionCount(options.length),
                    ?range,
                  ].join(' · '),
                  style: TextStyle(color: context.ww.ink2),
                ),
              ],
            ),
          ),
          for (final e in options)
            TripEntryRow(
              entry: e,
              currency: currency,
              showChecked: true,
              onTap: () => onOpen(e),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space2),
            child: Wrap(
              children: [
                if (onCompare != null)
                  TextButton.icon(
                    key: ValueKey('trip-compare-${kind.wire}'),
                    onPressed: onCompare,
                    icon: const Icon(Icons.compare_arrows),
                    label: Text(l10n.tripPlanCompare),
                  ),
                TextButton.icon(
                  key: ValueKey('trip-add-option-${kind.wire}'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.tripPlanAddOption),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
