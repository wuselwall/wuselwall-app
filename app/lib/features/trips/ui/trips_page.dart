import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_card.dart';
import 'package:wuselwall/features/trips/ui/trip_edit_sheet.dart';

/// Reisen (`Routes.trips`): the running or next trips, the ideas, past trips folded.
/// Adults only (specs/30 "Who does what").
class TripsPage extends ConsumerWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (!ref.watch(tripsOfferedProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tripsTitle)),
        body: EmptyView(illustrated: false, message: l10n.tripPageUnavailable),
      );
    }
    final trips = ref.watch(tripsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('trip-new'),
        onPressed: () => showTripEditSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.tripListNewIdea),
      ),
      body: ContentWidth(
        child: AsyncValueView<List<Trip>>(
          value: trips,
          onRetry: () => ref.invalidate(tripsProvider),
          data: (list) => _TripList(
            trips: list,
            today: ref.watch(todayProvider),
            onRefresh: () => ref.refresh(tripsProvider.future),
          ),
        ),
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({
    required this.trips,
    required this.today,
    required this.onRefresh,
  });

  final List<Trip> trips;
  final DateTime today;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final upcoming = [
      for (final t in trips)
        if (t.stage != TripStage.idea && t.hasDates && !t.isPast(today)) t,
    ]..sort((a, b) => daysBetween(b.startsOn!, a.startsOn!));
    final ideas = [
      for (final t in trips)
        if (t.stage == TripStage.idea) t,
    ];
    final past = [
      for (final t in trips)
        if (t.stage != TripStage.idea && t.hasDates && t.isPast(today)) t,
    ]..sort((a, b) => daysBetween(a.endsOn!, b.endsOn!));

    Widget card(Trip t) => TripCard(
      trip: t,
      today: today,
      onTap: () => context.push(Routes.tripPath(t.id)),
    );

    final entries = [
      _EntryTile(
        key: const ValueKey('trip-windows'),
        icon: Icons.date_range_outlined,
        title: l10n.tripListWindows,
        help: l10n.tripListWindowsHelp,
        onTap: () => context.push(Routes.tripWindows),
      ),
      _EntryTile(
        key: const ValueKey('trip-discover'),
        icon: Icons.travel_explore_outlined,
        title: l10n.tripListDiscover,
        help: l10n.tripListDiscoverHelp,
        onTap: () => context.push(Routes.tripDiscover),
      ),
    ];

    if (trips.isEmpty) {
      return EmptyView(
        title: l10n.tripListEmptyTitle,
        message: l10n.tripListEmpty,
        actions: [
          FilledButton.icon(
            onPressed: () => showTripEditSheet(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.tripListNewIdea),
          ),
          OutlinedButton(
            onPressed: () => context.push(Routes.tripWindows),
            child: Text(l10n.tripListWindows),
          ),
          OutlinedButton(
            onPressed: () => context.push(Routes.tripDiscover),
            child: Text(l10n.tripListDiscover),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          Tokens.space3,
          Tokens.space4,
          96,
        ),
        children: [
          _Columns(children: entries),
          if (upcoming.isNotEmpty) ...[
            _Heading(l10n.tripListUpcoming),
            _Columns(children: [for (final t in upcoming) card(t)]),
          ],
          if (ideas.isNotEmpty) ...[
            _Heading(l10n.tripListIdeas),
            _Columns(children: [for (final t in ideas) card(t)]),
          ],
          if (past.isNotEmpty)
            Theme(
              // The fold has no divider lines of its own.
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('trip-past'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  l10n.tripListPast(past.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                childrenPadding: EdgeInsets.zero,
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Columns(children: [for (final t in past) card(t)]),
                ],
              ),
            ),
        ],
      ),
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

/// One column on a phone, two from a tablet's width: the cards use the room.
class _Columns extends StatelessWidget {
  const _Columns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final two = box.maxWidth >= 700 && children.length > 1;
      if (!two) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      }
      const gap = Tokens.space3;
      final width = (box.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        children: [for (final c in children) SizedBox(width: width, child: c)],
      );
    },
  );
}

/// "Zeitfenster" and "Wohin?": the two ways to start from a window or from a place.
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.icon,
    required this.title,
    required this.help,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String help;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(help),
      trailing: Icon(Icons.chevron_right, color: context.ww.ink3),
      onTap: onTap,
    ),
  );
}
