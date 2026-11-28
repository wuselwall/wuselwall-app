import 'package:flutter/foundation.dart';
import 'package:wuselwall/core/text/suggest.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';

/// Who a built-in template invites (specs/28): every active member, every active
/// child, or the person creating it.
enum StarterPeople { family, children, actor }

/// The built-in templates of Kalender → *Neuer Termin* (specs/28 "Built-in templates").
/// Each language names them itself (the ARB keys `eventStarter*`); this is what they
/// start as. Every value is only a suggestion the editor shows before anything is saved.
/// The page lists them in this order: what a family enters often first, what comes once
/// a year last. The school ones ([school]) come after them and show only to a family
/// with a child.
enum EventStarter {
  cleaning(
    iconKey: 'broom',
    startMinute: 9 * 60,
    minutes: 180,
    people: StarterPeople.actor,
    weekly: true,
  ),
  sportsPractice(
    iconKey: 'football',
    startMinute: 17 * 60,
    minutes: 60,
    people: StarterPeople.actor,
  ),
  doctor(people: StarterPeople.actor),
  guestDinner(
    iconKey: 'house',
    startMinute: 18 * 60 + 30,
    minutes: 180,
    people: StarterPeople.family,
  ),
  dayOut(
    iconKey: 'hiking',
    allDay: true,
    people: StarterPeople.family,
    countdown: true,
  ),
  playdate(
    iconKey: 'game_die',
    startMinute: 15 * 60,
    minutes: 120,
    people: StarterPeople.children,
  ),
  cinema(
    iconKey: 'cinema',
    startMinute: 16 * 60,
    minutes: 120,
    people: StarterPeople.family,
  ),
  holiday(
    iconKey: 'plane',
    allDay: true,
    days: 7,
    people: StarterPeople.family,
    countdown: true,
  ),
  birthday(
    iconKey: 'cake',
    allDay: true,
    people: StarterPeople.family,
    yearly: true,
    countdown: true,
  ),
  parentsEvening(
    startMinute: 19 * 60 + 30,
    minutes: 120,
    people: StarterPeople.actor,
    school: true,
  ),
  parentTeacherTalk(
    startMinute: 16 * 60,
    minutes: 30,
    people: StarterPeople.actor,
    school: true,
  ),
  schoolTrip(
    iconKey: 'backpack',
    allDay: true,
    people: StarterPeople.children,
    countdown: true,
    school: true,
  ),
  schoolTest(
    iconKey: 'book',
    startMinute: 8 * 60,
    minutes: 60,
    people: StarterPeople.children,
    school: true,
  ),
  schoolParty(
    iconKey: 'balloon',
    startMinute: 16 * 60,
    minutes: 180,
    people: StarterPeople.family,
    school: true,
  ),
  sportsDay(allDay: true, people: StarterPeople.children, school: true);

  const EventStarter({
    required this.people,
    this.iconKey,
    this.allDay = false,
    this.startMinute,
    this.minutes = 60,
    this.days = 1,
    this.weekly = false,
    this.yearly = false,
    this.countdown = false,
    this.school = false,
  });

  /// The general starters, in the page's order.
  static List<EventStarter> get general => [
    for (final s in values)
      if (!s.school) s,
  ];

  /// The school starters, in the page's order.
  static List<EventStarter> get schoolOnes => [
    for (final s in values)
      if (s.school) s,
  ];

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
  final bool weekly;
  final bool yearly;
  final bool countdown;

  /// A school one: the page shows it only to a family with a child (specs/28).
  final bool school;

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
      weekly: weekly,
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
    this.weekly = false,
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

  /// Repeats every week on the start's weekday (only the built-in Putzhilfe).
  final bool weekly;

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

/// How often a picture must show up in a family's appointments before its built-in
/// tile moves to the front: one entry may be a one-off, two are a habit.
const int habitMinimum = 2;

/// [builtIns] with the tiles of the family's habits first (specs/29 feature 3): a tile
/// counts every earlier appointment whose picture is the tile's own [EventStarter.iconKey]
/// (the appointment's own picture, or when it has none what [iconOf] makes of its
/// title). Tiles with at least [minimum] of them come first, the most used first; the
/// others, and tiles with the same count, keep their order. With no history, or when
/// [iconOf] knows nothing, the order is unchanged.
List<EventStarter> orderBuiltInsByHabit(
  List<EventStarter> builtIns,
  Iterable<TextSuggestion> history,
  String? Function(String title) iconOf, {
  int minimum = habitMinimum,
}) {
  final used = <String, int>{};
  for (final entry in history) {
    final key = entry.iconKey ?? iconOf(entry.text);
    if (key != null) used[key] = (used[key] ?? 0) + entry.count;
  }
  if (used.isEmpty) return builtIns;
  int countOf(EventStarter s) => used[s.iconKey] ?? 0;
  final habits = [
    for (final s in builtIns)
      if (countOf(s) >= minimum) s,
  ];
  // List.sort is not stable: the position breaks the tie.
  final position = {for (final (i, s) in builtIns.indexed) s: i};
  habits.sort((a, b) {
    final byCount = countOf(b).compareTo(countOf(a));
    return byCount != 0 ? byCount : position[a]!.compareTo(position[b]!);
  });
  return [
    ...habits,
    for (final s in builtIns)
      if (countOf(s) < minimum) s,
  ];
}
