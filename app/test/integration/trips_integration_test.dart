@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/services/data/services_repository.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';
import 'package:wuselwall/features/trips/data/trips_repository.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// Family trips and the opt-in services (specs/30, ADR-023) against a real backend,
/// through the app's own repositories (so the Dart wire format is proven as well):
/// `flutter test test/integration --dart-define-from-file=env/ci.json` on a throwaway stack
/// (CI's `backend` job starts one; locally `npx supabase start`).
///
/// THIS TEST CONTACTS NO THIRD PARTY. A provider (Open-Meteo, MET Norway, Nominatim,
/// OpenWeatherMap, ...) is only ever asked by the `services` and `trips` Edge Functions, and
/// only for a capability that an *enabled* provider of the household offers. The test
///   * never enables a keyless provider (`open-meteo`, `met-no`, `nominatim`);
///   * enables only `openweathermap`, with a made-up key, and only for `forecast`, a
///     capability it never asks for (no `forecast`, `climate`, `route`, `map` or `test`
///     call is made anywhere in this file);
///   * asks `discover` (climate) and `geocode` while no enabled provider offers those
///     capabilities, so the answer is the bundled catalogue and `service_off`, produced by the
///     database door (`api.service_request`) and the runner before any fetch.
/// Every provider it touched is switched off and its key removed when the test ends.
///
/// Two tests, both founding or re-entering the one household of the stack the way
/// identity_shopping_integration_test.dart does (the seed's "dev-setup" token, else the
/// guardian just signs in):
///   * the database round trip: trips, the calendar entry, entries, combinations, checks, the
///     home place, the service settings and their secrecy, a child's refusals (api functions and
///     views only, so it needs nothing but PostgREST);
///   * the Edge Functions `occurrences`, `search`, `services` and `trips`. CI's stack serves every
///     function of supabase/functions (`supabase start` starts the edge runtime; backend-ci.yml
///     excludes only studio, imgproxy, logflare and vector), so it runs by default. A stack that
///     does not serve them skips just this test: `--dart-define=WW_EDGE_FUNCTIONS=false`.
///
/// Idempotent on a database that already has the household: every trip it makes is deleted
/// when the test ends, the home place is forgotten and the providers are switched off.
void main() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const edgeFunctions = bool.fromEnvironment(
    'WW_EDGE_FUNCTIONS',
    defaultValue: true,
  );
  // It creates trips, members and devices: throwaway stacks only (CI, or a local
  // `supabase start`), never the family's environment (ADR-013).
  final host = Uri.tryParse(url)?.host;
  final skip = url.isEmpty
      ? 'no backend configured (SUPABASE_URL)'
      : !{'127.0.0.1', 'localhost'}.contains(host)
      ? 'refusing to run against $host: throwaway stacks only (ADR-013)'
      : null;
  final edgeSkip =
      skip ??
      (edgeFunctions
          ? null
          : 'Edge Functions are not served by this stack '
                '(--dart-define=WW_EDGE_FUNCTIONS=false)');

  // The guardian of identity_shopping_integration_test.dart.
  const email = 'papa@example.org';
  const password = 'correct-horse-battery';
  const pin = '123456';

  setUpAll(() => HttpOverrides.global = null);

  final stamp = DateTime.now().millisecondsSinceEpoch;
  const uuid = Uuid();

  // Dates 200 days ahead, so no rule about the past can matter whenever CI runs.
  final today = DateTime.now();

  /// The local date [n] days from that day.
  DateTime day(int n) => DateTime(today.year, today.month, today.day + 200 + n);

  _Phone newPhone() {
    final client = SupabaseClient(
      url,
      key,
      postgrestOptions: const PostgrestClientOptions(schema: 'api'),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    return _Phone(client);
  }

  Future<DeviceInfo> ensureDevice(IdentityRepository repo, String label) async {
    final existing = (await repo.currentDevice()).unwrap();
    if (existing != null) return existing;
    expect((await repo.myProfile()).unwrap(), isNotNull);
    return (await repo.registerPersonalDevice(label)).unwrap();
  }

  /// The guardian's personal phone in the stack's one household.
  Future<(_Phone, DeviceInfo)> guardianPhone() async {
    final phone = newPhone();
    final setup = await phone.identity.setupHousehold(
      token: 'dev-setup',
      householdName: 'Haus Wusel',
      displayName: 'Papa',
      email: email,
      password: password,
      pin: pin,
      colorHex: '#2E7D6B',
    );
    if (setup case Err(:final failure)) {
      expect(
        failure.code,
        'setup_closed',
        reason: 'only "already set up" is acceptable',
      );
      expect((await phone.identity.signIn(email, password)).isOk, isTrue);
    }
    final device = await ensureDevice(phone.identity, 'Papas Handy $stamp');
    expect(device.deviceClass, DeviceClass.personal);
    expect(device.profileId, isNotNull);
    return (phone, device);
  }

  /// A child and a shared device (the iPad of the kid register) enrolled for it: what a
  /// child's tablet is. Returns the iPad and the child's profile id.
  Future<(_Phone, String)> kidsIpad(_Phone guardian) async {
    final name = 'Kind ${DateTime.now().microsecondsSinceEpoch}';
    await guardian.identity
        .addMember(actor: null, name: name, colorHex: '#FF8800')
        .must('add a member');
    final added = (await guardian.identity.members().must('list the members'))
        .firstWhere((m) => m.displayName == name);
    await guardian.identity
        .updateMember(actor: null, profileId: added.id, isChild: true)
        .must('make the member a child');
    final code = await guardian.identity
        .createEnrolmentCode(
          actor: null,
          label: 'iPad $name',
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
        )
        .must('create an enrolment code');
    final ipad = newPhone();
    await ipad.identity.enrolDevice(code.code).must('enrol the iPad');
    final device = (await ipad.identity.currentDevice().must('read the iPad'))!;
    expect(device.deviceClass, DeviceClass.shared);
    addTearDown(
      () => guardian.identity.revokeDevice(
        actor: null,
        deviceId: device.deviceId,
      ),
    );
    return (ipad, added.id);
  }

  /// The trip is removed when the test ends, with its entries, combinations, checks and its
  /// calendar entry.
  void deleteAfter(_Phone phone, String tripId) =>
      addTearDown(() => phone.trips.deleteTrip(actor: null, id: tripId));

  /// Leaves the household as found: no home place, every provider off and without a key.
  void tidyAfter(_Phone phone) => addTearDown(() async {
    await phone.trips.setHome(actor: null, home: null);
    for (final id in const ['openweathermap']) {
      await phone.services.setProvider(
        actor: null,
        provider: id,
        enabled: false,
        capabilities: const [],
        key: '',
      );
    }
  });

  test(
    'trips in the database: the idea, the calendar entry, entries, combinations, checks, '
    'the home place, the service settings and a child',
    () async {
      final (phone, device) = await guardianPhone();
      final me = device.profileId!;
      final trips = phone.trips;
      tidyAfter(phone);

      // --- the server announces both ---------------------------------------------------
      final info = await phone.api
          .rpc<Map<String, dynamic>>(
            'server_info',
            parse: (json) => Map<String, dynamic>.from(json! as Map),
          )
          .must('read server_info');
      expect(info['features'], containsAll(<String>['trips', 'services']));

      Future<Trip> tripOf(String id) async =>
          (await trips.trips().must('read the trips'))
              .firstWhere((t) => t.id == id);
      Future<List<TripEntry>> entriesOf(String tripId) async =>
          (await trips.entries().must('read the entries'))
              .where((e) => e.tripId == tripId)
              .toList();
      Future<List<TripCheck>> checksOf(String tripId) async =>
          (await trips.checks().must('read the checks'))
              .where((c) => c.tripId == tripId)
              .toList();
      Future<CalendarEvent> eventOf(String eventId) =>
          phone.calendar.event(eventId).must('read the calendar entry');

      // --- an idea, read back with the currency the server chose ----------------------
      final ibizaId = uuid.v7();
      final ibiza = Trip(
        id: ibizaId,
        title: 'Ibiza $stamp',
        destinationName: 'Ibiza',
        country: 'ES',
        lat: 38.91,
        lon: 1.43,
        note: 'warm',
      );
      final idea = await trips
          .saveTrip(actor: null, trip: ibiza)
          .must('save the idea');
      deleteAfter(phone, ibizaId);
      expect(idea.id, ibizaId);
      expect(idea.eventId, isNull, reason: 'an idea has no calendar entry');
      var trip = await tripOf(ibizaId);
      expect(trip.stage, TripStage.idea);
      expect(trip.title, 'Ibiza $stamp');
      expect(trip.destinationName, 'Ibiza');
      expect(trip.country, 'ES');
      expect(trip.lat, closeTo(38.91, 1e-9));
      expect(trip.lon, closeTo(1.43, 1e-9));
      expect(trip.note, 'warm');
      expect(trip.wholeFamily, isTrue);
      expect(trip.hasDates, isFalse);
      expect(trip.eventId, isNull);
      expect(trip.createdAt, isNotNull);
      expect(trip.currency, matches(RegExp(r'^[A-Z]{3}$')));

      // The same id again is the same trip.
      await trips.saveTrip(actor: null, trip: ibiza).must('save it again');
      expect(
        (await trips.trips().must('read the trips'))
            .where((t) => t.id == ibizaId),
        hasLength(1),
      );

      // A second idea, the target of "wie letztes Mal" below.
      final sardId = uuid.v7();
      await trips
          .saveTrip(
            actor: null,
            trip: Trip(
              id: sardId,
              title: 'Sardinien $stamp',
              destinationName: 'Sardinien',
              country: 'IT',
              lat: 40.1,
              lon: 9.0,
            ),
          )
          .must('save the second idea');
      deleteAfter(phone, sardId);

      // --- planned: one tentative all-day entry in the calendar ---------------------------
      final planned = await trips
          .patchTrip(
            actor: null,
            id: ibizaId,
            changes: {
              'stage': 'planned',
              'starts_on': isoDate(day(0)),
              'ends_on': isoDate(day(14)),
            },
          )
          .must('plan the trip');
      expect(planned.id, ibizaId);
      expect(planned.eventId, isNotNull);
      final eventId = planned.eventId!;
      trip = await tripOf(ibizaId);
      expect(trip.stage, TripStage.planned);
      expect((trip.startsOn, trip.endsOn), (day(0), day(14)));
      expect(trip.eventId, eventId);
      expect(trip.destinationName, 'Ibiza', reason: 'a patch keeps the rest');

      var event = await eventOf(eventId);
      expect(event.tripId, ibizaId);
      expect(event.kind, EventKind.appointment);
      expect(event.title, 'Ibiza $stamp');
      expect(event.status, EventStatus.tentative);
      expect(event.isAllDay, isTrue);
      expect((event.startDate, event.endDate), (day(0), day(14)));
      expect(event.countdown, isFalse);

      // --- fixed: confirmed, counting down, a key appointment --------------------------------
      final fixed = await trips
          .patchTrip(actor: null, id: ibizaId, changes: {'stage': 'fixed'})
          .must('fix the trip');
      expect(fixed.eventId, eventId, reason: 'the same entry');
      event = await eventOf(eventId);
      expect(event.status, EventStatus.confirmed);
      expect(event.countdown, isTrue);
      expect(event.importance, Importance.key);
      expect((event.startDate, event.endDate), (day(0), day(14)));

      // --- the calendar does not change a trip's entry -----------------------------------------
      expect(
        await outcome(
          phone.calendar.save(
            actor: null,
            event: CalendarEvent(
              id: eventId,
              title: 'Umbenannt',
              kind: EventKind.appointment,
              isAllDay: true,
              startDate: day(0),
              endDate: day(14),
            ),
          ),
        ),
        'trip_event',
      );
      expect(
        await outcome(phone.calendar.delete(actor: null, id: eventId)),
        'trip_event',
      );
      expect((await eventOf(eventId)).title, 'Ibiza $stamp');

      // --- entries: a flight, two stays and a rental -------------------------------------------
      final flightId = uuid.v7();
      final flight = TripEntry(
        id: flightId,
        tripId: ibizaId,
        kind: EntryKind.transport,
        mode: TransportMode.flight,
        title: 'ZRH-IBZ',
        priceCents: 84000,
        fromPlace: 'ZRH',
        toPlace: 'IBZ',
        startsOn: day(1),
        startsTime: const TimeOfDay(hour: 10, minute: 40),
        endsOn: day(1),
        endsTime: const TimeOfDay(hour: 12, minute: 55),
        url: 'https://air.example/x?a=1',
        details: 'direct',
        bookingRef: 'ABC123',
        sourceUid: 'uid-flight-$stamp',
      );
      final stay1Id = uuid.v7();
      final stay2Id = uuid.v7();
      final rentalId = uuid.v7();
      final saves = [
        flight,
        TripEntry(
          id: stay1Id,
          tripId: ibizaId,
          kind: EntryKind.stay,
          title: 'Finca',
          priceCents: 250000,
          address: 'Calle 1',
          startsOn: day(1),
          endsOn: day(8),
        ),
        TripEntry(
          id: stay2Id,
          tripId: ibizaId,
          kind: EntryKind.stay,
          title: 'Hotel Playa',
          state: EntryState.chosen,
          priceCents: 180000,
          startsOn: day(3),
          endsOn: day(10),
        ),
        TripEntry(
          id: rentalId,
          tripId: ibizaId,
          kind: EntryKind.rental,
          title: 'Fiat 500',
          priceCents: 40000,
          startsOn: day(1),
          endsOn: day(8),
        ),
      ];
      for (final e in saves) {
        expect(
          await trips.saveEntry(actor: null, entry: e).must('save ${e.title}'),
          e.id,
        );
      }
      var entries = await entriesOf(ibizaId);
      expect(entries, hasLength(4));
      TripEntry entry(String id) => entries.firstWhere((e) => e.id == id);
      final flightBack = entry(flightId);
      expect(flightBack.kind, EntryKind.transport);
      expect(flightBack.mode, TransportMode.flight);
      expect(flightBack.state, EntryState.option);
      expect(flightBack.title, 'ZRH-IBZ');
      expect(flightBack.priceCents, 84000);
      expect(flightBack.url, 'https://air.example/x?a=1');
      expect(flightBack.details, 'direct');
      expect((flightBack.fromPlace, flightBack.toPlace), ('ZRH', 'IBZ'));
      expect(flightBack.startsOn, day(1));
      expect(flightBack.startsTime, const TimeOfDay(hour: 10, minute: 40));
      expect(flightBack.endsTime, const TimeOfDay(hour: 12, minute: 55));
      expect(flightBack.bookingRef, 'ABC123');
      for (final id in [flightId, stay1Id, stay2Id, rentalId]) {
        expect(
          entry(id).priceCheckedOn,
          isNotNull,
          reason: 'the server dates a price it is given (${entry(id).title})',
        );
      }
      expect(entry(stay1Id).mode, isNull);
      expect(entry(stay1Id).nights, 7);
      expect(entry(stay2Id).state, EntryState.chosen);
      expect(entry(rentalId).kind, EntryKind.rental);

      // A copy is an option without reference and source, right after the original.
      final copyId = await trips
          .copyEntry(actor: null, id: flightId)
          .must('copy the flight');
      expect(copyId, isNot(flightId));
      entries = await entriesOf(ibizaId);
      final copy = entry(copyId);
      expect(copy.title, 'ZRH-IBZ');
      expect(copy.state, EntryState.option);
      expect(copy.bookingRef, isNull);
      expect(copy.sourceUid, isNull);
      expect(copy.position, entry(flightId).position + 1);
      expect(copy.priceCents, 84000);
      await trips.deleteEntry(actor: null, id: copyId).must('delete the copy');
      expect((await entriesOf(ibizaId)).any((e) => e.id == copyId), isFalse);

      // The same calendar file twice: added, then updated.
      final fileUid = 'ics-$stamp';
      TripEntry concert(String title) => TripEntry(
        id: uuid.v7(),
        tripId: ibizaId,
        kind: EntryKind.activity,
        title: title,
        sourceUid: fileUid,
        startsOn: day(2),
        startsTime: const TimeOfDay(hour: 20, minute: 0),
      );
      final first = await trips
          .importEntries(
            actor: null,
            tripId: ibizaId,
            entries: [concert('Konzert')],
          )
          .must('import the file');
      expect((first.added, first.updated), (1, 0));
      final second = await trips
          .importEntries(
            actor: null,
            tripId: ibizaId,
            entries: [concert('Konzert (neu)')],
          )
          .must('import the file again');
      expect((second.added, second.updated), (0, 1));
      entries = await entriesOf(ibizaId);
      final imported = entries.where((e) => e.sourceUid == fileUid).toList();
      expect(imported, hasLength(1));
      expect(imported.single.title, 'Konzert (neu)');
      expect(imported.single.kind, EntryKind.activity);

      // --- a combination: flight + one stay + the rental, taken ----------------------------------
      final comboId = uuid.v7();
      expect(
        await trips
            .saveCombo(
              actor: null,
              combo: TripCombo(
                id: comboId,
                tripId: ibizaId,
                name: 'Guenstig',
                entryIds: [flightId, stay1Id, rentalId],
              ),
            )
            .must('save the combination'),
        comboId,
      );
      final combo = (await trips.combos().must('read the combinations'))
          .firstWhere((c) => c.id == comboId);
      expect(combo.tripId, ibizaId);
      expect(combo.name, 'Guenstig');
      expect(combo.entryIds, unorderedEquals([flightId, stay1Id, rentalId]));

      final choice = await trips
          .chooseCombo(actor: null, id: comboId, setDates: true)
          .must('take the combination');
      expect(choice.chosen, 3);
      expect(choice.released, 1, reason: 'the other chosen stay');
      expect(choice.datesSet, isTrue);
      entries = await entriesOf(ibizaId);
      expect(entry(flightId).state, EntryState.chosen);
      expect(entry(stay1Id).state, EntryState.chosen);
      expect(entry(rentalId).state, EntryState.chosen);
      expect(entry(stay2Id).state, EntryState.option);
      expect(
        entries.firstWhere((e) => e.sourceUid == fileUid).state,
        EntryState.option,
        reason: 'an activity is never released or chosen by a combination',
      );
      trip = await tripOf(ibizaId);
      expect((trip.startsOn, trip.endsOn), (day(1), day(8)));
      expect(trip.stage, TripStage.fixed, reason: 'the stage stays');
      event = await eventOf(eventId);
      expect((event.startDate, event.endDate), (day(1), day(8)));
      expect(event.status, EventStatus.confirmed);
      final again = await trips
          .chooseCombo(actor: null, id: comboId)
          .must('take it again');
      expect((again.chosen, again.released, again.datesSet), (0, 0, false));

      // --- checks: the packing list and to-dos -----------------------------------------------------
      final passId = uuid.v7();
      await trips
          .saveCheck(
            actor: null,
            check: TripCheck(
              id: passId,
              tripId: ibizaId,
              kind: CheckKind.pack,
              title: 'Reisepaesse',
            ),
          )
          .must('save a check');
      final added = await trips
          .addChecks(
            actor: null,
            tripId: ibizaId,
            checks: [
              TripCheck(
                id: uuid.v7(),
                tripId: ibizaId,
                kind: CheckKind.pack,
                title: 'Reisepaesse',
              ),
              TripCheck(
                id: uuid.v7(),
                tripId: ibizaId,
                kind: CheckKind.pack,
                title: 'Sonnencreme',
                profileId: me,
              ),
              TripCheck(
                id: uuid.v7(),
                tripId: ibizaId,
                kind: CheckKind.todo,
                title: 'Nachbarn fragen',
                dueDaysBefore: 14,
              ),
            ],
          )
          .must('add the checks');
      expect(added, 2, reason: 'a title the trip has is skipped');
      var checks = await checksOf(ibizaId);
      expect(checks, hasLength(3));
      final todo = checks.firstWhere((c) => c.kind == CheckKind.todo);
      expect(todo.title, 'Nachbarn fragen');
      expect(todo.dueDaysBefore, 14);
      expect(todo.dueOn(await tripOf(ibizaId)), day(1 - 14));
      expect(checks.firstWhere((c) => c.title == 'Sonnencreme').profileId, me);
      expect(checks.every((c) => !c.done), isTrue);

      await trips
          .tickCheck(actor: null, id: passId, done: true)
          .must('tick a check');
      checks = await checksOf(ibizaId);
      final ticked = checks.firstWhere((c) => c.id == passId);
      expect(ticked.done, isTrue);
      expect(ticked.doneBy, me);

      final copied = await trips
          .copyChecks(actor: null, from: ibizaId, to: sardId)
          .must('copy the checks');
      expect(copied, 3);
      final sardChecks = await checksOf(sardId);
      expect(
        sardChecks.map((c) => c.title),
        unorderedEquals(checks.map((c) => c.title)),
      );
      expect(sardChecks.every((c) => !c.done), isTrue, reason: 'unticked');
      expect(
        await trips
            .copyChecks(actor: null, from: ibizaId, to: sardId)
            .must('copy them again'),
        0,
      );
      await trips
          .tickCheck(actor: null, id: passId, done: false)
          .must('untick');
      expect(
        (await checksOf(ibizaId)).firstWhere((c) => c.id == passId).done,
        isFalse,
      );

      // --- the home place: a guardian sets it, the server rounds it -----------------------------------
      await trips
          .setHome(
            actor: null,
            home: const TripHome(name: 'Zuhause', lat: 47.3769, lon: 8.5417),
          )
          .must('set the home place');
      var home = (await trips.home().must('read the home place'))!;
      expect(home.name, 'Zuhause');
      expect(home.lat, closeTo(47.38, 1e-9));
      expect(home.lon, closeTo(8.54, 1e-9));
      // The repository rounds before it sends; the server does too.
      await phone.api
          .rpc<void>(
            'trip_home_set',
            params: {
              'p_actor': null,
              'p_home': {'name': 'Zuhause', 'lat': 47.3769, 'lon': 8.5412},
            },
            parse: (_) {},
          )
          .must('set an unrounded home place');
      home = (await trips.home().must('read the home place'))!;
      expect(home.lat, closeTo(47.38, 1e-9));
      expect(home.lon, closeTo(8.54, 1e-9));
      expect(home.updatedAt, isNotNull);
      await trips.setHome(actor: null, home: null).must('forget the home');
      expect(await trips.home().must('read the home place'), isNull);

      // --- the service settings: a key goes in and is never read back -----------------------------------
      // The catalogue is the server's own (the Edge Function answers it below); a provider
      // that no Edge Function is asked about is only a row here.
      expect(
        (await phone.services.providers().must('read the providers'))
            .where((p) => p.enabled),
        isEmpty,
        reason: 'nothing is on until a guardian switches it on',
      );
      const secret = 'test-key-123456';
      await phone.services
          .setProvider(
            actor: null,
            provider: 'openweathermap',
            enabled: true,
            capabilities: [ServiceCapability.forecast],
            key: secret,
          )
          .must('switch a provider on');
      final state = (await phone.services.providers().must(
        'read the providers',
      )).singleWhere((p) => p.provider == 'openweathermap');
      expect(state.enabled, isTrue);
      expect(state.capabilities, [ServiceCapability.forecast]);
      expect(state.hasKey, isTrue);
      expect(state.keyHint, endsWith('3456'));
      expect(state.lastError, isNull);
      expect(state.callsToday, 0, reason: 'nothing was asked of it');
      final rows = await phone.api
          .select<Map<String, dynamic>>(
            'service_providers',
            parse: (row) => row,
          )
          .must('read the provider rows');
      expect(
        jsonEncode(rows),
        isNot(contains(secret)),
        reason: 'no field of the view holds the key',
      );
      for (final name in const [
        'service_secret',
        'service_secrets',
        'service_cache',
      ]) {
        expect(
          (await phone.api.select<Map<String, dynamic>>(
            name,
            parse: (row) => row,
          )).isOk,
          isFalse,
          reason: 'api.$name must not be readable',
        );
      }
      for (final call in <(String, Map<String, dynamic>)>[
        ('service_secrets', {'p_household': device.householdId}),
        ('service_cache_get', {'p_keys': <String>[]}),
      ]) {
        expect(
          (await phone.api.rpc<Object?>(
            call.$1,
            params: call.$2,
            parse: (json) => json,
          )).isOk,
          isFalse,
          reason: 'api.${call.$1} is for the service role only',
        );
      }
      await phone.services
          .setProvider(
            actor: null,
            provider: 'openweathermap',
            enabled: false,
            capabilities: const [],
            key: '',
          )
          .must('switch it off again');
      final off = (await phone.services.providers().must('read the providers'))
          .singleWhere((p) => p.provider == 'openweathermap');
      expect((off.enabled, off.hasKey, off.keyHint), (false, false, null));
      expect(off.capabilities, isEmpty);

      // --- a child's iPad reads, and changes nothing --------------------------------------------------------
      final (ipad, kidId) = await kidsIpad(phone);
      expect(
        (await ipad.trips.trips().must('read the trips as a child'))
            .any((t) => t.id == ibizaId),
        isTrue,
      );
      expect(
        await outcome(
          ipad.trips.saveTrip(
            actor: kidId,
            trip: Trip(id: uuid.v7(), title: 'Kinderreise'),
          ),
        ),
        'adults_only',
      );
      expect(
        await outcome(
          ipad.trips.patchTrip(
            actor: kidId,
            id: ibizaId,
            changes: {'title': 'Kinderreise'},
          ),
        ),
        'adults_only',
      );
      expect(
        await outcome(ipad.trips.deleteTrip(actor: kidId, id: ibizaId)),
        'adults_only',
      );
      expect(
        await outcome(
          ipad.trips.tickCheck(actor: kidId, id: passId, done: true),
        ),
        'adults_only',
      );
      expect(
        await outcome(
          ipad.services.setProvider(
            actor: kidId,
            provider: 'openweathermap',
            enabled: true,
            capabilities: [ServiceCapability.forecast],
          ),
        ),
        'adults_only',
      );
      expect(
        (await ipad.trips.trips().must('read the trips'))
            .firstWhere((t) => t.id == ibizaId)
            .title,
        'Ibiza $stamp',
        reason: 'and the trip is as it was',
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 180)),
  );

  test(
    'the Edge Functions: occurrences and search with a trip, windows, discovery without a '
    'provider, the catalogue, a geocode that no provider answers',
    () async {
      final (phone, device) = await guardianPhone();
      final me = device.profileId!;
      tidyAfter(phone);

      // --- the catalogue: seven providers, one keyless for weather --------------------------------------
      final catalogue = await phone.services.catalogue().must(
        'read the catalogue',
      );
      final byId = {for (final p in catalogue) p.id: p};
      expect(
        byId.keys,
        unorderedEquals(<String>[
          'open-meteo',
          'met-no',
          'nominatim',
          'openweathermap',
          'meteostat',
          'openrouteservice',
          'google',
        ]),
      );
      final openMeteo = byId['open-meteo']!;
      expect(openMeteo.needsKey, isFalse);
      expect(openMeteo.cost, ServiceCost.free);
      expect(openMeteo.keyUrl, isNull);
      expect(
        openMeteo.capabilities,
        containsAll([
          ServiceCapability.climate,
          ServiceCapability.forecast,
          ServiceCapability.geocode,
        ]),
      );
      expect(openMeteo.attribution, isNotEmpty);
      expect(byId['met-no']!.needsKey, isFalse);
      expect(byId['nominatim']!.needsKey, isFalse);
      final owm = byId['openweathermap']!;
      expect(owm.needsKey, isTrue);
      expect(owm.cost, ServiceCost.freeKey);
      expect(owm.offers(ServiceCapability.forecast), isTrue);
      expect(owm.receives, isNotEmpty);
      expect(byId['google']!.cost, ServiceCost.paidKey);
      expect(byId['google']!.offers(ServiceCapability.map), isTrue);
      expect(
        (await phone.services.providers().must('read the providers'))
            .where((p) => p.enabled),
        isEmpty,
        reason: 'nothing is on: every call below stays inside the server',
      );

      // --- a fixed trip and an idea with a place, for the calendar and the discovery -----------------------
      final tripId = uuid.v7();
      final saved = await phone.trips
          .saveTrip(
            actor: null,
            trip: Trip(
              id: tripId,
              title: 'Edge $stamp',
              stage: TripStage.fixed,
              startsOn: day(0),
              endsOn: day(3),
            ),
          )
          .must('save a fixed trip');
      deleteAfter(phone, tripId);
      expect(saved.eventId, isNotNull);
      final ideaId = uuid.v7();
      await phone.trips
          .saveTrip(
            actor: null,
            trip: Trip(
              id: ideaId,
              title: 'Sardinien $stamp',
              destinationName: 'Sardinien Edge $stamp',
              country: 'IT',
              lat: 40.1,
              lon: 9.0,
            ),
          )
          .must('save an idea with a place');
      deleteAfter(phone, ideaId);

      // --- the `occurrences` function names the trip --------------------------------------------------------
      final window = await phone.calendar
          .occurrences(day(-2), day(5))
          .must('read the occurrences');
      final mine = window.occurrences.where((o) => o.tripId == tripId).toList();
      expect(mine, hasLength(1));
      final occurrence = mine.single;
      expect(occurrence.eventId, saved.eventId);
      expect(occurrence.title, 'Edge $stamp');
      expect(occurrence.allDay, isTrue);
      expect(
        (occurrence.localStartDate, occurrence.localEndDate),
        (day(0), day(3)),
      );
      expect(occurrence.status, EventStatus.confirmed);
      expect(occurrence.countdown, isTrue);
      expect(occurrence.importance, Importance.key);
      expect(
        window.occurrences.where((o) => o.tripId == null),
        everyElement(
          isA<Occurrence>().having(
            (o) => o.eventId,
            'eventId',
            isNot(saved.eventId),
          ),
        ),
      );

      // --- the `search` function finds it by what it says (FR-10.2) -------------------------------------------
      // Folded: the title is "Edge <stamp>", the query is lower case. The trip runs from
      // today, so it is among the coming ones, once, in the shape `occurrences` gives.
      final searched = await phone.calendar
          .search('edge $stamp'.toLowerCase())
          .must('search the appointments');
      final hits = searched.upcoming.where((o) => o.tripId == tripId).toList();
      expect(hits, hasLength(1));
      expect(hits.single.eventId, saved.eventId);
      expect(hits.single.title, 'Edge $stamp');
      expect(
        (hits.single.localStartDate, hits.single.localEndDate),
        (day(0), day(3)),
      );
      expect(searched.past.where((o) => o.tripId == tripId), isEmpty);
      // Every word has to be found: one that no appointment says finds nothing.
      final none = await phone.calendar
          .search('edge $stamp qqzzxx')
          .must('search for what is not there');
      expect(none.isEmpty, isTrue);
      expect(none.more, isFalse);
      // One letter is no query (query_invalid).
      expect(await phone.calendar.search('e'), isA<Err<EventSearchResult>>());

      // --- `trips` / windows: the database only ---------------------------------------------------------------
      final windows = await phone.trips
          .windows(const TripWindowsArgs())
          .must('read the windows');
      for (final w in windows) {
        expect(w.to.isBefore(w.from), isFalse);
        expect(w.days, greaterThan(0));
        expect(w.leaveDays, greaterThanOrEqualTo(0));
      }
      await phone.trips
          .windows(
            TripWindowsArgs(
              from: day(0),
              to: day(120),
              minDays: 4,
              memberIds: [me],
              tripId: tripId,
            ),
          )
          .must('read the windows of one member');
      // (A household with a region and a school would list holidays here; the test does
      // not fill the holiday cache: that is holidays-sync, which asks openholidaysapi.org.)
      expect(
        await outcome(
          phone.trips.windows(TripWindowsArgs(memberIds: [uuid.v4()])),
        ),
        'invalid_request',
        reason: 'a member that is not in the household',
      );
      expect(
        await outcome(phone.trips.windows(const TripWindowsArgs(minDays: 1))),
        'invalid_request',
      );

      // --- `trips` / discover with no provider on: the bundled catalogue ------------------------------------------
      Future<DiscoverResult> discover([
        DiscoverFilters filters = const DiscoverFilters(),
      ]) => phone.trips
          .discover(
            actor: null,
            args: TripDiscoverArgs(
              from: day(30),
              to: day(40),
              lang: 'de',
              filters: filters,
            ),
          )
          .must('discover');
      await phone.trips.setHome(actor: null, home: null).must('forget home');
      var found = await discover();
      expect(found.places, isNotEmpty);
      expect(found.pending, 0);
      expect(found.provider, isNull);
      expect(found.attribution, isNull);
      for (final p in found.places) {
        expect(
          p.fits,
          anyOf(DiscoverFit.unknown, DiscoverFit.yes),
          reason: p.name,
        );
        expect(p.climate, isNull, reason: 'no climate service is on');
        expect(p.km, isNull, reason: 'no home place yet');
        expect(p.name, isNotEmpty);
        expect(p.lat, inInclusiveRange(-90, 90));
        expect(p.lon, inInclusiveRange(-180, 180));
      }
      expect(found.places.any((p) => p.key != null), isTrue);
      final idea = found.places.where((p) => p.tripId == ideaId).toList();
      expect(idea, hasLength(1), reason: 'the family\'s own idea is listed');
      expect(idea.single.isIdea, isTrue);
      expect(idea.single.name, 'Sardinien Edge $stamp');
      expect(
        found.places.any((p) => p.tripId == tripId),
        isFalse,
        reason: 'a fixed trip is no idea',
      );

      // With a home place the places carry the distance and the effort.
      await phone.trips
          .setHome(
            actor: null,
            home: const TripHome(name: 'Zuhause', lat: 47.37, lon: 8.54),
          )
          .must('set the home place');
      found = await discover();
      expect(found.places, isNotEmpty);
      for (final p in found.places) {
        expect(p.km, isNotNull, reason: p.name);
        expect(p.effort, isNotNull, reason: p.name);
      }
      found = await discover(const DiscoverFilters(effort: TravelEffort.car));
      expect(
        found.places.map((p) => p.effort),
        everyElement(anyOf(TravelEffort.near, TravelEffort.car)),
      );
      found = await discover(const DiscoverFilters(tags: ['sea']));
      expect(found.places, isNotEmpty);
      expect(found.places.map((p) => p.tags), everyElement(contains('sea')));
      await phone.trips.setHome(actor: null, home: null).must('forget home');

      // --- `services` / geocode: no provider offers it -----------------------------------------------------------------
      expect(
        await outcome(phone.services.geocode(q: 'Lisbon', lang: 'en')),
        'service_off',
      );
      expect(
        await outcome(phone.services.geocode(q: 'x')),
        'invalid_request',
        reason: 'refused by the function before anything else',
      );
      // A provider with a key, switched on for forecasts only, is not asked for places: the
      // door lists only the providers that offer the capability, so the answer is the same.
      await phone.services
          .setProvider(
            actor: null,
            provider: 'openweathermap',
            enabled: true,
            capabilities: [ServiceCapability.forecast],
            key: 'test-key-123456',
          )
          .must('switch a provider on for forecasts');
      expect(
        await outcome(phone.services.geocode(q: 'Lisbon', lang: 'en')),
        'service_off',
      );
      found = await discover();
      expect(found.places, isNotEmpty);
      expect(found.provider, isNull);
      expect(found.pending, 0);

      // --- a child's iPad: the door refuses, before any provider ----------------------------------------------------------
      final (ipad, kidId) = await kidsIpad(phone);
      expect(
        await outcome(
          ipad.trips.discover(
            actor: kidId,
            args: TripDiscoverArgs(from: day(30), to: day(40), lang: 'de'),
          ),
        ),
        'adults_only',
      );
      expect(
        await outcome(
          ipad.services.geocode(q: 'Lisbon', lang: 'en', actor: kidId),
        ),
        'adults_only',
      );
      expect(
        (await ipad.services.catalogue()).isOk,
        isTrue,
        reason: 'the catalogue is for any member',
      );
    },
    skip: edgeSkip,
    timeout: const Timeout(Duration(seconds: 240)),
  );
}

/// One simulated device: a client with the repositories of this test.
class _Phone {
  _Phone(this.client)
    : api = ApiClient(client),
      identity = IdentityRepository(ApiClient(client), client.auth),
      trips = TripsRepository(ApiClient(client)),
      services = ServicesRepository(ApiClient(client)),
      calendar = CalendarRepository(ApiClient(client));

  final SupabaseClient client;
  final ApiClient api;
  final IdentityRepository identity;
  final TripsRepository trips;
  final ServicesRepository services;
  final CalendarRepository calendar;
}

/// The value of a result, or a test failure that names what was tried and why it failed:
/// the first run of this file is in CI, where a bare `Instance of 'UnknownFailure'` helps
/// nobody.
extension _Must<T> on Future<Result<T>> {
  Future<T> must(String what) async {
    final result = await this;
    if (result case Err<T>(:final failure)) {
      throw TestFailure(
        '$what failed: ${failure.runtimeType} code=${failure.code} '
        'cause=${failure.cause}',
      );
    }
    return (result as Ok<T>).value;
  }
}

/// How a call ended: the failure's code, or `(ok)` / `(no code: Type)`, so a refusal that
/// did not happen reads as such in the test's output.
Future<String> outcome<T>(Future<Result<T>> call) async {
  final result = await call;
  return switch (result) {
    Ok<T>() => '(ok)',
    Err<T>(:final failure) =>
      failure.code ?? '(no code: ${failure.runtimeType})',
  };
}
