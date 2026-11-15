import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/ringed_avatar.dart';
import 'package:wuselwall/features/board/domain/week_board.dart'
    show BoardMember, MemberKind;
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';
import 'package:wuselwall/features/services/application/service_actions.dart';
import 'package:wuselwall/features/services/application/service_providers.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// "Neue Idee" and "Reise bearbeiten" as a sheet. Without [trip] it makes a new idea with a
/// fresh id; with it, it changes that trip. Resolves to the saved trip's id, or null when
/// the sheet was closed without saving.
Future<String?> showTripEditSheet(BuildContext context, {Trip? trip}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => TripEditSheet(trip: trip),
    );

/// The form behind [showTripEditSheet]: name (required), picture, destination with an
/// optional place search, who travels, the currency (when changing a trip) and a note.
class TripEditSheet extends ConsumerStatefulWidget {
  const TripEditSheet({this.trip, super.key});

  final Trip? trip;

  @override
  ConsumerState<TripEditSheet> createState() => _TripEditSheetState();
}

class _TripEditSheetState extends ConsumerState<TripEditSheet> {
  late final _title = TextEditingController(text: widget.trip?.title);
  late final _destination = TextEditingController(
    text: widget.trip?.destinationName,
  );
  late final _note = TextEditingController(text: widget.trip?.note);
  late final _currency = TextEditingController(text: widget.trip?.currency);

  late String? _iconKey = widget.trip?.iconKey;
  late final Set<String> _members = {...?widget.trip?.memberIds};

  // The destination's coordinates; they belong to the name they were found for and are
  // dropped when the name is changed by hand.
  late String? _destinationKey = widget.trip?.destinationKey;
  late String? _country = widget.trip?.country;
  late double? _lat = widget.trip?.lat;
  late double? _lon = widget.trip?.lon;
  late String? _boundName = widget.trip?.destinationName;

  List<GeoPlace>? _places;
  String? _attribution;
  bool _finding = false;
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  bool get _isNew => widget.trip == null;

  @override
  void dispose() {
    _title.dispose();
    _destination.dispose();
    _note.dispose();
    _currency.dispose();
    super.dispose();
  }

  void _destinationChanged(String text) {
    if (text.trim() == _boundName) return;
    setState(() {
      _boundName = null;
      _destinationKey = null;
      _country = null;
      _lat = null;
      _lon = null;
    });
  }

  Future<void> _findPlace() async {
    final query = _destination.text.trim();
    if (query.isEmpty || _finding) return;
    setState(() {
      _finding = true;
      _error = null;
    });
    final lang = Localizations.localeOf(context).languageCode;
    final result = await ref
        .read(serviceActionsProvider)
        .geocode(query, lang: lang);
    if (!mounted) return;
    setState(() {
      _finding = false;
      switch (result) {
        case Ok(:final value):
          _places = value.places.take(5).toList();
          _attribution = value.attribution;
        case Err(:final failure):
          _places = null;
          _error = failure.message(context.l10n);
      }
    });
  }

  void _pick(GeoPlace place) => setState(() {
    _destination.text = place.name;
    _boundName = place.name;
    _destinationKey = null;
    _country = place.country.isEmpty ? null : place.country;
    _lat = place.lat;
    _lon = place.lon;
    _places = null;
  });

  String? get _currencyError {
    final text = _currency.text.trim();
    if (_isNew || text.isEmpty) return null;
    return RegExp(r'^[A-Za-z]{3}$').hasMatch(text)
        ? null
        : context.l10n.tripEditCurrencyInvalid;
  }

  Future<void> _save(List<Member> members) async {
    setState(() => _submitted = true);
    if (_title.text.trim().isEmpty || _currencyError != null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final destination = _destination.text.trim();
    final currency = _currency.text.trim().toUpperCase();
    final base = widget.trip ?? Trip(id: TripActions.newId(), title: '');
    final trip = base.copyWith(
      title: _title.text.trim(),
      iconKey: _iconKey,
      destinationName: destination.isEmpty ? null : destination,
      destinationKey: _destinationKey,
      country: _country,
      lat: _lat,
      lon: _lon,
      note: _note.text.trim(),
      currency: _isNew || currency.isEmpty ? null : currency,
      memberIds: [
        for (final m in members)
          if (_members.contains(m.id)) m.id,
      ],
    );
    final result = await ref.read(tripActionsProvider).saveTrip(trip);
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(trip.id);
      case Err(:final failure):
        setState(() {
          _saving = false;
          _error = failure.message(context.l10n);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final members = [
      for (final m in ref.watch(membersProvider).value ?? const <Member>[])
        if (m.active) m,
    ];
    final canFind = ref.watch(serviceOffersProvider(ServiceCapability.geocode));
    final found = _lat != null && _lon != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
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
                _isNew ? l10n.tripListNewIdea : l10n.tripEditTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: Tokens.space3),
            TextField(
              key: const ValueKey('trip-edit-title'),
              controller: _title,
              autofocus: _isNew,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.tripEditName,
                hintText: l10n.tripEditNameHint,
                errorText: _submitted && _title.text.trim().isEmpty
                    ? l10n.tripEditNameRequired
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Tokens.space2),
            Text(l10n.eventIconLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: Tokens.space2),
            Wrap(
              spacing: Tokens.space1,
              runSpacing: Tokens.space1,
              children: [
                _IconChoice(
                  tooltip: l10n.eventIconNone,
                  selected: _iconKey == null,
                  onTap: () => setState(() => _iconKey = null),
                  child: const Icon(Icons.block, size: 22),
                ),
                for (final key in eventIconKeys)
                  _IconChoice(
                    key: ValueKey('trip-icon-$key'),
                    tooltip: eventIconName(l10n, key),
                    selected: _iconKey == key,
                    onTap: () => setState(() => _iconKey = key),
                    child: EmojiPicture(eventIconAsset(key)!, size: 28),
                  ),
              ],
            ),
            const SizedBox(height: Tokens.space4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('trip-edit-destination'),
                    controller: _destination,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.tripEditDestination,
                    ),
                    onChanged: _destinationChanged,
                    onSubmitted: canFind ? (_) => _findPlace() : null,
                  ),
                ),
                if (canFind) ...[
                  const SizedBox(width: Tokens.space2),
                  Padding(
                    padding: const EdgeInsets.only(top: Tokens.space1),
                    child: OutlinedButton.icon(
                      key: const ValueKey('trip-find-place'),
                      onPressed: _finding || _destination.text.trim().isEmpty
                          ? null
                          : _findPlace,
                      icon: _finding
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.place_outlined),
                      label: Text(l10n.tripEditFindPlace),
                    ),
                  ),
                ],
              ],
            ),
            if (canFind && found && _places == null)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space2),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: context.ww.success,
                    ),
                    const SizedBox(width: Tokens.space1),
                    Text(l10n.tripEditPlaceFound),
                  ],
                ),
              ),
            if (_places case final places?) ...[
              if (places.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: Tokens.space2),
                  child: Text(l10n.tripEditNoPlaces),
                ),
              for (final p in places)
                ListTile(
                  key: ValueKey('trip-place-${p.lat}-${p.lon}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(p.name),
                  subtitle: Text(
                    [
                      if (p.admin != null && p.admin!.isNotEmpty) p.admin!,
                      if (p.country.isNotEmpty) p.country,
                    ].join(', '),
                  ),
                  onTap: () => _pick(p),
                ),
              if (_attribution != null && _attribution!.isNotEmpty)
                Text(
                  _attribution!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.ww.ink2,
                  ),
                ),
            ],
            const SizedBox(height: Tokens.space2),
            Text(l10n.tripEditWho, style: theme.textTheme.labelLarge),
            const SizedBox(height: Tokens.space2),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                for (final m in members)
                  FilterChip(
                    key: ValueKey('trip-member-${m.id}'),
                    showCheckmark: false,
                    avatar: RingedAvatar(
                      selected: _members.contains(m.id),
                      child: MemberAvatar(
                        member: BoardMember(
                          id: m.id,
                          displayName: m.displayName,
                          color: m.color,
                          kind: m.isChild ? MemberKind.child : MemberKind.adult,
                        ),
                        size: 24,
                      ),
                    ),
                    label: Text(m.displayName),
                    selected: _members.contains(m.id),
                    onSelected: (on) => setState(() {
                      on ? _members.add(m.id) : _members.remove(m.id);
                    }),
                  ),
              ],
            ),
            if (_members.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space1),
                child: Text(
                  l10n.tripEditWholeFamily,
                  style: TextStyle(color: context.ww.ink2),
                ),
              ),
            if (!_isNew) ...[
              const SizedBox(height: Tokens.space3),
              TextField(
                key: const ValueKey('trip-edit-currency'),
                controller: _currency,
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.tripEditCurrency,
                  helperText: l10n.tripEditCurrencyHelp,
                  errorText: _currencyError,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: Tokens.space2),
            TextField(
              key: const ValueKey('trip-edit-note'),
              controller: _note,
              maxLength: 4000,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.tripEditNote),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Tokens.space2),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: Tokens.space2),
            FilledButton(
              key: const ValueKey('trip-edit-save'),
              onPressed: _saving ? null : () => _save(members),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.tooltip,
    required this.selected,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected ? scheme.primaryContainer : null,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: ExcludeSemantics(child: child),
          ),
        ),
      ),
    );
  }
}
