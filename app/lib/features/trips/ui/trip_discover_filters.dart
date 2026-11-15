import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/ui/trip_discover_labels.dart';

/// The temperatures the filters offer, in °C (specs/30 "Discovery").
const discoverTempMinChoices = <int>[18, 22, 25, 28];
const discoverTempMaxChoices = <int>[25, 30];
const discoverSeaChoices = <int>[18, 20, 22, 24];

/// The wishes of "Wohin?": temperature, little rain, sea, kind of place and travel
/// effort, as chips that read like wishes. What needs a climate service or a home place
/// is disabled with one line saying why, and a way to the settings.
class TripDiscoverFilters extends StatelessWidget {
  const TripDiscoverFilters({
    required this.filters,
    required this.climateAvailable,
    required this.homeAvailable,
    required this.onTempMin,
    required this.onTempMax,
    required this.onDry,
    required this.onSeaMin,
    required this.onTag,
    required this.onEffort,
    required this.onOpenServices,
    this.climateKnown = true,
    this.homeKnown = true,
    super.key,
  });

  final DiscoverFilters filters;

  /// A weather service is switched on: the temperature, rain and sea filters work.
  final bool climateAvailable;

  /// Whether that is known yet; the hint stays away until it is.
  final bool climateKnown;

  /// A home place is set: the effort filter works.
  final bool homeAvailable;
  final bool homeKnown;
  final ValueChanged<double?> onTempMin;
  final ValueChanged<double?> onTempMax;
  final ValueChanged<bool> onDry;
  final ValueChanged<double?> onSeaMin;
  final void Function(String tag, {required bool on}) onTag;
  final ValueChanged<TravelEffort?> onEffort;
  final VoidCallback onOpenServices;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final climateOn = climateAvailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (climateKnown && !climateAvailable)
          _Hint(
            text: l10n.tripDiscoverNeedsClimate,
            onOpenServices: onOpenServices,
          ),
        _ChoiceRow<int>(
          label: l10n.tripDiscoverTempMinLabel,
          choices: discoverTempMinChoices,
          choiceLabel: (t) => l10n.tripDiscoverDegrees(t),
          selected: filters.tempMin?.round(),
          enabled: climateOn,
          onSelected: (t) => onTempMin(t?.toDouble()),
        ),
        _ChoiceRow<int>(
          label: l10n.tripDiscoverTempMaxLabel,
          choices: discoverTempMaxChoices,
          choiceLabel: (t) => l10n.tripDiscoverDegrees(t),
          selected: filters.tempMax?.round(),
          enabled: climateOn,
          onSelected: (t) => onTempMax(t?.toDouble()),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.space2),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilterChip(
              label: Text(l10n.tripDiscoverDry),
              selected: filters.dry,
              onSelected: climateOn ? onDry : null,
            ),
          ),
        ),
        _ChoiceRow<int>(
          label: l10n.tripDiscoverSeaLabel,
          choices: discoverSeaChoices,
          choiceLabel: (t) => l10n.tripDiscoverDegrees(t),
          selected: filters.seaMin?.round(),
          enabled: climateOn,
          onSelected: (t) => onSeaMin(t?.toDouble()),
        ),
        _Label(l10n.tripDiscoverTagsLabel),
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.space2),
          child: Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space1,
            children: [
              for (final tag in discoverTags)
                FilterChip(
                  avatar: Icon(discoverTagIcon(tag), size: 18),
                  label: Text(discoverTagLabel(l10n, tag)),
                  selected: filters.tags.contains(tag),
                  onSelected: (on) => onTag(tag, on: on),
                ),
            ],
          ),
        ),
        if (homeKnown && !homeAvailable)
          _Hint(
            text: l10n.tripDiscoverNeedsHome,
            onOpenServices: onOpenServices,
          ),
        _ChoiceRow<TravelEffort>(
          label: l10n.tripDiscoverEffortLabel,
          choices: TravelEffort.values,
          choiceLabel: (e) => travelEffortLabel(l10n, e),
          selected: filters.effort,
          enabled: homeAvailable,
          onSelected: onEffort,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.space1),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// A wish with a few values to choose from, and "any" to take it back.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.choices,
    required this.choiceLabel,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final List<T> choices;
  final String Function(T) choiceLabel;
  final T? selected;
  final bool enabled;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label),
          Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space1,
            children: [
              ChoiceChip(
                label: Text(l10n.tripDiscoverAny),
                selected: selected == null,
                onSelected: enabled ? (_) => onSelected(null) : null,
              ),
              for (final c in choices)
                ChoiceChip(
                  label: Text(choiceLabel(c)),
                  selected: selected == c,
                  onSelected: enabled ? (_) => onSelected(c) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line on why a filter is off, with the way to switch it on.
class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.onOpenServices});

  final String text;
  final VoidCallback onOpenServices;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: Theme.of(context).textTheme.bodySmall),
          TextButton(
            onPressed: onOpenServices,
            child: Text(l10n.tripDiscoverOpenServices),
          ),
        ],
      ),
    );
  }
}
