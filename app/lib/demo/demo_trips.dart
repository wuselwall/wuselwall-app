import 'dart:math' as math;

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_clock.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/trips/data/trips_repository.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// The great-circle distance between two points in kilometres.
double demoDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  double rad(double d) => d * math.pi / 180;
  final a =
      math.pow(math.sin(rad(lat2 - lat1) / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(rad(lon2 - lon1) / 2), 2);
  return 6371 * 2 * math.asin(math.sqrt(a.toDouble()));
}

String _t(String de, String en, String fr, String es) =>
    DemoData.tr4(de, en, fr, es);

/// The demo family's trips (specs/30): three ideas, a planned ski week and the fixed
/// Sardinia holiday that starts in twelve days, with three flights, three stays, two
/// rental cars, two stored combinations, a packing list and to-dos. Everything is in
/// memory and relative to the demo clock, so the screenshots look the same on any day;
/// writes work and are kept until the demo is reloaded.
class DemoTripsRepository implements TripsRepository {
  DemoTripsRepository({DateTime Function()? clock})
    : _clock = clock ?? DemoClock.now;

  final DateTime Function() _clock;

  DateTime get _today => dayOf(_clock());
  DateTime _in(int days) => addDays(_today, days);

  var _next = 100;
  String _id(String prefix) => '$prefix-${++_next}';

  late final _home = TripHome(
    name: _t('Zürich', 'Zurich', 'Zurich', 'Zúrich'),
    lat: 47.37,
    lon: 8.54,
  );
  TripHome? _homeNow;
  var _homeTouched = false;
  TripHome? get _currentHome => _homeTouched ? _homeNow : _home;

  late final List<Trip> _trips = [
    Trip(
      id: 'trip-sardinia',
      title: _t('Sardinien', 'Sardinia', 'Sardaigne', 'Cerdeña'),
      iconKey: 'beach',
      stage: TripStage.fixed,
      destinationName: _t('Sardinien', 'Sardinia', 'Sardaigne', 'Cerdeña'),
      destinationKey: 'sardinia',
      country: 'IT',
      lat: 40.92,
      lon: 9.5,
      startsOn: _in(12),
      endsOn: _in(21),
      note: _t(
        'Mit Oma und Opa am letzten Wochenende.',
        'With grandma and grandpa on the last weekend.',
        'Avec mamie et papi le dernier week-end.',
        'Con los abuelos el último fin de semana.',
      ),
      currency: 'CHF',
      eventId: 'ev-trip-sardinia',
      createdAt: _today.subtract(const Duration(days: 40)),
    ),
    Trip(
      id: 'trip-ski',
      title: _t(
        'Skiwoche Graubünden',
        'Ski week in the Grisons',
        'Semaine de ski aux Grisons',
        'Semana de esquí en los Grisones',
      ),
      iconKey: 'hiking',
      stage: TripStage.planned,
      destinationName: 'Davos',
      destinationKey: 'davos',
      country: 'CH',
      lat: 46.8,
      lon: 9.84,
      startsOn: _in(95),
      endsOn: _in(101),
      currency: 'CHF',
      eventId: 'ev-trip-ski',
      createdAt: _today.subtract(const Duration(days: 20)),
    ),
    Trip(
      id: 'trip-north-sea',
      title: _t('Nordsee', 'North Sea', 'Mer du Nord', 'Mar del Norte'),
      iconKey: 'swim',
      destinationName: 'Sylt',
      country: 'DE',
      lat: 54.9,
      lon: 8.3,
      createdAt: _today.subtract(const Duration(days: 60)),
    ),
    Trip(
      id: 'trip-tuscany',
      title: _t('Toskana', 'Tuscany', 'Toscane', 'Toscana'),
      iconKey: 'tent',
      destinationName: _t('Toskana', 'Tuscany', 'Toscane', 'Toscana'),
      destinationKey: 'tuscany',
      country: 'IT',
      lat: 43.4,
      lon: 11.2,
      note: _t(
        'Eine Ferienwohnung mit Pool wäre schön.',
        'A holiday flat with a pool would be nice.',
        'Un appartement de vacances avec piscine, ce serait bien.',
        'Un apartamento con piscina estaría bien.',
      ),
      createdAt: _today.subtract(const Duration(days: 35)),
    ),
    Trip(
      id: 'trip-denmark',
      title: _t(
        'Dänemark mit dem Camper',
        'Denmark by camper',
        'Danemark en camping-car',
        'Dinamarca en autocaravana',
      ),
      iconKey: 'house',
      destinationName: _t('Dänemark', 'Denmark', 'Danemark', 'Dinamarca'),
      country: 'DK',
      lat: 55.7,
      lon: 10.2,
      createdAt: _today.subtract(const Duration(days: 12)),
    ),
  ];

  TripEntry _flight(
    String id,
    String title,
    int cents,
    String details, {
    required int day,
    required TimeOfDay from,
    required TimeOfDay to,
    EntryState state = EntryState.option,
    String? ref,
    int? cancelIn,
    String fromPlace = 'ZRH',
    String toPlace = 'OLB',
    int position = 0,
  }) => TripEntry(
    id: id,
    tripId: 'trip-sardinia',
    kind: EntryKind.transport,
    mode: TransportMode.flight,
    title: title,
    state: state,
    url: 'https://example.org/flug/$id',
    priceCents: cents,
    priceCheckedOn: _in(-3),
    details: details,
    fromPlace: fromPlace,
    toPlace: toPlace,
    bookingRef: ref,
    cancelUntil: cancelIn == null ? null : _in(cancelIn),
    startsOn: _in(day),
    startsTime: from,
    endsOn: _in(day),
    endsTime: to,
    position: position,
  );

  late final List<TripEntry> _entries = [
    _flight(
      'e-fl-1',
      _t(
        'Direktflug Zürich–Olbia',
        'Direct flight Zurich–Olbia',
        'Vol direct Zurich–Olbia',
        'Vuelo directo Zúrich–Olbia',
      ),
      84000,
      _t(
        'Direkt, Gepäck inklusive',
        'Direct, luggage included',
        'Direct, bagage inclus',
        'Directo, equipaje incluido',
      ),
      day: 12,
      from: const TimeOfDay(hour: 7, minute: 10),
      to: const TimeOfDay(hour: 8, minute: 55),
      state: EntryState.chosen,
      cancelIn: 5,
      position: 1,
    ),
    _flight(
      'e-fl-2',
      _t(
        'Flug via Mailand',
        'Flight via Milan',
        'Vol via Milan',
        'Vuelo vía Milán',
      ),
      62000,
      _t(
        '1 Stopp, Gepäck inklusive',
        '1 stop, luggage included',
        '1 escale, bagage inclus',
        '1 escala, equipaje incluido',
      ),
      day: 12,
      from: const TimeOfDay(hour: 6, minute: 30),
      to: const TimeOfDay(hour: 11, minute: 40),
      cancelIn: -2,
      position: 2,
    ),
    _flight(
      'e-fl-3',
      _t(
        'Basel–Olbia (Billigflieger)',
        'Basel–Olbia (budget airline)',
        'Bâle–Olbia (compagnie low cost)',
        'Basilea–Olbia (aerolínea de bajo coste)',
      ),
      51000,
      _t(
        'Gepäck kostet extra',
        'Luggage costs extra',
        'Bagage en supplément',
        'El equipaje cuesta aparte',
      ),
      day: 12,
      from: const TimeOfDay(hour: 15, minute: 25),
      to: const TimeOfDay(hour: 17, minute: 5),
      fromPlace: 'BSL',
      position: 3,
    ),
    _flight(
      'e-fl-ret',
      _t(
        'Rückflug Olbia–Zürich',
        'Return flight Olbia–Zurich',
        'Vol retour Olbia–Zurich',
        'Vuelo de vuelta Olbia–Zúrich',
      ),
      79000,
      _t(
        'Direkt, Gepäck inklusive',
        'Direct, luggage included',
        'Direct, bagage inclus',
        'Directo, equipaje incluido',
      ),
      day: 21,
      from: const TimeOfDay(hour: 17, minute: 40),
      to: const TimeOfDay(hour: 19, minute: 25),
      state: EntryState.chosen,
      fromPlace: 'OLB',
      toPlace: 'ZRH',
      cancelIn: 5,
      position: 4,
    ),
    TripEntry(
      id: 'e-stay-1',
      tripId: 'trip-sardinia',
      kind: EntryKind.stay,
      title: _t(
        'Ferienwohnung Cala Gonone',
        'Holiday flat in Cala Gonone',
        'Appartement à Cala Gonone',
        'Apartamento en Cala Gonone',
      ),
      state: EntryState.booked,
      url: 'https://example.org/unterkunft/cala-gonone',
      priceCents: 189000,
      priceCheckedOn: _in(-6),
      details: _t(
        '2 Schlafzimmer, 300 m zum Strand',
        '2 bedrooms, 300 m to the beach',
        '2 chambres, 300 m de la plage',
        '2 dormitorios, a 300 m de la playa',
      ),
      bookingRef: 'CG-55120',
      cancelUntil: _in(4),
      address: 'Via Lungomare 14, 08022 Cala Gonone',
      phone: '+39 0784 000000',
      lat: 40.28,
      lon: 9.63,
      startsOn: _in(12),
      startsTime: const TimeOfDay(hour: 15, minute: 0),
      endsOn: _in(21),
      endsTime: const TimeOfDay(hour: 10, minute: 0),
      position: 5,
    ),
    TripEntry(
      id: 'e-stay-2',
      tripId: 'trip-sardinia',
      kind: EntryKind.stay,
      title: 'Hotel Baia Blu',
      url: 'https://example.org/unterkunft/baia-blu',
      priceCents: 261000,
      priceCheckedOn: _in(-3),
      details: _t(
        'Halbpension, Familienzimmer',
        'Half board, family room',
        'Demi-pension, chambre familiale',
        'Media pensión, habitación familiar',
      ),
      cancelUntil: _in(-1),
      address: 'Strada Costiera 2, 07028 Santa Teresa Gallura',
      startsOn: _in(12),
      endsOn: _in(21),
      position: 6,
    ),
    TripEntry(
      id: 'e-stay-3',
      tripId: 'trip-sardinia',
      kind: EntryKind.stay,
      title: 'Camping Isuledda',
      url: 'https://example.org/unterkunft/isuledda',
      priceCents: 98000,
      priceCheckedOn: _in(-9),
      details: _t(
        'Bungalow mit Küche',
        'Bungalow with kitchen',
        'Bungalow avec cuisine',
        'Bungalow con cocina',
      ),
      cancelUntil: _in(8),
      startsOn: _in(12),
      endsOn: _in(19),
      position: 7,
    ),
    TripEntry(
      id: 'e-car-1',
      tripId: 'trip-sardinia',
      kind: EntryKind.rental,
      title: 'Fiat Panda',
      state: EntryState.chosen,
      url: 'https://example.org/mietwagen/panda',
      priceCents: 52000,
      priceCheckedOn: _in(-4),
      details: _t(
        'Kleinwagen, Vollkasko',
        'Small car, fully insured',
        'Petite voiture, tous risques',
        'Coche pequeño, todo riesgo',
      ),
      fromPlace: _t(
        'Flughafen Olbia',
        'Olbia airport',
        'Aéroport d’Olbia',
        'Aeropuerto de Olbia',
      ),
      toPlace: _t(
        'Flughafen Olbia',
        'Olbia airport',
        'Aéroport d’Olbia',
        'Aeropuerto de Olbia',
      ),
      cancelUntil: _in(9),
      startsOn: _in(12),
      startsTime: const TimeOfDay(hour: 9, minute: 30),
      endsOn: _in(21),
      endsTime: const TimeOfDay(hour: 15, minute: 0),
      position: 8,
    ),
    TripEntry(
      id: 'e-car-2',
      tripId: 'trip-sardinia',
      kind: EntryKind.rental,
      title: _t(
        'Familienwagen Kombi',
        'Family estate car',
        'Break familial',
        'Familiar ranchera',
      ),
      url: 'https://example.org/mietwagen/kombi',
      priceCents: 69000,
      priceCheckedOn: _in(-4),
      details: _t(
        '5 Sitze, grosser Kofferraum',
        '5 seats, big boot',
        '5 places, grand coffre',
        '5 plazas, maletero grande',
      ),
      fromPlace: _t(
        'Flughafen Olbia',
        'Olbia airport',
        'Aéroport d’Olbia',
        'Aeropuerto de Olbia',
      ),
      toPlace: _t(
        'Flughafen Olbia',
        'Olbia airport',
        'Aéroport d’Olbia',
        'Aeropuerto de Olbia',
      ),
      startsOn: _in(13),
      endsOn: _in(21),
      position: 9,
    ),
    TripEntry(
      id: 'e-act-1',
      tripId: 'trip-sardinia',
      kind: EntryKind.activity,
      title: _t(
        'Bootstour La Maddalena',
        'Boat trip to La Maddalena',
        'Excursion en bateau à La Maddalena',
        'Excursión en barco a La Maddalena',
      ),
      state: EntryState.booked,
      url: 'https://example.org/ausflug/maddalena',
      priceCents: 34000,
      priceCheckedOn: _in(-5),
      bookingRef: 'MAD-4821',
      address: 'Porto di Palau, 07020 Palau',
      startsOn: _in(16),
      startsTime: const TimeOfDay(hour: 10, minute: 0),
      endsOn: _in(16),
      endsTime: const TimeOfDay(hour: 16, minute: 30),
      position: 10,
    ),
    TripEntry(
      id: 'e-act-2',
      tripId: 'trip-sardinia',
      kind: EntryKind.activity,
      title: _t(
        'Nuraghe Barumini',
        'Nuraghe Barumini',
        'Nuraghe de Barumini',
        'Nuraghe de Barumini',
      ),
      state: EntryState.chosen,
      priceCents: 6000,
      startsOn: _in(18),
      startsTime: const TimeOfDay(hour: 9, minute: 30),
      position: 11,
    ),
    TripEntry(
      id: 'e-note-1',
      tripId: 'trip-sardinia',
      kind: EntryKind.note,
      title: _t(
        'Opa bringt die Strandspielsachen mit',
        'Grandpa brings the beach toys',
        'Papi apporte les jouets de plage',
        'El abuelo trae los juguetes de playa',
      ),
      state: EntryState.chosen,
      startsOn: _in(20),
      position: 12,
    ),
  ];

  late final List<TripCombo> _combos = [
    TripCombo(
      id: 'c-1',
      tripId: 'trip-sardinia',
      name: _t('Günstig', 'Cheap', 'Économique', 'Económico'),
      entryIds: const ['e-fl-3', 'e-fl-ret', 'e-stay-3', 'e-car-1'],
      position: 1,
    ),
    TripCombo(
      id: 'c-2',
      tripId: 'trip-sardinia',
      name: _t(
        'Direktflug und Strandhotel',
        'Direct flight and beach hotel',
        'Vol direct et hôtel de plage',
        'Vuelo directo y hotel de playa',
      ),
      entryIds: const ['e-fl-1', 'e-fl-ret', 'e-stay-2', 'e-car-2'],
      position: 2,
    ),
  ];

  late final List<TripCheck> _checks = _initialChecks();

  List<TripCheck> _initialChecks() {
    var position = 0;
    TripCheck pack(String id, String title, {String? who, bool done = false}) =>
        TripCheck(
          id: id,
          tripId: 'trip-sardinia',
          kind: CheckKind.pack,
          title: title,
          profileId: who,
          doneAt: done ? _today.subtract(const Duration(days: 1)) : null,
          doneBy: done ? DemoData.mama : null,
          position: position++,
        );
    TripCheck todo(
      String id,
      String title,
      int daysBefore, {
      bool done = false,
    }) => TripCheck(
      id: id,
      tripId: 'trip-sardinia',
      kind: CheckKind.todo,
      title: title,
      dueDaysBefore: daysBefore,
      doneAt: done ? _today.subtract(const Duration(days: 2)) : null,
      doneBy: done ? DemoData.papa : null,
      position: position++,
    );
    return [
      todo(
        'k-t1',
        _t(
          'Pässe prüfen',
          'Check the passports',
          'Vérifier les passeports',
          'Revisar los pasaportes',
        ),
        21,
        done: true,
      ),
      todo(
        'k-t2',
        _t(
          'Katze: Nachbarn fragen',
          'Cat: ask the neighbours',
          'Chat : demander aux voisins',
          'Gato: pedir a los vecinos',
        ),
        14,
      ),
      todo(
        'k-t3',
        _t(
          'Online einchecken',
          'Check in online',
          'Enregistrement en ligne',
          'Facturar en línea',
        ),
        1,
      ),
      todo(
        'k-t4',
        _t(
          'Reiseversicherung abschliessen',
          'Take out travel insurance',
          'Souscrire une assurance voyage',
          'Contratar un seguro de viaje',
        ),
        14,
      ),
      pack(
        'k-p1',
        _t('Pässe', 'Passports', 'Passeports', 'Pasaportes'),
        done: true,
      ),
      pack(
        'k-p2',
        _t('Reiseapotheke', 'Pharmacy bag', 'Trousse de secours', 'Botiquín'),
        done: true,
      ),
      pack(
        'k-p3',
        _t('Sonnencreme', 'Sunscreen', 'Crème solaire', 'Protector solar'),
      ),
      pack(
        'k-p4',
        _t('Ladegeräte', 'Chargers', 'Chargeurs', 'Cargadores'),
        done: true,
      ),
      pack(
        'k-p5',
        _t('Badesachen', 'Swimwear', 'Maillots de bain', 'Bañadores'),
        who: DemoData.daughter,
      ),
      pack(
        'k-p6',
        _t('Badesachen', 'Swimwear', 'Maillots de bain', 'Bañadores'),
        who: DemoData.son,
      ),
      pack(
        'k-p7',
        _t('Kuscheltier', 'Cuddly toy', 'Doudou', 'Peluche'),
        who: DemoData.son,
      ),
      pack(
        'k-p8',
        _t('Sonnenhut', 'Sun hat', 'Chapeau de soleil', 'Gorro de sol'),
        who: DemoData.daughter,
      ),
    ];
  }

  // ── reads ─────────────────────────────────────────────────────────────────────────

  @override
  Future<Result<List<Trip>>> trips() async => Ok([..._trips]);

  @override
  Future<Result<List<TripEntry>>> entries() async => Ok([..._entries]);

  @override
  Future<Result<List<TripCombo>>> combos() async => Ok([..._combos]);

  @override
  Future<Result<List<TripCheck>>> checks() async => Ok([..._checks]);

  @override
  Future<Result<TripHome?>> home() async => Ok(_currentHome);

  // ── trips ─────────────────────────────────────────────────────────────────────────

  @override
  Future<Result<TripSaved>> saveTrip({
    required String? actor,
    required Trip trip,
  }) async => _store(trip.toJson());

  @override
  Future<Result<TripSaved>> patchTrip({
    required String? actor,
    required String id,
    required Map<String, dynamic> changes,
  }) async => _store({'id': id, ...changes});

  Result<TripSaved> _store(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final i = _trips.indexWhere((t) => t.id == id);
    final merged = {if (i >= 0) ..._trips[i].toJson(), ...json};
    final stage = TripStage.parse(merged['stage'] as String?);
    if (merged['title'] == null || (merged['title'] as String).trim().isEmpty) {
      return const Err(ValidationFailure(code: 'trip_invalid'));
    }
    if (stage != TripStage.idea && merged['starts_on'] == null) {
      return const Err(ValidationFailure(code: 'trip_invalid'));
    }
    final eventId = stage == TripStage.idea ? null : 'ev-$id';
    final saved = Trip.fromJson({
      ...merged,
      'currency': merged['currency'] ?? 'CHF',
      'event_id': eventId,
      'created_at': (i >= 0 ? _trips[i].createdAt : _clock())
          ?.toIso8601String(),
    });
    i >= 0 ? _trips[i] = saved : _trips.add(saved);
    return Ok(TripSaved(id: id, eventId: eventId));
  }

  @override
  Future<Result<void>> deleteTrip({
    required String? actor,
    required String id,
  }) async {
    _trips.removeWhere((t) => t.id == id);
    _entries.removeWhere((e) => e.tripId == id);
    _combos.removeWhere((c) => c.tripId == id);
    _checks.removeWhere((c) => c.tripId == id);
    return const Ok(null);
  }

  // ── entries ───────────────────────────────────────────────────────────────────────

  TripEntry _stamped(TripEntry entry, TripEntry? old) {
    final changed = entry.priceCents != old?.priceCents;
    return entry.copyWith(
      priceCheckedOn: entry.priceCents == null
          ? null
          : changed
          ? _today
          : old?.priceCheckedOn,
      position: old?.position ?? ++_next,
    );
  }

  @override
  Future<Result<String>> saveEntry({
    required String? actor,
    required TripEntry entry,
  }) async {
    if (entry.title.trim().isEmpty) {
      return const Err(ValidationFailure(code: 'trip_entry_invalid'));
    }
    final i = _entries.indexWhere((e) => e.id == entry.id);
    final stamped = _stamped(entry, i >= 0 ? _entries[i] : null);
    i >= 0 ? _entries[i] = stamped : _entries.add(stamped);
    return Ok(entry.id);
  }

  @override
  Future<Result<void>> deleteEntry({
    required String? actor,
    required String id,
  }) async {
    _entries.removeWhere((e) => e.id == id);
    _combos.replaceRange(0, _combos.length, [
      for (final c in _combos)
        c.copyWith(
          entryIds: [
            for (final e in c.entryIds)
              if (e != id) e,
          ],
        ),
    ]);
    return const Ok(null);
  }

  @override
  Future<Result<String>> copyEntry({
    required String? actor,
    required String id,
  }) async {
    final i = _entries.indexWhere((e) => e.id == id);
    if (i < 0) return const Err(NotFoundFailure(code: 'trip_entry_not_found'));
    final id2 = _id('e');
    _entries.insert(
      i + 1,
      _entries[i].copyWith(
        id: id2,
        state: EntryState.option,
        bookingRef: null,
        sourceUid: null,
        position: _entries[i].position + 1,
      ),
    );
    return Ok(id2);
  }

  @override
  Future<Result<EntriesImported>> importEntries({
    required String? actor,
    required String tripId,
    required List<TripEntry> entries,
  }) async {
    var added = 0;
    var updated = 0;
    for (final e in entries) {
      final uid = e.sourceUid;
      final i = uid == null
          ? -1
          : _entries.indexWhere(
              (x) => x.tripId == tripId && x.sourceUid == uid,
            );
      if (i >= 0) {
        _entries[i] = e.copyWith(
          id: _entries[i].id,
          position: _entries[i].position,
        );
        updated++;
      } else {
        _entries.add(_stamped(e, null));
        added++;
      }
    }
    return Ok(EntriesImported(added: added, updated: updated));
  }

  // ── combinations ──────────────────────────────────────────────────────────────────

  @override
  Future<Result<String>> saveCombo({
    required String? actor,
    required TripCombo combo,
  }) async {
    if (combo.name.trim().isEmpty || combo.entryIds.length > 40) {
      return const Err(ValidationFailure(code: 'trip_combo_invalid'));
    }
    final i = _combos.indexWhere((c) => c.id == combo.id);
    final stored = TripCombo(
      id: combo.id,
      tripId: combo.tripId,
      name: combo.name,
      entryIds: combo.entryIds,
      position: i >= 0 ? _combos[i].position : ++_next,
    );
    i >= 0 ? _combos[i] = stored : _combos.add(stored);
    return Ok(combo.id);
  }

  @override
  Future<Result<void>> deleteCombo({
    required String? actor,
    required String id,
  }) async {
    _combos.removeWhere((c) => c.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<ComboChoice>> chooseCombo({
    required String? actor,
    required String id,
    bool setDates = false,
  }) async {
    final combo = _combos.where((c) => c.id == id).firstOrNull;
    if (combo == null) {
      return const Err(NotFoundFailure(code: 'trip_combo_not_found'));
    }
    var chosen = 0;
    var released = 0;
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (e.tripId != combo.tripId) continue;
      if (combo.entryIds.contains(e.id)) {
        if (e.state == EntryState.option) {
          _entries[i] = e.copyWith(state: EntryState.chosen);
          chosen++;
        }
      } else if (e.state == EntryState.chosen && e.kind.comparable) {
        _entries[i] = e.copyWith(state: EntryState.option);
        released++;
      }
    }
    var datesSet = false;
    if (setDates) {
      final dated = [
        for (final e in _entries)
          if (combo.entryIds.contains(e.id) && e.startsOn != null) e,
      ];
      if (dated.isNotEmpty) {
        final from = dated
            .map((e) => e.startsOn!)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final to = dated
            .map((e) => e.lastDay!)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        final t = _trips.indexWhere((x) => x.id == combo.tripId);
        if (t >= 0) {
          _trips[t] = _trips[t].copyWith(
            startsOn: from,
            endsOn: to,
            stage: _trips[t].stage == TripStage.idea
                ? TripStage.planned
                : _trips[t].stage,
          );
          datesSet = true;
        }
      }
    }
    return Ok(
      ComboChoice(chosen: chosen, released: released, datesSet: datesSet),
    );
  }

  // ── checks ────────────────────────────────────────────────────────────────────────

  @override
  Future<Result<String>> saveCheck({
    required String? actor,
    required TripCheck check,
  }) async {
    if (check.title.trim().isEmpty) {
      return const Err(ValidationFailure(code: 'trip_check_invalid'));
    }
    final i = _checks.indexWhere((c) => c.id == check.id);
    final stored = TripCheck(
      id: check.id,
      tripId: check.tripId,
      kind: check.kind,
      title: check.title,
      profileId: check.profileId,
      dueDaysBefore: check.dueDaysBefore,
      doneAt: i >= 0 ? _checks[i].doneAt : null,
      doneBy: i >= 0 ? _checks[i].doneBy : null,
      position: i >= 0 ? _checks[i].position : ++_next,
    );
    i >= 0 ? _checks[i] = stored : _checks.add(stored);
    return Ok(check.id);
  }

  bool _has(String tripId, TripCheck c) => _checks.any(
    (x) =>
        x.tripId == tripId &&
        x.kind == c.kind &&
        x.profileId == c.profileId &&
        x.title.toLowerCase() == c.title.toLowerCase(),
  );

  @override
  Future<Result<int>> addChecks({
    required String? actor,
    required String tripId,
    required List<TripCheck> checks,
  }) async {
    var added = 0;
    for (final c in checks) {
      if (_has(tripId, c)) continue;
      _checks.add(
        TripCheck(
          id: _id('k'),
          tripId: tripId,
          kind: c.kind,
          title: c.title,
          profileId: c.profileId,
          dueDaysBefore: c.dueDaysBefore,
          position: ++_next,
        ),
      );
      added++;
    }
    return Ok(added);
  }

  @override
  Future<Result<int>> copyChecks({
    required String? actor,
    required String from,
    required String to,
  }) => addChecks(
    actor: actor,
    tripId: to,
    checks: [
      for (final c in _checks)
        if (c.tripId == from) c,
    ],
  );

  @override
  Future<Result<void>> tickCheck({
    required String? actor,
    required String id,
    required bool done,
  }) async {
    final i = _checks.indexWhere((c) => c.id == id);
    if (i < 0) return const Err(NotFoundFailure(code: 'trip_check_not_found'));
    final c = _checks[i];
    _checks[i] = TripCheck(
      id: c.id,
      tripId: c.tripId,
      kind: c.kind,
      title: c.title,
      profileId: c.profileId,
      dueDaysBefore: c.dueDaysBefore,
      doneAt: done ? _clock() : null,
      doneBy: done ? (actor ?? DemoData.papa) : null,
      position: c.position,
    );
    return const Ok(null);
  }

  @override
  Future<Result<void>> deleteCheck({
    required String? actor,
    required String id,
  }) async {
    _checks.removeWhere((c) => c.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<void>> setHome({
    required String? actor,
    required TripHome? home,
  }) async {
    _homeTouched = true;
    _homeNow = home;
    return const Ok(null);
  }

  // ── the `trips` function ──────────────────────────────────────────────────────────

  late final List<TripWindow> _windows = [
    TripWindow(
      from: _in(20),
      to: _in(23),
      days: 4,
      kind: WindowKind.longWeekend,
      leaveDays: 1,
    ),
    TripWindow(
      from: _in(40),
      to: _in(54),
      days: 15,
      kind: WindowKind.holidays,
      name: _t(
        'Herbstferien',
        'Autumn holidays',
        'Vacances d’automne',
        'Vacaciones de otoño',
      ),
      leaveDays: 10,
      partial: [
        WindowPartial(profileId: DemoData.son, from: _in(40), to: _in(41)),
      ],
    ),
    TripWindow(
      from: _in(100),
      to: _in(114),
      days: 15,
      kind: WindowKind.holidays,
      name: _t(
        'Weihnachtsferien',
        'Christmas holidays',
        'Vacances de Noël',
        'Vacaciones de Navidad',
      ),
      leaveDays: 9,
      conflicts: [
        WindowConflict(
          date: _in(103),
          title: _t(
            'Dienstreise Berlin',
            'Business trip to Berlin',
            'Voyage d’affaires à Berlin',
            'Viaje de trabajo a Berlín',
          ),
          eventId: 'ev-demo-berlin',
          kind: 'presence',
          presenceState: 'travel',
          profileIds: [DemoData.papa],
        ),
      ],
    ),
  ];

  @override
  Future<Result<List<TripWindow>>> windows(TripWindowsArgs args) async {
    final min = args.minDays ?? 4;
    return Ok([
      for (final w in _windows)
        if (w.days >= min &&
            (args.from == null || !w.to.isBefore(args.from!)) &&
            (args.to == null || !w.from.isAfter(args.to!)))
          w,
    ]);
  }

  /// Place, key, country, coordinates, tags, mean day temperature in July and in
  /// January, rain days in July, sea temperature in August (null: no sea).
  static const _places =
      <
        (
          String,
          String,
          double,
          double,
          List<String>,
          double,
          double,
          double,
          double?,
        )
      >[
        ('sardinia', 'IT', 40.92, 9.5, ['sea', 'island'], 30, 14, 3, 24),
        ('mallorca', 'ES', 39.7, 3.0, ['sea', 'island'], 31, 15, 2, 25),
        ('tuscany', 'IT', 43.4, 11.2, ['countryside'], 31, 10, 4, null),
        ('algarve', 'PT', 37.1, -8.2, ['sea'], 29, 16, 1, 22),
        ('crete', 'GR', 35.2, 24.9, ['sea', 'island'], 31, 15, 0, 25),
        ('north-sea', 'DE', 54.9, 8.3, ['sea', 'north'], 20, 3, 10, 17),
        ('davos', 'CH', 46.8, 9.84, ['mountains'], 20, -2, 11, null),
        ('lake-garda', 'IT', 45.6, 10.7, ['lake'], 29, 8, 6, 24),
        ('lisbon', 'PT', 38.7, -9.14, ['city', 'sea'], 29, 15, 1, 20),
        (
          'canary',
          'ES',
          28.1,
          -15.4,
          ['sea', 'island', 'long_haul'],
          26,
          21,
          0,
          22,
        ),
      ];

  @override
  Future<Result<DiscoverResult>> discover({
    required String? actor,
    required TripDiscoverArgs args,
  }) async {
    final home = _currentHome;
    // Mean of the window's months on a cosine between January and July.
    final middle = args.from.add(
      Duration(days: daysBetween(args.from, args.to) ~/ 2),
    );
    final summer = (1 - math.cos((middle.month - 1) / 12 * 2 * math.pi)) / 2;
    final f = args.filters;
    final places = <DiscoverPlace>[];
    for (final (key, country, lat, lon, tags, july, jan, rain, sea)
        in _places) {
      final tmax = jan + (july - jan) * summer;
      final km = home == null
          ? null
          : demoDistanceKm(home.lat, home.lon, lat, lon);
      final effort = km == null
          ? null
          : km <= 300
          ? TravelEffort.near
          : km <= 800
          ? TravelEffort.car
          : km <= 1500
          ? TravelEffort.short
          : km <= 4000
          ? TravelEffort.medium
          : TravelEffort.long;
      final seaNow = sea == null ? null : 12 + (sea - 12) * summer;
      final rainDays = rain * (0.5 + summer / 2);
      final fits =
          (f.tempMin == null || tmax >= f.tempMin!) &&
          (f.tempMax == null || tmax <= f.tempMax!) &&
          (!f.dry || rainDays <= 4) &&
          (f.seaMin == null || (seaNow != null && seaNow >= f.seaMin!)) &&
          f.tags.every(tags.contains) &&
          (f.effort == null ||
              effort == null ||
              effort.index <= f.effort!.index);
      places.add(
        DiscoverPlace(
          key: key,
          name: _placeName(key),
          country: country,
          lat: lat,
          lon: lon,
          tags: tags,
          km: km?.roundToDouble(),
          effort: effort,
          climate: DiscoverClimate(
            tmax: double.parse(tmax.toStringAsFixed(1)),
            tmin: double.parse((tmax - 9).toStringAsFixed(1)),
            rainDays: double.parse(rainDays.toStringAsFixed(1)),
            sunHours: double.parse((4 + 5 * summer).toStringAsFixed(1)),
            sea: seaNow == null
                ? null
                : double.parse(seaNow.toStringAsFixed(1)),
          ),
          fits: fits ? DiscoverFit.yes : DiscoverFit.no,
        ),
      );
    }
    places.sort((a, b) {
      final c =
          (a.fits == DiscoverFit.yes ? 0 : 1) -
          (b.fits == DiscoverFit.yes ? 0 : 1);
      return c != 0 ? c : (a.km ?? 0).compareTo(b.km ?? 0);
    });
    return Ok(
      DiscoverResult(
        places: places,
        provider: 'open-meteo',
        attribution: 'Weather data by Open-Meteo.com',
      ),
    );
  }

  String _placeName(String key) => switch (key) {
    'sardinia' => _t('Sardinien', 'Sardinia', 'Sardaigne', 'Cerdeña'),
    'mallorca' => 'Mallorca',
    'tuscany' => _t('Toskana', 'Tuscany', 'Toscane', 'Toscana'),
    'algarve' => 'Algarve',
    'crete' => _t('Kreta', 'Crete', 'Crète', 'Creta'),
    'north-sea' => _t('Nordsee', 'North Sea', 'Mer du Nord', 'Mar del Norte'),
    'davos' => 'Davos',
    'lake-garda' => _t(
      'Gardasee',
      'Lake Garda',
      'Lac de Garde',
      'Lago de Garda',
    ),
    'lisbon' => _t('Lissabon', 'Lisbon', 'Lisbonne', 'Lisboa'),
    _ => _t(
      'Kanarische Inseln',
      'Canary Islands',
      'Îles Canaries',
      'Islas Canarias',
    ),
  };
}
