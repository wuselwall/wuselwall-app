import 'dart:convert';
import 'dart:typed_data';

import 'package:timezone/timezone.dart' as tz;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';

/// Reads one event from a calendar file somebody sent the family (specs/05 "Sharing one
/// event", the receiving side). Pure: no I/O.
///
/// The file is a stranger's text, so the reader is strict and small: one event per file,
/// a size cap, text cut to the lengths the server stores, and nothing else of the file is
/// kept (no alarms, attendees, organiser, attachments or links). A guardian sees the
/// result before anything is saved.

/// The largest file read. A single event with a long note is a few kilobytes.
const icsImportMaxBytes = 256 * 1024;

/// Why a file is not taken.
enum IcsImportProblem {
  /// Larger than [icsImportMaxBytes].
  tooLarge,

  /// Not an iCalendar file, or one without an event or without a readable start.
  notAnEvent,

  /// Several different events: a whole calendar belongs under "Kalender von außen".
  severalEvents,

  /// The sender cancelled the event.
  cancelled,
}

class IcsImportException implements Exception {
  const IcsImportException(this.problem);

  final IcsImportProblem problem;

  @override
  String toString() => 'IcsImportException(${problem.name})';
}

/// What a file says about its one event.
class ImportedEvent {
  const ImportedEvent({
    required this.title,
    required this.isAllDay,
    this.description,
    this.location,
    this.startsAt,
    this.endsAt,
    this.startDate,
    this.endDate,
    this.timezone,
    this.rrule,
    this.rdates = const [],
    this.exdates = const [],
    this.uid,
    this.sequence = 0,
    this.tentative = false,
    this.repeatDropped = false,
  });

  /// Empty when the file names none.
  final String title;
  final String? description;
  final String? location;
  final bool isAllDay;

  /// Timed events: instants (UTC).
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// All-day events: local dates, [endDate] inclusive.
  final DateTime? startDate;
  final DateTime? endDate;

  /// The IANA zone the file names, when the bundled database knows it; null: the
  /// family's zone.
  final String? timezone;
  final String? rrule;
  final List<DateTime> rdates;
  final List<DateTime> exdates;

  /// The file's UID, by which a second copy of the same event is recognised.
  final String? uid;
  final int sequence;
  final bool tentative;

  /// The file repeats in a way the calendar cannot store; only the first date is kept.
  final bool repeatDropped;

  /// The event as the family's own. [id] set: the copy received earlier, to be replaced.
  CalendarEvent toEvent({
    required String fallbackTitle,
    List<String> attendeeIds = const [],
    String? id,
  }) => CalendarEvent(
    id: id,
    title: title.isEmpty ? fallbackTitle : title,
    description: description,
    location: location,
    kind: EventKind.appointment,
    status: tentative ? EventStatus.tentative : EventStatus.confirmed,
    isAllDay: isAllDay,
    startsAt: startsAt,
    endsAt: endsAt,
    startDate: startDate,
    endDate: endDate,
    timezone: timezone,
    rrule: rrule,
    rdates: rdates,
    exdates: exdates,
    attendeeIds: attendeeIds,
  );
}

/// One content line: `NAME;PARAM=value:VALUE`.
class _Line {
  _Line(this.name, this.params, this.value);

  final String name;
  final Map<String, String> params;
  final String value;
}

/// Splits [text] at [separator] outside double quotes.
List<String> _split(String text, String separator, {int? limit}) {
  final parts = <String>[];
  final current = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch == '"') quoted = !quoted;
    if (ch == separator &&
        !quoted &&
        (limit == null || parts.length < limit - 1)) {
      parts.add(current.toString());
      current.clear();
    } else {
      current.write(ch);
    }
  }
  parts.add(current.toString());
  return parts;
}

_Line? _parseLine(String raw) {
  final halves = _split(raw, ':', limit: 2);
  if (halves.length < 2) return null;
  final head = _split(halves[0], ';');
  final params = <String, String>{};
  for (final p in head.skip(1)) {
    final at = p.indexOf('=');
    if (at <= 0) continue;
    params[p.substring(0, at).toUpperCase()] = p
        .substring(at + 1)
        .replaceAll('"', '');
  }
  return _Line(head.first.trim().toUpperCase(), params, halves[1]);
}

/// Undoes the TEXT escaping (RFC 5545 3.3.11) and drops control characters.
String _text(String value, {required int max, bool multiline = false}) {
  final out = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final ch = value[i];
    if (ch == r'\' && i + 1 < value.length) {
      final next = value[++i];
      out.write(next == 'n' || next == 'N' ? '\n' : next);
    } else {
      out.write(ch);
    }
  }
  var text = out
      .toString()
      .replaceAll(RegExp(r'[\u0000-\u0009\u000B-\u001F\u007F]'), '')
      .trim();
  if (!multiline) text = text.replaceAll(RegExp(r'\s*\n\s*'), ' ');
  // Cut on a code point, never inside a surrogate pair.
  final runes = text.runes.toList();
  return runes.length <= max
      ? text
      : String.fromCharCodes(runes.take(max)).trimRight();
}

/// The Windows zone names Outlook writes, for the zones the app's languages live in.
const _windowsZones = {
  'W. Europe Standard Time': 'Europe/Berlin',
  'Central Europe Standard Time': 'Europe/Budapest',
  'Central European Standard Time': 'Europe/Warsaw',
  'Romance Standard Time': 'Europe/Paris',
  'GMT Standard Time': 'Europe/London',
  'Greenwich Standard Time': 'Atlantic/Reykjavik',
  'E. Europe Standard Time': 'Europe/Chisinau',
  'FLE Standard Time': 'Europe/Helsinki',
  'GTB Standard Time': 'Europe/Bucharest',
  'Turkey Standard Time': 'Europe/Istanbul',
  'Eastern Standard Time': 'America/New_York',
  'Central Standard Time': 'America/Chicago',
  'Mountain Standard Time': 'America/Denver',
  'Pacific Standard Time': 'America/Los_Angeles',
  'SA Pacific Standard Time': 'America/Bogota',
  'Central Standard Time (Mexico)': 'America/Mexico_City',
  'Argentina Standard Time': 'America/Argentina/Buenos_Aires',
  'UTC': 'UTC',
};

final _dateOnly = RegExp(r'^(\d{4})(\d{2})(\d{2})$');
final _dateTime = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})?(Z)?$');
final _duration = RegExp(
  r'^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
);

/// The parts of a repeat rule the server stores (`app.rrule_valid`).
final _rrulePart = RegExp(
  r'^(FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)|INTERVAL=[1-9][0-9]{0,2}|COUNT=[1-9][0-9]{0,3}'
  r'|UNTIL=[0-9]{8}(T[0-9]{6}Z)?'
  r'|BYDAY=([+-]?[0-9]{1,2})?(MO|TU|WE|TH|FR|SA|SU)(,([+-]?[0-9]{1,2})?(MO|TU|WE|TH|FR|SA|SU))*'
  r'|BYMONTHDAY=-?[0-9]{1,2}(,-?[0-9]{1,2})*|BYMONTH=[0-9]{1,2}(,[0-9]{1,2})*'
  r'|BYSETPOS=-?[0-9]{1,3}|WKST=(MO|TU|WE|TH|FR|SA|SU))$',
);

/// A date, or an instant with the zone it was written in.
class _When {
  _When.date(DateTime this.date) : instant = null, zone = null;
  _When.instant(DateTime this.instant, this.zone) : date = null;

  final DateTime? date;
  final DateTime? instant;

  /// The named zone when the database knows it; null for UTC, floating and unknown zones.
  final tz.Location? zone;
}

class _Reader {
  _Reader(this.zoneOf, this.fallback);

  /// The bundled database's zone of an IANA name, or null.
  final tz.Location? Function(String name) zoneOf;

  /// The family's zone: for times without a zone, and for a zone nobody knows.
  final tz.Location fallback;

  tz.Location? _zone(String? tzid) {
    if (tzid == null) return null;
    final name = tzid.trim();
    return zoneOf(_windowsZones[name] ?? name);
  }

  _When? when(_Line line) {
    final value = line.value.trim();
    final d = _dateOnly.firstMatch(value);
    if (d != null) {
      return _When.date(
        DateTime(int.parse(d[1]!), int.parse(d[2]!), int.parse(d[3]!)),
      );
    }
    final m = _dateTime.firstMatch(value);
    if (m == null) return null;
    final f = [for (var i = 1; i <= 6; i++) int.parse(m[i] ?? '0')];
    if (m[7] != null) {
      return _When.instant(
        DateTime.utc(f[0], f[1], f[2], f[3], f[4], f[5]),
        null,
      );
    }
    final zone = _zone(line.params['TZID']);
    final local = tz.TZDateTime(
      zone ?? fallback,
      f[0],
      f[1],
      f[2],
      f[3],
      f[4],
      f[5],
    );
    return _When.instant(local.toUtc(), zone);
  }

  /// The local date of [w] in [zone], for RDATE and EXDATE.
  DateTime dateIn(_When w, tz.Location zone) {
    final date = w.date;
    if (date != null) return date;
    final local = tz.TZDateTime.from(w.instant!, zone);
    return DateTime(local.year, local.month, local.day);
  }
}

Duration? _parseDuration(String value) {
  final m = _duration.firstMatch(value.trim().toUpperCase());
  if (m == null) return null;
  int n(int group) => int.parse(m[group] ?? '0');
  final d = Duration(
    days: n(2) * 7 + n(3),
    hours: n(4),
    minutes: n(5),
    seconds: n(6),
  );
  return m[1] == '-' ? null : d;
}

/// Reads the one event in [bytes]. Throws [IcsImportException] when there is none to take.
///
/// [zoneOf] looks an IANA name up in the bundled database; [familyZone] is used for
/// times without a zone and for zones the database does not know.
ImportedEvent parseSharedEvent(
  Uint8List bytes, {
  required tz.Location? Function(String name) zoneOf,
  required tz.Location familyZone,
}) {
  if (bytes.length > icsImportMaxBytes) {
    throw const IcsImportException(IcsImportProblem.tooLarge);
  }
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  // Unfold: a line break followed by a space or a tab continues the line.
  final lines = text
      .replaceAll(RegExp(r'\r\n[ \t]|\n[ \t]|\r[ \t]'), '')
      .split(RegExp(r'\r\n|\n|\r'));

  var inCalendar = false;
  final events = <List<_Line>>[];
  List<_Line>? current;
  // A component inside the event (an alarm): skipped whole.
  final nested = <String>[];
  for (final raw in lines) {
    if (raw.trim().isEmpty) continue;
    final line = _parseLine(raw);
    if (line == null) continue;
    final value = line.value.trim().toUpperCase();
    if (line.name == 'BEGIN') {
      if (value == 'VCALENDAR') {
        inCalendar = true;
      } else if (current != null) {
        nested.add(value);
      } else if (value == 'VEVENT' && inCalendar) {
        // Far more than any shared event has; a whole calendar is refused below anyway.
        if (events.length >= 50) {
          throw const IcsImportException(IcsImportProblem.severalEvents);
        }
        current = [];
      }
      continue;
    }
    if (line.name == 'END') {
      if (nested.isNotEmpty) {
        nested.removeLast();
      } else if (value == 'VEVENT' && current != null) {
        events.add(current);
        current = null;
      }
      continue;
    }
    if (current != null && nested.isEmpty && current.length < 2000) {
      current.add(line);
    }
  }
  if (!inCalendar || events.isEmpty) {
    throw const IcsImportException(IcsImportProblem.notAnEvent);
  }

  String? first(List<_Line> e, String name) {
    for (final l in e) {
      if (l.name == name) return l.value;
    }
    return null;
  }

  final uids = {for (final e in events) (first(e, 'UID') ?? '').trim()};
  if (uids.length > 1) {
    throw const IcsImportException(IcsImportProblem.severalEvents);
  }
  // A series may come with its moved dates as further VEVENTs of the same UID: the
  // series itself is the one without RECURRENCE-ID. A lone moved date is taken as it is.
  final master = events.where((e) => first(e, 'RECURRENCE-ID') == null);
  final event = master.isEmpty ? events.first : master.first;
  final isInstance = master.isEmpty;

  if ((first(event, 'STATUS') ?? '').trim().toUpperCase() == 'CANCELLED') {
    throw const IcsImportException(IcsImportProblem.cancelled);
  }

  _Line? lineOf(String name) {
    for (final l in event) {
      if (l.name == name) return l;
    }
    return null;
  }

  final reader = _Reader(zoneOf, familyZone);
  final startLine = lineOf('DTSTART');
  final start = startLine == null ? null : reader.when(startLine);
  if (start == null) {
    throw const IcsImportException(IcsImportProblem.notAnEvent);
  }
  final endLine = lineOf('DTEND');
  final end = endLine == null ? null : reader.when(endLine);
  final duration = _parseDuration(first(event, 'DURATION') ?? '');
  final allDay = start.date != null;

  DateTime? startsAt;
  DateTime? endsAt;
  DateTime? startDate;
  DateTime? endDate;
  if (allDay) {
    startDate = start.date;
    final s = startDate!;
    // DTEND is the day after the last day.
    var last = s;
    final endOn = end?.date;
    if (endOn != null && endOn.isAfter(s)) {
      last = DateTime(endOn.year, endOn.month, endOn.day - 1);
    } else if (duration != null && duration.inDays > 1) {
      last = DateTime(s.year, s.month, s.day + duration.inDays - 1);
    }
    endDate = last;
  } else {
    startsAt = start.instant;
    final s = startsAt!;
    var e = end?.instant ?? (duration == null ? null : s.add(duration));
    // The calendar stores no event without a length.
    if (e == null || !e.isAfter(s)) e = s.add(const Duration(hours: 1));
    endsAt = e;
  }

  final zone = start.zone;
  final eventZone = zone ?? familyZone;

  String? rrule;
  var repeatDropped = false;
  final rdates = <DateTime>[];
  final exdates = <DateTime>[];
  if (!isInstance) {
    final rule = first(event, 'RRULE')?.trim().toUpperCase();
    if (rule != null && rule.isNotEmpty) {
      final parts = rule.split(';');
      final names = {for (final p in parts) p.split('=').first};
      final ok =
          rule.length <= 300 &&
          names.length == parts.length &&
          names.contains('FREQ') &&
          !(names.contains('COUNT') && names.contains('UNTIL')) &&
          parts.every(_rrulePart.hasMatch);
      if (ok) {
        rrule = rule;
      } else {
        repeatDropped = true;
      }
    }
    void dates(String name, List<DateTime> into, int cap) {
      for (final l in event.where((l) => l.name == name)) {
        for (final v in l.value.split(',')) {
          if (into.length >= cap) return;
          final w = reader.when(_Line(l.name, l.params, v));
          if (w == null) continue;
          final day = reader.dateIn(w, eventZone);
          if (!into.contains(day)) into.add(day);
        }
      }
    }

    if (!repeatDropped) {
      dates('RDATE', rdates, 366);
      if (rrule != null || rdates.isNotEmpty) dates('EXDATE', exdates, 1000);
    }
  }

  final uid = uids.single;
  final description = _text(
    first(event, 'DESCRIPTION') ?? '',
    max: 4000,
    multiline: true,
  );
  final location = _text(first(event, 'LOCATION') ?? '', max: 200);
  final status = (first(event, 'STATUS') ?? '').trim().toUpperCase();
  final sequence = int.tryParse((first(event, 'SEQUENCE') ?? '').trim()) ?? 0;

  return ImportedEvent(
    title: _text(first(event, 'SUMMARY') ?? '', max: 200),
    description: description.isEmpty ? null : description,
    location: location.isEmpty ? null : location,
    isAllDay: allDay,
    startsAt: startsAt,
    endsAt: endsAt,
    startDate: startDate,
    endDate: endDate,
    timezone: zone?.name,
    rrule: rrule,
    rdates: rdates,
    exdates: exdates,
    uid: uid.isEmpty || uid.length > 512 ? null : uid,
    sequence: sequence < 0 || sequence > 1 << 30 ? 0 : sequence,
    tentative: status == 'TENTATIVE',
    repeatDropped: repeatDropped,
  );
}
