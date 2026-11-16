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
import 'package:wuselwall/features/board/domain/week_board.dart'
    show BoardMember, MemberKind;
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_card.dart';
import 'package:wuselwall/features/trips/ui/trip_edit_sheet.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';
import 'package:wuselwall/features/trips/ui/trip_pack_view.dart';
import 'package:wuselwall/features/trips/ui/trip_plan_view.dart';
import 'package:wuselwall/features/trips/ui/trip_todo_view.dart';

/// The longest a trip can be (specs/30 `trip` table).
const _maxTripDays = 366;

enum _Menu { edit, backToIdea, delete }

/// One trip (`Routes.tripPath`): its header and stage, then Plan, Packen and Vorbereiten.
/// Adults only (specs/30 "Who does what").
class TripPage extends ConsumerStatefulWidget {
  const TripPage({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));
  bool _busy = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Runs a write, shows a failure, and says whether it worked.
  Future<bool> _write<T>(Future<Result<T>> write) async {
    setState(() => _busy = true);
    final result = await write;
    if (!mounted) return result.isOk;
    setState(() => _busy = false);
    if (!result.isOk) context.showFailure(result.failureOrNull!);
    return result.isOk;
  }

  Future<void> _pickDates(Trip trip) async {
    final today = ref.read(todayProvider);
    final firstDate = trip.hasDates && trip.startsOn!.isBefore(today)
        ? trip.startsOn!
        : today;
    final threeYears = addDays(today, 3 * 365);
    final lastDate = trip.hasDates && trip.endsOn!.isAfter(threeYears)
        ? trip.endsOn!
        : threeYears;
    final range = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: trip.hasDates
          ? DateTimeRange(start: trip.startsOn!, end: trip.endsOn!)
          : null,
    );
    if (range == null || !mounted) return;
    final start = dayOf(range.start);
    final end = dayOf(range.end);
    if (daysBetween(start, end) + 1 > _maxTripDays) {
      context.showMessage(context.l10n.tripPageDatesTooLong);
      return;
    }
    await _write(ref.read(tripActionsProvider).setDates(trip, start, end));
  }

  Future<void> _delete(Trip trip) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.tripPageDelete),
        content: Text(l10n.tripPageDeleteConfirm(trip.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('trip-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (await _write(ref.read(tripActionsProvider).deleteTrip(trip.id)) &&
        mounted) {
      context.canPop() ? context.pop() : context.go(Routes.trips);
    }
  }

  void _menu(Trip trip, _Menu choice) => switch (choice) {
    _Menu.edit => showTripEditSheet(context, trip: trip),
    _Menu.backToIdea => _write(
      ref.read(tripActionsProvider).setStage(trip, TripStage.idea),
    ),
    _Menu.delete => _delete(trip),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!ref.watch(tripsOfferedProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tripsTitle)),
        body: EmptyView(illustrated: false, message: l10n.tripPageUnavailable),
      );
    }
    final trip = ref.watch(tripProvider(widget.tripId));
    final loaded = trip.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.title ?? l10n.tripsTitle),
        actions: [
          if (loaded != null)
            PopupMenuButton<_Menu>(
              key: const ValueKey('trip-menu'),
              tooltip: l10n.tripPageMore,
              onSelected: (choice) => _menu(loaded, choice),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _Menu.edit,
                  child: Text(l10n.tripPageEdit),
                ),
                if (loaded.stage != TripStage.idea)
                  PopupMenuItem(
                    value: _Menu.backToIdea,
                    child: Text(l10n.tripPageBackToIdea),
                  ),
                PopupMenuItem(
                  value: _Menu.delete,
                  child: Text(l10n.tripPageDelete),
                ),
              ],
            ),
        ],
      ),
      body: ContentWidth(
        child: AsyncValueView<Trip?>(
          value: trip,
          onRetry: () => ref.invalidate(tripsProvider),
          data: (trip) => trip == null
              ? EmptyView(
                  illustrated: false,
                  message: l10n.tripPageNotFound,
                  actions: [
                    FilledButton(
                      onPressed: () => context.go(Routes.trips),
                      child: Text(l10n.tripPageToList),
                    ),
                  ],
                )
              : _content(trip),
        ),
      ),
    );
  }

  Widget _content(Trip trip) {
    final l10n = context.l10n;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        Tokens.space3,
        Tokens.space4,
        Tokens.space8,
      ),
      children: [
        _Header(
          trip: trip,
          members: members,
          today: ref.watch(todayProvider),
          busy: _busy,
          onFindWindow: () =>
              context.push(Routes.tripWindowsPath(tripId: trip.id)),
          onEnterDates: () => _pickDates(trip),
          onFix: () => _write(
            ref.read(tripActionsProvider).setStage(trip, TripStage.fixed),
          ),
          onPencil: () => _write(
            ref.read(tripActionsProvider).setStage(trip, TripStage.planned),
          ),
        ),
        const SizedBox(height: Tokens.space2),
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.tripPageTabPlan),
            Tab(text: l10n.tripPageTabPack),
            Tab(text: l10n.tripPageTabPrepare),
          ],
        ),
        const SizedBox(height: Tokens.space3),
        switch (_tabs.index) {
          0 => TripPlanView(tripId: trip.id),
          1 => TripPackView(trip: trip),
          _ => TripTodoView(trip: trip),
        },
      ],
    );
  }
}

/// The trip at a glance, and the one step that fits its stage: choose dates, pencil them
/// in, or decide.
class _Header extends StatelessWidget {
  const _Header({
    required this.trip,
    required this.members,
    required this.today,
    required this.busy,
    required this.onFindWindow,
    required this.onEnterDates,
    required this.onFix,
    required this.onPencil,
  });

  final Trip trip;
  final List<Member> members;
  final DateTime today;
  final bool busy;
  final VoidCallback onFindWindow;
  final VoidCallback onEnterDates;
  final VoidCallback onFix;
  final VoidCallback onPencil;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final destination = trip.destinationName?.trim() ?? '';
    final when = tripWhenText(l10n, trip, today);
    final travelling = [
      for (final m in members)
        if (trip.memberIds.contains(m.id)) m,
    ];

    final Widget actions = switch (trip.stage) {
      _ when !trip.hasDates => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tripPageChooseDates, style: theme.textTheme.labelLarge),
          const SizedBox(height: Tokens.space2),
          Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space2,
            children: [
              FilledButton.icon(
                key: const ValueKey('trip-find-window'),
                onPressed: busy ? null : onFindWindow,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(l10n.tripPageFindWindow),
              ),
              OutlinedButton.icon(
                key: const ValueKey('trip-enter-dates'),
                onPressed: busy ? null : onEnterDates,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(l10n.tripPageEnterDates),
              ),
            ],
          ),
        ],
      ),
      TripStage.idea => Wrap(
        spacing: Tokens.space2,
        runSpacing: Tokens.space2,
        children: [
          FilledButton(
            key: const ValueKey('trip-pencil'),
            onPressed: busy ? null : onPencil,
            child: Text(l10n.tripPagePencil),
          ),
          TextButton(
            key: const ValueKey('trip-change-dates'),
            onPressed: busy ? null : onEnterDates,
            child: Text(l10n.tripPageChangeDates),
          ),
        ],
      ),
      TripStage.planned => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space2,
            children: [
              FilledButton.icon(
                key: const ValueKey('trip-fix'),
                onPressed: busy ? null : onFix,
                icon: const Icon(Icons.check),
                label: Text(l10n.tripPageFix),
              ),
              TextButton(
                key: const ValueKey('trip-change-dates'),
                onPressed: busy ? null : onEnterDates,
                child: Text(l10n.tripPageChangeDates),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space2),
          Text(
            l10n.tripPageCalPlanned,
            style: TextStyle(color: context.ww.ink2),
          ),
        ],
      ),
      TripStage.fixed => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: context.ww.success),
              const SizedBox(width: Tokens.space2),
              Expanded(child: Text(l10n.tripPageDecided)),
            ],
          ),
          Wrap(
            spacing: Tokens.space2,
            children: [
              TextButton(
                key: const ValueKey('trip-unfix'),
                onPressed: busy ? null : onPencil,
                child: Text(l10n.tripPageUnfix),
              ),
              TextButton(
                key: const ValueKey('trip-change-dates'),
                onPressed: busy ? null : onEnterDates,
                child: Text(l10n.tripPageChangeDates),
              ),
            ],
          ),
          Text(l10n.tripPageCalFixed, style: TextStyle(color: context.ww.ink2)),
        ],
      ),
    };

    return Card(
      key: const ValueKey('trip-header'),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TripPicture(trip.iconKey, size: 56),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (destination.isNotEmpty)
                        Text(destination, style: theme.textTheme.titleMedium),
                      Text(
                        trip.hasDates
                            ? '${formatTripDates(context, trip.startsOn!, trip.endsOn!)}'
                                  ' · ${l10n.tripPageDays(trip.days)}'
                            : l10n.tripListNoDates,
                        style: TextStyle(color: context.ww.ink2),
                      ),
                      const SizedBox(height: Tokens.space2),
                      Wrap(
                        spacing: Tokens.space2,
                        runSpacing: Tokens.space1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TripStageChip(trip.stage),
                          if (when != null)
                            Text(when, style: theme.textTheme.labelLarge),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            if (trip.wholeFamily || travelling.isEmpty)
              Row(
                children: [
                  Icon(Icons.groups_outlined, color: context.ww.ink2),
                  const SizedBox(width: Tokens.space2),
                  Expanded(child: Text(l10n.tripPageWholeFamily)),
                ],
              )
            else
              Wrap(
                spacing: Tokens.space3,
                runSpacing: Tokens.space2,
                children: [
                  for (final m in travelling)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MemberAvatar(
                          member: BoardMember(
                            id: m.id,
                            displayName: m.displayName,
                            color: m.color,
                            kind: m.isChild
                                ? MemberKind.child
                                : MemberKind.adult,
                          ),
                          size: 24,
                        ),
                        const SizedBox(width: Tokens.space1),
                        Text(m.displayName),
                      ],
                    ),
                ],
              ),
            const SizedBox(height: Tokens.space3),
            actions,
          ],
        ),
      ),
    );
  }
}
