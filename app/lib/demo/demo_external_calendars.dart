import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/calendar/data/external_calendars_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';

/// Two plausible subscriptions for the reference household: the bin collection for the
/// whole family, and one child's football fixtures. Demo data only (specs/05).
class DemoExternalCalendarsRepository implements ExternalCalendarsRepository {
  DemoExternalCalendarsRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  var _nextId = 1;

  late final _calendars = <ExternalCalendar>[
    ExternalCalendar(
      id: demoBinCalendarId,
      name: 'Abfuhrkalender',
      urlHost: 'abfuhr.example.de',
      colourHex: '#9A5300',
      memberIds: const [],
      showOnBoard: true,
      active: true,
      lastFetchedAt: _clock().subtract(const Duration(minutes: 12)),
    ),
    ExternalCalendar(
      id: demoFootballCalendarId,
      name: 'FC Spielplan',
      urlHost: 'fc-beispiel.example.de',
      colourHex: '#1A4FA8',
      memberIds: const [DemoData.hanna],
      showOnBoard: false,
      active: true,
      lastFetchedAt: _clock().subtract(const Duration(minutes: 40)),
    ),
  ];

  @override
  Future<Result<List<ExternalCalendar>>> calendars() async =>
      Ok(List.unmodifiable(_calendars));

  @override
  Future<Result<String>> save({
    required String? actor,
    required ExternalCalendarDraft draft,
  }) async {
    final id = draft.id;
    if (id == null) {
      final created = ExternalCalendar(
        id: 'demo-ext-${_nextId++}',
        name: draft.name ?? '',
        urlHost: _hostOf(draft.url),
        colourHex: draft.colourHex ?? '#9A5300',
        memberIds: draft.memberIds ?? const [],
        showOnBoard: draft.showOnBoard ?? false,
        active: draft.active ?? true,
      );
      _calendars.add(created);
      _urls[created.id] = draft.url ?? '';
      return Ok(created.id);
    }
    final index = _calendars.indexWhere((c) => c.id == id);
    if (index < 0) {
      return const Err(NotFoundFailure(code: 'external_calendar_not_found'));
    }
    final old = _calendars[index];
    if (draft.url != null) _urls[id] = draft.url!;
    _calendars[index] = ExternalCalendar(
      id: old.id,
      name: draft.name ?? old.name,
      urlHost: draft.url == null ? old.urlHost : _hostOf(draft.url),
      colourHex: draft.colourHex ?? old.colourHex,
      memberIds: draft.memberIds ?? old.memberIds,
      showOnBoard: draft.showOnBoard ?? old.showOnBoard,
      active: draft.active ?? old.active,
      lastFetchedAt: old.lastFetchedAt,
      lastError: old.lastError,
    );
    return Ok(id);
  }

  @override
  Future<Result<void>> delete({
    required String? actor,
    required String id,
  }) async {
    _calendars.removeWhere((c) => c.id == id);
    return const Ok(null);
  }

  /// The demo keeps the full address per calendar, so the edit form can load it.
  final _urls = <String, String>{
    demoBinCalendarId: 'https://abfuhr.example.de/kalender.ics',
    demoFootballCalendarId: 'https://fc-beispiel.example.de/spielplan.ics',
  };

  @override
  Future<Result<String>> url({
    required String? actor,
    required String id,
  }) async {
    final url = _urls[id];
    if (url == null) {
      return const Err(NotFoundFailure(code: 'external_calendar_not_found'));
    }
    return Ok(url);
  }

  static String _hostOf(String? url) => Uri.tryParse(url ?? '')?.host ?? '';

  @override
  Future<Result<CalendarRefresh>> refresh({
    required String? actor,
    required String calendarId,
  }) async => Ok(
    CalendarRefresh(
      calendarId: calendarId,
      status: RefreshStatus.refreshed,
      rows: calendarId == demoBinCalendarId ? 4 : 2,
    ),
  );
}

const demoBinCalendarId = 'ext-abfuhr';
const demoFootballCalendarId = 'ext-fc';

/// The imported occurrences of the week starting on [monday] that fall between [first]
/// and [last] (inclusive local dates): bin days for everyone, one fixture for Hanna.
List<Occurrence> demoImportedOccurrences(
  DateTime monday,
  DateTime first,
  DateTime last,
) {
  DateTime day(int offset) =>
      DateTime(monday.year, monday.month, monday.day + offset);

  final out = <Occurrence>[];
  for (final bin in [
    (offset: 1, title: 'Restmüll', uid: 'bin-rest'),
    (offset: 4, title: 'Gelber Sack', uid: 'bin-gelb'),
  ]) {
    final d = day(bin.offset);
    if (d.isBefore(first) || d.isAfter(last)) {
      continue;
    }
    out.add(
      _imported(
        id: '${demoBinCalendarId}_${bin.uid}',
        calendarId: demoBinCalendarId,
        colourHex: '#9A5300',
        title: bin.title,
        date: d,
        allDay: true,
        attendees: const [],
      ),
    );
  }
  final fixture = day(5);
  if (!fixture.isBefore(first) && !fixture.isAfter(last)) {
    out.add(
      _imported(
        id: '${demoFootballCalendarId}_spiel-1',
        calendarId: demoFootballCalendarId,
        colourHex: '#1A4FA8',
        title: 'Junioren gegen TSV',
        date: fixture,
        start: const TimeOfDay(hour: 10, minute: 0),
        end: const TimeOfDay(hour: 11, minute: 30),
        location: 'Sportplatz Nord',
        attendees: const [DemoData.hanna],
      ),
    );
  }
  return out;
}

Occurrence _imported({
  required String id,
  required String calendarId,
  required String colourHex,
  required String title,
  required DateTime date,
  required List<String> attendees,
  bool allDay = false,
  TimeOfDay? start,
  TimeOfDay? end,
  String? location,
}) {
  final timed = !allDay && start != null && end != null;
  return Occurrence(
    id: 'imported|$id',
    eventId: '$calendarId|$id',
    calendarId: calendarId,
    title: title,
    location: location,
    kind: EventKind.appointment,
    status: EventStatus.confirmed,
    importance: Importance.normal,
    allDay: !timed,
    start: timed
        ? DateTime(date.year, date.month, date.day, start.hour, start.minute)
        : date,
    end: timed
        ? DateTime(date.year, date.month, date.day, end.hour, end.minute)
        : DateTime(date.year, date.month, date.day + 1),
    localStartDate: date,
    localEndDate: date,
    localStarts: timed ? start : null,
    localEnds: timed ? end : null,
    attendeeIds: attendees,
    source: OccurrenceSource.imported,
    colourHex: colourHex,
  );
}
