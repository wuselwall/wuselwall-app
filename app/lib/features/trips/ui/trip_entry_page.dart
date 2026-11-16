import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_entry_args.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_date_field.dart';
import 'package:wuselwall/features/trips/ui/trip_entry_dialogs.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';
import 'package:wuselwall/features/trips/ui/trip_links.dart';
import 'package:wuselwall/features/trips/ui/trip_price_input.dart';

/// Adding or changing one entry of a trip (`Routes.tripEntryPath`).
///
/// A new entry is a quick capture: the kind, a name and a price are enough, a pasted link
/// goes into the link field, and everything else sits under "more details", which is open
/// when an existing entry is changed (specs/30 "Options and the plan").
class TripEntryPage extends ConsumerStatefulWidget {
  const TripEntryPage({required this.tripId, this.args, super.key});

  final String tripId;

  /// The entry to change or the seed of a new one (the route's `extra`); null for a
  /// restored route.
  final TripEntryArgs? args;

  @override
  ConsumerState<TripEntryPage> createState() => _TripEntryPageState();
}

class _TripEntryPageState extends ConsumerState<TripEntryPage> {
  late final TripEntry _base = widget.args?.entry ?? _placeholder();
  late final bool _isNew = widget.args?.isNew ?? true;

  late EntryKind _kind = _base.kind;
  late TransportMode _mode = _base.mode ?? TransportMode.flight;
  late EntryState _state = _base.state;
  late DateTime? _startsOn = _base.startsOn;
  late TimeOfDay? _startsTime = _base.startsTime;
  late DateTime? _endsOn = _base.endsOn;
  late TimeOfDay? _endsTime = _base.endsTime;
  late DateTime? _cancelUntil = _base.cancelUntil;

  late final _title = TextEditingController(text: _base.title);
  final _price = TextEditingController();
  late final _url = TextEditingController(text: _base.url ?? '');
  late final _details = TextEditingController(text: _base.details ?? '');
  late final _from = TextEditingController(text: _base.fromPlace ?? '');
  late final _to = TextEditingController(text: _base.toPlace ?? '');
  late final _address = TextEditingController(text: _base.address ?? '');
  late final _phone = TextEditingController(text: _base.phone ?? '');
  late final _bookingRef = TextEditingController(text: _base.bookingRef ?? '');
  late final _note = TextEditingController(text: _base.note);
  final _bookingRefFocus = FocusNode();

  late bool _more =
      !_isNew ||
      _base.startsOn != null ||
      _base.endsOn != null ||
      (_base.details ?? '').isNotEmpty ||
      _base.state != EntryState.option;
  var _priceFilled = false;
  var _submitted = false;
  var _saving = false;

  TripEntry _placeholder() =>
      TripEntryArgs.seed(widget.tripId, EntryKind.activity).entry;

  @override
  void initState() {
    super.initState();
    if (widget.args == null) {
      // A restored route has nothing to edit: back to the trip.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _leave();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_priceFilled) return;
    _priceFilled = true;
    final cents = _base.priceCents;
    if (cents != null) {
      _price.text = priceInputText(cents, locale: _locale);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _price,
      _url,
      _details,
      _from,
      _to,
      _address,
      _phone,
      _bookingRef,
      _note,
    ]) {
      c.dispose();
    }
    _bookingRefFocus.dispose();
    super.dispose();
  }

  String get _locale => Localizations.localeOf(context).toLanguageTag();

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.tripPath(widget.tripId));
    }
  }

  bool get _hasPlaces =>
      _kind == EntryKind.transport || _kind == EntryKind.rental;
  bool get _hasAddress =>
      _kind == EntryKind.stay || _kind == EntryKind.activity;
  bool get _hasMoney => _kind != EntryKind.note;

  /// The end lies before the start: said inline, and saving is refused.
  bool get _endBeforeStart {
    final start = _startsOn;
    final end = _endsOn;
    if (start == null || end == null) return false;
    final days = daysBetween(start, end);
    if (days < 0) return true;
    final st = _startsTime;
    final et = _endsTime;
    return days == 0 &&
        st != null &&
        et != null &&
        et.hour * 60 + et.minute < st.hour * 60 + st.minute;
  }

  bool _isWebAddress(String text) {
    final uri = Uri.tryParse(text.trim());
    return uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty;
  }

  String? _nullIfEmpty(String text) {
    final t = text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (!_isWebAddress(text)) {
      context.showMessage(context.l10n.tripEntryPasteNone);
      return;
    }
    setState(() => _url.text = text);
  }

  Future<void> _open(Future<bool> opened) async {
    if (!await opened && mounted) {
      context.showMessage(context.l10n.tripEntryOpenFailed);
    }
  }

  void _setState(EntryState state) {
    setState(() => _state = state);
    if (state == EntryState.booked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bookingRefFocus.requestFocus();
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    final price = parsePriceInput(_price.text, locale: _locale);
    final link = _url.text.trim();
    if (_title.text.trim().isEmpty ||
        (_hasMoney && !price.valid) ||
        (_hasMoney && link.isNotEmpty && !_isWebAddress(link)) ||
        _endBeforeStart) {
      return;
    }
    final address = _hasAddress ? _nullIfEmpty(_address.text) : null;
    final addressChanged = address != _base.address;
    final entry = _base.copyWith(
      kind: _kind,
      mode: _kind == EntryKind.transport ? _mode : null,
      title: _title.text.trim(),
      state: _state,
      url: _hasMoney ? _nullIfEmpty(link) : null,
      priceCents: _hasMoney ? price.cents : null,
      details: _nullIfEmpty(_details.text),
      note: _note.text.trim(),
      fromPlace: _hasPlaces ? _nullIfEmpty(_from.text) : null,
      toPlace: _hasPlaces ? _nullIfEmpty(_to.text) : null,
      bookingRef: _hasMoney ? _nullIfEmpty(_bookingRef.text) : null,
      cancelUntil: _hasMoney ? _cancelUntil : null,
      address: address,
      phone: _hasAddress ? _nullIfEmpty(_phone.text) : null,
      lat: addressChanged ? null : _base.lat,
      lon: addressChanged ? null : _base.lon,
      startsOn: _startsOn,
      startsTime: _startsOn == null ? null : _startsTime,
      endsOn: _endsOn,
      endsTime: _endsOn == null ? null : _endsTime,
    );
    setState(() => _saving = true);
    final result = await ref.read(tripActionsProvider).saveEntry(entry);
    if (!mounted) return;
    switch (result) {
      case Ok():
        _leave();
      case Err(:final failure):
        setState(() => _saving = false);
        context.showFailure(failure);
    }
  }

  Future<void> _copy() async {
    final actions = ref.read(tripActionsProvider);
    final result = await actions.copyEntry(_base.id);
    if (!mounted) return;
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok(:final value):
        final entries = await ref.read(
          tripEntriesProvider(widget.tripId).future,
        );
        if (!mounted) return;
        final copy = entries.where((e) => e.id == value).firstOrNull;
        context.showMessage(context.l10n.tripEntryCopied);
        if (copy == null) {
          _leave();
        } else {
          context.pushReplacement(
            Routes.tripEntryPath(widget.tripId),
            extra: TripEntryArgs.edit(copy),
          );
        }
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await confirmTripDelete(
      context,
      title: l10n.tripEntryDeleteTitle,
      body: l10n.tripEntryDeleteBody(_base.title),
      confirmLabel: l10n.delete,
    );
    if (!ok || !mounted) return;
    final result = await ref.read(tripActionsProvider).deleteEntry(_base.id);
    if (!mounted) return;
    switch (result) {
      case Ok():
        _leave();
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!ref.watch(tripsOfferedProvider)) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyView(illustrated: false, message: l10n.tripEntryUnavailable),
      );
    }
    final trip = ref.watch(tripProvider(widget.tripId));
    if (widget.args == null || (trip.hasValue && trip.value == null)) {
      return Scaffold(
        appBar: AppBar(),
        body: trip.hasValue && trip.value == null
            ? EmptyView(illustrated: false, message: l10n.tripEntryGone)
            : const SizedBox.shrink(),
      );
    }
    final currency = trip.value?.currency ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.tripEntryNewTitle : l10n.tripEntryEditTitle),
        actions: [
          if (!_isNew) ...[
            IconButton(
              tooltip: l10n.tripEntryCopy,
              icon: const Icon(Icons.copy_outlined),
              onPressed: _copy,
            ),
            IconButton(
              tooltip: l10n.tripEntryDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
          IconButton(
            tooltip: l10n.save,
            icon: const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 720,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Tokens.space4),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kindChips(),
              if (_kind == EntryKind.transport) ...[
                const SizedBox(height: Tokens.space3),
                _modeChips(),
              ],
              const SizedBox(height: Tokens.space4),
              _text(
                const ValueKey('trip-entry-name'),
                _title,
                l10n.tripEntryName,
                autofocus: _isNew && _base.title.isEmpty,
                capitalize: true,
                error: _submitted && _title.text.trim().isEmpty
                    ? l10n.tripEntryNameRequired
                    : null,
                limit: 200,
              ),
              if (_hasMoney) ...[
                const SizedBox(height: Tokens.space3),
                _priceField(currency),
                const SizedBox(height: Tokens.space3),
                _linkField(),
              ],
              const SizedBox(height: Tokens.space2),
              _moreToggle(),
              if (_more) ..._moreFields(),
              const SizedBox(height: Tokens.space6),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindChips() => Wrap(
    spacing: Tokens.space2,
    runSpacing: Tokens.space1,
    children: [
      for (final kind in EntryKind.values)
        ChoiceChip(
          avatar: Icon(entryKindIcon(kind), size: 18),
          label: Text(context.entryKind(kind)),
          selected: _kind == kind,
          onSelected: (_) => setState(() => _kind = kind),
        ),
    ],
  );

  Widget _modeChips() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.tripEntryMode,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: Tokens.space1),
      Wrap(
        spacing: Tokens.space2,
        runSpacing: Tokens.space1,
        children: [
          for (final mode in TransportMode.values)
            ChoiceChip(
              avatar: Icon(transportModeIcon(mode), size: 18),
              label: Text(context.transportMode(mode)),
              selected: _mode == mode,
              onSelected: (_) => setState(() => _mode = mode),
            ),
        ],
      ),
    ],
  );

  Widget _text(
    Key key,
    TextEditingController controller,
    String label, {
    bool autofocus = false,
    bool capitalize = false,
    bool multiline = false,
    TextInputType? keyboard,
    String? hint,
    String? error,
    int limit = 80,
    Widget? suffix,
    FocusNode? focusNode,
    VoidCallback? onSubmitted,
  }) => TextField(
    key: key,
    controller: controller,
    focusNode: focusNode,
    autofocus: autofocus,
    minLines: multiline ? 2 : 1,
    maxLines: multiline ? 5 : 1,
    keyboardType: multiline ? TextInputType.multiline : keyboard,
    textCapitalization: capitalize
        ? TextCapitalization.sentences
        : TextCapitalization.none,
    textInputAction: onSubmitted != null
        ? TextInputAction.done
        : multiline
        ? TextInputAction.newline
        : TextInputAction.next,
    inputFormatters: [LengthLimitingTextInputFormatter(limit)],
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      errorMaxLines: 3,
      suffixIcon: suffix,
    ),
    onChanged: (_) => setState(() {}),
    onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
  );

  Widget _priceField(String currency) {
    final l10n = context.l10n;
    final price = parsePriceInput(_price.text, locale: _locale);
    final stamp = _base.priceCheckedOn;
    final unchanged = price.valid && price.cents == _base.priceCents;
    final label = l10n.tripEntryPrice(currency).replaceAll(' ()', '');
    return TextField(
      key: const ValueKey('trip-entry-price'),
      controller: _price,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r"[0-9.,' ]")),
      ],
      decoration: InputDecoration(
        labelText: label,
        errorText: _submitted && !price.valid
            ? l10n.tripEntryPriceInvalid
            : null,
        errorMaxLines: 3,
        helperText: stamp != null && unchanged && price.cents != null
            ? l10n.tripEntryPriceFrom(formatTripDate(context, stamp))
            : null,
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _save(),
    );
  }

  Widget _linkField() {
    final l10n = context.l10n;
    final link = _url.text.trim();
    return _text(
      const ValueKey('trip-entry-link'),
      _url,
      l10n.tripEntryLink,
      keyboard: TextInputType.url,
      limit: 2000,
      error: _submitted && link.isNotEmpty && !_isWebAddress(link)
          ? l10n.tripEntryLinkInvalid
          : null,
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('trip-entry-paste'),
            tooltip: l10n.tripEntryPasteLink,
            icon: const Icon(Icons.content_paste),
            onPressed: _paste,
          ),
          if (link.isNotEmpty)
            IconButton(
              tooltip: l10n.tripEntryOpenLink,
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _open(openTripLink(link)),
            ),
        ],
      ),
    );
  }

  Widget _moreToggle() {
    final l10n = context.l10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: const ValueKey('trip-entry-more'),
        onPressed: () => setState(() => _more = !_more),
        icon: Icon(_more ? Icons.expand_less : Icons.expand_more),
        label: Text(_more ? l10n.tripEntryLess : l10n.tripEntryMore),
      ),
    );
  }

  List<Widget> _moreFields() {
    final l10n = context.l10n;
    const gap = SizedBox(height: Tokens.space3);
    final (startLabel, endLabel) = switch (_kind) {
      EntryKind.transport => (
        l10n.tripEntryStartTransport,
        l10n.tripEntryEndTransport,
      ),
      EntryKind.stay => (l10n.tripEntryStartStay, l10n.tripEntryEndStay),
      EntryKind.rental => (l10n.tripEntryStartRental, l10n.tripEntryEndRental),
      _ => (l10n.tripEntryStartPlain, l10n.tripEntryEndPlain),
    };
    final (fromLabel, toLabel) = _kind == EntryKind.rental
        ? (l10n.tripEntryPickUpPlace, l10n.tripEntryReturnPlace)
        : (l10n.tripEntryFrom, l10n.tripEntryTo);
    return [
      gap,
      _text(
        const ValueKey('trip-entry-details'),
        _details,
        l10n.tripEntryDetails,
        hint: l10n.tripEntryDetailsHint,
        limit: 200,
      ),
      if (_hasPlaces) ...[
        gap,
        _text(const ValueKey('trip-entry-from'), _from, fromLabel),
        gap,
        _text(const ValueKey('trip-entry-to'), _to, toLabel),
      ],
      gap,
      TripDateField(
        fieldKey: 'trip-entry-start',
        label: startLabel,
        date: _startsOn,
        time: _startsTime,
        pickerStart: _endsOn,
        onDate: (d) => setState(() {
          _startsOn = d;
          if (d == null) _startsTime = null;
        }),
        onTime: (t) => setState(() => _startsTime = t),
      ),
      gap,
      TripDateField(
        fieldKey: 'trip-entry-end',
        label: endLabel,
        date: _endsOn,
        time: _endsTime,
        pickerStart: _startsOn,
        onDate: (d) => setState(() {
          _endsOn = d;
          if (d == null) _endsTime = null;
        }),
        onTime: (t) => setState(() => _endsTime = t),
      ),
      if (_endBeforeStart)
        Padding(
          padding: const EdgeInsets.only(top: Tokens.space1),
          child: Text(
            l10n.tripEntryEndBeforeStart,
            key: const ValueKey('trip-entry-range-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_hasMoney) ...[
        gap,
        TripDateField(
          fieldKey: 'trip-entry-cancel',
          label: l10n.tripEntryCancelUntil,
          date: _cancelUntil,
          withTime: false,
          pickerStart: _startsOn,
          onDate: (d) => setState(() => _cancelUntil = d),
        ),
      ],
      if (_hasAddress) ...[
        gap,
        _text(
          const ValueKey('trip-entry-address'),
          _address,
          l10n.tripEntryAddress,
          limit: 300,
          suffix: _address.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.tripEntryOpenAddress,
                  icon: const Icon(Icons.map_outlined),
                  onPressed: () => _open(
                    openTripPlace(
                      address: _address.text,
                      lat: _base.lat,
                      lon: _base.lon,
                    ),
                  ),
                ),
        ),
        gap,
        _text(
          const ValueKey('trip-entry-phone'),
          _phone,
          l10n.tripEntryPhone,
          keyboard: TextInputType.phone,
          limit: 40,
          suffix: _phone.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: l10n.tripEntryCallPhone,
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => _open(callTripPhone(_phone.text)),
                ),
        ),
      ],
      gap,
      Text(l10n.tripEntryState, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: Tokens.space1),
      Wrap(
        spacing: Tokens.space2,
        children: [
          for (final state in EntryState.values)
            ChoiceChip(
              key: ValueKey('trip-entry-state-${state.wire}'),
              label: Text(context.entryState(state)),
              selected: _state == state,
              onSelected: (_) => _setState(state),
            ),
        ],
      ),
      if (_hasMoney) ...[
        gap,
        _text(
          const ValueKey('trip-entry-ref'),
          _bookingRef,
          l10n.tripEntryBookingRef,
          focusNode: _bookingRefFocus,
          limit: 80,
        ),
      ],
      gap,
      _text(
        const ValueKey('trip-entry-note'),
        _note,
        l10n.tripEntryNote,
        multiline: true,
        capitalize: true,
        limit: 4000,
      ),
    ];
  }
}
