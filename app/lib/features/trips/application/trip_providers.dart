import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/trips/data/trips_repository.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/domain/trip_plan.dart';
import 'package:wuselwall/features/trips/domain/trip_today.dart';

/// Whether the trips are on offer on this device: the server has them (specs/30) and the
/// device shows the adult register. Children look forward to a fixed trip in the
/// calendar; the wall shows its calendar entry; neither plans.
final tripsOfferedProvider = Provider<bool>(
  (ref) =>
      ref.watch(tripsSupportedProvider) &&
      ref.watch(uiRegisterProvider) == UiRegister.adult,
);

/// Re-runs the calling provider when the household's trips change (realtime topic
/// `trips`).
void _refreshOnTrips(Ref ref) {
  ref.watch(deviceKeyProvider);
  final householdId = ref.watch(deviceProvider).value?.householdId;
  if (householdId != null) {
    refreshOnInvalidation(ref, householdId: householdId, topic: 'trips');
  }
}

/// Every trip of the household, ideas, planned and fixed, past ones included, in the
/// order they were made; empty on a server without the trips. A failure is an error
/// value, for the page to show with a retry.
final tripsProvider = FutureProvider.autoDispose<List<Trip>>((ref) async {
  if (!ref.watch(tripsSupportedProvider)) return const [];
  _refreshOnTrips(ref);
  return (await ref.watch(tripsRepositoryProvider).trips()).unwrap();
});

/// Every entry of every trip. Pages use [tripEntriesProvider].
final allTripEntriesProvider = FutureProvider.autoDispose<List<TripEntry>>((
  ref,
) async {
  if (!ref.watch(tripsSupportedProvider)) return const [];
  _refreshOnTrips(ref);
  return (await ref.watch(tripsRepositoryProvider).entries()).unwrap();
});

/// Every stored combination of every trip. Pages use [tripCombosProvider].
final allTripCombosProvider = FutureProvider.autoDispose<List<TripCombo>>((
  ref,
) async {
  if (!ref.watch(tripsSupportedProvider)) return const [];
  _refreshOnTrips(ref);
  return (await ref.watch(tripsRepositoryProvider).combos()).unwrap();
});

/// Every check of every trip. Pages use [tripChecksProvider].
final allTripChecksProvider = FutureProvider.autoDispose<List<TripCheck>>((
  ref,
) async {
  if (!ref.watch(tripsSupportedProvider)) return const [];
  _refreshOnTrips(ref);
  return (await ref.watch(tripsRepositoryProvider).checks()).unwrap();
});

/// The household's home place; null when none is set (or on an older server).
final tripHomeProvider = FutureProvider.autoDispose<TripHome?>((ref) async {
  if (!ref.watch(tripsSupportedProvider)) return null;
  _refreshOnTrips(ref);
  return (await ref.watch(tripsRepositoryProvider).home()).unwrap();
});

/// One trip; null when it does not exist (deleted meanwhile).
final tripProvider = FutureProvider.autoDispose.family<Trip?, String>((
  ref,
  id,
) async {
  final trips = await ref.watch(tripsProvider.future);
  return trips.where((t) => t.id == id).firstOrNull;
});

/// The entries of one trip in the trip's order (position).
final tripEntriesProvider = FutureProvider.autoDispose
    .family<List<TripEntry>, String>((ref, tripId) async {
      final all = await ref.watch(allTripEntriesProvider.future);
      return [
        for (final e in all)
          if (e.tripId == tripId) e,
      ];
    });

/// The stored combinations of one trip.
final tripCombosProvider = FutureProvider.autoDispose
    .family<List<TripCombo>, String>((ref, tripId) async {
      final all = await ref.watch(allTripCombosProvider.future);
      return [
        for (final c in all)
          if (c.tripId == tripId) c,
      ];
    });

/// The packing list and to-dos of one trip, in the trip's order.
final tripChecksProvider = FutureProvider.autoDispose
    .family<List<TripCheck>, String>((ref, tripId) async {
      final all = await ref.watch(allTripChecksProvider.future);
      return [
        for (final c in all)
          if (c.tripId == tripId) c,
      ];
    });

/// The day plan of one trip; null when the trip does not exist.
final tripPlanProvider = FutureProvider.autoDispose.family<TripPlan?, String>((
  ref,
  tripId,
) async {
  final trip = await ref.watch(tripProvider(tripId).future);
  if (trip == null) return null;
  return TripPlan.of(trip, await ref.watch(tripEntriesProvider(tripId).future));
});

/// The trip card of Today: null on every device but an adult's, on a server without the
/// trips, while nothing has loaded and when there is nothing to show (no fixed trip
/// running or within 30 days). Never an error: the card just stays away.
final tripTodayProvider = Provider.autoDispose<TripToday?>((ref) {
  if (!ref.watch(tripsOfferedProvider)) return null;
  final trips = ref.watch(tripsProvider).value;
  if (trips == null) return null;
  return TripToday.of(
    trips: trips,
    entries: ref.watch(allTripEntriesProvider).value ?? const [],
    checks: ref.watch(allTripChecksProvider).value ?? const [],
    today: ref.watch(todayProvider),
  );
});

/// Planned and fixed trips with dates that are not over, soonest first: what a booking's
/// calendar file can be added to. Empty while loading and on failure.
final upcomingTripsProvider = Provider.autoDispose<List<Trip>>((ref) {
  final today = ref.watch(todayProvider);
  final trips = ref.watch(tripsProvider).value ?? const <Trip>[];
  return [
    for (final t in trips)
      if (t.stage != TripStage.idea && t.hasDates && !t.isPast(today)) t,
  ]..sort((a, b) => daysBetween(b.startsOn!, a.startsOn!));
});

/// The compact line of Today for trips being planned: null on every device but an adult's, on
/// a server without the trips, while the full [tripTodayProvider] card is shown, while nothing
/// has loaded and when there is no planned (or far-off fixed) trip with dates. Never an error.
final tripPlanningProvider = Provider.autoDispose<TripPlanningLine?>((ref) {
  if (!ref.watch(tripsOfferedProvider)) return null;
  if (ref.watch(tripTodayProvider) != null) return null;
  return TripPlanningLine.of(ref.watch(upcomingTripsProvider));
});

/// When the family could travel (`trips` function, action `windows`); refreshed when
/// the calendar or the school's holidays change.
final tripWindowsProvider = FutureProvider.autoDispose
    .family<List<TripWindow>, TripWindowsArgs>((ref, args) async {
      // Windows read the calendar and the school's Ferien, not the trips.
      ref.watch(deviceKeyProvider);
      final householdId = ref.watch(deviceProvider).value?.householdId;
      if (householdId != null) {
        refreshOnInvalidation(
          ref,
          householdId: householdId,
          topic: 'calendar',
          also: {'school'},
        );
      }
      return (await ref.watch(tripsRepositoryProvider).windows(args)).unwrap();
    });

/// How long a page waits before it asks discovery again while the answer says some
/// climates are `pending`.
const discoverPendingRetry = Duration(seconds: 30);

/// Where it is warm and dry in a window (`trips` function, action `discover`). While
/// [DiscoverResult.pending] is above zero the page asks again after
/// [discoverPendingRetry] (`ref.invalidate(tripDiscoverProvider(args))`).
final tripDiscoverProvider = FutureProvider.autoDispose
    .family<DiscoverResult, TripDiscoverArgs>((ref, args) async {
      final actor = ref.watch(actingProfileProvider);
      return (await ref
              .watch(tripsRepositoryProvider)
              .discover(actor: actor, args: args))
          .unwrap();
    });
