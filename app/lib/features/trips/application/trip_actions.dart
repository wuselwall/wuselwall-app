import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/data/trips_repository.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// Every write of the trips, as the acting profile, so a page calls one line. After a
/// successful write the household's trip lists are read again (the server's realtime
/// message does the same on other devices).
///
/// The server decides who may write: an adult profile on a personal or shared device, not
/// the wall; the home place only a guardian. A refusal comes back as a [Result] error
/// whose `FailureL10n.message` is the text to show (`adults_only`, `guardian_required`,
/// `kiosk_forbidden`, `trip_invalid`, ...).
class TripActions {
  const TripActions(this._ref);

  final Ref _ref;

  TripsRepository get _repo => _ref.read(tripsRepositoryProvider);
  String? get _actor => _ref.read(actingProfileProvider);

  /// A new client-chosen id for a trip, entry, combination or check (a UUID): saving
  /// with it again changes the same record instead of making another.
  static String newId() => const Uuid().v4();

  Future<Result<T>> _done<T>(Future<Result<T>> write) async {
    final result = await write;
    if (result.isOk) {
      _ref
        ..invalidate(tripsProvider)
        ..invalidate(allTripEntriesProvider)
        ..invalidate(allTripCombosProvider)
        ..invalidate(allTripChecksProvider)
        ..invalidate(tripHomeProvider);
    }
    return result;
  }

  // ── trips ─────────────────────────────────────────────────────────────────────────

  /// Creates or updates [trip]; keeps the calendar entry in step.
  Future<Result<TripSaved>> saveTrip(Trip trip) =>
      _done(_repo.saveTrip(actor: _actor, trip: trip));

  /// Changes only [changes] (wire keys of `p_trip`: `stage`, `starts_on`, ...).
  Future<Result<TripSaved>> patchTrip(
    String id,
    Map<String, dynamic> changes,
  ) => _done(_repo.patchTrip(actor: _actor, id: id, changes: changes));

  /// Moves a trip to [stage]. Fixing needs dates; a fixed trip that falls through
  /// becomes an idea again and its calendar entry goes.
  Future<Result<TripSaved>> setStage(Trip trip, TripStage stage) =>
      saveTrip(trip.copyWith(stage: stage));

  /// Sets the dates (`null`, `null` clears them); an idea that gets dates becomes
  /// planned.
  Future<Result<TripSaved>> setDates(
    Trip trip,
    DateTime? startsOn,
    DateTime? endsOn,
  ) => saveTrip(
    trip.copyWith(
      startsOn: startsOn,
      endsOn: endsOn,
      stage: startsOn != null && trip.stage == TripStage.idea
          ? TripStage.planned
          : startsOn == null
          ? TripStage.idea
          : trip.stage,
    ),
  );

  Future<Result<void>> deleteTrip(String id) =>
      _done(_repo.deleteTrip(actor: _actor, id: id));

  // ── entries ───────────────────────────────────────────────────────────────────────

  /// Creates or updates an entry; returns its id. The server stamps the price's date.
  Future<Result<String>> saveEntry(TripEntry entry) =>
      _done(_repo.saveEntry(actor: _actor, entry: entry));

  Future<Result<void>> deleteEntry(String id) =>
      _done(_repo.deleteEntry(actor: _actor, id: id));

  /// "The same flight a day later": a copy as `option`; returns its id.
  Future<Result<String>> copyEntry(String id) =>
      _done(_repo.copyEntry(actor: _actor, id: id));

  /// Sets one entry to [state] (`chosen`, `booked`, back to `option`).
  Future<Result<String>> setEntryState(TripEntry entry, EntryState state) =>
      saveEntry(entry.copyWith(state: state));

  /// Adds the entries of a booking's calendar file ([tripEntriesFromCalendarFile]); one
  /// the trip has with the same `source_uid` is updated.
  Future<Result<EntriesImported>> importEntries(
    String tripId,
    List<TripEntry> entries,
  ) => _done(
    _repo.importEntries(actor: _actor, tripId: tripId, entries: entries),
  );

  // ── combinations ──────────────────────────────────────────────────────────────────

  /// "Als Kombination merken" / saving a changed one; returns its id.
  Future<Result<String>> saveCombo(TripCombo combo) =>
      _done(_repo.saveCombo(actor: _actor, combo: combo));

  Future<Result<void>> deleteCombo(String id) =>
      _done(_repo.deleteCombo(actor: _actor, id: id));

  /// "Diese nehmen": its entries become chosen, other chosen transport, stay and rental
  /// go back to option, a booked entry is never touched; with [setDates] the trip takes
  /// the combination's dates (and an idea becomes planned).
  Future<Result<ComboChoice>> chooseCombo(String id, {bool setDates = false}) =>
      _done(_repo.chooseCombo(actor: _actor, id: id, setDates: setDates));

  // ── checks ────────────────────────────────────────────────────────────────────────

  Future<Result<String>> saveCheck(TripCheck check) =>
      _done(_repo.saveCheck(actor: _actor, check: check));

  /// Ticks or unticks. Nothing counts or earns points.
  Future<Result<void>> tickCheck(String id, {required bool done}) =>
      _done(_repo.tickCheck(actor: _actor, id: id, done: done));

  Future<Result<void>> deleteCheck(String id) =>
      _done(_repo.deleteCheck(actor: _actor, id: id));

  /// Adds [checks] (at most 100; the starter list from `buildStarterChecks`); one the
  /// trip already has for the same person and kind is skipped. Returns how many were
  /// added.
  Future<Result<int>> addChecks(String tripId, List<TripCheck> checks) =>
      _done(_repo.addChecks(actor: _actor, tripId: tripId, checks: checks));

  /// "Wie letztes Mal": the checks of [from] copied to [to], unticked.
  Future<Result<int>> copyChecks({required String from, required String to}) =>
      _done(_repo.copyChecks(actor: _actor, from: from, to: to));

  // ── home ──────────────────────────────────────────────────────────────────────────

  /// Sets the home place, or forgets it with null. A guardian.
  Future<Result<void>> setHome(TripHome? home) =>
      _done(_repo.setHome(actor: _actor, home: home));
}

final tripActionsProvider = Provider<TripActions>(TripActions.new);
