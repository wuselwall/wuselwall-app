import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/ui/text_prompt.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_window_card.dart';

/// The shortest stays the page offers (specs/30 "Time windows").
const tripWindowMinDays = [3, 4, 7, 10, 14];

/// Zeitfenster (`Routes.tripWindows`): when the family could travel, as the server
/// computes it from the calendar and the school's Ferien. With a [tripId] a window sets
/// that idea's dates; without, it leads to "Wohin?" or starts a new trip.
class TripWindowsPage extends ConsumerStatefulWidget {
  const TripWindowsPage({this.tripId, super.key});

  /// The idea a chosen window is for (the `trip` query); null: a window to start a new
  /// trip from.
  final String? tripId;

  @override
  ConsumerState<TripWindowsPage> createState() => _TripWindowsPageState();
}

class _TripWindowsPageState extends ConsumerState<TripWindowsPage> {
  var _minDays = 4;

  /// Who travels as chosen on this page; null until a chip is touched, when the trip's
  /// own members (or everyone) stand.
  Set<String>? _who;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = widget.tripId;
    final Widget body;
    if (!ref.watch(tripsOfferedProvider)) {
      body = EmptyView(
        illustrated: false,
        message: l10n.tripWindowsUnavailable,
      );
    } else if (id == null) {
      body = _content(null);
    } else {
      body = AsyncValueView<Trip?>(
        value: ref.watch(tripProvider(id)),
        onRetry: () => ref.invalidate(tripsProvider),
        data: (trip) => trip == null
            ? EmptyView(illustrated: false, message: l10n.errorNotFound)
            : _content(trip),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripWindowsTitle)),
      body: ContentWidth(child: body),
    );
  }

  Widget _content(Trip? trip) {
    final l10n = context.l10n;
    final members = [
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        if (m.active) m,
    ];
    final who = _who ?? {...?trip?.memberIds};
    final args = TripWindowsArgs(
      minDays: _minDays,
      memberIds: [
        for (final m in members)
          if (who.contains(m.id)) m.id,
      ],
      tripId: widget.tripId,
    );
    final windows = ref.watch(tripWindowsProvider(args));
    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        Text(l10n.tripWindowsIntro),
        const SizedBox(height: Tokens.space4),
        _label(l10n.tripWindowsLengthLabel),
        Wrap(
          spacing: Tokens.space2,
          runSpacing: Tokens.space1,
          children: [
            for (final days in tripWindowMinDays)
              ChoiceChip(
                label: Text(l10n.tripWindowDays(days)),
                selected: _minDays == days,
                onSelected: (_) => setState(() => _minDays = days),
              ),
          ],
        ),
        const SizedBox(height: Tokens.space3),
        _label(l10n.tripWindowsWhoLabel),
        Wrap(
          spacing: Tokens.space2,
          runSpacing: Tokens.space1,
          children: [
            for (final m in members)
              FilterChip(
                label: Text(m.displayName),
                avatar: ExcludeSemantics(
                  child: MemberDot(
                    memberColor: m.color,
                    semanticLabel: m.displayName,
                  ),
                ),
                showCheckmark: false,
                selected: who.contains(m.id),
                onSelected: (on) => setState(() {
                  final next = {...who};
                  on ? next.add(m.id) : next.remove(m.id);
                  _who = next;
                }),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: Tokens.space1),
          child: Text(
            l10n.tripWindowsWhoHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: Tokens.space4),
        AsyncValueView<List<TripWindow>>(
          value: windows,
          keepPrevious: true,
          onRetry: () => ref.invalidate(tripWindowsProvider(args)),
          data: (list) => list.isEmpty
              ? EmptyView(
                  illustrated: false,
                  scrolls: false,
                  message: l10n.tripWindowEmpty,
                  actions: [
                    OutlinedButton(
                      onPressed: () => context.push(Routes.settingsCalendar),
                      child: Text(l10n.tripWindowEmptyAction),
                    ),
                  ],
                )
              : _windowList(list, members, trip, args),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.space1),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );

  /// The cards, under a heading for each month their first day lies in.
  Widget _windowList(
    List<TripWindow> windows,
    List<Member> members,
    Trip? trip,
    TripWindowsArgs args,
  ) {
    final tag = Localizations.localeOf(context).toLanguageTag();
    final children = <Widget>[];
    DateTime? month;
    for (final w in windows) {
      final first = DateTime(w.from.year, w.from.month);
      if (month != first) {
        month = first;
        children.add(
          Padding(
            padding: const EdgeInsets.only(
              top: Tokens.space3,
              bottom: Tokens.space2,
            ),
            child: Semantics(
              header: true,
              child: Text(
                DateFormat.yMMMM(tag).format(first),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        );
      }
      children.add(
        TripWindowCard(
          window: w,
          members: members,
          onTake: trip == null ? null : () => _take(w, trip),
          onWhere: trip != null ? null : () => _where(w),
          onNewTrip: trip != null ? null : () => _newTrip(w, args.memberIds),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Future<void> _take(TripWindow w, Trip trip) async {
    final l10n = context.l10n;
    final range = await showDateRangePicker(
      context: context,
      firstDate: w.from,
      lastDate: w.to,
      initialDateRange: DateTimeRange(start: w.from, end: w.to),
      helpText: l10n.tripWindowTakeHelp,
    );
    if (range == null || !mounted) return;
    final result = await ref
        .read(tripActionsProvider)
        .setDates(trip, dayOf(range.start), dayOf(range.end));
    if (!mounted) return;
    switch (result) {
      case Ok():
        context.showMessage(l10n.tripWindowTaken);
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.tripPath(trip.id));
        }
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  void _where(TripWindow w) => context.push(
    Routes.tripDiscover,
    extra: DateTimeRange(start: w.from, end: w.to),
  );

  Future<void> _newTrip(TripWindow w, List<String> memberIds) async {
    final l10n = context.l10n;
    final name = await askText(
      context,
      title: l10n.tripWindowNewTripTitle,
      label: l10n.tripWindowNewTripLabel,
      maxLength: 120,
      confirm: l10n.save,
    );
    if (name == null || !mounted) return;
    final trip = Trip(
      id: TripActions.newId(),
      title: name,
      stage: TripStage.planned,
      startsOn: w.from,
      endsOn: w.to,
      memberIds: memberIds,
    );
    final result = await ref.read(tripActionsProvider).saveTrip(trip);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        await context.push(Routes.tripPath(value.id));
      case Err(:final failure):
        context.showFailure(failure);
    }
  }
}
