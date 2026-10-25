import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/event_templates.dart';
import 'package:wuselwall/features/calendar/domain/tradition_starters.dart';
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
    this.iconKey,
    this.countdown = false,
    this.tradition = false,
    this.traditionMeal = '',
    this.traditionMealSlot = 'dinner',
    this.traditionMealRecipe,
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

  /// A new family tradition from Kalender → *Neue Tradition* (specs/27): weekly on its
  /// start's weekday, [attendeeIds] (the whole family), always on the wall.
  factory EventDraft.fromTradition(
    TraditionTemplate t, {
    required Set<String> attendeeIds,
  }) => EventDraft(
    start: t.start,
    end: t.end,
    title: t.title,
    isAllDay: t.allDay,
    attendeeIds: attendeeIds,
    key: true,
    recurrence: Recurrence(
      kind: RepeatKind.weekly,
      weekdays: {t.start.weekday},
    ),
    iconKey: t.iconKey,
    tradition: true,
    traditionMeal: t.meal,
    traditionMealSlot: t.mealSlot,
  );

  /// A new event from a template (specs/28) on [day] (local). A template without a
  /// start time starts at [defaultHour]. Only [activeMembers] are kept as attendees.
  factory EventDraft.fromTemplate(
    EventTemplate t, {
    required DateTime day,
    required int defaultHour,
    required Set<String> activeMembers,
  }) {
    final date = DateTime(day.year, day.month, day.day);
    final minute = t.startMinute;
    final start = t.allDay
        ? date
        : minute == null
        ? DateTime(date.year, date.month, date.day, defaultHour)
        : DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);
    final end = t.allDay
        ? DateTime(date.year, date.month, date.day + (t.days ?? 1) - 1)
        : start.add(Duration(minutes: t.durationMinutes ?? 60));
    final importance = t.importance;
    return EventDraft(
      start: start,
      end: end,
      title: t.title,
      notes: t.notes,
      location: t.location,
      kind: t.kind,
      presenceState: t.kind == EventKind.presence ? t.presenceState : null,
      isAllDay: t.allDay,
      attendeeIds: t.attendeeIds.where(activeMembers.contains).toSet(),
      keyTouched: importance != null,
      key: importance == Importance.key,
      recurrence: t.yearly
          ? const Recurrence(kind: RepeatKind.yearly)
          : const Recurrence(),
      iconKey: t.kind == EventKind.presence ? null : t.iconKey,
      countdown: t.kind != EventKind.presence && t.countdown,
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
      iconKey: event.iconKey,
      countdown: event.countdown,
      tradition: event.tradition,
      traditionMeal:
          event.traditionMeal?.freeText ?? event.traditionMeal?.title ?? '',
      traditionMealSlot: event.traditionMeal?.slot ?? 'dinner',
      traditionMealRecipe: switch (event.traditionMeal) {
        TraditionMeal(:final recipeId?, :final freeText, :final title) => (
          recipeId: recipeId,
          words: freeText ?? title ?? '',
        ),
        _ => null,
      },
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

  /// A content icon (specs/27); null for none.
  String? iconKey;

  /// "Darauf freuen wir uns".
  bool countdown;

  /// A family tradition: always on the wall, so the key switch follows it.
  bool tradition;

  /// A tradition's meal in a few words ("Pizza"); empty for none.
  String traditionMeal;
  String traditionMealSlot;

  /// The stored meal's recipe and the words it showed as. The editor takes only words,
  /// so the recipe is kept while those words stay unchanged.
  final ({String recipeId, String words})? traditionMealRecipe;

  bool effectiveKey(bool defaultKey) =>
      tradition || (keyTouched ? key : defaultKey);

  /// Moves the start; a timed event keeps its length, an all-day end never sits
  /// before its start.
  void moveStart(DateTime to) {
    start = to;
    _timedEnd = null;
    if (isAllDay) {
      if (dateOnly(end).isBefore(dateOnly(start))) end = start;
    } else {
      end = start.add(duration);
    }
  }

  /// Sets the end and remembers the length when it is after the start.
  void setEnd(DateTime to) {
    end = to;
    _timedEnd = null;
    final length = _positive(end.difference(start));
    if (!isAllDay && length != null) duration = length;
  }

  /// The timed end before the switch to all-day, restored on the way back while
  /// neither date was changed in between.
  DateTime? _timedEnd;

  /// Switching to all-day keeps the days the event covers: a timed end is an
  /// exclusive instant, an all-day end date is inclusive (specs/04), so an end at
  /// midnight belongs to the day before (23:00–00:00 stays one day). Back to timed
  /// restores the end it had, or a valid one.
  void setAllDay(bool value) {
    if (value == isAllDay) return;
    isAllDay = value;
    if (value) {
      _timedEnd = end;
      if (end.isAfter(start) && end == dateOnly(end)) {
        end = DateTime(end.year, end.month, end.day - 1);
      }
    } else {
      final restored = _timedEnd;
      _timedEnd = null;
      if (restored != null) {
        end = restored;
      } else if (!end.isAfter(start)) {
        end = start.add(duration);
      }
    }
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
      iconKey: kind == EventKind.presence ? null : iconKey,
      countdown: kind != EventKind.presence && countdown,
      tradition: kind != EventKind.presence && tradition,
      traditionMeal: tradition && traditionMeal.trim().isNotEmpty
          ? _meal(traditionMeal.trim())
          : null,
    );
  }

  /// What [EventTemplate.toJson] saves of this draft (specs/28 "Saved templates"):
  /// not the date, the repeat, the tradition or "Noch nicht sicher". [attendees] are
  /// in household order.
  EventTemplate toTemplate({required List<String> attendees}) {
    final timed = !isAllDay;
    final minutes = end.difference(start).inMinutes;
    final days = dateOnly(end).difference(dateOnly(start)).inDays + 1;
    return EventTemplate(
      title: title.trim(),
      iconKey: kind == EventKind.presence ? null : iconKey,
      kind: kind,
      presenceState: kind == EventKind.presence ? presenceState : null,
      allDay: isAllDay,
      startMinute: timed ? start.hour * 60 + start.minute : null,
      durationMinutes: timed ? minutes.clamp(5, 7 * 24 * 60) : null,
      days: timed ? null : days.clamp(1, 366),
      attendeeIds: {...attendees},
      location: location.trim(),
      notes: notes.trim(),
      importance: keyTouched
          ? (key ? Importance.key : Importance.normal)
          : null,
      countdown: kind != EventKind.presence && countdown,
    );
  }

  TraditionMeal _meal(String words) {
    final recipe = traditionMealRecipe;
    return recipe != null && recipe.words.trim() == words
        ? TraditionMeal(slot: traditionMealSlot, recipeId: recipe.recipeId)
        : TraditionMeal(slot: traditionMealSlot, freeText: words);
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
