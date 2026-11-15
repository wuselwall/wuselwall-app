import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/ui/trip_discover_labels.dart';

/// One ranked place of "Wohin?": its name and country, what kind of place it is, an
/// estimate of the distance and effort, and what is typical at the window's time of year
/// (specs/30 "Discovery"). An idea of the family opens its trip; any other place can be
/// kept as an idea.
class TripPlaceCard extends StatelessWidget {
  const TripPlaceCard({
    required this.place,
    required this.filtersActive,
    required this.onKeep,
    required this.onOpen,
    super.key,
  });

  final DiscoverPlace place;

  /// Whether any wish is set, which makes "misses a wish" meaningful.
  final bool filtersActive;
  final VoidCallback onKeep;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ww = context.ww;
    final climate = place.climate;
    final km = place.km;
    final effort = place.effort;
    final title = place.country.isEmpty
        ? place.name
        : '${place.name} · ${place.country}';
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: place.isIdea ? onOpen : null,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: Tokens.space1),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space1,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (place.isIdea)
                    Chip(
                      avatar: const Icon(Icons.lightbulb_outline, size: 18),
                      label: Text(l10n.tripDiscoverIdea),
                      visualDensity: VisualDensity.compact,
                    ),
                  for (final tag in place.tags)
                    Tooltip(
                      message: discoverTagLabel(l10n, tag),
                      child: Icon(
                        discoverTagIcon(tag),
                        size: 20,
                        color: ww.ink2,
                        semanticLabel: discoverTagLabel(l10n, tag),
                      ),
                    ),
                  if (filtersActive && place.fits == DiscoverFit.no)
                    Text(
                      l10n.tripDiscoverMisses,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ww.ink2,
                      ),
                    ),
                ],
              ),
              if (km != null && effort != null) ...[
                const SizedBox(height: Tokens.space1),
                Text(
                  l10n.tripDiscoverDistance(
                    _roundedKm(context, km),
                    travelEffortLabel(l10n, effort),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: ww.ink2),
                ),
              ],
              const SizedBox(height: Tokens.space2),
              if (climate == null)
                Text(
                  l10n.tripDiscoverNoClimate,
                  style: theme.textTheme.bodySmall?.copyWith(color: ww.ink2),
                )
              else
                Wrap(
                  spacing: Tokens.space3,
                  runSpacing: Tokens.space1,
                  children: [
                    _Fact(
                      Icons.thermostat_outlined,
                      l10n.tripDiscoverTemps(
                        climate.tmax.round(),
                        climate.tmin.round(),
                      ),
                    ),
                    if (climate.rainDays case final days?)
                      _Fact(
                        Icons.water_drop_outlined,
                        l10n.tripDiscoverRain(days.round()),
                      ),
                    if (climate.sunHours case final hours?)
                      _Fact(
                        Icons.wb_sunny_outlined,
                        l10n.tripDiscoverSun(hours.round()),
                      ),
                    if (climate.sea case final sea?)
                      _Fact(
                        Icons.waves_outlined,
                        l10n.tripDiscoverSea(sea.round()),
                      ),
                  ],
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: place.isIdea
                    ? TextButton(
                        onPressed: onOpen,
                        child: Text(l10n.tripDiscoverOpen),
                      )
                    : TextButton.icon(
                        onPressed: onKeep,
                        icon: const Icon(Icons.lightbulb_outline),
                        label: Text(l10n.tripDiscoverKeep),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A distance as an estimate reads: to the nearest 10 km (5 below 100).
String _roundedKm(BuildContext context, double km) {
  final step = km < 100 ? 5 : 10;
  final rounded = ((km / step).round() * step).clamp(step, 1 << 30);
  return NumberFormat.decimalPattern(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(rounded);
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: context.ww.ink2),
      const SizedBox(width: Tokens.space1),
      Flexible(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
    ],
  );
}
