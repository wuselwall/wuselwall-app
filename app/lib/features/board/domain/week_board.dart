import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/painting.dart';
import 'package:wuselwall/features/identity/domain/models.dart'
    show parseHexColor;

/// The kiosk week board's read model (specs/09 "The week board"), as returned by
/// `api.board_week(p_week_start)`. One call carries everything the board and its
/// tap-through details show, so the wall renders from one consistent snapshot.
///
/// Each module fills its own part: presence and events from the calendar (M1.3a),
/// school days and timetables from the Stundenplan (M1.3b), meals (M1.4), open tasks
/// (M1.2), the shopping count (M1.1). A part whose module is not built yet arrives
/// empty, and the board still draws its zone: an empty zone is a statement.
class WeekBoard {
  const WeekBoard({
    required this.weekStart,
    required this.today,
    required this.generatedAt,
    required this.settings,
    required this.members,
    required this.presence,
    required this.timetables,
    required this.days,
    required this.openTasks,
    required this.shoppingCount,
  });

  factory WeekBoard.fromJson(Map<String, dynamic> json) => WeekBoard(
    weekStart: parseDate(json['week_start'] as String),
    today: parseDate(json['today'] as String),
    generatedAt: DateTime.parse(json['generated_at'] as String),
    settings: BoardSettings.fromJson(
      json['settings'] as Map<String, dynamic>? ?? const {},
    ),
    members: _list(json['members'], BoardMember.fromJson),
    presence: _list(json['presence'], PresenceBand.fromJson),
    timetables: _list(json['timetables'], BoardTimetable.fromJson),
    days: _list(json['days'], BoardDay.fromJson),
    openTasks: {
      for (final row in _maps(json['open_tasks']))
        row['member_id'] as String: row['count'] as int,
    },
    shoppingCount: json['shopping_count'] as int? ?? 0,
  );

  /// Monday of the week on the board (after the rollover, the coming week).
  final DateTime weekStart;

  /// Today in the household's timezone. May lie outside the week after the rollover.
  final DateTime today;

  /// When the server built this snapshot.
  final DateTime generatedAt;

  final BoardSettings settings;

  /// Active members in household order (`profile.sort_order`): one row each.
  final List<BoardMember> members;

  /// Deviations from the baseline, each possibly spanning several days.
  final List<PresenceBand> presence;

  /// One per child with a timetable this week: bell times and class.
  final List<BoardTimetable> timetables;

  /// Exactly seven, Monday to Sunday.
  final List<BoardDay> days;

  /// Open tasks today per member id; members with none are absent.
  final Map<String, int> openTasks;

  /// Open items on the default shopping list.
  final int shoppingCount;

  BoardMember? member(String id) =>
      members.where((m) => m.id == id).firstOrNull;

  BoardTimetable? timetableOf(String memberId) =>
      timetables.where((t) => t.memberId == memberId).firstOrNull;

  /// Index 0–6 of [today] in this week, or null when today is outside it.
  int? get todayIndex {
    final i = today.difference(weekStart).inDays;
    return i >= 0 && i < 7 ? i : null;
  }

  /// ISO 8601 week number of this week.
  int get isoWeek => isoWeekOf(weekStart);

  /// Bands of [memberId] that touch day [index] (0–6), longest first.
  List<PresenceBand> presenceOn(String memberId, int index) {
    final day = days[index].date;
    return presence
        .where((b) => b.memberId == memberId && b.covers(day))
        .toList()
      ..sort((a, b) => b.dayCount.compareTo(a.dayCount));
  }
}

class BoardSettings {
  const BoardSettings({
    this.morningEnds = const TimeOfDay(hour: 12, minute: 0),
    this.eveningStarts = const TimeOfDay(hour: 17, minute: 0),
    this.memberLabel = MemberLabel.name,
  });

  factory BoardSettings.fromJson(Map<String, dynamic> json) {
    final parts = (json['day_parts'] as List?)?.cast<String>();
    return BoardSettings(
      morningEnds: parts == null
          ? const TimeOfDay(hour: 12, minute: 0)
          : parseTime(parts[0]),
      eveningStarts: parts == null
          ? const TimeOfDay(hour: 17, minute: 0)
          : parseTime(parts[1]),
      memberLabel: json['member_label'] == 'initial'
          ? MemberLabel.initial
          : MemberLabel.name,
    );
  }

  /// `board.day_parts`: where Vormittag ends and Abend begins.
  final TimeOfDay morningEnds;
  final TimeOfDay eveningStarts;

  /// `board.member_label`.
  final MemberLabel memberLabel;

  /// The band an event starting at [start] belongs to; all-day events go to morning.
  DayPart partOf(TimeOfDay? start) {
    if (start == null) return DayPart.morning;
    final m = minutesOf(start);
    if (m < minutesOf(morningEnds)) return DayPart.morning;
    if (m < minutesOf(eveningStarts)) return DayPart.afternoon;
    return DayPart.evening;
  }
}

enum MemberLabel { name, initial }

enum DayPart { morning, afternoon, evening }

enum MemberKind {
  adult,
  child;

  static MemberKind parse(String? v) => v == 'child' ? child : adult;
}

/// The six presence states (ADR-009, specs/17 "Presence treatments").
enum PresenceState {
  working,
  homeOffice,
  travel,
  away,
  off,
  childcare;

  static PresenceState parse(String v) => switch (v) {
    'working' => working,
    'home_office' => homeOffice,
    'travel' => travel,
    'away' => away,
    'off' => off,
    'childcare' => childcare,
    _ => throw FormatException('Unknown presence state $v'),
  };
}

class BoardMember {
  const BoardMember({
    required this.id,
    required this.displayName,
    required this.color,
    required this.kind,
    this.baseline,
  });

  factory BoardMember.fromJson(Map<String, dynamic> json) => BoardMember(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    color: parseHexColor(json['color'] as String),
    kind: MemberKind.parse(json['kind'] as String?),
    baseline: json['baseline'] == null
        ? null
        : Baseline.fromJson(json['baseline'] as Map<String, dynamic>),
  );

  final String id;
  final String displayName;

  /// The stored `colour_hex`; resolve it with `context.ww.member(color)`.
  final Color color;
  final MemberKind kind;

  /// Where this member normally is (`profile.default_presence_*`); drawn as a quiet
  /// chip on days without a deviation. Null: nothing is drawn.
  final Baseline? baseline;

  bool get isChild => kind == MemberKind.child;

  String get initial =>
      displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase();
}

class Baseline {
  const Baseline({required this.state, this.label});

  factory Baseline.fromJson(Map<String, dynamic> json) => Baseline(
    state: PresenceState.parse(json['state'] as String),
    label: json['label'] as String?,
  );

  final PresenceState state;

  /// The household's own words ("zu Hause"); null falls back to the state's name.
  final String? label;
}

/// One deviation from a member's baseline: a presence event's occurrence, clipped to
/// the week. A band from Thursday to Friday is one band, drawn across both columns.
class PresenceBand {
  const PresenceBand({
    required this.id,
    required this.memberId,
    required this.state,
    required this.firstDay,
    required this.lastDay,
    this.label,
    this.starts,
    this.ends,
    this.tentative = false,
    this.startsBeforeWeek = false,
    this.endsAfterWeek = false,
  });

  factory PresenceBand.fromJson(Map<String, dynamic> json) => PresenceBand(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    state: PresenceState.parse(json['state'] as String),
    label: json['label'] as String?,
    firstDay: parseDate(json['first_day'] as String),
    lastDay: parseDate(json['last_day'] as String),
    starts: _time(json['starts']),
    ends: _time(json['ends']),
    tentative: json['tentative'] as bool? ?? false,
    startsBeforeWeek: json['starts_before_week'] as bool? ?? false,
    endsAfterWeek: json['ends_after_week'] as bool? ?? false,
  );

  final String id;
  final String memberId;
  final PresenceState state;

  /// The event's title ("Dienst", "Dienstreise Berlin"); null → the state's name.
  final String? label;

  /// Inclusive, within the week.
  final DateTime firstDay;
  final DateTime lastDay;

  /// Times for a timed band ("8:30–14:00"); null for all-day bands.
  final TimeOfDay? starts;
  final TimeOfDay? ends;
  final bool tentative;

  /// The band continues past the week's edges; draw it open on that side.
  final bool startsBeforeWeek;
  final bool endsAfterWeek;

  int get dayCount => lastDay.difference(firstDay).inDays + 1;

  bool covers(DateTime day) => !day.isBefore(firstDay) && !day.isAfter(lastDay);
}

class BoardTimetable {
  const BoardTimetable({
    required this.memberId,
    required this.periods,
    this.classLabel,
    this.schoolName,
  });

  factory BoardTimetable.fromJson(Map<String, dynamic> json) => BoardTimetable(
    memberId: json['member_id'] as String,
    classLabel: json['class_label'] as String?,
    schoolName: json['school_name'] as String?,
    periods: _list(json['periods'], SchoolPeriod.fromJson),
  );

  final String memberId;
  final String? classLabel;
  final String? schoolName;

  /// The school's bell times, lessons and breaks, in order.
  final List<SchoolPeriod> periods;
}

enum PeriodKind { lesson, breakTime }

class SchoolPeriod {
  const SchoolPeriod({
    required this.index,
    required this.starts,
    required this.ends,
    required this.kind,
    this.label,
  });

  factory SchoolPeriod.fromJson(Map<String, dynamic> json) => SchoolPeriod(
    index: json['index'] as int,
    label: json['label'] as String?,
    starts: parseTime(json['starts'] as String),
    ends: parseTime(json['ends'] as String),
    kind: json['kind'] == 'break' ? PeriodKind.breakTime : PeriodKind.lesson,
  );

  /// 1 = 1. Stunde. Breaks carry the index of the lesson they follow.
  final int index;
  final String? label;
  final TimeOfDay starts;
  final TimeOfDay ends;
  final PeriodKind kind;
}

class BoardDay {
  const BoardDay({
    required this.date,
    required this.events,
    required this.busyUntil,
    required this.school,
    required this.meal,
  });

  factory BoardDay.fromJson(Map<String, dynamic> json) => BoardDay(
    date: parseDate(json['date'] as String),
    events: _list(json['events'], BoardEvent.fromJson),
    busyUntil: {
      for (final row in _maps(json['busy_until']))
        row['member_id'] as String: parseTime(row['until'] as String),
    },
    school: {
      for (final s in _list(json['school'], SchoolDay.fromJson)) s.memberId: s,
    },
    meal: json['meal'] == null
        ? null
        : BoardMeal.fromJson(json['meal'] as Map<String, dynamic>),
  );

  final DateTime date;

  /// Every appointment of the day (never presence), all-day first, then by time.
  /// The board shows the `isKey` ones; the day detail shows all.
  final List<BoardEvent> events;

  /// "Termine bis 17:00" per member (FR-1.19).
  final Map<String, TimeOfDay> busyUntil;

  /// Per child with a timetable; a child absent here has no school data at all.
  final Map<String, SchoolDay> school;

  /// The one warm meal (FR-8.4). Null only when the meals module is not built.
  final BoardMeal? meal;

  List<BoardEvent> get keyEvents => events.where((e) => e.isKey).toList();
}

class BoardEvent {
  const BoardEvent({
    required this.id,
    required this.title,
    required this.attendeeIds,
    this.location,
    this.starts,
    this.ends,
    this.tentative = false,
    this.isKey = false,
  });

  factory BoardEvent.fromJson(Map<String, dynamic> json) => BoardEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    location: json['location'] as String?,
    starts: _time(json['starts']),
    ends: _time(json['ends']),
    attendeeIds: ((json['attendee_ids'] as List?) ?? const []).cast<String>(),
    tentative: json['tentative'] as bool? ?? false,
    isKey: json['key'] as bool? ?? false,
  );

  final String id;
  final String title;
  final String? location;

  /// Null for an all-day event.
  final TimeOfDay? starts;
  final TimeOfDay? ends;

  /// In household member order.
  final List<String> attendeeIds;

  /// `status = 'tentative'`: drawn dashed, with a "?".
  final bool tentative;

  /// `importance = 'key'`: on the board, not only in the day detail.
  final bool isKey;

  bool get isAllDay => starts == null;
}

enum FreeReason { weekend, holiday }

enum LessonKind { lesson, care, club }

enum LessonStatus {
  normal,
  cancelled,
  substituted,
  roomChange,
  extra;

  static LessonStatus parse(String? v) => switch (v) {
    'cancelled' => cancelled,
    'substituted' => substituted,
    'room_change' => roomChange,
    'extra' => extra,
    _ => normal,
  };
}

/// One child's school day, already projected (A/B week, holidays, exceptions applied).
class SchoolDay {
  const SchoolDay({
    required this.memberId,
    required this.lessons,
    this.starts,
    this.ends,
    this.notable = const [],
    this.careUntil,
    this.careLabel,
    this.free,
    this.holidayName,
  });

  factory SchoolDay.fromJson(Map<String, dynamic> json) => SchoolDay(
    memberId: json['member_id'] as String,
    starts: _time(json['starts']),
    ends: _time(json['ends']),
    notable: ((json['notable'] as List?) ?? const []).cast<String>(),
    careUntil: _time(json['care_until']),
    careLabel: json['care_label'] as String?,
    free: switch (json['free']) {
      'weekend' => FreeReason.weekend,
      'holiday' => FreeReason.holiday,
      _ => null,
    },
    holidayName: json['holiday_name'] as String?,
    lessons: _list(json['lessons'], Lesson.fromJson),
  );

  final String memberId;

  /// The school-day span; null when there is no school ([free] says why).
  final TimeOfDay? starts;
  final TimeOfDay? ends;

  /// Names of notable lessons ("Sport", "Schwimmen"), in order, without repeats.
  final List<String> notable;

  /// End of the care row ("Hort bis 15:00"), when there is one.
  final TimeOfDay? careUntil;
  final String? careLabel;

  final FreeReason? free;
  final String? holidayName;

  /// Lessons, care and club rows in time order, cancelled ones included.
  final List<Lesson> lessons;

  bool get hasSchool => starts != null && ends != null;

  /// Equipment notes of the day's lessons that are not cancelled, without repeats.
  List<String> get equipment => {
    for (final l in lessons)
      if (l.equipment != null && l.status != LessonStatus.cancelled)
        l.equipment!,
  }.toList();
}

class Lesson {
  const Lesson({
    required this.starts,
    required this.ends,
    required this.subject,
    this.period,
    this.shortName,
    this.room,
    this.teacher,
    this.tint,
    this.kind = LessonKind.lesson,
    this.status = LessonStatus.normal,
    this.note,
    this.notable = false,
    this.equipment,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    period: json['period'] as int?,
    starts: parseTime(json['starts'] as String),
    ends: parseTime(json['ends'] as String),
    subject: json['subject'] as String,
    shortName: json['short'] as String?,
    room: json['room'] as String?,
    teacher: json['teacher'] as String?,
    tint: json['tint'] as String?,
    kind: switch (json['kind']) {
      'care' => LessonKind.care,
      'club' => LessonKind.club,
      _ => LessonKind.lesson,
    },
    status: LessonStatus.parse(json['status'] as String?),
    note: json['note'] as String?,
    notable: json['notable'] as bool? ?? false,
    equipment: json['equipment'] as String?,
  );

  /// The Stunde (1-based); null for rows off the grid (Hort, an AG).
  final int? period;
  final TimeOfDay starts;
  final TimeOfDay ends;

  /// Full subject name, or the title of a care or club row.
  final String subject;
  final String? shortName;
  final String? room;
  final String? teacher;

  /// A paper tint key (`PaperTints`, specs/17): blue, rose, lilac, leaf, …
  final String? tint;
  final LessonKind kind;
  final LessonStatus status;

  /// "Frau Klein", "fällt aus".
  final String? note;
  final bool notable;

  /// "Sportsachen" (FR-7.12).
  final String? equipment;
}

enum MealSlot { lunch, dinner }

/// The day's one warm meal. Present even when nothing is planned ([title] null), so
/// the slot and who is eating still show.
class BoardMeal {
  const BoardMeal({
    required this.slot,
    required this.eating,
    this.time,
    this.title,
    this.cookId,
    this.guests = 0,
  });

  factory BoardMeal.fromJson(Map<String, dynamic> json) => BoardMeal(
    slot: json['slot'] == 'lunch' ? MealSlot.lunch : MealSlot.dinner,
    time: _time(json['time']),
    title: json['title'] as String?,
    cookId: json['cook_id'] as String?,
    eating: ((json['eating'] as List?) ?? const []).cast<String>().toSet(),
    guests: json['guests'] as int? ?? 0,
  );

  final MealSlot slot;
  final TimeOfDay? time;

  /// The dish; null = nothing planned.
  final String? title;
  final String? cookId;

  /// Members eating (filled dot); every other member gets a hollow dot.
  final Set<String> eating;
  final int guests;

  bool get isPlanned => title != null;
}

// ── parsing helpers, shared with the demo and the tests ──────────────────────────

/// `2026-09-02` → a local date at midnight.
DateTime parseDate(String v) {
  final p = v.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// `08:30` or `08:30:00` → [TimeOfDay].
TimeOfDay parseTime(String v) {
  final p = v.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

/// ISO 8601 week number.
int isoWeekOf(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final jan1 = DateTime.utc(thursday.year);
  return thursday.difference(jan1).inDays ~/ 7 + 1;
}

TimeOfDay? _time(Object? v) => v == null ? null : parseTime(v as String);

Iterable<Map<String, dynamic>> _maps(Object? v) =>
    ((v as List?) ?? const []).cast<Map<String, dynamic>>();

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) parse) =>
    _maps(v).map(parse).toList(growable: false);
