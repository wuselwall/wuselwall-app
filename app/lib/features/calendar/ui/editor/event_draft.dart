import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/editor/recurrence.dart';

/// What the editor shows while the user types or picks: an event being made or
/// changed. Pure Dart, so the rules (ends after starts, the key default) are tested
/// without a widget tree. [toEvent] is the `p_event` of `api.event_save`.
class EventDraft {
  EventDraft({
    required this.start,
    required this.end,
    this.id,
    this.calendarId,
    this.timezone,
    this.title = '',
    this.notes = '',
    this.location = '',
    this.kind = EventKind.appointment,
    this.presenceState,
    this.isAllDay = false,
    this.attendeeIds = const {},
    this.tentative = false,
    this.keyTouched = false,
    this.key = false,
    this.recurrence = const Recurrence(),
    this.exdates = const [],
  }) : duration = _positive(end.difference(start)) ?? const Duration(hours: 1);

  /// A new event on [day] (local), starting at [startHour] and lasting an hour.
  factory EventDraft.forNew({
    required DateTime day,
    required int startHour,
    required Set<String> attendeeIds,
  }) {
    final start = DateTime(day.year, day.month, day.day, startHour);
    return EventDraft(
      start: start,
      end: start.add(const Duration(hours: 1)),
      attendeeIds: attendeeIds,
    );
  }

  factory EventDraft.fromEvent(CalendarEvent event) {
    final start = event.isAllDay ? event.startDate! : event.startsAt!.toLocal();
    final end = event.isAllDay ? event.endDate! : event.endsAt!.toLocal();
    return EventDraft(
      id: event.id,
      calendarId: event.calendarId,
      timezone: event.timezone,
      start: start,
      end: end,
      title: event.title,
      notes: event.description ?? '',
      location: event.location ?? '',
      kind: event.kind,
      presenceState: event.presenceState,
      isAllDay: event.isAllDay,
      attendeeIds: event.attendeeIds.toSet(),
      tentative: event.status == EventStatus.tentative,
      keyTouched: event.importance != null,
      key: event.importance == Importance.key,
      recurrence: Recurrence.fromStored(
        start: start,
        rrule: event.rrule,
        rdates: event.rdates,
      ),
      exdates: event.exdates,
    );
  }

  final String? id;
  final String? calendarId;
  final String? timezone;
  final List<DateTime> exdates;

  String title;
  String notes;
  String location;
  EventKind kind;
  PresenceState? presenceState;
  bool isAllDay;

  /// Timed: the instants. All-day: only the dates are used.
  DateTime start;
  DateTime end;

  /// Kept when the start moves, so a moved event keeps its length. Updated when the
  /// user sets an end after the start.
  Duration duration;
  Set<String> attendeeIds;
  bool tentative;

  /// Until the user touches the kitchen-display switch, its value follows the
  /// household's `calendar.key_default` and the attendees ([effectiveKey]).
  bool keyTouched;
  bool key;
  Recurrence recurrence;

  bool effectiveKey(bool defaultKey) => keyTouched ? key : defaultKey;

  /// Moves the start; a timed event keeps its length, an all-day end never sits
  /// before its start.
  void moveStart(DateTime to) {
    start = to;
    if (isAllDay) {
      if (dateOnly(end).isBefore(dateOnly(start))) end = start;
    } else {
      end = start.add(duration);
    }
  }

  /// Sets the end and remembers the length when it is after the start.
  void setEnd(DateTime to) {
    end = to;
    final length = _positive(end.difference(start));
    if (!isAllDay && length != null) duration = length;
  }

  /// Switching to all-day keeps the dates; back to timed restores a valid end.
  void setAllDay(bool value) {
    isAllDay = value;
    if (!value && !end.isAfter(start)) end = start.add(duration);
  }

  /// The first problem with the draft, or null.
  DraftError? validate() {
    if (title.trim().isEmpty) return DraftError.titleRequired;
    if (kind == EventKind.presence && presenceState == null) {
      return DraftError.presenceStateRequired;
    }
    if (recurrence.needsWeekdays) return DraftError.weekdaysRequired;
    final ordered = isAllDay
        ? !dateOnly(end).isBefore(dateOnly(start))
        : end.isAfter(start);
    if (!ordered) return DraftError.endBeforeStart;
    return null;
  }

  /// The `p_event` of the save. [attendees] are in household order; [key] is the
  /// effective kitchen-display value.
  CalendarEvent toEvent({required List<String> attendees, required bool key}) {
    final text = notes.trim();
    final place = location.trim();
    final timed = !isAllDay;
    return CalendarEvent(
      id: id,
      calendarId: calendarId,
      title: title.trim(),
      description: text.isEmpty ? null : text,
      location: place.isEmpty ? null : place,
      kind: kind,
      presenceState: kind == EventKind.presence ? presenceState : null,
      status: tentative ? EventStatus.tentative : EventStatus.confirmed,
      importance: key ? Importance.key : Importance.normal,
      isAllDay: isAllDay,
      startsAt: timed ? start : null,
      endsAt: timed ? end : null,
      startDate: timed ? null : dateOnly(start),
      endDate: timed ? null : dateOnly(end),
      timezone: timezone,
      rrule: recurrence.toRrule(start),
      rdates: recurrence.rdatesFor(start),
      exdates: exdates,
      attendeeIds: attendees,
    );
  }

  /// The change to one occurrence of a series ("Nur dieser Termin").
  Map<String, dynamic> occurrencePatch() {
    final text = location.trim();
    return {
      'title': title.trim(),
      if (isAllDay) ...{
        'start_date': isoDate(dateOnly(start)),
        'end_date': isoDate(dateOnly(end)),
      } else ...{
        'starts_at': start.toUtc().toIso8601String(),
        'ends_at': end.toUtc().toIso8601String(),
      },
      'location': text.isEmpty ? null : text,
      'status':
          (tentative ? EventStatus.tentative : EventStatus.confirmed).wire,
    };
  }
}

/// The problems [EventDraft.validate] reports, one per field the user must fix.
enum DraftError {
  titleRequired,
  presenceStateRequired,
  weekdaysRequired,
  endBeforeStart,
}

/// What `calendar.key_default` implies for a new or changed event (specs/21): the
/// whole family's events, every event, or none. [activeMembers] are the household's
/// active profile ids.
bool defaultKeyFor({
  required String? setting,
  required Set<String> attendees,
  required Iterable<String> activeMembers,
}) {
  switch (setting) {
    case 'all':
      return true;
    case 'none':
      return false;
    default:
      if (attendees.isEmpty) return true;
      return activeMembers.every(attendees.contains);
  }
}

Duration? _positive(Duration d) => d > Duration.zero ? d : null;
