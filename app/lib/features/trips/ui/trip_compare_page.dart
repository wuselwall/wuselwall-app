import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/ui/text_prompt.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/application/trip_compare_state.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/combination.dart';
import 'package:wuselwall/features/trips/domain/trip_entry_args.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_card_parts.dart';
import 'package:wuselwall/features/trips/ui/trip_combination_bar.dart';
import 'package:wuselwall/features/trips/ui/trip_combo_card.dart';
import 'package:wuselwall/features/trips/ui/trip_entry_dialogs.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';
import 'package:wuselwall/features/trips/ui/trip_links.dart';
import 'package:wuselwall/features/trips/ui/trip_option_card.dart';

/// The kinds that are compared and combined, in the order the page shows them.
const _comparedKinds = [EntryKind.transport, EntryKind.stay, EntryKind.rental];

/// Comparing and combining the options of a trip (`Routes.tripComparePath`): the kept
/// combinations on top, then the options of each kind as cards with a tick, and the
/// combination being tried in a bar at the bottom (specs/30 "Comparing and combining").
class TripComparePage extends ConsumerStatefulWidget {
  const TripComparePage({required this.tripId, this.kind, super.key});

  final String tripId;

  /// The kind to start on (the `kind` query: `transport`, `stay` or `rental`); null: the
  /// first kind with options.
  final EntryKind? kind;

  @override
  ConsumerState<TripComparePage> createState() => _TripComparePageState();
}

class _TripComparePageState extends ConsumerState<TripComparePage> {
  final _sectionKeys = {for (final k in EntryKind.values) k: GlobalKey()};
  var _scrolled = false;

  /// Brings the section of [TripComparePage.kind] into view, once, after it was built.
  void _scrollToKind() {
    final kind = widget.kind;
    if (_scrolled || kind == null) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _sectionKeys[kind]?.currentContext;
      if (mounted && context != null && context.mounted) {
        Scrollable.ensureVisible(context, duration: Duration.zero);
      }
    });
  }

  void _addOption(EntryKind kind) => context.push(
    Routes.tripEntryPath(widget.tripId),
    extra: TripEntryArgs.seed(widget.tripId, kind),
  );

  void _edit(TripEntry entry) => context.push(
    Routes.tripEntryPath(widget.tripId),
    extra: TripEntryArgs.edit(entry),
  );

  Future<void> _copy(TripEntry entry) async {
    final result = await ref.read(tripActionsProvider).copyEntry(entry.id);
    if (!mounted) return;
    switch (result) {
      case Ok():
        context.showMessage(context.l10n.tripEntryCopied);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _openLink(String url) async {
    if (!await openTripLink(url) && mounted) {
      context.showMessage(context.l10n.tripEntryOpenFailed);
    }
  }

  /// A name to start from when the ticks are kept: the stay's, else the first thing's.
  String _suggestedName(Combination combination) {
    final stay = combination.ofKind(EntryKind.stay).firstOrNull;
    final first = stay ?? combination.entries.firstOrNull;
    final title = first?.title ?? '';
    return title.length > 60 ? title.substring(0, 60) : title;
  }

  Future<void> _keep(
    Combination combination,
    List<TripCombo> combos,
    TripCompareState selection,
  ) async {
    final l10n = context.l10n;
    final loaded = combos
        .where((c) => c.id == selection.loadedComboId)
        .firstOrNull;
    final name = await askText(
      context,
      title: l10n.tripComboKeepTitle,
      label: l10n.tripComboName,
      initial: loaded?.name ?? _suggestedName(combination),
      maxLength: 60,
      confirm: l10n.save,
      fieldKey: const ValueKey('combo-name'),
    );
    if (name == null || !mounted) return;
    // The same name as the loaded combination changes that one; any other name is a new one.
    final update =
        loaded != null && loaded.name.toLowerCase() == name.toLowerCase();
    final id = update ? loaded.id : TripActions.newId();
    final result = await ref
        .read(tripActionsProvider)
        .saveCombo(
          TripCombo(
            id: id,
            tripId: widget.tripId,
            name: name,
            entryIds: [for (final e in combination.entries) e.id],
          ),
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.read(tripCompareProvider(widget.tripId).notifier).kept(id);
        context.showMessage(l10n.tripComboKept);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  void _load(TripCombo combo, List<TripEntry> entries) {
    final existing = {for (final e in entries) e.id};
    ref.read(tripCompareProvider(widget.tripId).notifier).load(combo.id, [
      for (final id in combo.entryIds)
        if (existing.contains(id)) id,
    ]);
    context.showMessage(context.l10n.tripComboLoaded(combo.name));
  }

  Future<void> _rename(TripCombo combo) async {
    final l10n = context.l10n;
    final name = await askText(
      context,
      title: l10n.tripComboRename,
      label: l10n.tripComboName,
      initial: combo.name,
      maxLength: 60,
      confirm: l10n.save,
      fieldKey: const ValueKey('combo-name'),
    );
    if (name == null || name == combo.name || !mounted) return;
    final result = await ref
        .read(tripActionsProvider)
        .saveCombo(combo.copyWith(name: name));
    if (!mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }

  Future<void> _delete(TripCombo combo) async {
    final l10n = context.l10n;
    final ok = await confirmTripDelete(
      context,
      title: l10n.tripComboDeleteTitle(combo.name),
      body: l10n.tripComboDeleteBody,
      confirmLabel: l10n.delete,
    );
    if (!ok || !mounted) return;
    final result = await ref.read(tripActionsProvider).deleteCombo(combo.id);
    if (!mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }

  Future<void> _take(
    Trip trip,
    TripCombo combo,
    Combination combination,
  ) async {
    final l10n = context.l10n;
    final setDates = await askTakeCombo(
      context,
      name: combo.name,
      combination: combination,
      tripHasDates: trip.hasDates,
    );
    if (setDates == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(tripActionsProvider)
        .chooseCombo(combo.id, setDates: setDates);
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok(:final value):
        ref.read(tripCompareProvider(widget.tripId).notifier).reset();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                value.datesSet
                    ? l10n.tripComboTakenDates(value.chosen, value.released)
                    : l10n.tripComboTaken(value.chosen, value.released),
              ),
            ),
          );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.tripPath(widget.tripId));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appBar = AppBar(title: Text(l10n.tripCompareTitle));
    if (!ref.watch(tripsOfferedProvider)) {
      return Scaffold(
        appBar: appBar,
        body: EmptyView(
          illustrated: false,
          message: l10n.tripCompareUnavailable,
        ),
      );
    }
    final trip = ref.watch(tripProvider(widget.tripId));
    final entries = ref.watch(tripEntriesProvider(widget.tripId));
    final combos = ref.watch(tripCombosProvider(widget.tripId));
    final loaded = trip.hasValue && entries.hasValue && combos.hasValue;
    if (loaded && trip.requireValue == null) {
      return Scaffold(
        appBar: appBar,
        body: EmptyView(illustrated: false, message: l10n.tripCompareGone),
      );
    }
    if (!loaded) {
      // The first of the three that is still loading, or failed.
      final waiting = [trip, entries, combos].firstWhere((a) => !a.hasValue);
      return Scaffold(
        appBar: appBar,
        body: AsyncValueView<Object?>(
          value: waiting,
          onRetry: () {
            ref.invalidate(tripsProvider);
            ref.invalidate(allTripEntriesProvider);
            ref.invalidate(allTripCombosProvider);
          },
          data: (_) => const SizedBox.shrink(),
        ),
      );
    }
    final view = _view(
      trip.requireValue!,
      entries.requireValue,
      combos.requireValue,
    );
    return Scaffold(
      appBar: appBar,
      body: view.comparable.isEmpty && combos.requireValue.isEmpty
          ? _empty()
          : _content(view),
      // Below the body, so a snackbar floats above the bar instead of covering it.
      bottomNavigationBar: view.comparable.isEmpty
          ? null
          : TripCombinationBar(
              combination: view.combination,
              currency: view.trip.currency,
              onKeep: () =>
                  _keep(view.combination, view.combos, view.selection),
            ),
    );
  }

  _View _view(Trip trip, List<TripEntry> entries, List<TripCombo> combos) {
    final comparable = [
      for (final e in entries)
        if (e.kind != EntryKind.note) e,
    ];
    final selection = ref.watch(tripCompareProvider(widget.tripId));
    final existing = {for (final e in comparable) e.id};
    final ticks = {
      for (final id in selection.ticks ?? defaultTicks(comparable))
        if (existing.contains(id)) id,
    };
    return _View(
      trip: trip,
      comparable: comparable,
      combos: combos,
      selection: selection,
      ticks: ticks,
      combination: Combination.of(trip, [
        for (final e in comparable)
          if (ticks.contains(e.id)) e,
      ]),
    );
  }

  Widget _content(_View view) {
    final l10n = context.l10n;
    final today = ref.watch(todayProvider);
    final trip = view.trip;
    final comparable = view.comparable;
    final combos = view.combos;
    final selection = view.selection;
    final ticks = view.ticks;
    final cheapest = Combination.cheapestOf([
      for (final e in comparable)
        if (e.kind.comparable) e,
    ]);

    // Combinations, with their warnings, and the cheapest of the complete ones.
    final evaluated = [
      for (final c in combos)
        (combo: c, combination: Combination.ofCombo(trip, c, comparable)),
    ];
    final complete = [
      for (final c in evaluated)
        if (!c.combination.isEmpty && !c.combination.incomplete)
          c.combination.total,
    ];
    final cheapestTotal = complete.length >= 2
        ? complete.reduce((a, b) => a < b ? a : b)
        : null;

    final kinds = [
      ..._comparedKinds,
      if (comparable.any((e) => e.kind == EntryKind.activity))
        EntryKind.activity,
    ];
    _scrollToKind();

    return ContentWidth(
      maxWidth: 1240,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                l10n.tripCompareHint,
                key: const ValueKey('compare-hint'),
              ),
            ),
            if (evaluated.isNotEmpty) ...[
              _header(l10n.tripComboSection, evaluated.length),
              TripCardStrip(
                label: l10n.tripComboSection,
                children: [
                  for (final c in evaluated)
                    TripComboCard(
                      key: ValueKey('combo-${c.combo.id}'),
                      combo: c.combo,
                      combination: c.combination,
                      currency: trip.currency,
                      cheapest:
                          cheapestTotal != null &&
                          !c.combination.isEmpty &&
                          !c.combination.incomplete &&
                          c.combination.total == cheapestTotal,
                      loaded: selection.loadedComboId == c.combo.id,
                      onLoad: () => _load(c.combo, comparable),
                      onRename: () => _rename(c.combo),
                      onDelete: () => _delete(c.combo),
                      onTake: () => _take(trip, c.combo, c.combination),
                    ),
                ],
              ),
            ],
            for (final kind in kinds)
              _section(
                trip,
                kind,
                [
                  for (final e in comparable)
                    if (e.kind == kind) e,
                ],
                ticks,
                cheapest,
                today,
              ),
            const SizedBox(height: Tokens.space4),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, int count, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.fromLTRB(
      Tokens.space4,
      Tokens.space4,
      Tokens.space4,
      Tokens.space2,
    ),
    child: Semantics(
      header: true,
      child: Text(
        context.l10n.tripCompareSection(title, count),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );

  Widget _section(
    Trip trip,
    EntryKind kind,
    List<TripEntry> options,
    Set<String> ticks,
    Set<String> cheapest,
    DateTime today,
  ) {
    final l10n = context.l10n;
    final title = context.entryKinds(kind);
    return Column(
      key: _sectionKeys[kind],
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(title, options.length),
        TripCardStrip(
          label: l10n.tripCompareStripLabel(title),
          children: [
            for (final e in options)
              TripOptionCard(
                key: ValueKey('option-${e.id}'),
                entry: e,
                currency: trip.currency,
                today: today,
                ticked: ticks.contains(e.id),
                cheapest: cheapest.contains(e.id),
                onTick: () => ref
                    .read(tripCompareProvider(widget.tripId).notifier)
                    .toggle(e.id, ticks),
                onEdit: () => _edit(e),
                onCopy: () => _copy(e),
                onOpenLink: (e.url ?? '').trim().isEmpty
                    ? null
                    : () => _openLink(e.url!),
              ),
            _AddOptionCard(
              key: ValueKey('add-${kind.wire}'),
              onTap: () => _addOption(kind),
            ),
          ],
        ),
      ],
    );
  }

  Widget _empty() {
    final l10n = context.l10n;
    return EmptyView(
      title: l10n.tripCompareEmptyTitle,
      message: l10n.tripCompareEmptyMessage,
      actions: [
        FilledButton.icon(
          key: const ValueKey('empty-add-transport'),
          onPressed: () => _addOption(EntryKind.transport),
          icon: Icon(entryKindIcon(EntryKind.transport)),
          label: Text(l10n.tripCompareAddTransport),
        ),
        OutlinedButton.icon(
          key: const ValueKey('empty-add-stay'),
          onPressed: () => _addOption(EntryKind.stay),
          icon: Icon(entryKindIcon(EntryKind.stay)),
          label: Text(l10n.tripCompareAddStay),
        ),
        OutlinedButton.icon(
          key: const ValueKey('empty-add-rental'),
          onPressed: () => _addOption(EntryKind.rental),
          icon: Icon(entryKindIcon(EntryKind.rental)),
          label: Text(l10n.tripCompareAddRental),
        ),
      ],
    );
  }
}

/// What the page shows, worked out once per build from the three lists and the ticks.
class _View {
  const _View({
    required this.trip,
    required this.comparable,
    required this.combos,
    required this.selection,
    required this.ticks,
    required this.combination,
  });

  final Trip trip;
  final List<TripEntry> comparable;
  final List<TripCombo> combos;
  final TripCompareState selection;
  final Set<String> ticks;
  final Combination combination;
}

/// The last card of a section: add another option of that kind.
class _AddOptionCard extends StatelessWidget {
  const _AddOptionCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TripCardFrame(
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: 120,
          minWidth: kMinInteractiveDimension,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.space3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add),
                const SizedBox(height: Tokens.space1),
                Text(context.l10n.tripCompareAdd, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
