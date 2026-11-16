import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart'
    show isoDate;
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

Map<String, dynamic> _object(Object? json) =>
    Map<String, dynamic>.from(json! as Map);

/// The trips of the household (specs/30): ideas, planned and fixed trips with their
/// entries, stored combinations, checks and the home place, and the `trips` Edge
/// Function's time windows and discovery.
///
/// Reads are whole-household lists with a read-cache key, so everything is readable
/// offline; providers filter them per trip. Writes need the server. [actor] is the
/// acting profile on a shared device and null on a personal one (the server then takes
/// the device's own profile), as everywhere.
class TripsRepository {
  const TripsRepository(this._api);

  final ApiClient _api;

  // ── reads (api views) ─────────────────────────────────────────────────────────────

  Future<Result<List<Trip>>> trips() => _api.select(
    'trips',
    parse: Trip.fromJson,
    build: (q) => q.order('created_at', ascending: true),
    cacheKey: 'trips',
  );

  Future<Result<List<TripEntry>>> entries() => _api.select(
    'trip_entries',
    parse: TripEntry.fromJson,
    build: (q) => q
        .order('position', ascending: true)
        .order('created_at', ascending: true),
    cacheKey: 'trip-entries',
  );

  Future<Result<List<TripCombo>>> combos() => _api.select(
    'trip_combos',
    parse: TripCombo.fromJson,
    build: (q) => q
        .order('position', ascending: true)
        .order('created_at', ascending: true),
    cacheKey: 'trip-combos',
  );

  Future<Result<List<TripCheck>>> checks() => _api.select(
    'trip_checks',
    parse: TripCheck.fromJson,
    build: (q) => q
        .order('position', ascending: true)
        .order('created_at', ascending: true),
    cacheKey: 'trip-checks',
  );

  /// The household's home place; null when none is set.
  Future<Result<TripHome?>> home() async {
    final rows = await _api.select(
      'trip_home',
      parse: TripHome.fromJson,
      cacheKey: 'trip-home',
    );
    return rows.map((list) => list.firstOrNull);
  }

  // ── trips ─────────────────────────────────────────────────────────────────────────

  /// Creates or updates [trip] (its id makes the call idempotent) and keeps the
  /// calendar entry in step.
  Future<Result<TripSaved>> saveTrip({
    required String? actor,
    required Trip trip,
  }) => _saveTrip(actor, trip.toJson());

  /// Changes only the given keys of the trip [id] (`stage`, `starts_on`, ...); the
  /// server keeps the others.
  Future<Result<TripSaved>> patchTrip({
    required String? actor,
    required String id,
    required Map<String, dynamic> changes,
  }) => _saveTrip(actor, {'id': id, ...changes});

  Future<Result<TripSaved>> _saveTrip(
    String? actor,
    Map<String, dynamic> trip,
  ) => _api.rpc(
    'trip_save',
    params: {'p_actor': actor, 'p_trip': trip},
    parse: (json) => TripSaved.fromJson(_object(json)),
  );

  /// Removes the trip, its entries and checks, and its calendar entry.
  Future<Result<void>> deleteTrip({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'trip_delete',
    params: {'p_actor': actor, 'p_id': id},
    parse: (_) {},
  );

  // ── entries ───────────────────────────────────────────────────────────────────────

  /// Creates or updates an entry; returns its id.
  Future<Result<String>> saveEntry({
    required String? actor,
    required TripEntry entry,
  }) => _api.rpc(
    'trip_entry_save',
    params: {'p_actor': actor, 'p_entry': entry.toJson()},
    parse: (json) => _object(json)['id'] as String,
  );

  Future<Result<void>> deleteEntry({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'trip_entry_delete',
    params: {'p_actor': actor, 'p_id': id},
    parse: (_) {},
  );

  /// A copy as `option`, without booking reference and `source_uid`, placed after the
  /// original; returns the copy's id.
  Future<Result<String>> copyEntry({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'trip_entry_copy',
    params: {'p_actor': actor, 'p_id': id},
    parse: (json) => _object(json)['id'] as String,
  );

  /// Adds the entries of a calendar file (at most 50, each with a `source_uid`; one the
  /// trip already has with the same `source_uid` is updated).
  Future<Result<EntriesImported>> importEntries({
    required String? actor,
    required String tripId,
    required List<TripEntry> entries,
  }) => _api.rpc(
    'trip_entries_import',
    params: {
      'p_actor': actor,
      'p_trip': tripId,
      'p_entries': [for (final e in entries) e.toImportJson()],
    },
    parse: (json) => EntriesImported.fromJson(_object(json)),
  );

  // ── combinations ──────────────────────────────────────────────────────────────────

  /// Creates or updates a stored combination; the entry set is replaced. Returns its id.
  Future<Result<String>> saveCombo({
    required String? actor,
    required TripCombo combo,
  }) => _api.rpc(
    'trip_combo_save',
    params: {'p_actor': actor, 'p_combo': combo.toJson()},
    parse: (json) => _object(json)['id'] as String,
  );

  Future<Result<void>> deleteCombo({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'trip_combo_delete',
    params: {'p_actor': actor, 'p_id': id},
    parse: (_) {},
  );

  /// "Diese nehmen": the combination's entries become `chosen`, every other chosen
  /// transport, stay and rental goes back to `option` (a booked entry is never touched),
  /// and with [setDates] the trip takes the combination's dates.
  Future<Result<ComboChoice>> chooseCombo({
    required String? actor,
    required String id,
    bool setDates = false,
  }) => _api.rpc(
    'trip_combo_choose',
    params: {'p_actor': actor, 'p_id': id, 'p_set_dates': setDates},
    parse: (json) => ComboChoice.fromJson(_object(json)),
  );

  // ── checks ────────────────────────────────────────────────────────────────────────

  /// Creates or updates a check; returns its id.
  Future<Result<String>> saveCheck({
    required String? actor,
    required TripCheck check,
  }) => _api.rpc(
    'trip_check_save',
    params: {'p_actor': actor, 'p_check': check.toJson()},
    parse: (json) => _object(json)['id'] as String,
  );

  /// Adds up to 100 checks at once (the starter list); a title the trip already has
  /// for the same person and kind is skipped. Returns how many were added.
  Future<Result<int>> addChecks({
    required String? actor,
    required String tripId,
    required List<TripCheck> checks,
  }) => _api.rpc(
    'trip_checks_add',
    params: {
      'p_actor': actor,
      'p_trip': tripId,
      'p_checks': [
        for (final c in checks)
          c.toJson()
            ..remove('trip_id')
            ..remove('id'),
      ],
    },
    parse: (json) => (_object(json)['added'] as num?)?.toInt() ?? 0,
  );

  /// "Wie letztes Mal": copies the checks of the trip [from] to [to], unticked,
  /// skipping what [to] has. Returns how many were added.
  Future<Result<int>> copyChecks({
    required String? actor,
    required String from,
    required String to,
  }) => _api.rpc(
    'trip_checks_copy',
    params: {'p_actor': actor, 'p_from': from, 'p_to': to},
    parse: (json) => (_object(json)['added'] as num?)?.toInt() ?? 0,
  );

  Future<Result<void>> tickCheck({
    required String? actor,
    required String id,
    required bool done,
  }) => _api.rpc(
    'trip_check_tick',
    params: {'p_actor': actor, 'p_id': id, 'p_done': done},
    parse: (_) {},
  );

  Future<Result<void>> deleteCheck({
    required String? actor,
    required String id,
  }) => _api.rpc(
    'trip_check_delete',
    params: {'p_actor': actor, 'p_id': id},
    parse: (_) {},
  );

  // ── home ──────────────────────────────────────────────────────────────────────────

  /// Sets the household's home place, or forgets it with null. A guardian only.
  Future<Result<void>> setHome({
    required String? actor,
    required TripHome? home,
  }) => _api.rpc(
    'trip_home_set',
    params: {'p_actor': actor, 'p_home': home?.toJson()},
    parse: (_) {},
  );

  // ── the `trips` Edge Function ─────────────────────────────────────────────────────

  /// When the family could travel: the proposed windows of [args].
  Future<Result<List<TripWindow>>> windows(TripWindowsArgs args) =>
      _api.function(
        'trips',
        body: args.toJson(),
        parse: (json) => [
          for (final row in (_object(json)['windows'] as List?) ?? const [])
            TripWindow.fromJson(_object(row)),
        ],
      );

  /// Where it is warm and dry in the window, and how far. Contacts a provider only
  /// through the household's services, so it needs a climate service switched on to say
  /// more than tags and distance.
  Future<Result<DiscoverResult>> discover({
    required String? actor,
    required TripDiscoverArgs args,
  }) => _api.function(
    'trips',
    body: {
      'action': 'discover',
      'from': isoDate(args.from),
      'to': isoDate(args.to),
      if (args.lang != null) 'lang': args.lang,
      'filters': args.filters.toJson(),
      'actor_profile_id': ?actor,
    },
    parse: (json) => DiscoverResult.fromJson(_object(json)),
  );
}

final tripsRepositoryProvider = Provider<TripsRepository>(
  (ref) => TripsRepository(ref.watch(apiClientProvider)),
);
