import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/trips/domain/combination.dart';
import 'package:wuselwall/features/trips/domain/packing_starters.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_import.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/domain/trip_plan.dart';
import 'package:wuselwall/features/trips/domain/trip_today.dart';

DateTime d(int month, int day) => DateTime(2027, month, day);

Trip trip({
  String id = 't1',
  TripStage stage = TripStage.fixed,
  DateTime? from,
  DateTime? to,
  bool dated = true,
}) => Trip(
  id: id,
  title: 'Sardinien',
  stage: stage,
  startsOn: dated ? from ?? d(7, 10) : null,
  endsOn: dated ? to ?? d(7, 19) : null,
  currency: 'CHF',
);

TripEntry entry(
  String id,
  EntryKind kind, {
  int? price,
  DateTime? from,
  DateTime? to,
  EntryState state = EntryState.option,
  TimeOfDay? time,
  TimeOfDay? endTime,
  int position = 0,
  String tripId = 't1',
  DateTime? cancelUntil,
}) => TripEntry(
  id: id,
  tripId: tripId,
  kind: kind,
  mode: kind == EntryKind.transport ? TransportMode.flight : null,
  title: id,
  state: state,
  priceCents: price,
  startsOn: from,
  endsOn: to,
  startsTime: time,
  endsTime: endTime,
  position: position,
  cancelUntil: cancelUntil,
);

void main() {
  group('Trip', () {
    test('reads and writes the contract', () {
      final t = Trip.fromJson({
        'id': 't1',
        'title': 'Sardinien',
        'icon_key': 'beach',
        'stage': 'planned',
        'destination_name': 'Olbia',
        'destination_key': 'sardinia',
        'country': 'IT',
        'lat': 40.9,
        'lon': 9,
        'starts_on': '2027-07-10',
        'ends_on': '2027-07-19',
        'note': 'n',
        'currency': 'EUR',
        'member_ids': ['a', 'b'],
        'event_id': 'ev',
        'created_at': '2026-11-01T10:00:00Z',
      });
      expect(t.stage, TripStage.planned);
      expect(t.lat, 40.9);
      expect(t.lon, 9.0);
      expect(t.memberIds, ['a', 'b']);
      expect(t.eventId, 'ev');
      expect(t.toJson(), {
        'id': 't1',
        'title': 'Sardinien',
        'icon_key': 'beach',
        'stage': 'planned',
        'destination_name': 'Olbia',
        'destination_key': 'sardinia',
        'country': 'IT',
        'lat': 40.9,
        'lon': 9.0,
        'starts_on': '2027-07-10',
        'ends_on': '2027-07-19',
        'note': 'n',
        'currency': 'EUR',
        'member_ids': ['a', 'b'],
      });
    });

    test('tolerates a row with only the required keys', () {
      final t = Trip.fromJson({'id': 't', 'title': 'Nordsee'});
      expect(t.stage, TripStage.idea);
      expect(t.hasDates, isFalse);
      expect(t.memberIds, isEmpty);
      expect(t.wholeFamily, isTrue);
      expect(t.nights, 0);
      expect(t.daysUntil(d(1, 1)), isNull);
      // A cleared value is sent as null; a currency not chosen is left to the server.
      final json = t.toJson();
      expect(json['starts_on'], isNull);
      expect(json.containsKey('starts_on'), isTrue);
      expect(json.containsKey('currency'), isFalse);
    });

    test('counts nights, days and the days around the trip', () {
      final t = trip(from: d(7, 10), to: d(7, 19));
      expect(t.nights, 9);
      expect(t.days, 10);
      expect(t.daysUntil(d(7, 1)), 9);
      expect(t.daysUntil(d(7, 10)), 0);
      expect(t.daysUntil(d(7, 12)), -2);
      expect(t.isRunning(d(7, 9)), isFalse);
      expect(t.isRunning(d(7, 10)), isTrue);
      expect(t.isRunning(DateTime(2027, 7, 19, 23, 30)), isTrue);
      expect(t.isRunning(d(7, 20)), isFalse);
      expect(t.isPast(d(7, 19)), isFalse);
      expect(t.isPast(d(7, 20)), isTrue);
      expect(t.dayNumber(d(7, 9)), isNull);
      expect(t.dayNumber(d(7, 10)), 1);
      expect(t.dayNumber(d(7, 12)), 3);
      expect(t.dayNumber(d(7, 19)), 10);
      expect(t.dayNumber(d(7, 20)), isNull);
    });

    test('days do not drift over a clock change', () {
      final t = trip(from: DateTime(2027, 3, 26), to: DateTime(2027, 3, 29));
      expect(t.nights, 3);
      expect(t.daysUntil(DateTime(2027, 3, 20)), 6);
    });

    test(
      'copyWith keeps what is not passed and clears what is passed as null',
      () {
        final t = trip(from: d(7, 10), to: d(7, 19)).copyWith(iconKey: 'beach');
        expect(t.iconKey, 'beach');
        expect(t.copyWith(title: 'x').iconKey, 'beach');
        expect(t.copyWith(iconKey: null).iconKey, isNull);
        final idea = t.copyWith(startsOn: null, endsOn: null);
        expect(idea.hasDates, isFalse);
        expect(idea.title, 'Sardinien');
      },
    );
  });

  group('TripEntry', () {
    test('reads the contract and writes the server keys', () {
      final e = TripEntry.fromJson({
        'id': 'e1',
        'trip_id': 't1',
        'kind': 'transport',
        'mode': 'flight',
        'title': 'ZRH-OLB',
        'state': 'chosen',
        'url': 'https://example.org/x',
        'price_cents': 84000,
        'price_checked_on': '2027-01-12',
        'details': '1 Stopp',
        'note': '',
        'from_place': 'ZRH',
        'to_place': 'OLB',
        'booking_ref': 'ABC',
        'cancel_until': '2027-06-01',
        'lat': null,
        'lon': null,
        'starts_on': '2027-07-10',
        'starts_time': '07:10:00',
        'ends_on': '2027-07-10',
        'ends_time': '08:55',
        'position': 3,
        'source_uid': 'uid-1',
      });
      expect(e.kind, EntryKind.transport);
      expect(e.mode, TransportMode.flight);
      expect(e.state, EntryState.chosen);
      expect(e.startsTime, const TimeOfDay(hour: 7, minute: 10));
      expect(e.endsTime, const TimeOfDay(hour: 8, minute: 55));
      expect(e.priceCheckedOn, DateTime(2027, 1, 12));
      final json = e.toJson();
      expect(json['starts_time'], '07:10');
      expect(json['ends_time'], '08:55');
      expect(json['cancel_until'], '2027-06-01');
      expect(json['source_uid'], 'uid-1');
      expect(json.containsKey('price_checked_on'), isFalse);
      expect(json.containsKey('position'), isFalse);
      expect(e.toImportJson().containsKey('id'), isFalse);
      expect(e.toImportJson().containsKey('trip_id'), isFalse);
      expect(e.toImportJson()['source_uid'], 'uid-1');
    });

    test('sends no mode for an entry that is not a transport', () {
      final stay = entry('s', EntryKind.stay).copyWith(mode: TransportMode.car);
      expect(stay.toJson()['mode'], isNull);
    });

    test('tolerates a row with only the required keys', () {
      final e = TripEntry.fromJson({
        'id': 'e',
        'trip_id': 't',
        'kind': 'unheard-of',
        'title': 'x',
      });
      expect(e.kind, EntryKind.activity);
      expect(e.state, EntryState.option);
      expect(e.hasDates, isFalse);
      expect(e.nights, isNull);
      expect(e.pricePerNight, isNull);
    });

    test('computes nights, days and prices per night and per day', () {
      final stay = entry(
        's',
        EntryKind.stay,
        price: 189000,
        from: d(7, 10),
        to: d(7, 19),
      );
      expect(stay.nights, 9);
      expect(stay.days, 10);
      expect(stay.pricePerNight, 21000);
      expect(stay.pricePerDay, 18900);
      final rental = entry(
        'r',
        EntryKind.rental,
        price: 52000,
        from: d(7, 10),
        to: d(7, 19),
      );
      expect(rental.pricePerDay, 5200);
      // No night between two times on the same day, and no price, no price per night.
      expect(
        entry(
          'x',
          EntryKind.stay,
          price: 100,
          from: d(7, 10),
          to: d(7, 10),
        ).pricePerNight,
        isNull,
      );
      expect(
        entry('y', EntryKind.stay, from: d(7, 10), to: d(7, 12)).pricePerNight,
        isNull,
      );
    });

    test('knows when free cancellation is over', () {
      final e = entry('s', EntryKind.stay, cancelUntil: d(6, 1));
      expect(e.cancellationPassed(d(5, 31)), isFalse);
      expect(e.cancellationPassed(d(6, 1)), isFalse);
      expect(e.cancellationPassed(d(6, 2)), isTrue);
      expect(entry('x', EntryKind.stay).cancellationPassed(d(12, 1)), isFalse);
    });

    test('copyWith clears and keeps', () {
      final e = entry('s', EntryKind.stay, price: 5, from: d(7, 1));
      expect(e.copyWith(priceCents: null).priceCents, isNull);
      expect(e.copyWith(title: 'n').priceCents, 5);
      expect(e.copyWith(state: EntryState.booked).state, EntryState.booked);
    });
  });

  group('TripCheck', () {
    test('is due the given days before the first day', () {
      final t = trip(from: d(7, 10), to: d(7, 19));
      final c = TripCheck(
        id: 'c',
        tripId: 't1',
        kind: CheckKind.todo,
        title: 'Pässe',
        dueDaysBefore: 14,
      );
      expect(c.dueOn(t), d(6, 26));
      expect(c.done, isFalse);
      expect(c.dueOn(trip(dated: false)), isNull);
      expect(
        TripCheck(
          id: 'p',
          tripId: 't1',
          kind: CheckKind.pack,
          title: 'x',
        ).dueOn(t),
        isNull,
      );
    });

    test('writes only what its kind has', () {
      final todo = TripCheck(
        id: 'c',
        tripId: 't1',
        kind: CheckKind.todo,
        title: ' a ',
        profileId: 'p',
        dueDaysBefore: 3,
      ).toJson();
      expect(todo['profile_id'], isNull);
      expect(todo['due_days_before'], 3);
      expect(todo['title'], 'a');
      final pack = TripCheck(
        id: 'c',
        tripId: 't1',
        kind: CheckKind.pack,
        title: 'a',
        profileId: 'p',
        dueDaysBefore: 3,
      ).toJson();
      expect(pack['profile_id'], 'p');
      expect(pack['due_days_before'], isNull);
    });
  });

  group('Combination', () {
    final tr = trip();
    final out = entry(
      'out',
      EntryKind.transport,
      price: 40000,
      from: d(7, 10),
      to: d(7, 10),
      position: 1,
    );
    final back = entry(
      'back',
      EntryKind.transport,
      price: 30000,
      from: d(7, 19),
      position: 2,
    );
    final stay = entry(
      'stay',
      EntryKind.stay,
      price: 90000,
      from: d(7, 10),
      to: d(7, 19),
      position: 3,
    );
    final car = entry(
      'car',
      EntryKind.rental,
      price: 20000,
      from: d(7, 10),
      to: d(7, 19),
      position: 4,
    );

    test('sums the prices, spans the dates and finds nothing wrong', () {
      final c = Combination.of(tr, [car, stay, back, out]);
      expect(c.total, 180000);
      expect(c.incomplete, isFalse);
      expect(c.from, d(7, 10));
      expect(c.to, d(7, 19));
      expect(c.nights, 9);
      expect(c.warnings, isEmpty);
      expect(c.entries.map((e) => e.id), ['out', 'back', 'stay', 'car']);
      expect(c.ofKind(EntryKind.stay).single.id, 'stay');
    });

    test('an empty set has nothing', () {
      final c = Combination.of(tr, const []);
      expect(c.isEmpty, isTrue);
      expect(c.total, 0);
      expect(c.from, isNull);
      expect(c.warnings, isEmpty);
    });

    test('ignores entries of another trip', () {
      final c = Combination.of(tr, [
        out,
        entry('other', EntryKind.stay, price: 1, tripId: 't2'),
      ]);
      expect(c.entries.map((e) => e.id), ['out']);
    });

    test('names the nights no stay covers', () {
      final shortStay = entry(
        'short',
        EntryKind.stay,
        price: 1,
        from: d(7, 10),
        to: d(7, 17),
      );
      final c = Combination.of(tr, [out, back, shortStay]);
      final w = c.warnings.whereType<UncoveredNights>().single;
      expect(w.ranges, [NightRange(d(7, 17), d(7, 18))]);
      expect(w.nights, 2);
    });

    test('two stays with a gap between them leave that gap', () {
      final a = entry(
        'a',
        EntryKind.stay,
        price: 1,
        from: d(7, 10),
        to: d(7, 13),
      );
      final b = entry(
        'b',
        EntryKind.stay,
        price: 1,
        from: d(7, 15),
        to: d(7, 19),
      );
      final c = Combination.of(tr, [out, back, a, b]);
      expect(c.warnings.whereType<UncoveredNights>().single.ranges, [
        NightRange(d(7, 13), d(7, 14)),
      ]);
      expect(c.warnings.whereType<OverlappingStays>(), isEmpty);
    });

    test(
      'flights alone leave every night uncovered, a rental alone does not',
      () {
        final flights = Combination.of(tr, [out, back]);
        expect(flights.warnings.whereType<UncoveredNights>().single.ranges, [
          NightRange(d(7, 10), d(7, 18)),
        ]);
        final onlyCar = Combination.of(tr, [
          entry('c', EntryKind.rental, price: 1, from: d(7, 10), to: d(7, 19)),
        ]);
        expect(onlyCar.warnings.whereType<UncoveredNights>(), isEmpty);
      },
    );

    test('a combination within one day has no night to cover', () {
      final c = Combination.of(tr, [
        entry('x', EntryKind.transport, price: 1, from: d(7, 10), to: d(7, 10)),
      ]);
      expect(c.warnings, isEmpty);
    });

    test('warns about a rental ticked without any transport', () {
      final c = Combination.of(tr, [stay, car]);
      final w = c.warnings.whereType<RentalOutsideTransport>().single;
      expect(w.rental.id, 'car');
      expect(w.reason, RentalMismatch.noTransport);
    });

    test('warns about a rental that starts before the arrival', () {
      final early = entry(
        'early',
        EntryKind.rental,
        price: 1,
        from: d(7, 9),
        to: d(7, 19),
      );
      final c = Combination.of(tr, [out, back, stay, early]);
      expect(
        c.warnings.whereType<RentalOutsideTransport>().map((w) => w.reason),
        [RentalMismatch.startsBeforeArrival],
      );
    });

    test('the arrival is the end date of the first flight', () {
      final overnight = entry(
        'night',
        EntryKind.transport,
        price: 1,
        from: d(7, 10),
        to: d(7, 11),
      );
      final carOn10 = entry(
        'car',
        EntryKind.rental,
        price: 1,
        from: d(7, 10),
        to: d(7, 19),
      );
      final c = Combination.of(tr, [overnight, back, stay, carOn10]);
      expect(
        c.warnings.whereType<RentalOutsideTransport>().single.reason,
        RentalMismatch.startsBeforeArrival,
      );
    });

    test('warns about a rental that ends after the departure', () {
      final late = entry(
        'late',
        EntryKind.rental,
        price: 1,
        from: d(7, 10),
        to: d(7, 20),
      );
      final c = Combination.of(tr, [out, back, stay, late]);
      expect(
        c.warnings.whereType<RentalOutsideTransport>().map((w) => w.reason),
        [RentalMismatch.endsAfterDeparture],
      );
    });

    test('with a single transport only the arrival is checked', () {
      final late = entry(
        'late',
        EntryKind.rental,
        price: 1,
        from: d(7, 10),
        to: d(7, 25),
      );
      final c = Combination.of(tr, [out, late]);
      expect(c.warnings.whereType<RentalOutsideTransport>(), isEmpty);
      final early = entry(
        'early',
        EntryKind.rental,
        price: 1,
        from: d(7, 8),
        to: d(7, 25),
      );
      expect(
        Combination.of(tr, [
          out,
          early,
        ]).warnings.whereType<RentalOutsideTransport>().single.reason,
        RentalMismatch.startsBeforeArrival,
      );
    });

    test(
      'the last transport by start decides the departure, not the list order',
      () {
        final c = Combination.of(tr, [
          entry(
            'back',
            EntryKind.transport,
            price: 1,
            from: d(7, 19),
            position: 1,
          ),
          entry(
            'out',
            EntryKind.transport,
            price: 1,
            from: d(7, 10),
            position: 2,
          ),
          entry(
            'car',
            EntryKind.rental,
            price: 1,
            from: d(7, 10),
            to: d(7, 19),
            position: 3,
          ),
          stay,
        ]);
        expect(c.warnings.whereType<RentalOutsideTransport>(), isEmpty);
      },
    );

    test('warns about two stays that share a night', () {
      final other = entry(
        'other',
        EntryKind.stay,
        price: 1,
        from: d(7, 14),
        to: d(7, 19),
      );
      final first = entry(
        'first',
        EntryKind.stay,
        price: 1,
        from: d(7, 10),
        to: d(7, 16),
      );
      final c = Combination.of(tr, [out, back, other, first]);
      final w = c.warnings.whereType<OverlappingStays>().single;
      expect(w.first.id, 'first');
      expect(w.second.id, 'other');
      expect(w.shared, NightRange(d(7, 14), d(7, 15)));
    });

    test('a check-out on the day of the next check-in is fine', () {
      final a = entry(
        'a',
        EntryKind.stay,
        price: 1,
        from: d(7, 10),
        to: d(7, 14),
      );
      final b = entry(
        'b',
        EntryKind.stay,
        price: 1,
        from: d(7, 14),
        to: d(7, 19),
      );
      final c = Combination.of(tr, [out, back, a, b]);
      expect(c.warnings, isEmpty);
    });

    test('an option without a price makes the total "at least"', () {
      final free = entry('free', EntryKind.stay, from: d(7, 10), to: d(7, 19));
      final c = Combination.of(tr, [out, back, free]);
      expect(c.total, 70000);
      expect(c.incomplete, isTrue);
      expect(
        c.warnings.whereType<PriceMissing>().single.entries.single.id,
        'free',
      );
    });

    test('a note needs no price', () {
      final c = Combination.of(tr, [out, entry('n', EntryKind.note)]);
      expect(c.incomplete, isFalse);
      expect(c.warnings.whereType<PriceMissing>(), isEmpty);
    });

    test('a stored combination is made of the entries that still exist', () {
      final combo = TripCombo(
        id: 'c',
        tripId: 't1',
        name: 'Günstig',
        entryIds: ['out', 'gone', 'stay'],
      );
      final c = Combination.ofCombo(tr, combo, [out, back, stay, car]);
      expect(c.entries.map((e) => e.id), ['out', 'stay']);
    });

    group('cheapestOf', () {
      test('marks the cheapest of each kind', () {
        final ids = Combination.cheapestOf([
          entry('f1', EntryKind.transport, price: 500),
          entry('f2', EntryKind.transport, price: 300),
          entry('s1', EntryKind.stay, price: 100),
          entry('s2', EntryKind.stay, price: 900),
        ]);
        expect(ids, {'f2', 's1'});
      });

      test('marks all of a tie', () {
        final ids = Combination.cheapestOf([
          entry('a', EntryKind.stay, price: 300),
          entry('b', EntryKind.stay, price: 300),
          entry('c', EntryKind.stay, price: 400),
        ]);
        expect(ids, {'a', 'b'});
      });

      test('marks none with fewer than two priced options', () {
        expect(
          Combination.cheapestOf([
            entry('a', EntryKind.stay, price: 300),
            entry('b', EntryKind.stay),
          ]),
          isEmpty,
        );
        expect(Combination.cheapestOf(const []), isEmpty);
      });

      test('kinds do not compete', () {
        expect(
          Combination.cheapestOf([
            entry('a', EntryKind.stay, price: 100),
            entry('b', EntryKind.transport, price: 50),
          ]),
          isEmpty,
        );
      });
    });
  });

  group('TripPlan', () {
    final tr = trip(from: d(7, 10), to: d(7, 14));
    final flight = entry(
      'flight',
      EntryKind.transport,
      price: 40000,
      from: d(7, 10),
      to: d(7, 10),
      time: const TimeOfDay(hour: 7, minute: 10),
      endTime: const TimeOfDay(hour: 8, minute: 55),
      state: EntryState.booked,
      position: 1,
    );
    final stay = entry(
      'stay',
      EntryKind.stay,
      price: 90000,
      from: d(7, 10),
      to: d(7, 14),
      time: const TimeOfDay(hour: 15, minute: 0),
      endTime: const TimeOfDay(hour: 10, minute: 0),
      state: EntryState.chosen,
      position: 2,
    );
    final car = entry(
      'car',
      EntryKind.rental,
      from: d(7, 10),
      to: d(7, 14),
      time: const TimeOfDay(hour: 9, minute: 30),
      state: EntryState.chosen,
      position: 3,
    );
    final boat = entry(
      'boat',
      EntryKind.activity,
      price: 8000,
      from: d(7, 12),
      time: const TimeOfDay(hour: 10, minute: 0),
      state: EntryState.booked,
      position: 4,
    );
    final loose = entry(
      'loose',
      EntryKind.activity,
      state: EntryState.chosen,
      position: 5,
    );
    final option = entry(
      'opt',
      EntryKind.stay,
      price: 5,
      from: d(7, 10),
      to: d(7, 14),
      position: 6,
    );
    final outsider = entry(
      'outsider',
      EntryKind.activity,
      from: d(7, 20),
      state: EntryState.chosen,
      position: 7,
    );
    final plan = TripPlan.of(tr, [
      outsider,
      option,
      loose,
      boat,
      car,
      stay,
      flight,
      entry('other', EntryKind.stay, tripId: 't2', state: EntryState.chosen),
    ]);

    test('has a day for each day of the trip', () {
      expect(plan.days.map((e) => e.date), [
        d(7, 10),
        d(7, 11),
        d(7, 12),
        d(7, 13),
        d(7, 14),
      ]);
      expect(plan.days.map((e) => e.dayNumber), [1, 2, 3, 4, 5]);
    });

    test('puts a day\'s items in time order with the right role', () {
      final first = plan.days.first;
      expect(first.items.map((i) => (i.entry.id, i.role)), [
        ('flight', PlanRole.single),
        ('car', PlanRole.start),
        ('stay', PlanRole.start),
      ]);
      expect(first.items.map((i) => i.time), [
        const TimeOfDay(hour: 7, minute: 10),
        const TimeOfDay(hour: 9, minute: 30),
        const TimeOfDay(hour: 15, minute: 0),
      ]);
      expect(plan.days[2].items.map((i) => (i.entry.id, i.role)), [
        ('boat', PlanRole.single),
      ]);
      final last = plan.days.last;
      expect(last.items.map((i) => (i.entry.id, i.role)), [
        ('car', PlanRole.end),
        ('stay', PlanRole.end),
      ]);
      // The check-out time, not the check-in time.
      expect(last.items.last.time, const TimeOfDay(hour: 10, minute: 0));
    });

    test('a stay and a rental continue through the days in between', () {
      expect(plan.days[1].items, isEmpty);
      expect(plan.days[1].ongoing.map((i) => (i.entry.id, i.role)), [
        ('stay', PlanRole.during),
        ('car', PlanRole.during),
      ]);
      expect(plan.days.first.ongoing, isEmpty);
    });

    test('knows where the family sleeps each night', () {
      for (final day in [10, 11, 12, 13]) {
        expect(plan.stayTonight(d(7, day))!.id, 'stay');
      }
      // The check-out day has no night in the stay.
      expect(plan.stayTonight(d(7, 14)), isNull);
      expect(plan.stayTonight(d(7, 20)), isNull);
    });

    test(
      'lists what has no date, what is only an option and what lies outside',
      () {
        expect(plan.undated.map((e) => e.id), ['loose']);
        expect(plan.options.map((e) => e.id), ['opt']);
        expect(plan.outside.map((e) => e.id), ['outsider']);
      },
    );

    test(
      'adds up the chosen and the booked and says when a price is missing',
      () {
        expect(plan.sum, 138000);
        expect(plan.incomplete, isTrue);
        final complete = TripPlan.of(tr, [flight, stay]);
        expect(complete.sum, 130000);
        expect(complete.incomplete, isFalse);
      },
    );

    test('items without a time come first, ties keep the trip\'s order', () {
      final a = entry(
        'a',
        EntryKind.activity,
        from: d(7, 11),
        state: EntryState.chosen,
        position: 1,
      );
      final b = entry(
        'b',
        EntryKind.activity,
        from: d(7, 11),
        state: EntryState.chosen,
        position: 2,
      );
      final timed = entry(
        't',
        EntryKind.activity,
        from: d(7, 11),
        time: const TimeOfDay(hour: 8, minute: 0),
        state: EntryState.chosen,
        position: 0,
      );
      final p = TripPlan.of(tr, [timed, b, a]);
      expect(p.days[1].items.map((i) => i.entry.id), ['a', 'b', 't']);
    });

    test(
      'an entry partly outside shows on the days it covers and is flagged',
      () {
        final early = entry(
          'early',
          EntryKind.stay,
          from: d(7, 8),
          to: d(7, 11),
          state: EntryState.chosen,
        );
        final p = TripPlan.of(tr, [early]);
        expect(p.days.first.ongoing.single.role, PlanRole.during);
        expect(p.days[1].items.single.role, PlanRole.end);
        expect(p.outside.map((e) => e.id), ['early']);
      },
    );

    test(
      'a trip without dates has no days and lists dated entries as outside',
      () {
        final p = TripPlan.of(trip(stage: TripStage.idea, dated: false), [
          entry(
            'x',
            EntryKind.stay,
            from: d(7, 1),
            to: d(7, 3),
            state: EntryState.chosen,
          ),
          entry('y', EntryKind.stay, state: EntryState.chosen),
        ]);
        expect(p.days, isEmpty);
        expect(p.outside.map((e) => e.id), ['x']);
        expect(p.undated.map((e) => e.id), ['y']);
        expect(p.stayTonight(d(7, 1)), isNull);
      },
    );
  });

  group('TripToday', () {
    final tr = trip(from: d(7, 10), to: d(7, 19));
    final stay = entry(
      'stay',
      EntryKind.stay,
      from: d(7, 10),
      to: d(7, 19),
      state: EntryState.booked,
    );
    final boat = entry(
      'boat',
      EntryKind.activity,
      from: d(7, 12),
      time: const TimeOfDay(hour: 10, minute: 0),
      state: EntryState.booked,
    );
    final tomorrow = entry(
      'museum',
      EntryKind.activity,
      from: d(7, 13),
      time: const TimeOfDay(hour: 9, minute: 0),
      state: EntryState.chosen,
    );
    TripCheck todo(String id, int days, {bool done = false}) => TripCheck(
      id: id,
      tripId: 't1',
      kind: CheckKind.todo,
      title: id,
      dueDaysBefore: days,
      doneAt: done ? d(1, 1) : null,
    );
    TripCheck pack(String id, {bool done = false}) => TripCheck(
      id: id,
      tripId: 't1',
      kind: CheckKind.pack,
      title: id,
      doneAt: done ? d(1, 1) : null,
    );

    test('is nothing for a trip that is far away, past or not fixed', () {
      TripToday? at(DateTime day, [Trip? t]) => TripToday.of(
        trips: [t ?? tr],
        entries: const [],
        checks: const [],
        today: day,
      );
      expect(at(d(6, 9)), isNull); // 31 days before
      expect(at(d(7, 20)), isNull);
      expect(at(d(7, 1), trip(stage: TripStage.planned)), isNull);
      expect(at(d(7, 1), trip(stage: TripStage.idea, dated: false)), isNull);
      expect(
        TripToday.of(
          trips: const [],
          entries: const [],
          checks: const [],
          today: d(7, 1),
        ),
        isNull,
      );
    });

    test(
      'before the trip: days left, the to-dos that are due, the packing',
      () {
        final c = TripToday.of(
          trips: [tr],
          entries: [stay, boat],
          checks: [
            todo('due', 21), // due 19 June
            todo('later', 3), // due 7 July
            todo('done', 21, done: true),
            TripCheck(
              id: 'nodue',
              tripId: 't1',
              kind: CheckKind.todo,
              title: 'x',
            ),
            pack('a', done: true),
            pack('b'),
            pack('c'),
          ],
          today: d(7, 1),
        )!;
        expect(c.phase, TripTodayPhase.before);
        expect(c.running, isFalse);
        expect(c.daysLeft, 9);
        expect(c.dayNumber, isNull);
        expect(c.dayCount, 10);
        expect(c.dueTodos.map((e) => e.id), ['due']);
        expect(c.packed, 1);
        expect(c.packTotal, 3);
        expect(c.todayItems, isEmpty);
      },
    );

    test('appears 30 days before and not 31', () {
      final far = TripToday.of(
        trips: [tr],
        entries: const [],
        checks: const [],
        today: d(6, 10),
      );
      expect(far!.daysLeft, 30);
    });

    test(
      'during the trip: the day, today\'s plan, tonight\'s stay, tomorrow',
      () {
        final c = TripToday.of(
          trips: [tr],
          entries: [stay, boat, tomorrow],
          checks: const [],
          today: DateTime(2027, 7, 12, 14, 30),
        )!;
        expect(c.running, isTrue);
        expect(c.daysLeft, 0);
        expect(c.dayNumber, 3);
        expect(c.dayCount, 10);
        expect(c.todayItems.map((i) => i.entry.id), ['boat']);
        expect(c.stayTonight!.id, 'stay');
        expect(c.tomorrowFirst!.entry.id, 'museum');
      },
    );

    test('on the last day there is no tomorrow and no night', () {
      final c = TripToday.of(
        trips: [tr],
        entries: [stay],
        checks: const [],
        today: d(7, 19),
      )!;
      expect(c.tomorrowFirst, isNull);
      expect(c.stayTonight, isNull);
      expect(c.dayNumber, 10);
    });

    test('a running trip wins over a nearer one that has not begun', () {
      final next = trip(id: 't2', from: d(7, 14), to: d(7, 16));
      final c = TripToday.of(
        trips: [next, tr],
        entries: const [],
        checks: const [],
        today: d(7, 12),
      )!;
      expect(c.trip.id, 't1');
    });

    test('of two upcoming trips the nearest is shown', () {
      final soon = trip(id: 'soon', from: d(7, 3), to: d(7, 5));
      final c = TripToday.of(
        trips: [tr, soon],
        entries: const [],
        checks: const [],
        today: d(7, 1),
      )!;
      expect(c.trip.id, 'soon');
    });
  });

  group('Occurrence and CalendarEvent', () {
    final occurrence = {
      'id': 'o',
      'event_id': 'e',
      'calendar_id': 'c',
      'title': 'Sardinien',
      'kind': 'appointment',
      'all_day': true,
      'start': '2027-07-10T00:00:00Z',
      'end': '2027-07-19T00:00:00Z',
      'local_start_date': '2027-07-10',
      'local_end_date': '2027-07-19',
    };

    test('an occurrence knows its trip, and older servers send none', () {
      expect(
        Occurrence.fromJson({...occurrence, 'trip_id': 't1'}).tripId,
        't1',
      );
      expect(Occurrence.fromJson(occurrence).tripId, isNull);
    });

    test('an event knows its trip but never sends it', () {
      final e = CalendarEvent.fromJson({
        'id': 'e',
        'title': 'Sardinien',
        'kind': 'appointment',
        'is_all_day': true,
        'start_date': '2027-07-10',
        'end_date': '2027-07-19',
        'trip_id': 't1',
      });
      expect(e.tripId, 't1');
      expect(e.toJson().containsKey('trip_id'), isFalse);
    });
  });

  group('the windows and discovery requests', () {
    test('windows ask with the keys of the contract', () {
      expect(
        TripWindowsArgs(
          from: d(1, 1),
          to: d(6, 1),
          minDays: 7,
          memberIds: ['a'],
          tripId: 't',
        ).toJson(),
        {
          'action': 'windows',
          'from': '2027-01-01',
          'to': '2027-06-01',
          'min_days': 7,
          'member_ids': ['a'],
          'trip_id': 't',
        },
      );
      expect(const TripWindowsArgs().toJson(), {'action': 'windows'});
    });

    test('arguments compare by value, so they can key a provider', () {
      expect(
        TripWindowsArgs(from: d(1, 1), memberIds: ['a', 'b']),
        TripWindowsArgs(from: d(1, 1), memberIds: ['a', 'b']),
      );
      expect(
        TripWindowsArgs(from: d(1, 1)).hashCode,
        TripWindowsArgs(from: d(1, 1)).hashCode,
      );
      expect(
        TripDiscoverArgs(
          from: d(7, 1),
          to: d(7, 14),
          filters: const DiscoverFilters(tags: ['sea'], dry: true),
        ),
        TripDiscoverArgs(
          from: d(7, 1),
          to: d(7, 14),
          filters: const DiscoverFilters(tags: ['sea'], dry: true),
        ),
      );
      expect(const DiscoverFilters(dry: true), isNot(const DiscoverFilters()));
    });

    test('filters write only what is set', () {
      expect(const DiscoverFilters().toJson(), isEmpty);
      expect(const DiscoverFilters().isEmpty, isTrue);
      expect(
        const DiscoverFilters(
          tempMin: 24,
          dry: true,
          seaMin: 20,
          tags: ['sea', 'island'],
          effort: TravelEffort.car,
        ).toJson(),
        {
          'temp_min': 24.0,
          'dry': true,
          'sea_min': 20.0,
          'tags': ['sea', 'island'],
          'effort': 'car',
        },
      );
    });

    test('reads a window and a discovery answer', () {
      final w = TripWindow.fromJson({
        'from': '2027-07-10',
        'to': '2027-07-24',
        'days': 15,
        'name': 'Sommerferien',
        'kind': 'holidays',
        'leave_days': 10,
        'partial': [
          {'profile_id': 'p', 'from': '2027-07-10', 'to': '2027-07-11'},
        ],
        'conflicts': [
          {
            'date': '2027-07-15',
            'title': 'Dienstreise',
            'event_id': 'e',
            'kind': 'presence',
            'presence_state': 'travel',
            'profile_ids': ['p'],
          },
        ],
      });
      expect(w.kind, WindowKind.holidays);
      expect(w.partial.single.to, d(7, 11));
      expect(w.conflicts.single.presenceState, 'travel');
      expect(w.hasConflicts, isTrue);
      final r = DiscoverResult.fromJson({
        'places': [
          {
            'key': 'sardinia',
            'name': 'Sardinien',
            'country': 'IT',
            'lat': 40.9,
            'lon': 9.5,
            'tags': ['sea'],
            'km': 780,
            'effort': 'car',
            'climate': {'tmax': 30, 'tmin': 20, 'sea': 24},
            'fits': 'yes',
          },
          {
            'trip_id': 'idea',
            'name': 'Nordsee',
            'country': 'DE',
            'lat': 54.9,
            'lon': 8.3,
            'tags': <String>[],
            'fits': 'unknown',
          },
        ],
        'pending': 2,
        'provider': 'open-meteo',
        'attribution': 'x',
      });
      expect(r.places.first.effort, TravelEffort.car);
      expect(r.places.first.fits, DiscoverFit.yes);
      expect(r.places.first.climate!.sea, 24);
      expect(r.places.last.isIdea, isTrue);
      expect(r.places.last.climate, isNull);
      expect(r.pending, 2);
    });
  });

  group('packing starters', () {
    test('has about twenty-five unique items in known groups', () {
      expect(packingStarters.length, inInclusiveRange(20, 32));
      expect(
        packingStarters.map((s) => s.id).toSet().length,
        packingStarters.length,
      );
      expect(
        packingStarters.map((s) => s.group).toSet(),
        PackingGroup.values.toSet(),
      );
      expect(packingStarters.first.arbKey, 'tripPackStarterPassports');
    });

    test('builds one check per person for personal items', () {
      final checks = buildStarterChecks(
        tripId: 't1',
        titleOf: (s) => s.id,
        travellers: ['mama', 'papa', 'kid'],
        children: ['kid'],
      );
      expect(checks.every((c) => c.kind == CheckKind.pack), isTrue);
      expect(
        checks.where((c) => c.title == 'passports').map((c) => c.profileId),
        ['mama', 'papa', 'kid'],
      );
      expect(
        checks.where((c) => c.title == 'cuddlyToy').map((c) => c.profileId),
        ['kid'],
      );
      expect(
        checks.where((c) => c.title == 'pharmacyBag').map((c) => c.profileId),
        [null],
      );
      expect(checks.map((c) => c.id).toSet().length, checks.length);
    });

    test('without travellers a personal item goes to the family once', () {
      final checks = buildStarterChecks(
        tripId: 't1',
        titleOf: (s) => s.id,
        travellers: const [],
        children: const [],
      );
      expect(
        checks.where((c) => c.title == 'passports').single.profileId,
        isNull,
      );
      expect(checks.where((c) => c.title == 'cuddlyToy'), isEmpty);
    });
  });

  group('guessing what a booking is', () {
    GuessedKind guess(String title, [String? description]) =>
        guessEntryKind(title, description);

    void expectTransport(String title, TransportMode mode) {
      final g = guess(title);
      expect((g.kind, g.mode), (EntryKind.transport, mode), reason: title);
    }

    void expectKind(String title, EntryKind kind) =>
        expect(guess(title).kind, kind, reason: title);

    test('German', () {
      expectTransport('Flug LX1234 Zürich–Olbia', TransportMode.flight);
      expectTransport('Zugfahrt Zürich – Mailand', TransportMode.train);
      expectTransport('Bahn nach Hamburg', TransportMode.train);
      expectTransport('Fähre Livorno–Olbia', TransportMode.ferry);
      expectTransport('Fernbus nach Berlin', TransportMode.bus);
      expectKind('Ferienwohnung Cala Gonone', EntryKind.stay);
      expectKind('Hotel Sole, Check-in ab 15 Uhr', EntryKind.stay);
      expectKind('Unterkunft am Meer', EntryKind.stay);
      expectKind('Mietwagen Sixt Olbia', EntryKind.rental);
      expectKind('Bootstour La Maddalena', EntryKind.activity);
    });

    test('English', () {
      expectTransport('Flight to Olbia', TransportMode.flight);
      expectTransport('Train to Milan', TransportMode.train);
      expectTransport('Ferry crossing', TransportMode.ferry);
      expectTransport('Bus to the airport', TransportMode.bus);
      expectKind('Hotel Baia Blu', EntryKind.stay);
      expectKind('Apartment in Cala Gonone', EntryKind.stay);
      expectKind('Rental car pick-up', EntryKind.rental);
      expectKind('Car hire Europcar', EntryKind.rental);
      expectKind('Boat trip', EntryKind.activity);
    });

    test('French', () {
      expectTransport('Vol Genève–Olbia', TransportMode.flight);
      expectTransport('Train Paris–Lyon', TransportMode.train);
      expectTransport('Traversée Marseille–Ajaccio', TransportMode.ferry);
      expectKind('Hébergement à Cala Gonone', EntryKind.stay);
      expectKind('Camping Isuledda', EntryKind.stay);
      expectKind('Location de voiture à Olbia', EntryKind.rental);
      expectKind('Visite du musée', EntryKind.activity);
    });

    test('Spanish', () {
      expectTransport('Vuelo Madrid–Cagliari', TransportMode.flight);
      expectTransport('Tren a Barcelona', TransportMode.train);
      expectTransport('Ferri a Mallorca', TransportMode.ferry);
      expectTransport(
        'Autobús al aeropuerto'.replaceAll('Autobús', 'Autobus'),
        TransportMode.bus,
      );
      expectKind('Alojamiento en Cala Gonone', EntryKind.stay);
      expectKind('Alquiler de coche en Olbia', EntryKind.rental);
      expectKind('Excursión en barco', EntryKind.activity);
    });

    test('a rental car is not taken for a flight or a stay', () {
      expectKind('Mietwagen am Flughafen', EntryKind.rental);
      expect(
        guess('Flug nach Olbia, Online-Check-in offen').kind,
        EntryKind.transport,
      );
    });

    test('whole words only', () {
      expectKind('Business lunch', EntryKind.activity);
      expectKind('Volleyball', EntryKind.activity);
      expectKind('Trainingslager', EntryKind.activity);
    });

    test('the description decides when the title says nothing', () {
      final g = guess('Zürich → Milano', 'Train EC 123, 2nd class');
      expect((g.kind, g.mode), (EntryKind.transport, TransportMode.train));
      expect(guess('Ausflug', 'Treffpunkt am Hafen').kind, EntryKind.activity);
    });
  });

  group('a booking\'s calendar file', () {
    late tz.Location zurich;

    setUpAll(() {
      tzdata.initializeTimeZones();
      zurich = tz.getLocation('Europe/Zurich');
    });

    tz.Location? zoneOf(String name) {
      try {
        return tz.getLocation(name);
      } on tz.LocationNotFoundException {
        return null;
      }
    }

    Uint8List file(
      List<List<String>> events, {
      List<String> header = const [],
    }) => Uint8List.fromList(
      utf8.encode(
        [
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          ...header,
          for (final e in events) ...['BEGIN:VEVENT', ...e, 'END:VEVENT'],
          'END:VCALENDAR',
          '',
        ].join('\r\n'),
      ),
    );

    TripFileImport read(
      Uint8List bytes, {
      DateTime Function(DateTime)? toLocal,
    }) => tripEntriesFromCalendarFile(
      bytes,
      tripId: 't1',
      zoneOf: zoneOf,
      fallbackTitle: 'Termin',
      toLocal: toLocal,
    );

    test('every event becomes a booked entry of the trip', () {
      final r = read(
        file([
          [
            'UID:out@airline.example',
            'SUMMARY:Flug LX1234 ZRH-OLB',
            'DTSTART;TZID=Europe/Zurich:20270710T071000',
            'DTEND;TZID=Europe/Rome:20270710T085500',
            r'LOCATION:Flughafen Zürich\, Terminal 2',
            r'DESCRIPTION:Buchung ABC123\nGepäck inklusive',
            'URL:https://airline.example/booking/ABC123',
          ],
          [
            'UID:back@airline.example',
            'SUMMARY:Flug LX1235 OLB-ZRH',
            'DTSTART;TZID=Europe/Rome:20270719T174000',
            'DTEND;TZID=Europe/Zurich:20270719T192500',
          ],
        ]),
      );
      expect(r.skipped, 0);
      expect(r.entries, hasLength(2));
      final out = r.entries.first;
      expect(out.tripId, 't1');
      expect(out.state, EntryState.booked);
      expect(out.kind, EntryKind.transport);
      expect(out.mode, TransportMode.flight);
      expect(out.title, 'Flug LX1234 ZRH-OLB');
      expect(out.startsOn, DateTime(2027, 7, 10));
      expect(out.startsTime, const TimeOfDay(hour: 7, minute: 10));
      // The arrival is written in the arrival airport's own clock.
      expect(out.endsOn, DateTime(2027, 7, 10));
      expect(out.endsTime, const TimeOfDay(hour: 8, minute: 55));
      expect(out.address, 'Flughafen Zürich, Terminal 2');
      expect(out.note, 'Buchung ABC123\nGepäck inklusive');
      expect(out.url, 'https://airline.example/booking/ABC123');
      expect(out.sourceUid, 'out@airline.example');
      final back = r.entries.last;
      expect(back.startsTime, const TimeOfDay(hour: 17, minute: 40));
      expect(back.endsTime, const TimeOfDay(hour: 19, minute: 25));
      expect(back.url, isNull);
      expect(back.address, isNull);
      expect(out.id, isNot(back.id));
      expect(out.toImportJson()['state'], 'booked');
    });

    test('a floating time is taken as written', () {
      final r = read(
        file([
          [
            'UID:f',
            'SUMMARY:Hotel Sole',
            'DTSTART:20270710T150000',
            'DTEND:20270719T100000',
          ],
        ]),
      );
      final e = r.entries.single;
      expect(e.kind, EntryKind.stay);
      expect(e.startsOn, DateTime(2027, 7, 10));
      expect(e.startsTime, const TimeOfDay(hour: 15, minute: 0));
      expect(e.endsOn, DateTime(2027, 7, 19));
      expect(e.endsTime, const TimeOfDay(hour: 10, minute: 0));
    });

    test('a time in UTC is converted to the device\'s local time', () {
      final r = read(
        file([
          [
            'UID:u',
            'SUMMARY:Zug Zürich–Mailand',
            'DTSTART:20270710T053000Z',
            'DTEND:20270710T093000Z',
          ],
        ]),
        toLocal: (utc) => tz.TZDateTime.from(utc, zurich),
      );
      final e = r.entries.single;
      expect(e.mode, TransportMode.train);
      // 05:30 UTC is 07:30 in Zurich in July.
      expect(e.startsTime, const TimeOfDay(hour: 7, minute: 30));
      expect(e.endsTime, const TimeOfDay(hour: 11, minute: 30));
      expect(e.startsOn, DateTime(2027, 7, 10));
    });

    test('a UTC time that crosses midnight lands on the local date', () {
      final r = read(
        file([
          [
            'UID:u',
            'SUMMARY:Flight',
            'DTSTART:20270710T223000Z',
            'DTEND:20270710T233000Z',
          ],
        ]),
        toLocal: (utc) => tz.TZDateTime.from(utc, zurich),
      );
      final e = r.entries.single;
      expect(e.startsOn, DateTime(2027, 7, 11));
      expect(e.startsTime, const TimeOfDay(hour: 0, minute: 30));
    });

    test('an all-day event has dates only and an inclusive end', () {
      final r = read(
        file([
          [
            'UID:a',
            'SUMMARY:Ferienwohnung',
            'DTSTART;VALUE=DATE:20270710',
            'DTEND;VALUE=DATE:20270719',
          ],
          [
            'UID:b',
            'SUMMARY:Ausflug',
            'DTSTART;VALUE=DATE:20270712',
            'DTEND;VALUE=DATE:20270713',
          ],
        ]),
      );
      final a = r.entries.first;
      expect(a.startsOn, DateTime(2027, 7, 10));
      expect(a.endsOn, DateTime(2027, 7, 18));
      expect(a.startsTime, isNull);
      expect(a.endsTime, isNull);
      final b = r.entries.last;
      expect(b.startsOn, DateTime(2027, 7, 12));
      expect(b.endsOn, isNull);
    });

    test('an event without an end has none', () {
      final r = read(
        file([
          ['UID:n', 'SUMMARY:Check-in Hotel', 'DTSTART:20270710T150000'],
        ]),
      );
      expect(r.entries.single.endsOn, isNull);
      expect(r.entries.single.endsTime, isNull);
    });

    test('skips what the parser refuses and counts it', () {
      final r = read(
        file([
          [
            'UID:c',
            'SUMMARY:Cancelled flight',
            'STATUS:CANCELLED',
            'DTSTART:20270710T150000',
          ],
          ['UID:x', 'SUMMARY:No start'],
          ['UID:ok', 'SUMMARY:Hotel', 'DTSTART:20270710T150000'],
        ]),
      );
      expect(r.entries.single.sourceUid, 'ok');
      expect(r.skipped, 2);
    });

    test('a UID repeated in one file stays apart', () {
      final r = read(
        file([
          ['UID:same', 'SUMMARY:Flug hin', 'DTSTART:20270710T071000'],
          ['UID:same', 'SUMMARY:Flug zurück', 'DTSTART:20270719T174000'],
        ]),
      );
      expect(r.entries.map((e) => e.sourceUid), ['same', 'same#2']);
    });

    test('keeps only http and https links', () {
      final r = read(
        file([
          [
            'UID:1',
            'SUMMARY:A',
            'DTSTART:20270710T071000',
            'URL:javascript:alert(1)',
          ],
          [
            'UID:2',
            'SUMMARY:B',
            'DTSTART:20270710T071000',
            'URL:http://example.org/x',
          ],
        ]),
      );
      expect(r.entries.first.url, isNull);
      expect(r.entries.last.url, 'http://example.org/x');
    });

    test('names an event without a title', () {
      final r = read(
        file([
          ['UID:t', 'DTSTART:20270710T071000'],
        ]),
      );
      expect(r.entries.single.title, 'Termin');
    });

    test('a file that is not a calendar gives nothing', () {
      final r = read(Uint8List.fromList(utf8.encode('hello')));
      expect(r.entries, isEmpty);
      expect(r.skipped, 0);
    });

    test('the header and the time zones travel with each event', () {
      final parts = splitCalendarEvents(
        [
          'BEGIN:VCALENDAR',
          'VERSION:2.0',
          'BEGIN:VTIMEZONE',
          'TZID:Europe/Zurich',
          'END:VTIMEZONE',
          'BEGIN:VEVENT',
          'UID:1',
          'DTSTART:20270710T071000',
          'BEGIN:VALARM',
          'ACTION:DISPLAY',
          'END:VALARM',
          'END:VEVENT',
          'BEGIN:VEVENT',
          'UID:2',
          'DTSTART:20270711T071000',
          'END:VEVENT',
          'END:VCALENDAR',
        ].join('\n'),
      );
      expect(parts, hasLength(2));
      for (final p in parts) {
        expect(p, contains('BEGIN:VTIMEZONE'));
        expect(RegExp('BEGIN:VEVENT').allMatches(p), hasLength(1));
        expect(p.trim().endsWith('END:VCALENDAR'), isTrue);
      }
      expect(parts.first, contains('BEGIN:VALARM'));
      expect(parts.last, contains('UID:2'));
    });

    test('takes at most fifty events', () {
      final r = read(
        file([
          for (var i = 0; i < 53; i++)
            ['UID:e$i', 'SUMMARY:Hotel $i', 'DTSTART:20270710T150000'],
        ]),
      );
      expect(r.entries, hasLength(tripImportMaxEntries));
      expect(r.skipped, greaterThan(0));
    });
  });
}
