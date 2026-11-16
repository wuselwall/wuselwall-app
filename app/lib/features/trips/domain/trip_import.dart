import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import 'package:wuselwall/features/calendar/domain/ics_import.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// A booking's calendar file as entries of a trip (specs/30 "A booking's calendar file").
/// Pure: no I/O.
///
/// [parseSharedEvent] reads one event per file and refuses a file with several UIDs, but
/// a booking confirmation often holds the outward and the return flight as two events. So
/// the file is cut into one calendar text per VEVENT here ([splitCalendarEvents]) and each
/// is read with the existing parser, unchanged; what the parser refuses (a cancelled
/// event, one without a readable start) is skipped and counted.

/// The most events one file may bring (`api.trip_entries_import` takes 50).
const tripImportMaxEntries = 50;

/// What a calendar file made of.
class TripFileImport {
  const TripFileImport({required this.entries, required this.skipped});

  /// One entry per readable event, state `booked`, ready for `importEntries`.
  final List<TripEntry> entries;

  /// Events of the file that were not taken (cancelled, no readable start, or more than
  /// [tripImportMaxEntries]).
  final int skipped;
}

/// Reads every event of [bytes] as an entry of the trip [tripId].
///
/// Times are the place's own wall clock, as written (specs/30 "Times are the place's
/// own"): a floating time and a time with a TZID are taken as the file writes them (a TZID
/// the database does not know is taken as written too). **A time in UTC (`...Z`) is
/// converted to the device's local time** with [toLocal] (default `DateTime.toLocal`),
/// since the file says nothing about where it happens; the family sees it in its own
/// clock. All-day events carry the date only, and the exclusive DTEND becomes the
/// inclusive last day. An event without DTEND and DURATION has no end.
///
/// [zoneOf] looks an IANA name up in the bundled timezone database. [fallbackTitle] names
/// an event the file left without a title.
///
/// A file without any readable event gives an empty list; a file that is not a calendar
/// file at all too (check [TripFileImport.skipped] to tell "nothing in it" apart).
TripFileImport tripEntriesFromCalendarFile(
  Uint8List bytes, {
  required String tripId,
  required tz.Location? Function(String name) zoneOf,
  String fallbackTitle = 'Event',
  DateTime Function(DateTime utc)? toLocal,
}) {
  final text = utf8.decode(bytes, allowMalformed: true);
  final blocks = splitCalendarEvents(text);
  final entries = <TripEntry>[];
  final seen = <String, int>{};
  var skipped = 0;
  for (final block in blocks) {
    if (entries.length >= tripImportMaxEntries) {
      skipped++;
      continue;
    }
    final ImportedEvent event;
    try {
      event = parseSharedEvent(
        Uint8List.fromList(utf8.encode(block)),
        zoneOf: zoneOf,
        // Floating times come out as written: read in UTC and shown in UTC.
        familyZone: tz.UTC,
      );
    } on IcsImportException {
      skipped++;
      continue;
    }
    entries.add(
      _entryOf(
        event,
        block,
        tripId: tripId,
        zoneOf: zoneOf,
        fallbackTitle: fallbackTitle,
        toLocal: toLocal ?? (d) => d.toLocal(),
        seen: seen,
      ),
    );
  }
  return TripFileImport(entries: entries, skipped: skipped);
}

/// Cuts a calendar file into one self-contained calendar text per VEVENT: the lines
/// outside every event (the calendar's header, VTIMEZONE) with that one event. A text
/// without any VEVENT gives an empty list. At most [tripImportMaxEntries] + 1 are
/// returned, so the caller sees that there were more.
List<String> splitCalendarEvents(String text) {
  final lines = text
      .replaceAll(RegExp(r'\r\n[ \t]|\n[ \t]|\r[ \t]'), '')
      .split(RegExp(r'\r\n|\n|\r'));
  final header = <String>[];
  final blocks = <List<String>>[];
  List<String>? current;
  for (final raw in lines) {
    final upper = raw.trim().toUpperCase();
    if (upper == 'BEGIN:VEVENT') {
      if (blocks.length > tripImportMaxEntries) break;
      current = [raw];
    } else if (upper == 'END:VEVENT' && current != null) {
      current.add(raw);
      blocks.add(current);
      current = null;
    } else if (current != null) {
      current.add(raw);
    } else if (upper != 'END:VCALENDAR' && raw.trim().isNotEmpty) {
      header.add(raw);
    }
  }
  if (!header.any((l) => l.trim().toUpperCase() == 'BEGIN:VCALENDAR')) {
    header.insert(0, 'BEGIN:VCALENDAR');
  }
  return [
    for (final block in blocks)
      [...header, ...block, 'END:VCALENDAR'].join('\r\n'),
  ];
}

TripEntry _entryOf(
  ImportedEvent event,
  String block, {
  required String tripId,
  required tz.Location? Function(String name) zoneOf,
  required String fallbackTitle,
  required DateTime Function(DateTime utc) toLocal,
  required Map<String, int> seen,
}) {
  final props = _properties(block);
  final guess = guessEntryKind(event.title, event.description);

  DateTime? startsOn;
  TimeOfDay? startsTime;
  DateTime? endsOn;
  TimeOfDay? endsTime;
  if (event.isAllDay) {
    startsOn = event.startDate;
    final last = event.endDate;
    endsOn = last != null && startsOn != null && last.isAfter(startsOn)
        ? last
        : null;
  } else {
    final start = _wall(
      event.startsAt!,
      utc: _isUtc(props['DTSTART']),
      zone: event.timezone == null ? null : zoneOf(event.timezone!),
      toLocal: toLocal,
    );
    startsOn = DateTime(start.year, start.month, start.day);
    startsTime = TimeOfDay(hour: start.hour, minute: start.minute);
    final hasEnd = props.containsKey('DTEND') || props.containsKey('DURATION');
    if (hasEnd) {
      final end = _wall(
        event.endsAt!,
        utc:
            _isUtc(props['DTEND']) ||
            !props.containsKey('DTEND') && _isUtc(props['DTSTART']),
        zone: event.timezone == null ? null : zoneOf(event.timezone!),
        toLocal: toLocal,
      );
      endsOn = DateTime(end.year, end.month, end.day);
      endsTime = TimeOfDay(hour: end.hour, minute: end.minute);
    }
  }

  var uid = event.uid;
  if (uid != null) {
    // Two events of one file may share a UID; the second needs its own to stay apart.
    final n = seen[uid] = (seen[uid] ?? 0) + 1;
    if (n > 1) uid = '$uid#$n';
  }

  return TripEntry(
    id: const Uuid().v4(),
    tripId: tripId,
    kind: guess.kind,
    mode: guess.mode,
    title: event.title.isEmpty ? fallbackTitle : event.title,
    state: EntryState.booked,
    url: _url(props['URL']),
    note: _cut(event.description ?? '', 4000),
    address: event.location == null ? null : _cut(event.location!, 300),
    startsOn: startsOn,
    startsTime: startsTime,
    endsOn: endsOn,
    endsTime: endsTime,
    sourceUid: uid,
  );
}

/// The first value of each property of an event block, by upper-case name (parameters
/// dropped, kept in front of the value as `;PARAM=...:`-less text: only the value).
Map<String, String> _properties(String block) {
  final out = <String, String>{};
  for (final raw in block.split(RegExp(r'\r\n|\n|\r'))) {
    final colon = raw.indexOf(':');
    if (colon <= 0) continue;
    final name = raw.substring(0, colon).split(';').first.trim().toUpperCase();
    out.putIfAbsent(name, () => raw.substring(colon + 1).trim());
  }
  return out;
}

bool _isUtc(String? value) =>
    value != null && value.toUpperCase().endsWith('Z');

({int year, int month, int day, int hour, int minute}) _wall(
  DateTime instant, {
  required bool utc,
  required tz.Location? zone,
  required DateTime Function(DateTime utc) toLocal,
}) {
  final DateTime w = utc
      ? toLocal(instant)
      : zone != null
      ? tz.TZDateTime.from(instant, zone)
      : instant.toUtc();
  return (
    year: w.year,
    month: w.month,
    day: w.day,
    hour: w.hour,
    minute: w.minute,
  );
}

String? _url(String? value) {
  if (value == null) return null;
  final text = value.replaceAll(r'\,', ',').replaceAll(r'\;', ';').trim();
  final uri = Uri.tryParse(text);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty ||
      text.length > 2000) {
    return null;
  }
  return text;
}

String _cut(String text, int max) {
  final runes = text.runes.toList();
  return runes.length <= max
      ? text
      : String.fromCharCodes(runes.take(max)).trimRight();
}

// ── guessing what an event is ──────────────────────────────────────────────────────

/// What an event looks like from its words.
class GuessedKind {
  const GuessedKind(this.kind, [this.mode]);

  final EntryKind kind;

  /// Only for a transport.
  final TransportMode? mode;
}

/// Guesses the kind (and for a transport the mode) from the words of [title] and, when
/// the title says nothing, of [description], in German, English, French and Spanish.
/// A rental car is recognised before a flight, a flight before a train, a train before a
/// ferry, a ferry before a bus, and any of them before a stay, because a flight's text
/// often says "check-in". Anything else is an activity.
GuessedKind guessEntryKind(String title, [String? description]) =>
    _guess(title) ??
    _guess(description ?? '') ??
    const GuessedKind(EntryKind.activity);

GuessedKind? _guess(String text) {
  if (text.trim().isEmpty) return null;
  final lower = text.toLowerCase();
  for (final (pattern, result) in _patterns) {
    if (pattern.hasMatch(lower)) return result;
  }
  return null;
}

RegExp _words(List<String> words) => RegExp(
  '(?<![\\p{L}\\p{N}])(?:${words.map(RegExp.escape).join('|')})(?![\\p{L}\\p{N}])',
  unicode: true,
);

final _patterns = <(RegExp, GuessedKind)>[
  (
    _words([
      'rental car',
      'car rental',
      'car hire',
      'hire car',
      'mietwagen',
      'mietauto',
      'autovermietung',
      'location de voiture',
      'location de véhicule',
      'location voiture',
      'voiture de location',
      'alquiler de coche',
      'alquiler de coches',
      'alquiler de auto',
      'alquiler de vehículo',
      'coche de alquiler',
      'sixt',
      'europcar',
      'hertz',
    ]),
    const GuessedKind(EntryKind.rental),
  ),
  (
    _words([
      'flight',
      'flights',
      'flug',
      'flüge',
      'flugzeug',
      'abflug',
      'vol',
      'vols',
      'vuelo',
      'vuelos',
      'airline',
      'easyjet',
      'ryanair',
      'lufthansa',
      'eurowings',
      'edelweiss',
      'vueling',
    ]),
    const GuessedKind(EntryKind.transport, TransportMode.flight),
  ),
  (
    _words([
      'train',
      'zug',
      'zugfahrt',
      'zugreise',
      'bahn',
      'bahnfahrt',
      'tren',
      'tgv',
      'sbb',
      'sncf',
      'renfe',
      'trenitalia',
      'eurostar',
      'railjet',
      'nightjet',
    ]),
    const GuessedKind(EntryKind.transport, TransportMode.train),
  ),
  (
    _words([
      'ferry',
      'ferries',
      'fähre',
      'faehre',
      'ferri',
      'traversée',
      'transbordador',
      'moby',
      'tirrenia',
    ]),
    const GuessedKind(EntryKind.transport, TransportMode.ferry),
  ),
  (
    _words(['bus', 'autobus', 'autocar', 'flixbus', 'reisebus', 'fernbus']),
    const GuessedKind(EntryKind.transport, TransportMode.bus),
  ),
  (
    _words([
      'hotel',
      'apartment',
      'appartement',
      'apartamento',
      'ferienwohnung',
      'ferienhaus',
      'unterkunft',
      'check-in',
      'check in',
      'checkin',
      'check-out',
      'hébergement',
      'hebergement',
      'alojamiento',
      'camping',
      'campingplatz',
      'hostel',
      'airbnb',
      'b&b',
      'gîte',
      'gite',
      'chalet',
      'resort',
      'pension',
      'pensión',
      'albergue',
      'auberge',
      'logement',
      'accommodation',
      'lodging',
      'übernachtung',
    ]),
    const GuessedKind(EntryKind.stay),
  ),
];
