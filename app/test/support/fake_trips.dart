import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/services/data/services_repository.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/trips/data/trips_repository.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// The trips in memory, for widget tests (specs/30). Seed the lists in the constructor
/// (or assign to them), call the UI, then read what was recorded.
///
/// Writes change the lists, so a page that reads again sees them. Set [failure] to make
/// every write (and read) answer with that failure instead. [actors] holds the `actor` of
/// every write, in order.
class FakeTripsRepository implements TripsRepository {
  FakeTripsRepository({
    List<Trip> trips = const [],
    List<TripEntry> entries = const [],
    List<TripCombo> combos = const [],
    List<TripCheck> checks = const [],
    this.homePlace,
    this.windowList = const [],
    this.discovered = const DiscoverResult(),
    this.failure,
  }) : tripList = [...trips],
       entryList = [...entries],
       comboList = [...combos],
       checkList = [...checks];

  final List<Trip> tripList;
  final List<TripEntry> entryList;
  final List<TripCombo> comboList;
  final List<TripCheck> checkList;

  /// The home place `home()` answers; `setHome` changes it.
  TripHome? homePlace;

  /// What `windows` answers, and the arguments it was asked with.
  List<TripWindow> windowList;
  final windowRequests = <TripWindowsArgs>[];

  /// What `discover` answers, and the arguments it was asked with.
  DiscoverResult discovered;
  final discoverRequests = <TripDiscoverArgs>[];

  /// When set, every call fails with it.
  Failure? failure;

  /// The `actor` of each write.
  final actors = <String?>[];

  /// What was written, for assertions.
  final savedTrips = <Trip>[];
  final patches = <({String id, Map<String, dynamic> changes})>[];
  final deletedTrips = <String>[];
  final savedEntries = <TripEntry>[];
  final deletedEntries = <String>[];
  final copiedEntries = <String>[];
  final imports = <({String tripId, List<TripEntry> entries})>[];
  final savedCombos = <TripCombo>[];
  final deletedCombos = <String>[];
  final chosenCombos = <({String id, bool setDates})>[];
  final savedChecks = <TripCheck>[];
  final addedChecks = <({String tripId, List<TripCheck> checks})>[];
  final copiedChecks = <({String from, String to})>[];
  final ticks = <({String id, bool done})>[];
  final deletedChecks = <String>[];
  final homes = <TripHome?>[];

  var _next = 0;

  Result<T> _fail<T>() => Err(failure!);

  Future<Result<T>> _ok<T>(String? actor, T Function() write) async {
    if (failure != null) return _fail();
    actors.add(actor);
    return Ok(write());
  }

  @override
  Future<Result<List<Trip>>> trips() async =>
      failure != null ? _fail() : Ok([...tripList]);

  @override
  Future<Result<List<TripEntry>>> entries() async =>
      failure != null ? _fail() : Ok([...entryList]);

  @override
  Future<Result<List<TripCombo>>> combos() async =>
      failure != null ? _fail() : Ok([...comboList]);

  @override
  Future<Result<List<TripCheck>>> checks() async =>
      failure != null ? _fail() : Ok([...checkList]);

  @override
  Future<Result<TripHome?>> home() async =>
      failure != null ? _fail() : Ok(homePlace);

  @override
  Future<Result<TripSaved>> saveTrip({
    required String? actor,
    required Trip trip,
  }) => _ok(actor, () {
    savedTrips.add(trip);
    final i = tripList.indexWhere((t) => t.id == trip.id);
    i >= 0 ? tripList[i] = trip : tripList.add(trip);
    return TripSaved(
      id: trip.id,
      eventId: trip.stage == TripStage.idea ? null : 'ev-${trip.id}',
    );
  });

  @override
  Future<Result<TripSaved>> patchTrip({
    required String? actor,
    required String id,
    required Map<String, dynamic> changes,
  }) => _ok(actor, () {
    patches.add((id: id, changes: changes));
    final i = tripList.indexWhere((t) => t.id == id);
    if (i >= 0) {
      tripList[i] = Trip.fromJson({
        ...tripList[i].toJson(),
        ...changes,
        'currency': tripList[i].currency,
      });
    }
    return TripSaved(id: id);
  });

  @override
  Future<Result<void>> deleteTrip({
    required String? actor,
    required String id,
  }) => _ok(actor, () {
    deletedTrips.add(id);
    tripList.removeWhere((t) => t.id == id);
    entryList.removeWhere((e) => e.tripId == id);
    comboList.removeWhere((c) => c.tripId == id);
    checkList.removeWhere((c) => c.tripId == id);
  });

  @override
  Future<Result<String>> saveEntry({
    required String? actor,
    required TripEntry entry,
  }) => _ok(actor, () {
    savedEntries.add(entry);
    final i = entryList.indexWhere((e) => e.id == entry.id);
    i >= 0 ? entryList[i] = entry : entryList.add(entry);
    return entry.id;
  });

  @override
  Future<Result<void>> deleteEntry({
    required String? actor,
    required String id,
  }) => _ok(actor, () {
    deletedEntries.add(id);
    entryList.removeWhere((e) => e.id == id);
  });

  @override
  Future<Result<String>> copyEntry({
    required String? actor,
    required String id,
  }) => _ok(actor, () {
    copiedEntries.add(id);
    final copy = 'copy-${++_next}';
    final i = entryList.indexWhere((e) => e.id == id);
    if (i >= 0) {
      entryList.insert(
        i + 1,
        entryList[i].copyWith(
          id: copy,
          state: EntryState.option,
          bookingRef: null,
          sourceUid: null,
        ),
      );
    }
    return copy;
  });

  @override
  Future<Result<EntriesImported>> importEntries({
    required String? actor,
    required String tripId,
    required List<TripEntry> entries,
  }) => _ok(actor, () {
    imports.add((tripId: tripId, entries: entries));
    var added = 0;
    var updated = 0;
    for (final e in entries) {
      final i = entryList.indexWhere(
        (x) =>
            x.tripId == tripId &&
            e.sourceUid != null &&
            x.sourceUid == e.sourceUid,
      );
      if (i >= 0) {
        entryList[i] = e.copyWith(id: entryList[i].id);
        updated++;
      } else {
        entryList.add(e);
        added++;
      }
    }
    return EntriesImported(added: added, updated: updated);
  });

  @override
  Future<Result<String>> saveCombo({
    required String? actor,
    required TripCombo combo,
  }) => _ok(actor, () {
    savedCombos.add(combo);
    final i = comboList.indexWhere((c) => c.id == combo.id);
    i >= 0 ? comboList[i] = combo : comboList.add(combo);
    return combo.id;
  });

  @override
  Future<Result<void>> deleteCombo({
    required String? actor,
    required String id,
  }) => _ok(actor, () {
    deletedCombos.add(id);
    comboList.removeWhere((c) => c.id == id);
  });

  /// What `chooseCombo` answers; the entries are not changed, tests that need that seed
  /// them.
  ComboChoice choice = const ComboChoice(
    chosen: 0,
    released: 0,
    datesSet: false,
  );

  @override
  Future<Result<ComboChoice>> chooseCombo({
    required String? actor,
    required String id,
    bool setDates = false,
  }) => _ok(actor, () {
    chosenCombos.add((id: id, setDates: setDates));
    return choice;
  });

  @override
  Future<Result<String>> saveCheck({
    required String? actor,
    required TripCheck check,
  }) => _ok(actor, () {
    savedChecks.add(check);
    final i = checkList.indexWhere((c) => c.id == check.id);
    i >= 0 ? checkList[i] = check : checkList.add(check);
    return check.id;
  });

  @override
  Future<Result<int>> addChecks({
    required String? actor,
    required String tripId,
    required List<TripCheck> checks,
  }) => _ok(actor, () {
    addedChecks.add((tripId: tripId, checks: checks));
    checkList.addAll(checks);
    return checks.length;
  });

  @override
  Future<Result<int>> copyChecks({
    required String? actor,
    required String from,
    required String to,
  }) => _ok(actor, () {
    copiedChecks.add((from: from, to: to));
    return 0;
  });

  @override
  Future<Result<void>> tickCheck({
    required String? actor,
    required String id,
    required bool done,
  }) => _ok(actor, () {
    ticks.add((id: id, done: done));
    final i = checkList.indexWhere((c) => c.id == id);
    if (i >= 0) {
      final c = checkList[i];
      checkList[i] = TripCheck(
        id: c.id,
        tripId: c.tripId,
        kind: c.kind,
        title: c.title,
        profileId: c.profileId,
        dueDaysBefore: c.dueDaysBefore,
        doneAt: done ? DateTime(2026, 11, 15) : null,
        doneBy: done ? actor : null,
        position: c.position,
      );
    }
  });

  @override
  Future<Result<void>> deleteCheck({
    required String? actor,
    required String id,
  }) => _ok(actor, () {
    deletedChecks.add(id);
    checkList.removeWhere((c) => c.id == id);
  });

  @override
  Future<Result<void>> setHome({
    required String? actor,
    required TripHome? home,
  }) => _ok(actor, () {
    homes.add(home);
    homePlace = home;
  });

  @override
  Future<Result<List<TripWindow>>> windows(TripWindowsArgs args) async {
    windowRequests.add(args);
    return failure != null ? _fail() : Ok([...windowList]);
  }

  @override
  Future<Result<DiscoverResult>> discover({
    required String? actor,
    required TripDiscoverArgs args,
  }) async {
    discoverRequests.add(args);
    return failure != null ? _fail() : Ok(discovered);
  }
}

/// The opt-in services in memory, for widget tests. Seed [catalogueList], [states] and
/// the answers; every call is recorded. A capability whose answer is null fails with
/// `service_off`, as the server does when no provider is on.
class FakeServicesRepository implements ServicesRepository {
  FakeServicesRepository({
    this.catalogueList = const [],
    List<ServiceProviderState> states = const [],
    this.geocodeResult,
    this.forecastResult,
    this.climateResult,
    this.routeResult,
    this.mapResult,
    this.testResult = const ServiceTestResult(ok: true),
    this.failure,
  }) : stateList = [...states];

  List<ServiceProviderInfo> catalogueList;
  final List<ServiceProviderState> stateList;
  GeocodeResult? geocodeResult;
  Forecast? forecastResult;
  Climate? climateResult;
  RouteInfo? routeResult;
  MapPicture? mapResult;
  ServiceTestResult testResult;

  /// When set, every call fails with it.
  Failure? failure;

  final setCalls =
      <
        ({
          String provider,
          bool? enabled,
          List<ServiceCapability>? capabilities,
          int? position,
          String? key,
        })
      >[];
  final tested = <String>[];
  final geocoded = <({String q, String? lang})>[];
  final forecasts = <({double lat, double lon})>[];
  final climates = <({double lat, double lon})>[];
  final routes =
      <({double fromLat, double fromLon, double toLat, double toLon})>[];
  final maps = <({double lat, double lon, int width, int height, int? zoom})>[];

  Result<T> _answer<T>(T? value) {
    if (failure != null) return Err(failure!);
    return value == null
        ? const Err(ConflictFailure(code: 'service_off'))
        : Ok(value);
  }

  @override
  Future<Result<List<ServiceProviderInfo>>> catalogue() async =>
      failure != null ? Err(failure!) : Ok(catalogueList);

  @override
  Future<Result<List<ServiceProviderState>>> providers() async =>
      failure != null ? Err(failure!) : Ok([...stateList]);

  @override
  Future<Result<void>> setProvider({
    required String? actor,
    required String provider,
    bool? enabled,
    List<ServiceCapability>? capabilities,
    int? position,
    String? key,
  }) async {
    if (failure != null) return Err(failure!);
    setCalls.add((
      provider: provider,
      enabled: enabled,
      capabilities: capabilities,
      position: position,
      key: key,
    ));
    final i = stateList.indexWhere((s) => s.provider == provider);
    final old = i >= 0 ? stateList[i] : null;
    final hasKey = key == null ? old?.hasKey ?? false : key.isNotEmpty;
    final next = ServiceProviderState(
      provider: provider,
      enabled: enabled ?? old?.enabled ?? false,
      capabilities: capabilities ?? old?.capabilities ?? const [],
      position: position ?? old?.position ?? stateList.length,
      hasKey: hasKey,
      keyHint: hasKey ? '…${key ?? old?.keyHint ?? ''}' : null,
    );
    i >= 0 ? stateList[i] = next : stateList.add(next);
    return const Ok(null);
  }

  @override
  Future<Result<ServiceTestResult>> test({
    required String provider,
    String? actor,
  }) async {
    tested.add(provider);
    return failure != null ? Err(failure!) : Ok(testResult);
  }

  @override
  Future<Result<GeocodeResult>> geocode({
    required String q,
    String? lang,
    String? actor,
  }) async {
    geocoded.add((q: q, lang: lang));
    return _answer(geocodeResult);
  }

  @override
  Future<Result<Forecast>> forecast({
    required double lat,
    required double lon,
    String? actor,
  }) async {
    forecasts.add((lat: lat, lon: lon));
    return _answer(forecastResult);
  }

  @override
  Future<Result<Climate>> climate({
    required double lat,
    required double lon,
    String? actor,
  }) async {
    climates.add((lat: lat, lon: lon));
    return _answer(climateResult);
  }

  @override
  Future<Result<RouteInfo>> route({
    required ({double lat, double lon}) from,
    required ({double lat, double lon}) to,
    String? actor,
  }) async {
    routes.add((
      fromLat: from.lat,
      fromLon: from.lon,
      toLat: to.lat,
      toLon: to.lon,
    ));
    return _answer(routeResult);
  }

  @override
  Future<Result<MapPicture>> map({
    required double lat,
    required double lon,
    int? zoom,
    required int width,
    required int height,
    String? actor,
  }) async {
    maps.add((lat: lat, lon: lon, width: width, height: height, zoom: zoom));
    return _answer(mapResult);
  }
}
