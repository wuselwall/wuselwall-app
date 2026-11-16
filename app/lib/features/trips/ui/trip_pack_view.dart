import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/ui/text_prompt.dart';
import 'package:wuselwall/features/board/domain/week_board.dart'
    show BoardMember, MemberKind;
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/packing_starters.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_check_row.dart';

/// The packing list is "short" below this many items: the two helpers show.
const _shortList = 10;

/// The localised title of a starter item (`tripPackStarter` + its id).
String packStarterTitle(AppLocalizations l10n, PackingStarter s) =>
    switch (s.id) {
      'passports' => l10n.tripPackStarterPassports,
      'healthInsuranceCard' => l10n.tripPackStarterHealthInsuranceCard,
      'bookingConfirmations' => l10n.tripPackStarterBookingConfirmations,
      'cashAndCards' => l10n.tripPackStarterCashAndCards,
      'pharmacyBag' => l10n.tripPackStarterPharmacyBag,
      'regularMedication' => l10n.tripPackStarterRegularMedication,
      'sunscreen' => l10n.tripPackStarterSunscreen,
      'insectRepellent' => l10n.tripPackStarterInsectRepellent,
      'chargers' => l10n.tripPackStarterChargers,
      'powerAdapter' => l10n.tripPackStarterPowerAdapter,
      'powerBank' => l10n.tripPackStarterPowerBank,
      'headphones' => l10n.tripPackStarterHeadphones,
      'underwearSocks' => l10n.tripPackStarterUnderwearSocks,
      'tshirts' => l10n.tripPackStarterTshirts,
      'trousersShorts' => l10n.tripPackStarterTrousersShorts,
      'warmJumper' => l10n.tripPackStarterWarmJumper,
      'rainJacket' => l10n.tripPackStarterRainJacket,
      'walkingShoes' => l10n.tripPackStarterWalkingShoes,
      'sleepwear' => l10n.tripPackStarterSleepwear,
      'swimwear' => l10n.tripPackStarterSwimwear,
      'beachTowels' => l10n.tripPackStarterBeachTowels,
      'sunHat' => l10n.tripPackStarterSunHat,
      'sunglasses' => l10n.tripPackStarterSunglasses,
      'cuddlyToy' => l10n.tripPackStarterCuddlyToy,
      'kidsGames' => l10n.tripPackStarterKidsGames,
      'nappiesWipes' => l10n.tripPackStarterNappiesWipes,
      'journeySnacks' => l10n.tripPackStarterJourneySnacks,
      _ => s.id,
    };

/// The name of a group of starter items.
String packGroupTitle(AppLocalizations l10n, PackingGroup g) => switch (g) {
  PackingGroup.documents => l10n.tripPackGroupDocuments,
  PackingGroup.health => l10n.tripPackGroupHealth,
  PackingGroup.electronics => l10n.tripPackGroupElectronics,
  PackingGroup.clothes => l10n.tripPackGroupClothes,
  PackingGroup.beach => l10n.tripPackGroupBeach,
  PackingGroup.kids => l10n.tripPackGroupKids,
};

/// The Packen tab (specs/30 "Packing and preparing"): the list per person and for the
/// family, with a field to add to each, and two helpers while the list is short.
class TripPackView extends ConsumerWidget {
  const TripPackView({required this.trip, super.key});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks = ref.watch(tripChecksProvider(trip.id));
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    return AsyncValueView<List<TripCheck>>(
      value: checks,
      onRetry: () => ref.invalidate(tripChecksProvider(trip.id)),
      data: (all) => _PackBody(
        trip: trip,
        members: members,
        checks: [
          for (final c in all)
            if (c.kind == CheckKind.pack) c,
        ],
      ),
    );
  }
}

class _PackBody extends ConsumerWidget {
  const _PackBody({
    required this.trip,
    required this.members,
    required this.checks,
  });

  final Trip trip;
  final List<Member> members;
  final List<TripCheck> checks;

  TripActions _actions(WidgetRef ref) => ref.read(tripActionsProvider);

  Future<void> _tick(
    BuildContext context,
    WidgetRef ref,
    TripCheck c,
    bool on,
  ) => runTripWrite(context, _actions(ref).tickCheck(c.id, done: on));

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    String title,
    String? profileId,
  ) => runTripWrite(
    context,
    _actions(ref).saveCheck(
      TripCheck(
        id: TripActions.newId(),
        tripId: trip.id,
        kind: CheckKind.pack,
        title: title,
        profileId: profileId,
      ),
    ),
  );

  Future<void> _rename(BuildContext context, WidgetRef ref, TripCheck c) async {
    final l10n = context.l10n;
    final title = await askText(
      context,
      title: l10n.tripPackRename,
      label: l10n.tripPackItem,
      initial: c.title,
      maxLength: 120,
    );
    if (title == null || title == c.title || !context.mounted) return;
    await runTripWrite(
      context,
      _actions(ref).saveCheck(c.copyWith(title: title)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, TripCheck c) =>
      runTripWrite(context, _actions(ref).deleteCheck(c.id));

  /// Everyone on the trip: its members, or the whole active family.
  List<Member> get _travellers => [
    for (final m in members)
      if (trip.wholeFamily ? m.active : trip.memberIds.contains(m.id)) m,
  ];

  Future<void> _suggest(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final groups = await showModalBottomSheet<Set<PackingGroup>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => const _SuggestionsSheet(),
    );
    if (groups == null || groups.isEmpty || !context.mounted) return;
    final travellers = _travellers;
    final built = buildStarterChecks(
      tripId: trip.id,
      titleOf: (s) => packStarterTitle(l10n, s),
      travellers: [for (final m in travellers) m.id],
      children: [
        for (final m in travellers)
          if (m.isChild) m.id,
      ],
      starters: [
        for (final s in packingStarters)
          if (groups.contains(s.group)) s,
      ],
    );
    final result = await _actions(ref).addChecks(trip.id, built);
    if (!context.mounted) return;
    if (reportTripResult(context, result)) {
      context.showMessage(l10n.tripPackAdded(result.valueOrNull ?? 0));
    }
  }

  Future<void> _lastTime(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final trips = await ref.read(tripsProvider.future);
    final all = await ref.read(allTripChecksProvider.future);
    final withList = {
      for (final c in all)
        if (c.kind == CheckKind.pack) c.tripId,
    };
    final sources =
        [
          for (final t in trips)
            if (t.id != trip.id && withList.contains(t.id)) t,
        ]..sort(
          (a, b) =>
              (b.startsOn ?? DateTime(0)).compareTo(a.startsOn ?? DateTime(0)),
        );
    if (!context.mounted) return;
    if (sources.isEmpty) {
      context.showMessage(l10n.tripPackLastTimeNone);
      return;
    }
    final from = await showDialog<Trip>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.tripPackLastTimeChoose),
        children: [
          for (final t in sources)
            SimpleDialogOption(
              key: ValueKey('trip-copy-from-${t.id}'),
              onPressed: () => Navigator.pop(context, t),
              child: Text(t.title),
            ),
        ],
      ),
    );
    if (from == null || !context.mounted) return;
    final result = await _actions(ref).copyChecks(from: from.id, to: trip.id);
    if (!context.mounted) return;
    if (reportTripResult(context, result)) {
      context.showMessage(l10n.tripPackAdded(result.valueOrNull ?? 0));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final done = checks.where((c) => c.done).length;
    final byPerson = <String?, List<TripCheck>>{};
    for (final c in checks) {
      (byPerson[c.profileId] ??= []).add(c);
    }
    final travellerIds = {for (final m in _travellers) m.id};
    final people = [
      for (final m in members)
        if (travellerIds.contains(m.id) || byPerson.containsKey(m.id)) m,
    ];

    Widget section({
      required Widget leading,
      required String name,
      required List<TripCheck> items,
      required String? profileId,
    }) => _Section(
      key: ValueKey('trip-pack-${profileId ?? 'family'}'),
      leading: leading,
      name: name,
      items: items,
      onTick: (c, on) => _tick(context, ref, c, on),
      onRename: (c) => _rename(context, ref, c),
      onDelete: (c) => _delete(context, ref, c),
      onAdd: (title) => _add(context, ref, title, profileId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (checks.isNotEmpty)
          _Progress(done: done, total: checks.length)
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
            child: Text(
              l10n.tripPackEmpty,
              style: TextStyle(color: context.ww.ink2),
            ),
          ),
        if (checks.length < _shortList)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space2),
            child: Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('trip-pack-suggest'),
                  onPressed: () => _suggest(context, ref),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(l10n.tripPackSuggestions),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('trip-pack-last-time'),
                  onPressed: () => _lastTime(context, ref),
                  icon: const Icon(Icons.content_copy_outlined),
                  label: Text(l10n.tripPackLastTime),
                ),
              ],
            ),
          ),
        section(
          leading: Icon(Icons.groups_outlined, color: context.ww.ink2),
          name: l10n.tripPackForAll,
          items: byPerson[null] ?? const [],
          profileId: null,
        ),
        for (final m in people)
          section(
            leading: MemberAvatar(
              member: BoardMember(
                id: m.id,
                displayName: m.displayName,
                color: m.color,
                kind: m.isChild ? MemberKind.child : MemberKind.adult,
              ),
              size: 28,
            ),
            name: m.displayName,
            items: byPerson[m.id] ?? const [],
            profileId: m.id,
          ),
      ],
    );
  }
}

/// "7 von 20", calm: a plain bar, no score.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.space2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.tripPackProgress(done, total),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: Tokens.space1),
        LinearProgressIndicator(
          value: total == 0 ? 0 : done / total,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    ),
  );
}

/// One person's items (or the family's), with the field that adds another.
class _Section extends StatelessWidget {
  const _Section({
    required this.leading,
    required this.name,
    required this.items,
    required this.onTick,
    required this.onRename,
    required this.onDelete,
    required this.onAdd,
    super.key,
  });

  final Widget leading;
  final String name;
  final List<TripCheck> items;
  final void Function(TripCheck check, bool done) onTick;
  final void Function(TripCheck check) onRename;
  final void Function(TripCheck check) onDelete;
  final void Function(String title) onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final done = items.where((c) => c.done).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Tokens.space3,
                vertical: Tokens.space1,
              ),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: Tokens.space2),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(name, style: theme.textTheme.titleSmall),
                    ),
                  ),
                  if (items.isNotEmpty)
                    Text(
                      l10n.tripPackProgress(done, items.length),
                      style: TextStyle(color: context.ww.ink2),
                    ),
                ],
              ),
            ),
            for (final c in items)
              TripCheckRow(
                check: c,
                editLabel: l10n.tripPackRename,
                onTick: (on) => onTick(c, on),
                onEdit: () => onRename(c),
                onDelete: () => onDelete(c),
              ),
            _AddField(hint: l10n.tripPackAddHint, onAdd: onAdd),
          ],
        ),
      ),
    );
  }
}

/// An inline field: type, press enter or the plus, and it joins the list.
class _AddField extends StatefulWidget {
  const _AddField({required this.hint, required this.onAdd});

  final String hint;
  final void Function(String title) onAdd;

  @override
  State<_AddField> createState() => _AddFieldState();
}

class _AddFieldState extends State<_AddField> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _text.text.trim();
    if (title.isEmpty) return;
    _text.clear();
    widget.onAdd(title);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Tokens.space3),
    child: TextField(
      controller: _text,
      maxLength: 120,
      buildCounter: (
        _, {
        required currentLength,
        required isFocused,
        maxLength,
      }) => null,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: widget.hint,
        suffixIcon: IconButton(
          tooltip: context.l10n.tripPackAdd,
          icon: const Icon(Icons.add),
          onPressed: _submit,
        ),
      ),
      onSubmitted: (_) => _submit(),
    ),
  );
}

/// "Vorschläge": which groups of the starter list to add.
class _SuggestionsSheet extends StatefulWidget {
  const _SuggestionsSheet();

  @override
  State<_SuggestionsSheet> createState() => _SuggestionsSheetState();
}

class _SuggestionsSheetState extends State<_SuggestionsSheet> {
  final _chosen = {...PackingGroup.values};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space4,
        0,
        Tokens.space4,
        Tokens.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.tripPackSuggestions,
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: Tokens.space1),
          Text(l10n.tripPackSuggestionsHelp),
          const SizedBox(height: Tokens.space2),
          for (final g in PackingGroup.values)
            CheckboxListTile(
              key: ValueKey('trip-suggest-${g.name}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _chosen.contains(g),
              onChanged: (on) => setState(() {
                on == true ? _chosen.add(g) : _chosen.remove(g);
              }),
              title: Text(packGroupTitle(l10n, g)),
              subtitle: Text(
                [
                  for (final s in packingStarters)
                    if (s.group == g) packStarterTitle(l10n, s),
                ].join(', '),
              ),
            ),
          const SizedBox(height: Tokens.space2),
          FilledButton(
            key: const ValueKey('trip-suggest-add'),
            onPressed: _chosen.isEmpty
                ? null
                : () => Navigator.pop(context, {..._chosen}),
            child: Text(l10n.tripPackSuggestionsAdd),
          ),
        ],
      ),
    );
  }
}
