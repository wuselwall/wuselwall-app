import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/services/application/service_actions.dart';
import 'package:wuselwall/features/services/application/service_providers.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/settings/application/app_locale_provider.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// The home place (specs/30 "Discovery"): where distances are counted from. Everyone sees
/// it; a guardian sets it, by searching a name (with a place-search service on) or by
/// typing coordinates, and forgets it.
class TripHomeEditor extends ConsumerWidget {
  const TripHomeEditor({required this.canEdit, super.key});

  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AsyncValueView<TripHome?>(
      value: ref.watch(tripHomeProvider),
      onRetry: () => ref.invalidate(tripHomeProvider),
      data: (home) => Card(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.tripHomeTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: Tokens.space1),
              Text(
                home == null
                    ? l10n.tripHomeNotSet
                    : '${home.name} · ${home.lat.toStringAsFixed(2)}, '
                          '${home.lon.toStringAsFixed(2)}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: Tokens.space1),
              Text(
                l10n.tripHomeExplain,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.ww.ink2,
                ),
              ),
              if (canEdit)
                Wrap(
                  spacing: Tokens.space2,
                  children: [
                    TextButton(
                      onPressed: () => _set(context, ref, home),
                      child: Text(
                        home == null ? l10n.tripHomeSet : l10n.tripHomeChange,
                      ),
                    ),
                    if (home != null)
                      TextButton(
                        onPressed: () => _forget(context, ref),
                        child: Text(l10n.tripHomeForget),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, TripHome? old) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final home = await showDialog<TripHome>(
      context: context,
      builder: (_) => _HomeDialog(initial: old),
    );
    if (home == null || !context.mounted) return;
    final result = await ref.read(tripActionsProvider).setHome(home);
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.tripHomeForgetAsk),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.tripHomeForget),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result = await ref.read(tripActionsProvider).setHome(null);
    if (!context.mounted) return;
    if (result case Err(:final failure)) context.showFailure(failure);
  }
}

class _HomeDialog extends ConsumerStatefulWidget {
  const _HomeDialog({required this.initial});

  final TripHome? initial;

  @override
  ConsumerState<_HomeDialog> createState() => _HomeDialogState();
}

class _HomeDialogState extends ConsumerState<_HomeDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _lat = TextEditingController(
    text: widget.initial?.lat.toStringAsFixed(2),
  );
  late final _lon = TextEditingController(
    text: widget.initial?.lon.toStringAsFixed(2),
  );
  List<GeoPlace>? _found;
  String? _searchError;
  var _searching = false;

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  static double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  double? get _latValue {
    final v = _number(_lat.text);
    return v != null && v >= -90 && v <= 90 ? v : null;
  }

  double? get _lonValue {
    final v = _number(_lon.text);
    return v != null && v >= -180 && v <= 180 ? v : null;
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _latValue != null && _lonValue != null;

  Future<void> _search() async {
    final query = _name.text.trim();
    if (query.isEmpty) return;
    final l10n = context.l10n;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    final result = await ref
        .read(serviceActionsProvider)
        .geocode(query, lang: ref.read(appLocaleProvider).languageCode);
    if (!mounted) return;
    setState(() {
      _searching = false;
      switch (result) {
        case Ok(:final value):
          _found = value.places;
        case Err(:final failure):
          _found = null;
          _searchError = failure.message(l10n);
      }
    });
  }

  void _pick(GeoPlace p) => setState(() {
    _name.text = p.name;
    _lat.text = p.lat.toStringAsFixed(2);
    _lon.text = p.lon.toStringAsFixed(2);
    _found = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canSearch = ref.watch(
      serviceOffersProvider(ServiceCapability.geocode),
    );
    final found = _found;
    final coordinateError =
        (_lat.text.isNotEmpty && _latValue == null) ||
            (_lon.text.isNotEmpty && _lonValue == null)
        ? l10n.tripHomeInvalid
        : null;
    return AlertDialog(
      title: Text(l10n.tripHomeDialogTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 120,
            textInputAction: canSearch
                ? TextInputAction.search
                : TextInputAction.next,
            onSubmitted: canSearch ? (_) => _search() : null,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.tripHomeName,
              suffixIcon: canSearch
                  ? IconButton(
                      tooltip: l10n.tripHomeSearch,
                      onPressed: _searching ? null : _search,
                      icon: const Icon(Icons.search),
                    )
                  : null,
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          if (_searchError != null)
            Text(
              _searchError!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          if (found != null && found.isEmpty) Text(l10n.tripHomeNoResults),
          if (found != null)
            for (final p in found)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.name),
                subtitle: Text(
                  [
                    if (p.admin != null && p.admin!.isNotEmpty) p.admin!,
                    if (p.country.isNotEmpty) p.country,
                  ].join(', '),
                ),
                onTap: () => _pick(p),
              ),
          const SizedBox(height: Tokens.space2),
          Text(
            canSearch ? l10n.tripHomeCoordsHint : l10n.tripHomeNoGeocode,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Tokens.space2),
          Row(
            children: [
              Expanded(child: _coordinateField(_lat, l10n.tripHomeLat)),
              const SizedBox(width: Tokens.space2),
              Expanded(child: _coordinateField(_lon, l10n.tripHomeLon)),
            ],
          ),
          if (coordinateError != null)
            Padding(
              padding: const EdgeInsets.only(top: Tokens.space1),
              child: Text(
                coordinateError,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(
                  context,
                  TripHome(
                    name: _name.text.trim(),
                    lat: _latValue!,
                    lon: _lonValue!,
                  ),
                )
              : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Widget _coordinateField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label),
      );
}
