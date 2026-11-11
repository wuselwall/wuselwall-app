import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';

/// One event as a calendar file for people outside the household (specs/05 "Sharing one
/// event"). Pure: no I/O. The file leaves through the device's share sheet; the server
/// takes no part.
///
/// What is written is deliberately little: title, time, place, the repeat rule, and the
/// note only when asked. Never the attendees, the household's name, presence, pictures or
/// the family's rituals. `METHOD:PUBLISH` without ORGANIZER or ATTENDEE, so no calendar
/// app offers a reply.
///
/// Follows the rules of the server's feed renderer (`supabase/functions/_shared/ics.ts`):
/// local times with a TZID and a VTIMEZONE built from the zone's real transitions, so a
/// 19:00 series stays at 19:00 across a summer-time change.

/// A reminder the recipients' calendar app shows; WuselWall notifies nobody.
enum ShareReminder { none, hourBefore, dayBefore }

const _crlf = '\r\n';

/// Escapes a TEXT value (RFC 5545 3.3.11). The backslash goes first.
String icsEscapeText(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n');

/// Folds one content line to 75 octets. Counts UTF-8 bytes and never splits a
/// character; a continuation line starts with one space and carries 74 octets.
String icsFoldLine(String line) {
  final parts = <String>[];
  var current = StringBuffer();
  var octets = 0;
  var limit = 75;
  for (final rune in line.runes) {
    final ch = String.fromCharCode(rune);
    final n = utf8.encode(ch).length;
    if (octets + n > limit) {
      parts.add(current.toString());
      current = StringBuffer();
      octets = 0;
      limit = 74;
    }
    current.write(ch);
    octets += n;
  }
  parts.add(current.toString());
  return parts.join('$_crlf ');
}

String _pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');

String _ymd(DateTime d) => '${_pad(d.year, 4)}${_pad(d.month)}${_pad(d.day)}';

String _ymdhms(DateTime d) =>
    '${_ymd(d)}T${_pad(d.hour)}${_pad(d.minute)}${_pad(d.second)}';

String _utcStamp(DateTime instant) => '${_ymdhms(instant.toUtc())}Z';

/// ±HHMM, or ±HHMMSS when the offset has seconds.
String _offset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final a = offset.inSeconds.abs();
  final ss = a % 60 == 0 ? '' : _pad(a % 60);
  return '$sign${_pad(a ~/ 3600)}${_pad((a % 3600) ~/ 60)}$ss';
}

/// The wall clock of [ms] at [offset], as a plain UTC-flagged value to read fields from.
DateTime _wall(int ms, Duration offset) => DateTime.fromMillisecondsSinceEpoch(
  ms + offset.inMilliseconds,
  isUtc: true,
);

/// VTIMEZONE for [zone], one component per real transition between the two years
/// (inclusive), after one for the offset in force at the start.
List<String> _vtimezone(tz.Location zone, int fromYear, int toYear) {
  final startMs = DateTime.utc(fromYear).millisecondsSinceEpoch;
  final endMs = DateTime.utc(toYear + 1).millisecondsSinceEpoch;
  final lines = ['BEGIN:VTIMEZONE', 'TZID:${zone.name}'];

  void component(tz.TimeZone to, Duration from, int atMs) {
    final kind = to.isDst ? 'DAYLIGHT' : 'STANDARD';
    lines.addAll([
      'BEGIN:$kind',
      // Local wall-clock time as it was before the transition (RFC 5545 3.6.1).
      'DTSTART:${_ymdhms(_wall(atMs, from))}',
      'TZOFFSETFROM:${_offset(from)}',
      'TZOFFSETTO:${_offset(to.offset)}',
      'END:$kind',
    ]);
  }

  var last = zone.timeZone(startMs);
  component(last, last.offset, startMs);
  for (final at in zone.transitionAt) {
    if (at <= startMs) continue;
    if (at >= endMs) break;
    final next = zone.timeZone(at);
    component(next, last.offset, at);
    last = next;
  }
  lines.add('END:VTIMEZONE');
  return lines;
}

/// Renders [event] as an `.ics` file with exactly one VEVENT.
///
/// [zone] is the event's own zone; without it a timed event is written in UTC, which is
/// right for a single date and drifts by the summer-time hour for a series.
/// [occurrence] set: only that date of a series, as an event of its own (its own UID,
/// no repeat rule). Otherwise the whole event; individually moved dates of a series are
/// not part of the event row and so are sent at their usual time.
String renderSharedEvent({
  required CalendarEvent event,
  required DateTime now,
  tz.Location? zone,
  Occurrence? occurrence,
  bool includeNote = false,
  ShareReminder reminder = ShareReminder.none,
}) {
  final allDay = occurrence?.allDay ?? event.isAllDay;
  final series = occurrence == null && event.isRecurring;
  final title = occurrence?.title ?? event.title;
  final location = occurrence?.location ?? event.location;
  final note = occurrence?.description ?? event.description;

  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//WuselWall//Shared event//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
  ];
  final vevent = <String>['BEGIN:VEVENT'];

  // The series' wall-clock time, for RDATE and EXDATE values.
  DateTime? clock;
  String listParam;
  if (allDay) {
    final start = occurrence?.localStartDate ?? event.startDate!;
    final end = occurrence?.localEndDate ?? event.endDate ?? start;
    // ICS end dates are exclusive: DTEND is the day after the last day.
    final after = DateTime(end.year, end.month, end.day + 1);
    vevent.addAll([
      'DTSTART;VALUE=DATE:${_ymd(start)}',
      'DTEND;VALUE=DATE:${_ymd(after)}',
    ]);
    listParam = ';VALUE=DATE';
  } else {
    final start = occurrence?.start ?? event.startsAt!;
    final end = occurrence?.end ?? event.endsAt;
    if (zone == null) {
      vevent.add('DTSTART:${_utcStamp(start)}');
      if (end != null) vevent.add('DTEND:${_utcStamp(end)}');
      clock = start.toUtc();
      listParam = '';
    } else {
      final localStart = tz.TZDateTime.from(start, zone);
      final localEnd = end == null ? null : tz.TZDateTime.from(end, zone);
      final lastYear = series
          // An open rule has no last year; calendar apps know IANA zones and take over.
          ? (localStart.year > now.year ? localStart.year : now.year) + 2
          : (localEnd ?? localStart).year;
      lines.addAll(_vtimezone(zone, localStart.year, lastYear));
      vevent.add('DTSTART;TZID=${zone.name}:${_ymdhms(localStart)}');
      if (localEnd != null) {
        vevent.add('DTEND;TZID=${zone.name}:${_ymdhms(localEnd)}');
      }
      clock = localStart;
      listParam = ';TZID=${zone.name}';
    }
  }

  final baseUid = event.uid ?? '${event.id}@wuselwall.app';
  final at = occurrence?.recurrenceId;
  // One date of a series is its own event for the recipient, so it gets its own UID.
  final uid = occurrence != null && at != null
      ? '${_utcStamp(at)}-$baseUid'
      : baseUid;
  vevent.addAll([
    'UID:${icsEscapeText(uid)}',
    'DTSTAMP:${_utcStamp(now)}',
    'SEQUENCE:${event.sequence}',
    'SUMMARY:${icsEscapeText(title)}',
  ]);
  if (includeNote && note != null && note.trim().isNotEmpty) {
    vevent.add('DESCRIPTION:${icsEscapeText(note.trim())}');
  }
  if (location != null && location.trim().isNotEmpty) {
    vevent.add('LOCATION:${icsEscapeText(location.trim())}');
  }
  final status = occurrence?.status ?? event.status;
  vevent.addAll([
    'STATUS:${status == EventStatus.tentative ? 'TENTATIVE' : 'CONFIRMED'}',
    'TRANSP:OPAQUE',
  ]);

  if (series) {
    if (event.rrule != null) vevent.add('RRULE:${event.rrule}');
    String value(DateTime date) {
      final c = clock;
      return c == null
          ? _ymd(date)
          : '${_ymd(date)}T${_pad(c.hour)}${_pad(c.minute)}${_pad(c.second)}'
                '${zone == null ? 'Z' : ''}';
    }

    void list(String name, List<DateTime> dates) {
      if (dates.isEmpty) return;
      final values = {for (final d in dates) value(d)}.toList()..sort();
      vevent.add('$name$listParam:${values.join(',')}');
    }

    list('RDATE', event.rdates);
    list('EXDATE', event.exdates);
  }

  final trigger = switch (reminder) {
    ShareReminder.none => null,
    ShareReminder.hourBefore => '-PT1H',
    // An all-day event starts at midnight: nine o'clock the day before.
    ShareReminder.dayBefore => allDay ? '-PT15H' : '-P1D',
  };
  if (trigger != null) {
    vevent.addAll([
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:${icsEscapeText(title)}',
      'TRIGGER:$trigger',
      'END:VALARM',
    ]);
  }
  vevent.add('END:VEVENT');

  lines
    ..addAll(vevent)
    ..add('END:VCALENDAR');
  return lines.map(icsFoldLine).join(_crlf) + _crlf;
}

/// `Spieleabend.ics`: the title's letters and digits, or `event.ics` when none are left.
String sharedEventFileName(String title) {
  final slug = title
      .trim()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final short = slug.length > 40 ? slug.substring(0, 40) : slug;
  return '${short.isEmpty ? 'event' : short}.ics';
}
