import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/domain/trip_plan.dart';
import 'package:wuselwall/features/trips/domain/trip_today.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';
import 'package:wuselwall/features/trips/ui/trip_links.dart';

/// How many open to-dos the card lists before it says "+N more".
const tripTodayTodoLimit = 3;

/// The trip card on Today (specs/30 "During the trip"): before a fixed trip the days
/// left, the to-dos that are due and the packing progress; during it the day, today's
/// plan, where the family sleeps tonight and tomorrow's first entry. The whole card
/// opens the trip. Without such a trip it is one quiet line for the trips being planned
/// (see [TripPlanningLine]). It stays away (never an error) when there is nothing to show;
/// the providers read through the cache, so it also works without a network.
class TripTodayCard extends ConsumerWidget {
  const TripTodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(tripTodayProvider);
    if (today == null) {
      final planning = ref.watch(tripPlanningProvider);
      return planning == null
          ? const SizedBox.shrink()
          : _PlanningLine(line: planning);
    }
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('trip-today-card'),
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        hint: l10n.tripTodayOpen(today.trip.title),
        child: InkWell(
          onTap: () => unawaited(context.push(Routes.tripPath(today.trip.id))),
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space3),
            child: _Content(today: today),
          ),
        ),
      ),
    );
  }
}

/// The compact form: the nearest trip being planned, its dates and stage, "+N more", and the
/// way to all trips. The title and the details wrap under each other at large text.
class _PlanningLine extends StatelessWidget {
  const _PlanningLine({required this.line});

  final TripPlanningLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final trip = line.trip;
    final asset = eventIconAsset(trip.iconKey);
    final details = [
      formatTripDates(context, trip.startsOn!, trip.endsOn!),
      tripStageLabel(l10n, trip.stage),
      if (line.more > 0) l10n.tripTodayMore(line.more),
    ].join(' · ');
    return Card(
      key: const ValueKey('trip-planning-line'),
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        hint: l10n.tripTodayOpen(trip.title),
        child: InkWell(
          onTap: () => unawaited(context.push(Routes.tripPath(trip.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Tokens.space3,
              vertical: Tokens.space2,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: asset != null
                      ? EmojiPicture(asset, size: 32)
                      : Icon(
                          Icons.luggage_outlined,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                ),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Tokens.space2,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            details,
                            key: const ValueKey('trip-planning-details'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        key: const ValueKey('trip-planning-all'),
                        onPressed: () => unawaited(context.push(Routes.trips)),
                        child: Text(l10n.tripTodayAllTrips),
                      ),
                    ],
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

/// The word for what happens at [item] ("Einchecken", "Abholung", "Abfahrt"), or null
/// for an entry that simply takes place that day.
String? tripTodayRole(AppLocalizations l10n, PlanItem item) {
  final start = item.role == PlanRole.start;
  final end = item.role == PlanRole.end;
  return switch (item.entry.kind) {
    EntryKind.stay when start => l10n.tripTodayCheckIn,
    EntryKind.stay when end => l10n.tripTodayCheckOut,
    EntryKind.rental when start => l10n.tripTodayPickUp,
    EntryKind.rental when end => l10n.tripTodayReturn,
    EntryKind.transport when start => l10n.tripTodayDeparture,
    EntryKind.transport when end => l10n.tripTodayArrival,
    _ => null,
  };
}

class _Content extends StatelessWidget {
  const _Content({required this.today});

  final TripToday today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final trip = today.trip;
    final asset = eventIconAsset(trip.iconKey);
    final when = today.running
        ? l10n.tripTodayDayOf(today.dayNumber ?? 1, today.dayCount)
        : switch (today.daysLeft) {
            <= 0 => l10n.countdownToday,
            1 => l10n.countdownTomorrow,
            final days => l10n.countdownInDays(days),
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: asset != null
                  ? EmojiPicture(asset, size: 40)
                  : Icon(
                      Icons.luggage_outlined,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
            ),
            const SizedBox(width: Tokens.space3),
            // The title and the count share the width and wrap under each other when they do
            // not fit side by side (large text, a long title): never a fixed-width count.
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Tokens.space2,
                children: [
                  Text(
                    trip.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    when,
                    key: const ValueKey('trip-today-when'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (today.running) ..._running(context) else ..._before(context),
      ],
    );
  }

  List<Widget> _before(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final todos = today.dueTodos;
    return [
      if (todos.isNotEmpty) ...[
        const SizedBox(height: Tokens.space3),
        _Label(l10n.tripTodayTodos),
        for (final c in todos.take(tripTodayTodoLimit))
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space1),
            child: Row(
              children: [
                Icon(
                  Icons.radio_button_unchecked,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Tokens.space2),
                Expanded(child: Text(c.title)),
              ],
            ),
          ),
        if (todos.length > tripTodayTodoLimit)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space1),
            child: Text(
              l10n.tripTodayMore(todos.length - tripTodayTodoLimit),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
      if (today.packTotal > 0) ...[
        const SizedBox(height: Tokens.space3),
        Text(
          l10n.tripTodayPacked(today.packed, today.packTotal),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Tokens.space1),
        ClipRRect(
          borderRadius: BorderRadius.circular(Tokens.space1),
          child: LinearProgressIndicator(
            key: const ValueKey('trip-today-packing'),
            minHeight: 6,
            value: today.packed / today.packTotal,
          ),
        ),
      ],
    ];
  }

  List<Widget> _running(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final stay = today.stayTonight;
    final next = today.tomorrowFirst;
    return [
      const SizedBox(height: Tokens.space3),
      if (today.todayItems.isEmpty)
        Text(
          l10n.tripTodayNothing,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
      else
        for (final item in today.todayItems) _ItemRow(item: item),
      if (stay != null) ...[
        const SizedBox(height: Tokens.space3),
        _Label(l10n.tripTodayTonight),
        _Stay(entry: stay),
      ],
      if (next != null) ...[
        const SizedBox(height: Tokens.space3),
        _Label(l10n.tripTodayTomorrow),
        _ItemRow(item: next),
      ],
    ];
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// One plan item: its time, a picture of the kind, the role word and the title.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final PlanItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final time = item.time;
    final role = tripTodayRole(l10n, item);
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              time == null ? '' : formatTripTime(context, time),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Icon(
            entryIcon(item.entry),
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              role == null ? item.entry.title : '$role · ${item.entry.title}',
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the family sleeps tonight, with the address and the phone one tap from the
/// phone's own maps and dialler.
class _Stay extends StatelessWidget {
  const _Stay({required this.entry});

  final TripEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final address = entry.address;
    final phone = entry.phone;
    final canMap =
        (address != null && address.trim().isNotEmpty) ||
        (entry.lat != null && entry.lon != null);
    final canCall = phone != null && phone.trim().isNotEmpty;

    Future<void> run(Future<bool> open) async {
      if (!await open && context.mounted) {
        context.showMessage(l10n.tripTodayCannotOpen);
      }
    }

    return Row(
      children: [
        Icon(
          Icons.hotel_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: Tokens.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.title),
              if (address != null && address.isNotEmpty)
                Text(
                  address,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (canMap)
          IconButton(
            key: const ValueKey('trip-today-map'),
            tooltip: l10n.tripTodayMap,
            icon: const Icon(Icons.place_outlined),
            onPressed: () => unawaited(
              run(
                openTripPlace(address: address, lat: entry.lat, lon: entry.lon),
              ),
            ),
          ),
        if (canCall)
          IconButton(
            key: const ValueKey('trip-today-call'),
            tooltip: l10n.tripTodayCall,
            icon: const Icon(Icons.call_outlined),
            onPressed: () => unawaited(run(callTripPhone(phone))),
          ),
      ],
    );
  }
}
