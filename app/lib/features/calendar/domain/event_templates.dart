import 'package:flutter/foundation.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';

/// Who a built-in template invites (specs/28): every active member, every active
/// child, or the person creating it.
enum StarterPeople { family, children, actor }

/// The built-in templates of Kalender → *Neuer Termin* (specs/28 "Built-in templates").
/// Each language names them itself (the ARB keys `eventStarter*`); this is what they
/// start as. Every value is only a suggestion the editor shows before anything is saved.
enum EventStarter {
  birthday(
    iconKey: 'cake',
    allDay: true,
    people: StarterPeople.family,
    yearly: true,
    countdown: true,
  ),
  guestDinner(
    iconKey: 'house',
    startMinute: 18 * 60 + 30,
    minutes: 180,
    people: StarterPeople.family,
  ),
  kidsParty(
    iconKey: 'gift',
    startMinute: 14 * 60,
    minutes: 180,
    people: StarterPeople.children,
  ),
  sportsEvent(
    iconKey: 'football',
    startMinute: 10 * 60,
    minutes: 120,
    people: StarterPeople.actor,
  ),
  doctor(people: StarterPeople.actor),
  performance(
    iconKey: 'music',
    startMinute: 19 * 60,
    minutes: 120,
    people: StarterPeople.family,
  ),
  dayOut(
    iconKey: 'hiking',
    allDay: true,
    people: StarterPeople.family,
    countdown: true,
  ),
  holiday(
    iconKey: 'plane',
    allDay: true,
    days: 7,
    people: StarterPeople.family,
    countdown: true,
  );

  const EventStarter({
    required this.people,
    this.iconKey,
    this.allDay = false,
    this.startMinute,
    this.minutes = 60,
    this.days = 1,
    this.yearly = false,
    this.countdown = false,
  });

  /// One of `eventIconKeys`; null for none.
  final String? iconKey;
  final bool allDay;

  /// Minutes after midnight; null starts at the editor's next full hour.
  final int? startMinute;

  /// How long a timed one lasts.
  final int minutes;

  /// How many days an all-day one covers.
  final int days;
  final StarterPeople people;
  final bool yearly;
  final bool countdown;

  /// The template in the household's language ([title]), its people chosen from
  /// [members] and the person creating it ([actor]).
  EventTemplate template({
    required String title,
    required List<({String id, bool isChild})> members,
    required String? actor,
  }) {
    final attendees = switch (people) {
      StarterPeople.family => {for (final m in members) m.id},
      StarterPeople.children => {
        for (final m in members)
          if (m.isChild) m.id,
      },
      StarterPeople.actor => <String>{},
    };
    return EventTemplate(
      title: title,
      iconKey: iconKey,
      allDay: allDay,
      startMinute: allDay ? null : startMinute,
      durationMinutes: allDay ? null : minutes,
      days: allDay ? days : null,
      attendeeIds: attendees.isEmpty ? {?actor} : attendees,
      countdown: countdown,
      yearly: yearly,
    );
  }
}

/// A starting point for a new event (specs/28): a built-in one, one the family saved
/// (`api.event_templates`, [id] set) or one suggested from its history
/// (`api.event_suggestions`, [signature] set). Applying one never ties the event to it.
@immutable
class EventTemplate {
  const EventTemplate({
    required this.title,
    this.id,
    this.signature,
    this.count,
    this.iconKey,
    this.kind = EventKind.appointment,
    this.presenceState,
    this.allDay = false,
    this.startMinute,
    this.durationMinutes,
    this.days,
    this.attendeeIds = const {},
    this.location = '',
    this.notes = '',
    this.importance,
    this.countdown = false,
    this.yearly = false,
    this.createdBy,
  });

  /// A row of `api.event_templates`.
  factory EventTemplate.fromJson(Map<String, dynamic> json) => EventTemplate(
    id: json['id'] as String,
    title: json['title'] as String,
    iconKey: json['icon_key'] as String?,
    kind: EventKind.parse(json['kind'] as String? ?? 'appointment'),
    presenceState: json['presence_state'] == null
        ? null
        : PresenceState.parse(json['presence_state'] as String),
    allDay: json['is_all_day'] as bool? ?? false,
    startMinute: (json['start_minute'] as num?)?.toInt(),
    durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
    days: (json['days'] as num?)?.toInt(),
    attendeeIds: {
      for (final id in json['attendee_ids'] as List? ?? const []) id as String,
    },
    location: json['location'] as String? ?? '',
    notes: json['description'] as String? ?? '',
    importance: json['importance'] == null
        ? null
        : Importance.parse(json['importance'] as String),
    countdown: json['countdown'] as bool? ?? false,
    createdBy: json['created_by_profile_id'] as String?,
  );

  /// An element of `api.event_suggestions`.
  factory EventTemplate.fromSuggestion(Map<String, dynamic> json) =>
      EventTemplate(
        signature: json['signature'] as String,
        count: (json['count'] as num?)?.toInt(),
        title: json['title'] as String,
        iconKey: json['icon_key'] as String?,
        kind: EventKind.parse(json['kind'] as String? ?? 'appointment'),
        presenceState: json['presence_state'] == null
            ? null
            : PresenceState.parse(json['presence_state'] as String),
        allDay: json['is_all_day'] as bool? ?? false,
        startMinute: (json['start_minute'] as num?)?.toInt(),
        durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
        days: (json['days'] as num?)?.toInt(),
        attendeeIds: {
          for (final id in json['attendee_ids'] as List? ?? const [])
            id as String,
        },
        location: json['location'] as String? ?? '',
      );

  /// The saved template's id; null for a built-in or a suggested one.
  final String? id;

  /// A suggestion's group (`app.event_signature`), what hiding it names.
  final String? signature;

  /// How many events a suggestion was counted from.
  final int? count;

  final String title;
  final String? iconKey;
  final EventKind kind;
  final PresenceState? presenceState;
  final bool allDay;

  /// Minutes after midnight; null starts at the editor's next full hour.
  final int? startMinute;

  /// A timed template's length.
  final int? durationMinutes;

  /// The days an all-day template covers.
  final int? days;
  final Set<String> attendeeIds;
  final String location;
  final String notes;

  /// The kitchen-display choice set by hand; null follows `calendar.key_default`.
  final Importance? importance;
  final bool countdown;

  /// Repeats every year (only the built-in Geburtstag).
  final bool yearly;
  final String? createdBy;

  bool get isSuggestion => signature != null;
  bool get isSaved => id != null;

  /// The `p_template` of `api.event_template_save`; a suggestion kept as a template
  /// sends no id, so it is inserted.
  Map<String, dynamic> toJson() {
    final place = location.trim();
    final text = notes.trim();
    // A template's title is at most 120 characters; an event's may be longer.
    final name = String.fromCharCodes(title.trim().runes.take(120)).trimRight();
    return {
      'id': ?id,
      'title': name,
      'icon_key': kind == EventKind.presence ? null : iconKey,
      'kind': kind.wire,
      'presence_state': kind == EventKind.presence ? presenceState?.wire : null,
      'is_all_day': allDay,
      'start_minute': allDay ? null : startMinute,
      'duration_minutes': allDay ? null : durationMinutes,
      'days': allDay ? (days ?? 1) : null,
      'attendee_ids': attendeeIds.toList(),
      'location': place.isEmpty ? null : place,
      'description': text.isEmpty ? null : text,
      'importance': importance?.wire,
      'countdown': kind != EventKind.presence && countdown,
    };
  }
}
