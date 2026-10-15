import 'package:flutter/material.dart' show Color, TimeOfDay;
import 'package:wuselwall/features/board/domain/week_board.dart';

/// Calendar read and write models, shaped by the contract in `api.events`, the
/// `occurrences` Edge Function and `api.event_save` (specs/05, ADR-009).
///
/// Times arrive as instants and are shown in the device's zone; the event's own wall
/// clock (`local_starts`, `local_start_date`) is kept as well, because an all-day event
/// and a recurring "every Monday at 15:00" must not drift when the zone or a summer
/// time change differs between the household and a traveller's phone.

enum EventKind {
  appointment,
  presence;

  static EventKind parse(String v) => v == 'presence' ? presence : appointment;

  String get wire => name;
}

enum EventStatus {
  confirmed,
  tentative,
  cancelled;

  static EventStatus parse(String? v) => switch (v) {
    'tentative' => tentative,
    'cancelled' => cancelled,
    _ => confirmed,
  };

  String get wire => name;
}

/// Where an occurrence comes from. Imported ones (an ICS subscription, specs/05) are
/// read-only everywhere; an older server sends no `source`, so every one is an event.
enum OccurrenceSource {
  event,
  imported;

  static OccurrenceSource parse(String? v) =>
      v == 'imported' ? imported : event;
}

/// `#RRGGBB` as a colour, or null for anything else (including a missing value).
Color? colourFromHex(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

enum Importance {
  normal,
  key;

  static Importance parse(String? v) => v == 'key' ? key : normal;

  String get wire => name;
}

/// The wire name of a presence state (`home_office`, not `homeOffice`).
extension PresenceStateWire on PresenceState {
  String get wire => switch (this) {
    PresenceState.working => 'working',
    PresenceState.homeOffice => 'home_office',
    PresenceState.travel => 'travel',
    PresenceState.away => 'away',
    PresenceState.off => 'off',
    PresenceState.childcare => 'childcare',
  };
}

/// One occurrence of an event inside a window: what the views draw. Produced by the
/// `occurrences` function, which expands recurrence and applies overrides.
class Occurrence {
  const Occurrence({
    required this.id,
    required this.eventId,
    required this.calendarId,
    required this.title,
    required this.kind,
    required this.status,
    required this.importance,
    required this.allDay,
    required this.start,
    required this.end,
    required this.localStartDate,
    required this.localEndDate,
    this.recurrenceId,
    this.location,
    this.description,
    this.presenceState,
    this.localStarts,
    this.localEnds,
    this.attendeeIds = const [],
    this.isRecurring = false,
    this.isOverride = false,
    this.source = OccurrenceSource.event,
    this.colourHex,
  });

  factory Occurrence.fromJson(Map<String, dynamic> json) => Occurrence(
    id: json['id'] as String,
    eventId: json['event_id'] as String,
    recurrenceId: _instant(json['recurrence_id']),
    calendarId: json['calendar_id'] as String,
    title: json['title'] as String,
    location: json['location'] as String?,
    description: json['description'] as String?,
    kind: EventKind.parse(json['kind'] as String),
    presenceState: json['presence_state'] == null
        ? null
        : PresenceState.parse(json['presence_state'] as String),
    status: EventStatus.parse(json['status'] as String?),
    importance: Importance.parse(json['importance'] as String?),
    allDay: json['all_day'] as bool,
    start: DateTime.parse(json['start'] as String).toLocal(),
    end: DateTime.parse(json['end'] as String).toLocal(),
    localStartDate: parseDate(json['local_start_date'] as String),
    localEndDate: parseDate(json['local_end_date'] as String),
    localStarts: _clock(json['local_starts']),
    localEnds: _clock(json['local_ends']),
    attendeeIds: ((json['attendee_ids'] as List?) ?? const []).cast<String>(),
    isRecurring: json['is_recurring'] as bool? ?? false,
    isOverride: json['is_override'] as bool? ?? false,
    source: OccurrenceSource.parse(json['source'] as String?),
    colourHex: json['colour_hex'] as String?,
  );

  final String id;
  final String eventId;

  /// The original start instant of a recurring occurrence; null for a single event.
  final DateTime? recurrenceId;
  final String calendarId;
  final String title;
  final String? location;
  final String? description;
  final EventKind kind;
  final PresenceState? presenceState;
  final EventStatus status;
  final Importance importance;
  final bool allDay;

  /// Instants in the device's zone. All-day: local midnights.
  final DateTime start;
  final DateTime end;

  /// Inclusive local dates in the event's timezone.
  final DateTime localStartDate;
  final DateTime localEndDate;

  /// Wall-clock start and end; null for all-day occurrences.
  final TimeOfDay? localStarts;
  final TimeOfDay? localEnds;

  /// In household member order; empty for an event nobody is attending.
  final List<String> attendeeIds;
  final bool isRecurring;
  final bool isOverride;

  /// `event` (the household's own, editable) or `imported` (read-only).
  final OccurrenceSource source;

  /// The imported calendar's colour; null for events, which take their members' colour.
  final String? colourHex;

  bool get isImported => source == OccurrenceSource.imported;
  bool get isPresence => kind == EventKind.presence;
  bool get isTentative => status == EventStatus.tentative;
  bool get isKey => importance == Importance.key;

  /// True when this occurrence covers [day] (a local date).
  bool coversDay(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(localStartDate) && !d.isAfter(localEndDate);
  }
}

/// An `api.events` row: the editable event itself, as the editor sees it. [toJson] is
/// the `p_event` map of `api.event_save`.
class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.kind,
    required this.isAllDay,
    this.id,
    this.calendarId,
    this.description,
    this.location,
    this.presenceState,
    this.status = EventStatus.confirmed,
    this.importance,
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
    this.attendeeIds = const [],
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    calendarId: json['calendar_id'] as String?,
    title: json['title'] as String,
    description: json['description'] as String?,
    location: json['location'] as String?,
    kind: EventKind.parse(json['kind'] as String),
    presenceState: json['presence_state'] == null
        ? null
        : PresenceState.parse(json['presence_state'] as String),
    status: EventStatus.parse(json['status'] as String?),
    importance: Importance.parse(json['importance'] as String?),
    isAllDay: json['is_all_day'] as bool,
    startsAt: _instant(json['starts_at']),
    endsAt: _instant(json['ends_at']),
    startDate: _date(json['start_date']),
    endDate: _date(json['end_date']),
    timezone: json['timezone'] as String?,
    rrule: json['rrule'] as String?,
    rdates: _dates(json['rdates']),
    exdates: _dates(json['exdates']),
    uid: json['uid'] as String?,
    sequence: json['sequence'] as int? ?? 0,
    attendeeIds: ((json['attendee_ids'] as List?) ?? const []).cast<String>(),
  );

  /// Null for a new event: the server generates the id.
  final String? id;

  /// Null: the household's own calendar (the server's default).
  final String? calendarId;
  final String title;
  final String? description;
  final String? location;
  final EventKind kind;

  /// Required when [kind] is presence, null otherwise.
  final PresenceState? presenceState;
  final EventStatus status;

  /// Null: the server applies `calendar.key_default`.
  final Importance? importance;
  final bool isAllDay;

  /// Timed events: both set, [endsAt] after [startsAt].
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// All-day events: both set, [endDate] inclusive.
  final DateTime? startDate;
  final DateTime? endDate;

  /// IANA zone; null: the household's zone.
  final String? timezone;

  /// RFC 5545 RRULE body without the `RRULE:` prefix.
  final String? rrule;
  final List<DateTime> rdates;
  final List<DateTime> exdates;
  final String? uid;
  final int sequence;

  /// Replaces the attendee set on save; order is the household's member order.
  final List<String> attendeeIds;

  bool get isRecurring => rrule != null || rdates.isNotEmpty;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (calendarId != null) 'calendar_id': calendarId,
    'title': title,
    'description': description,
    'location': location,
    'kind': kind.wire,
    'presence_state': presenceState?.wire,
    'status': status.wire,
    if (importance != null) 'importance': importance!.wire,
    'is_all_day': isAllDay,
    'starts_at': startsAt?.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'start_date': startDate == null ? null : isoDate(startDate!),
    'end_date': endDate == null ? null : isoDate(endDate!),
    if (timezone != null) 'timezone': timezone,
    'rrule': rrule,
    'rdates': [for (final d in rdates) isoDate(d)],
    'exdates': [for (final d in exdates) isoDate(d)],
    'attendee_ids': attendeeIds,
  };
}

/// The `occurrences` function's reply: the window's occurrences, the zone they are
/// written in and every member's "Termine bis" limit for the days in it.
class OccurrenceWindow {
  const OccurrenceWindow({
    required this.timezone,
    required this.occurrences,
    this.busyUntil = const {},
  });

  factory OccurrenceWindow.fromJson(Map<String, dynamic> json) {
    final rows = ((json['busy_until'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    return OccurrenceWindow(
      timezone: json['timezone'] as String? ?? 'UTC',
      occurrences: ((json['occurrences'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Occurrence.fromJson)
          .toList(growable: false),
      busyUntil: {
        for (final row in rows)
          (
            profileId: row['profile_id'] as String,
            date: parseDate(row['on_date'] as String),
          ): parseTime(
            row['until'] as String,
          ),
      },
    );
  }

  static const empty = OccurrenceWindow(timezone: 'UTC', occurrences: []);

  final String timezone;
  final List<Occurrence> occurrences;

  /// "Termine bis 17:00", keyed by member and local date.
  final Map<BusyKey, TimeOfDay> busyUntil;
}

typedef BusyKey = ({String profileId, DateTime date});

/// `2026-09-02` for a local date, the form the API takes.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `HH:MM`, the form `api.busy_until_set` takes.
String clockOf(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? _instant(Object? v) => v == null ? null : DateTime.parse(v as String);

DateTime? _date(Object? v) => v == null ? null : parseDate(v as String);

TimeOfDay? _clock(Object? v) => v == null ? null : parseTime(v as String);

List<DateTime> _dates(Object? v) => ((v as List?) ?? const [])
    .cast<String>()
    .map(parseDate)
    .toList(growable: false);
