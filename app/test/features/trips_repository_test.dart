import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/trips/data/trips_repository.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// One request the repository sent.
class Sent {
  Sent(this.method, this.url, this.body);

  final String method;
  final Uri url;
  final Object? body;

  String get path => url.path;
  Map<String, dynamic> get params => body! as Map<String, dynamic>;
}

/// A repository on a fake server: [answer] is given the request and says what the server
/// replies (`(status, json)`); everything sent is recorded.
({TripsRepository repo, List<Sent> sent}) fixture(
  (int, Object?) Function(Sent request) answer,
) {
  final sent = <Sent>[];
  final client = MockClient((req) async {
    final body = req.body.isEmpty ? null : jsonDecode(req.body);
    final s = Sent(req.method, req.url, body);
    sent.add(s);
    final (status, json) = answer(s);
    return http.Response(
      jsonEncode(json),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: req,
    );
  });
  final api = ApiClient(
    SupabaseClient(
      'http://localhost:54321',
      'anon-key',
      httpClient: client,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );
  return (repo: TripsRepository(api), sent: sent);
}

const _uuid = '11111111-1111-4111-8111-111111111111';

void main() {
  group('reads', () {
    test('the household\'s lists come from the api views, in order', () async {
      final f = fixture(
        (r) => switch (r.path) {
          '/rest/v1/trips' => (
            200,
            [
              {'id': 't1', 'title': 'Sardinien', 'stage': 'fixed'},
            ],
          ),
          '/rest/v1/trip_entries' => (
            200,
            [
              {'id': 'e1', 'trip_id': 't1', 'kind': 'stay', 'title': 'Hotel'},
            ],
          ),
          '/rest/v1/trip_combos' => (
            200,
            [
              {
                'id': 'c1',
                'trip_id': 't1',
                'name': 'Günstig',
                'entry_ids': ['e1'],
              },
            ],
          ),
          '/rest/v1/trip_checks' => (
            200,
            [
              {'id': 'k1', 'trip_id': 't1', 'kind': 'pack', 'title': 'Pässe'},
            ],
          ),
          _ => (404, {}),
        },
      );
      expect((await f.repo.trips()).unwrap().single.stage, TripStage.fixed);
      expect((await f.repo.entries()).unwrap().single.kind, EntryKind.stay);
      expect((await f.repo.combos()).unwrap().single.entryIds, ['e1']);
      expect((await f.repo.checks()).unwrap().single.title, 'Pässe');
      expect(f.sent.map((s) => s.method).toSet(), {'GET'});
      expect(
        f.sent[0].url.queryParameters['order'],
        startsWith('created_at.asc'),
      );
      expect(
        f.sent[1].url.queryParameters['order'],
        startsWith('position.asc'),
      );
    });

    test('the home place is the one row, or none', () async {
      var rows = <Map<String, Object?>>[
        {'name': 'Zürich', 'lat': 47.37, 'lon': 8.54},
      ];
      final f = fixture((r) => (200, rows));
      final home = (await f.repo.home()).unwrap()!;
      expect(home.name, 'Zürich');
      expect(home.lat, 47.37);
      rows = [];
      expect((await f.repo.home()).unwrap(), isNull);
    });

    test('a refusal arrives as a failure with the server\'s hint', () async {
      final f = fixture(
        (r) => (
          403,
          {
            'code': '42501',
            'message': 'only adults',
            'hint': 'adults_only',
            'details': null,
          },
        ),
      );
      final result = await f.repo.trips();
      expect(result, isA<Err<List<Trip>>>());
      expect(result.failureOrNull, isA<PermissionFailure>());
      expect(result.failureOrNull!.code, 'adults_only');
    });
  });

  group('trips', () {
    test(
      'saveTrip sends the p_trip of the contract and answers the ids',
      () async {
        final f = fixture((r) => (200, {'id': 't1', 'event_id': 'ev1'}));
        final saved = (await f.repo.saveTrip(
          actor: 'p-papa',
          trip: Trip(
            id: 't1',
            title: ' Sardinien ',
            stage: TripStage.planned,
            startsOn: DateTime(2027, 7, 10),
            endsOn: DateTime(2027, 7, 19),
            memberIds: const ['a'],
          ),
        )).unwrap();
        expect(saved.id, 't1');
        expect(saved.eventId, 'ev1');
        final s = f.sent.single;
        expect(s.method, 'POST');
        expect(s.path, '/rest/v1/rpc/trip_save');
        expect(s.params.keys.toSet(), {'p_actor', 'p_trip'});
        expect(s.params['p_actor'], 'p-papa');
        final trip = s.params['p_trip'] as Map<String, dynamic>;
        expect(trip['title'], 'Sardinien');
        expect(trip['stage'], 'planned');
        expect(trip['starts_on'], '2027-07-10');
        expect(trip['member_ids'], ['a']);
        expect(trip.containsKey('currency'), isFalse);
      },
    );

    test('patchTrip sends only the id and the changes', () async {
      final f = fixture((r) => (200, {'id': 't1'}));
      await f.repo.patchTrip(
        actor: null,
        id: 't1',
        changes: {'stage': 'fixed'},
      );
      expect(f.sent.single.params, {
        'p_actor': null,
        'p_trip': {'id': 't1', 'stage': 'fixed'},
      });
    });

    test('deleteTrip', () async {
      final f = fixture((r) => (204, null));
      expect((await f.repo.deleteTrip(actor: 'a', id: 't1')).isOk, isTrue);
      expect(f.sent.single.path, '/rest/v1/rpc/trip_delete');
      expect(f.sent.single.params, {'p_actor': 'a', 'p_id': 't1'});
    });

    test('a refusal of the trip keeps its hint', () async {
      final f = fixture(
        (r) => (
          400,
          {
            'code': '22023',
            'message': 'WW-TRIP-001 trip invalid',
            'hint': 'trip_invalid',
            'details': null,
          },
        ),
      );
      final r = await f.repo.saveTrip(
        actor: null,
        trip: const Trip(id: 't', title: ''),
      );
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(r.failureOrNull!.code, 'trip_invalid');
    });
  });

  group('entries', () {
    test('saveEntry sends the p_entry and answers the id', () async {
      final f = fixture((r) => (200, {'id': 'e1'}));
      final id = (await f.repo.saveEntry(
        actor: null,
        entry: TripEntry(
          id: 'e1',
          tripId: 't1',
          kind: EntryKind.transport,
          mode: TransportMode.flight,
          title: 'Flug',
          priceCents: 84000,
          startsOn: DateTime(2027, 7, 10),
          startsTime: const TimeOfDay(hour: 7, minute: 10),
        ),
      )).unwrap();
      expect(id, 'e1');
      final s = f.sent.single;
      expect(s.path, '/rest/v1/rpc/trip_entry_save');
      expect(s.params.keys.toSet(), {'p_actor', 'p_entry'});
      final e = s.params['p_entry'] as Map<String, dynamic>;
      expect(e['trip_id'], 't1');
      expect(e['mode'], 'flight');
      expect(e['price_cents'], 84000);
      expect(e['starts_time'], '07:10');
    });

    test('deleteEntry and copyEntry', () async {
      final f = fixture(
        (r) => r.path.endsWith('copy') ? (200, {'id': 'e2'}) : (204, null),
      );
      await f.repo.deleteEntry(actor: 'a', id: 'e1');
      final copy = (await f.repo.copyEntry(actor: 'a', id: 'e1')).unwrap();
      expect(copy, 'e2');
      expect(f.sent[0].path, '/rest/v1/rpc/trip_entry_delete');
      expect(f.sent[0].params, {'p_actor': 'a', 'p_id': 'e1'});
      expect(f.sent[1].path, '/rest/v1/rpc/trip_entry_copy');
      expect(f.sent[1].params, {'p_actor': 'a', 'p_id': 'e1'});
    });

    test('importEntries sends the entries without id and trip', () async {
      final f = fixture((r) => (200, {'added': 2, 'updated': 1}));
      final r = (await f.repo.importEntries(
        actor: 'a',
        tripId: 't1',
        entries: [
          TripEntry(
            id: 'x',
            tripId: 't1',
            kind: EntryKind.stay,
            title: 'Hotel',
            state: EntryState.booked,
            sourceUid: 'uid-1',
          ),
        ],
      )).unwrap();
      expect((r.added, r.updated), (2, 1));
      final s = f.sent.single;
      expect(s.path, '/rest/v1/rpc/trip_entries_import');
      expect(s.params.keys.toSet(), {'p_actor', 'p_trip', 'p_entries'});
      expect(s.params['p_trip'], 't1');
      final e = (s.params['p_entries'] as List).single as Map<String, dynamic>;
      expect(e['source_uid'], 'uid-1');
      expect(e['state'], 'booked');
      expect(e.containsKey('id'), isFalse);
      expect(e.containsKey('trip_id'), isFalse);
    });
  });

  group('combinations', () {
    test('saveCombo, deleteCombo and chooseCombo', () async {
      final f = fixture(
        (r) => switch (r.path) {
          '/rest/v1/rpc/trip_combo_save' => (200, {'id': 'c1'}),
          '/rest/v1/rpc/trip_combo_choose' => (
            200,
            {'chosen': 3, 'released': 1, 'dates_set': true},
          ),
          _ => (204, null),
        },
      );
      expect(
        (await f.repo.saveCombo(
          actor: null,
          combo: const TripCombo(
            id: 'c1',
            tripId: 't1',
            name: ' Günstig ',
            entryIds: ['e1', 'e2'],
          ),
        )).unwrap(),
        'c1',
      );
      final choice = (await f.repo.chooseCombo(
        actor: 'a',
        id: 'c1',
        setDates: true,
      )).unwrap();
      expect((choice.chosen, choice.released, choice.datesSet), (3, 1, true));
      await f.repo.chooseCombo(actor: 'a', id: 'c1');
      await f.repo.deleteCombo(actor: 'a', id: 'c1');
      expect(f.sent[0].params['p_combo'], {
        'id': 'c1',
        'trip_id': 't1',
        'name': 'Günstig',
        'entry_ids': ['e1', 'e2'],
      });
      expect(f.sent[1].params, {
        'p_actor': 'a',
        'p_id': 'c1',
        'p_set_dates': true,
      });
      expect(f.sent[2].params['p_set_dates'], false);
      expect(f.sent[3].path, '/rest/v1/rpc/trip_combo_delete');
    });
  });

  group('checks', () {
    test(
      'every write of a check uses the contract\'s parameter names',
      () async {
        final f = fixture(
          (r) => switch (r.path) {
            '/rest/v1/rpc/trip_check_save' => (200, {'id': 'k1'}),
            '/rest/v1/rpc/trip_checks_add' => (200, {'added': 2}),
            '/rest/v1/rpc/trip_checks_copy' => (200, {'added': 5}),
            _ => (204, null),
          },
        );
        expect(
          (await f.repo.saveCheck(
            actor: 'a',
            check: const TripCheck(
              id: 'k1',
              tripId: 't1',
              kind: CheckKind.todo,
              title: 'Pässe prüfen',
              dueDaysBefore: 14,
            ),
          )).unwrap(),
          'k1',
        );
        expect(
          (await f.repo.addChecks(
            actor: 'a',
            tripId: 't1',
            checks: const [
              TripCheck(
                id: 'x',
                tripId: 't1',
                kind: CheckKind.pack,
                title: 'Pässe',
                profileId: 'p',
              ),
              TripCheck(
                id: 'y',
                tripId: 't1',
                kind: CheckKind.pack,
                title: 'Creme',
              ),
            ],
          )).unwrap(),
          2,
        );
        expect(
          (await f.repo.copyChecks(actor: 'a', from: 't0', to: 't1')).unwrap(),
          5,
        );
        await f.repo.tickCheck(actor: 'a', id: 'k1', done: true);
        await f.repo.deleteCheck(actor: 'a', id: 'k1');
        expect(f.sent[0].params['p_check'], {
          'id': 'k1',
          'trip_id': 't1',
          'kind': 'todo',
          'title': 'Pässe prüfen',
          'profile_id': null,
          'due_days_before': 14,
        });
        expect(f.sent[1].params.keys.toSet(), {
          'p_actor',
          'p_trip',
          'p_checks',
        });
        expect((f.sent[1].params['p_checks'] as List).first, {
          'kind': 'pack',
          'title': 'Pässe',
          'profile_id': 'p',
          'due_days_before': null,
        });
        expect(f.sent[2].params, {
          'p_actor': 'a',
          'p_from': 't0',
          'p_to': 't1',
        });
        expect(f.sent[3].path, '/rest/v1/rpc/trip_check_tick');
        expect(f.sent[3].params, {
          'p_actor': 'a',
          'p_id': 'k1',
          'p_done': true,
        });
        expect(f.sent[4].path, '/rest/v1/rpc/trip_check_delete');
        expect(f.sent[4].params, {'p_actor': 'a', 'p_id': 'k1'});
      },
    );
  });

  group('home', () {
    test('sets the rounded place and forgets it with null', () async {
      final f = fixture((r) => (204, null));
      await f.repo.setHome(
        actor: 'a',
        home: const TripHome(name: ' Zürich ', lat: 47.3769, lon: 8.5417),
      );
      await f.repo.setHome(actor: 'a', home: null);
      expect(f.sent[0].path, '/rest/v1/rpc/trip_home_set');
      expect(f.sent[0].params, {
        'p_actor': 'a',
        'p_home': {'name': 'Zürich', 'lat': 47.38, 'lon': 8.54},
      });
      expect(f.sent[1].params, {'p_actor': 'a', 'p_home': null});
    });
  });

  group('the trips function', () {
    test('windows asks with the body of the contract', () async {
      final f = fixture(
        (r) => (
          200,
          {
            'windows': [
              {
                'from': '2027-07-10',
                'to': '2027-07-24',
                'days': 15,
                'kind': 'holidays',
                'name': 'Sommerferien',
                'leave_days': 10,
                'partial': <Object>[],
                'conflicts': <Object>[],
              },
            ],
          },
        ),
      );
      final windows = (await f.repo.windows(
        TripWindowsArgs(
          minDays: 7,
          memberIds: const ['a'],
          from: DateTime(2027, 1, 1),
        ),
      )).unwrap();
      expect(windows.single.leaveDays, 10);
      final s = f.sent.single;
      expect(s.path, '/functions/v1/trips');
      expect(s.params, {
        'action': 'windows',
        'from': '2027-01-01',
        'min_days': 7,
        'member_ids': ['a'],
      });
    });

    test('discover sends the filters and the acting profile', () async {
      final f = fixture(
        (r) => (
          200,
          {
            'places': [
              {
                'key': 'sardinia',
                'name': 'Sardinien',
                'country': 'IT',
                'lat': 40.9,
                'lon': 9.5,
                'tags': ['sea'],
                'fits': 'yes',
              },
            ],
            'pending': 1,
          },
        ),
      );
      final r = (await f.repo.discover(
        actor: _uuid,
        args: TripDiscoverArgs(
          from: DateTime(2027, 7, 10),
          to: DateTime(2027, 7, 24),
          lang: 'de',
          filters: const DiscoverFilters(
            tempMin: 25,
            dry: true,
            tags: ['sea'],
            effort: TravelEffort.short,
          ),
        ),
      )).unwrap();
      expect(r.places.single.key, 'sardinia');
      expect(r.pending, 1);
      expect(f.sent.single.path, '/functions/v1/trips');
      expect(f.sent.single.params, {
        'action': 'discover',
        'from': '2027-07-10',
        'to': '2027-07-24',
        'lang': 'de',
        'filters': {
          'temp_min': 25.0,
          'dry': true,
          'tags': ['sea'],
          'effort': 'short',
        },
        'actor_profile_id': _uuid,
      });
    });

    test('a refusal of the function carries its word as the code', () async {
      final f = fixture((r) => (409, {'error': 'service_off'}));
      final r = await f.repo.discover(
        actor: null,
        args: TripDiscoverArgs(
          from: DateTime(2027, 7, 1),
          to: DateTime(2027, 7, 2),
        ),
      );
      expect(r.failureOrNull!.code, 'service_off');
    });

    test('a database refusal passed through keeps its hint and kind', () async {
      final f = fixture(
        (r) => (
          403,
          {
            'error': 'adults_only',
            'code': '42501',
            'hint': 'adults_only',
            'message': 'adults only',
          },
        ),
      );
      final r = await f.repo.windows(const TripWindowsArgs());
      expect(r.failureOrNull, isA<PermissionFailure>());
      expect(r.failureOrNull!.code, 'adults_only');
    });
  });
}
