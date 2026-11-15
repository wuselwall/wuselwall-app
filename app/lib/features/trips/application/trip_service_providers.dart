import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/services/application/service_providers.dart';
import 'package:wuselwall/features/services/data/services_repository.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';

/// What the opt-in services add to a trip's page (specs/30 "During the trip"). Each is
/// null when the capability is off for this household, when the trip has no coordinates
/// (or no dates, where dates matter) and when the server could not answer: `service_off`,
/// `service_key_missing`, `service_limit`, `service_failed` and a lost connection all end
/// as "nothing to show", never as an error in the page. A last good answer is read from
/// the cache when offline.

/// How many days before a trip its forecast shows.
const forecastLeadDays = 7;

/// The forecast for the trip's days, from [forecastLeadDays] days before its first day
/// until its last; null outside that time (before it the climate stands in).
final tripForecastProvider = FutureProvider.autoDispose
    .family<Forecast?, String>((ref, tripId) async {
      if (!ref.watch(serviceOffersProvider(ServiceCapability.forecast))) {
        return null;
      }
      final trip = await ref.watch(tripProvider(tripId).future);
      if (trip == null || !trip.hasCoordinates || !trip.hasDates) return null;
      final today = ref.watch(todayProvider);
      if (daysBetween(today, trip.startsOn!) > forecastLeadDays ||
          trip.isPast(today)) {
        return null;
      }
      final result = await ref
          .watch(servicesRepositoryProvider)
          .forecast(
            lat: trip.lat!,
            lon: trip.lon!,
            actor: ref.watch(actingProfileProvider),
          );
      final forecast = result.valueOrNull;
      if (forecast == null) return null;
      final days = forecast.between(trip.startsOn!, trip.endsOn!);
      return days.isEmpty
          ? null
          : Forecast(
              days: days,
              provider: forecast.provider,
              attribution: forecast.attribution,
            );
    });

/// What is typical at the destination, month by month ([Climate.monthsFor] picks the
/// trip's months); null without a climate service or coordinates.
final tripClimateProvider = FutureProvider.autoDispose.family<Climate?, String>(
  (ref, tripId) async {
    if (!ref.watch(serviceOffersProvider(ServiceCapability.climate))) {
      return null;
    }
    final trip = await ref.watch(tripProvider(tripId).future);
    if (trip == null || !trip.hasCoordinates) return null;
    return (await ref
            .watch(servicesRepositoryProvider)
            .climate(
              lat: trip.lat!,
              lon: trip.lon!,
              actor: ref.watch(actingProfileProvider),
            ))
        .valueOrNull;
  },
);

/// The driving distance and time from the home place to the destination; null without a
/// route service, a home place or coordinates.
final tripRouteProvider = FutureProvider.autoDispose.family<RouteInfo?, String>(
  (ref, tripId) async {
    if (!ref.watch(serviceOffersProvider(ServiceCapability.route))) {
      return null;
    }
    final trip = await ref.watch(tripProvider(tripId).future);
    final home = await ref.watch(tripHomeProvider.future);
    if (trip == null || home == null || !trip.hasCoordinates) return null;
    return (await ref
            .watch(servicesRepositoryProvider)
            .route(
              from: (lat: home.lat, lon: home.lon),
              to: (lat: trip.lat!, lon: trip.lon!),
              actor: ref.watch(actingProfileProvider),
            ))
        .valueOrNull;
  },
);

/// The width and height of the map picture the trip page asks for.
const tripMapWidth = 640;
const tripMapHeight = 360;

/// The zoom of the trip's map picture: an island or a region.
const tripMapZoom = 9;

/// A map picture of the destination ([tripMapWidth] x [tripMapHeight], zoom
/// [tripMapZoom]); null without a map service or coordinates.
final tripMapProvider = FutureProvider.autoDispose.family<MapPicture?, String>((
  ref,
  tripId,
) async {
  if (!ref.watch(serviceOffersProvider(ServiceCapability.map))) return null;
  final trip = await ref.watch(tripProvider(tripId).future);
  if (trip == null || !trip.hasCoordinates) return null;
  return (await ref
          .watch(servicesRepositoryProvider)
          .map(
            lat: trip.lat!,
            lon: trip.lon!,
            zoom: tripMapZoom,
            width: tripMapWidth,
            height: tripMapHeight,
            actor: ref.watch(actingProfileProvider),
          ))
      .valueOrNull;
});
