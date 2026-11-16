import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/trips/application/trip_service_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/domain/trip_plan.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';

/// What the trip adds up to and what the optional services say about it: the sum of what is
/// chosen and booked, the forecast (or what is typical for the month), the drive from home
/// and a map picture. Data that is absent (a service off, no coordinates, no answer) is
/// simply left out: this card never spins or reports an error. Each piece with its
/// provider's attribution line.
class TripInfoCard extends ConsumerWidget {
  const TripInfoCard({required this.plan, super.key});

  final TripPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = plan.trip.id;
    final forecast = ref.watch(tripForecastProvider(id)).value;
    final climate = ref.watch(tripClimateProvider(id)).value;
    final route = ref.watch(tripRouteProvider(id)).value;
    final map = ref.watch(tripMapProvider(id)).value;
    final l10n = context.l10n;
    final trip = plan.trip;
    final sections = <Widget>[
      if (plan.sum > 0)
        Text(
          plan.incomplete
              ? l10n.tripInfoSumAtLeast(
                  formatTripMoney(context, plan.sum, trip.currency),
                )
              : l10n.tripInfoSum(
                  formatTripMoney(context, plan.sum, trip.currency),
                ),
          key: const ValueKey('trip-info-sum'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      if (forecast != null && forecast.days.isNotEmpty)
        _ForecastRow(forecast: forecast)
      else if (climate != null && trip.hasDates)
        _ClimateLines(climate: climate, trip: trip),
      if (route != null) _RouteLine(route: route),
      if (map != null) _MapPictureView(map: map),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const ValueKey('trip-info'),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: Tokens.space3),
              sections[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A provider's attribution line, in small type; nothing when it has none.
class _Attribution extends StatelessWidget {
  const _Attribution(this.text);

  final String? text;

  @override
  Widget build(BuildContext context) {
    final line = text?.trim() ?? '';
    if (line.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space1),
      child: Text(
        line,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: context.ww.ink2),
      ),
    );
  }
}

String _degrees(double value) => value.round().toString();

String _weatherWord(AppLocalizations l10n, WeatherCode code) => switch (code) {
  WeatherCode.clear => l10n.tripInfoWeatherClear,
  WeatherCode.partly => l10n.tripInfoWeatherPartly,
  WeatherCode.cloudy => l10n.tripInfoWeatherCloudy,
  WeatherCode.fog => l10n.tripInfoWeatherFog,
  WeatherCode.rain => l10n.tripInfoWeatherRain,
  WeatherCode.snow => l10n.tripInfoWeatherSnow,
  WeatherCode.storm => l10n.tripInfoWeatherStorm,
};

IconData _weatherIcon(WeatherCode code) => switch (code) {
  WeatherCode.clear => Icons.wb_sunny_outlined,
  WeatherCode.partly => Icons.cloud_queue,
  WeatherCode.cloudy => Icons.cloud_outlined,
  WeatherCode.fog => Icons.foggy,
  WeatherCode.rain => Icons.water_drop_outlined,
  WeatherCode.snow => Icons.ac_unit,
  WeatherCode.storm => Icons.thunderstorm_outlined,
};

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({required this.forecast});

  final Forecast forecast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tag = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.tripInfoForecast, style: theme.textTheme.titleSmall),
        const SizedBox(height: Tokens.space2),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final d in forecast.days)
                Semantics(
                  label: l10n.tripInfoForecastDay(
                    formatTripDay(context, d.date),
                    _weatherWord(l10n, d.code),
                    _degrees(d.tmax),
                    _degrees(d.tmin),
                  ),
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.only(right: Tokens.space3),
                    child: Column(
                      children: [
                        Text(
                          DateFormat.E(tag).add_d().format(d.date),
                          style: theme.textTheme.labelMedium,
                        ),
                        Icon(
                          _weatherIcon(d.code),
                          color: theme.colorScheme.primary,
                        ),
                        Text('${_degrees(d.tmax)}° / ${_degrees(d.tmin)}°'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _Attribution(forecast.attribution),
      ],
    );
  }
}

class _ClimateLines extends StatelessWidget {
  const _ClimateLines({required this.climate, required this.trip});

  final Climate climate;
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tag = Localizations.localeOf(context).toLanguageTag();
    final months = climate.monthsFor(trip.startsOn!, trip.endsOn!);
    if (months.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tripInfoClimate,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: Tokens.space1),
        for (final m in months)
          Text(
            [
              l10n.tripInfoClimateMonth(
                DateFormat.MMMM(tag).format(DateTime(2000, m.month)),
                _degrees(m.tmax),
                _degrees(m.tmin),
              ),
              if (m.rainDays != null)
                l10n.tripInfoRainDays(m.rainDays!.round()),
              if (m.sea != null) l10n.tripInfoSea(_degrees(m.sea!)),
            ].join(' · '),
          ),
        _Attribution(climate.attribution),
      ],
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.route});

  final RouteInfo route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hours = route.minutes ~/ 60;
    final minutes = route.minutes % 60;
    final time = hours == 0
        ? l10n.tripInfoDurationM(minutes)
        : l10n.tripInfoDurationHM(hours, minutes);
    final km = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(route.km.round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.directions_car_outlined, color: context.ww.ink2),
            const SizedBox(width: Tokens.space2),
            Expanded(child: Text(l10n.tripInfoRoute(time, km))),
          ],
        ),
        _Attribution(route.attribution),
      ],
    );
  }
}

class _MapPictureView extends StatelessWidget {
  const _MapPictureView({required this.map});

  final MapPicture map;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.space2),
        child: AspectRatio(
          aspectRatio: tripMapWidth / tripMapHeight,
          child: Image.memory(
            map.bytes,
            fit: BoxFit.cover,
            semanticLabel: context.l10n.tripInfoMap,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
      _Attribution(map.attribution),
    ],
  );
}
