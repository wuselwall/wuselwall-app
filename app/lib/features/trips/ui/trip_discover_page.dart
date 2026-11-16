import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/services/application/service_providers.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/settings/application/app_locale_provider.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_discover_filters.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';
import 'package:wuselwall/features/trips/ui/trip_place_card.dart';

/// How many answers in a row may bring no new climate value before the page stops asking
/// (five minutes of [discoverPendingRetry]).
final _discoverMaxStalled =
    const Duration(minutes: 5).inSeconds ~/ discoverPendingRetry.inSeconds;

/// Wohin? (`Routes.tripDiscover`): where it is warm and dry in a window, and how far it
/// is. The window comes from the route or is asked first; the wishes narrow the list.
class TripDiscoverPage extends ConsumerStatefulWidget {
  const TripDiscoverPage({this.range, super.key});

  /// The window to look at (the route's `extra`); null: the page asks.
  final DateTimeRange? range;

  @override
  ConsumerState<TripDiscoverPage> createState() => _TripDiscoverPageState();
}

class _TripDiscoverPageState extends ConsumerState<TripDiscoverPage> {
  /// What the family chose on this page, or the default found for a page without a range.
  DateTimeRange? _range;
  var _filters = const DiscoverFilters();

  /// The arguments the page shows, for the retry timer.
  TripDiscoverArgs? _args;
  Timer? _timer;

  /// The fewest places still pending so far, how many answers in a row brought no fall,
  /// and whether the page has stopped asking.
  int? _bestPending;
  var _stalled = 0;
  var _gaveUp = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget body;
    if (!ref.watch(tripsOfferedProvider)) {
      body = EmptyView(
        illustrated: false,
        message: l10n.tripDiscoverUnavailable,
      );
    } else {
      final given = _range ?? widget.range;
      if (given != null) {
        body = _content(given);
      } else {
        // Without a window: the next school holidays if the server proposes some, else
        // the month after next. Decided once, so the list is not asked twice.
        final windows = ref.watch(
          tripWindowsProvider(const TripWindowsArgs(minDays: 7)),
        );
        body = windows.isLoading && !windows.hasError
            ? const Center(child: CircularProgressIndicator())
            : _content(_range = _defaultRange(windows.value));
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripDiscoverTitle)),
      body: ContentWidth(child: body),
    );
  }

  DateTimeRange _defaultRange(List<TripWindow>? windows) {
    final holidays = windows
        ?.where((w) => w.kind == WindowKind.holidays)
        .firstOrNull;
    if (holidays != null) {
      return DateTimeRange(start: holidays.from, end: holidays.to);
    }
    final today = ref.read(todayProvider);
    return DateTimeRange(
      start: DateTime(today.year, today.month + 2),
      end: DateTime(today.year, today.month + 3, 0),
    );
  }

  Widget _content(DateTimeRange range) {
    final l10n = context.l10n;
    final args = TripDiscoverArgs(
      from: dayOf(range.start),
      to: dayOf(range.end),
      filters: _filters,
      lang: ref.watch(appLocaleProvider).languageCode,
    );
    _args = args;
    ref.listen<AsyncValue<DiscoverResult>>(tripDiscoverProvider(args), (
      _,
      next,
    ) {
      if (next.hasValue && !next.isLoading) _onResult(next.requireValue);
    });
    final result = ref.watch(tripDiscoverProvider(args));
    final setup = ref.watch(serviceSetupProvider);
    final home = ref.watch(tripHomeProvider);
    final wishes = _wishCount(_filters);
    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(formatTripDates(context, range.start, range.end)),
            subtitle: Text(l10n.tripDiscoverWhen),
            trailing: TextButton(
              onPressed: () => _pickRange(range),
              child: Text(l10n.tripDiscoverChange),
            ),
          ),
        ),
        const SizedBox(height: Tokens.space2),
        Card(
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(l10n.tripDiscoverWishes),
            subtitle: Text(
              wishes == 0
                  ? l10n.tripDiscoverWishesNone
                  : l10n.tripDiscoverWishesCount(wishes),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              Tokens.space4,
              0,
              Tokens.space4,
              Tokens.space2,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TripDiscoverFilters(
                filters: _filters,
                climateAvailable: ref.watch(
                  serviceOffersProvider(ServiceCapability.climate),
                ),
                climateKnown: setup.hasValue,
                homeAvailable: home.value != null,
                homeKnown: home.hasValue,
                onTempMin: (v) => _setFilters(tempMin: v, keepTempMin: false),
                onTempMax: (v) => _setFilters(tempMax: v, keepTempMax: false),
                onDry: (on) => _setFilters(dry: on),
                onSeaMin: (v) => _setFilters(seaMin: v, keepSeaMin: false),
                onTag: (tag, {required on}) => _toggleTag(tag, on: on),
                onEffort: (e) => _setFilters(effort: e, keepEffort: false),
                onOpenServices: () => context.push(Routes.servicesSettings),
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space3),
        AsyncValueView<DiscoverResult>(
          value: result,
          keepPrevious: true,
          onRetry: () => ref.invalidate(tripDiscoverProvider(args)),
          data: (r) => _results(r, args),
        ),
        const SizedBox(height: Tokens.space2),
        Text(
          l10n.tripDiscoverNote,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.ww.ink2),
        ),
      ],
    );
  }

  Widget _results(DiscoverResult r, TripDiscoverArgs args) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ww = context.ww;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (r.pending > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_gaveUp) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: Tokens.space1),
                ],
                Text(
                  _gaveUp
                      ? l10n.tripDiscoverPendingLater
                      : l10n.tripDiscoverPending(r.pending),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        if (r.places.isEmpty)
          EmptyView(
            illustrated: false,
            scrolls: false,
            message: l10n.tripDiscoverEmpty,
          )
        else
          for (final place in r.places)
            TripPlaceCard(
              place: place,
              filtersActive: !_filters.isEmpty,
              onOpen: () => context.push(Routes.tripPath(place.tripId!)),
              onKeep: () => _keep(place, args),
            ),
        if ((r.attribution ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space1),
            child: Text(
              r.attribution!,
              style: theme.textTheme.bodySmall?.copyWith(color: ww.ink2),
            ),
          ),
      ],
    );
  }

  int _wishCount(DiscoverFilters f) =>
      (f.tempMin != null ? 1 : 0) +
      (f.tempMax != null ? 1 : 0) +
      (f.dry ? 1 : 0) +
      (f.seaMin != null ? 1 : 0) +
      f.tags.length +
      (f.effort != null ? 1 : 0);

  /// Changes one wish; a `keep…` flag true leaves that value as it is (so null can mean
  /// "any").
  void _setFilters({
    double? tempMin,
    double? tempMax,
    bool? dry,
    double? seaMin,
    List<String>? tags,
    TravelEffort? effort,
    bool keepTempMin = true,
    bool keepTempMax = true,
    bool keepSeaMin = true,
    bool keepEffort = true,
  }) {
    final f = _filters;
    final nextSea = keepSeaMin ? f.seaMin : seaMin;
    var nextTags = tags ?? f.tags;
    // Wanting warm water means a place by the sea.
    if (nextSea != null && !nextTags.contains('sea')) {
      nextTags = [...nextTags, 'sea'];
    }
    setState(() {
      _filters = DiscoverFilters(
        tempMin: keepTempMin ? f.tempMin : tempMin,
        tempMax: keepTempMax ? f.tempMax : tempMax,
        dry: dry ?? f.dry,
        seaMin: nextSea,
        tags: nextTags,
        effort: keepEffort ? f.effort : effort,
      );
      _resetPending();
    });
  }

  void _toggleTag(String tag, {required bool on}) {
    final tags = [
      for (final t in _filters.tags)
        if (t != tag) t,
      if (on) tag,
    ];
    // No sea tag, no sea temperature to ask for.
    final dropsSea = !on && tag == 'sea';
    _setFilters(
      tags: tags,
      seaMin: dropsSea ? null : _filters.seaMin,
      keepSeaMin: !dropsSea,
    );
  }

  Future<void> _pickRange(DateTimeRange current) async {
    final today = ref.read(todayProvider);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 3, today.month, today.day),
      initialDateRange: current,
      helpText: context.l10n.tripDiscoverPickHelp,
    );
    if (range == null || !mounted) return;
    setState(() {
      _range = range;
      _resetPending();
    });
  }

  void _resetPending() {
    _timer?.cancel();
    _bestPending = null;
    _stalled = 0;
    _gaveUp = false;
  }

  /// Asks again in [discoverPendingRetry] while climates are pending, until five minutes
  /// bring no new value.
  void _onResult(DiscoverResult result) {
    _timer?.cancel();
    if (result.pending == 0) {
      _bestPending = null;
      _stalled = 0;
      if (_gaveUp && mounted) setState(() => _gaveUp = false);
      return;
    }
    final best = _bestPending;
    if (best == null || result.pending < best) {
      _bestPending = result.pending;
      _stalled = 0;
    } else {
      _stalled++;
    }
    if (_stalled >= _discoverMaxStalled) {
      if (!_gaveUp && mounted) setState(() => _gaveUp = true);
      return;
    }
    if (_gaveUp && mounted) setState(() => _gaveUp = false);
    _timer = Timer(discoverPendingRetry, _retry);
  }

  void _retry() {
    final args = _args;
    if (!mounted || args == null) return;
    // A page under another route is not looked at: wait without counting.
    if (!TickerMode.valuesOf(context).enabled) {
      _timer = Timer(discoverPendingRetry, _retry);
      return;
    }
    ref.invalidate(tripDiscoverProvider(args));
  }

  Future<void> _keep(DiscoverPlace place, TripDiscoverArgs args) async {
    final l10n = context.l10n;
    final id = TripActions.newId();
    final result = await ref
        .read(tripActionsProvider)
        .saveTrip(
          Trip(
            id: id,
            title: place.name,
            destinationName: place.name,
            destinationKey: place.key,
            country: place.country.isEmpty ? null : place.country,
            lat: place.lat,
            lon: place.lon,
          ),
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(tripDiscoverProvider(args));
        context.showMessageWithAction(
          l10n.tripDiscoverKept(place.name),
          actionLabel: l10n.tripDiscoverOpen,
          onAction: () => context.push(Routes.tripPath(id)),
        );
      case Err(:final failure):
        context.showFailure(failure);
    }
  }
}
