import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/features/board/domain/week_board.dart';

/// The Stundenplan's rows as the `api` views return them (specs/15, the tables in
/// `school.sql`), plus the `school-week` reply. Times are `HH:MM` strings on the wire.

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String? _hm(TimeOfDay? t) => t == null
    ? null
    : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? _tod(Object? v) => v == null ? null : parseTime(v as String);

class SchoolRecord {
  const SchoolRecord({
    required this.id,
    required this.name,
    this.stateCode,
    this.regionCode,
    this.timezone = 'Europe/Berlin',
  });

  /// Rows of an older server carry only `state_code`; that stands in for the region.
  factory SchoolRecord.fromJson(Map<String, dynamic> json) => SchoolRecord(
    id: json['id'] as String,
    name: json['name'] as String,
    stateCode: json['state_code'] as String?,
    regionCode: json['region_code'] as String? ?? json['state_code'] as String?,
    timezone: json['timezone'] as String? ?? 'Europe/Berlin',
  );

  final String id;
  final String name;

  /// ISO 3166-2 (`DE-BE`), null when not given. Kept for rows written before regions.
  final String? stateCode;

  /// The school's region (any depth, `CH-ZH-ZH-ZH`), null when not given.
  final String? regionCode;
  final String timezone;
}

class PeriodRecord {
  const PeriodRecord({
    required this.schoolId,
    required this.index,
    required this.starts,
    required this.ends,
    required this.kind,
    this.id,
    this.label,
  });

  factory PeriodRecord.fromJson(Map<String, dynamic> json) => PeriodRecord(
    id: json['id'] as String?,
    schoolId: json['school_id'] as String,
    index: json['index'] as int,
    label: json['label'] as String?,
    starts: parseTime(json['starts_at'] as String),
    ends: parseTime(json['ends_at'] as String),
    kind: json['kind'] as String,
  );

  final String? id;
  final String schoolId;
  final int index;
  final String? label;
  final TimeOfDay starts;
  final TimeOfDay ends;

  /// 'lesson' or 'break'.
  final String kind;

  bool get isBreak => kind == 'break';

  Map<String, dynamic> toJson() => {
    'index': index,
    'label': label,
    'starts_at': _hm(starts),
    'ends_at': _hm(ends),
    'kind': kind,
  };
}

class TermRecord {
  const TermRecord({
    required this.id,
    required this.schoolId,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    this.abAnchorWeek,
    this.isCurrent = false,
  });

  factory TermRecord.fromJson(Map<String, dynamic> json) => TermRecord(
    id: json['id'] as String,
    schoolId: json['school_id'] as String,
    name: json['name'] as String,
    startsOn: parseDate(json['starts_on'] as String),
    endsOn: parseDate(json['ends_on'] as String),
    abAnchorWeek: json['ab_anchor_week'] as int?,
    isCurrent: json['is_current'] as bool? ?? false,
  );

  final String id;
  final String schoolId;
  final String name;
  final DateTime startsOn;
  final DateTime endsOn;
  final int? abAnchorWeek;
  final bool isCurrent;

  bool covers(DateTime day) => !day.isBefore(startsOn) && !day.isAfter(endsOn);

  Map<String, dynamic> toJson({String? id}) => {
    'id': ?id,
    'school_id': schoolId,
    'name': name,
    'starts_on': ymd(startsOn),
    'ends_on': ymd(endsOn),
    'ab_anchor_week': abAnchorWeek,
    'is_current': isCurrent,
  };
}

class SubjectRecord {
  const SubjectRecord({
    required this.id,
    required this.name,
    required this.shortName,
    required this.tint,
    this.iconKey,
    this.equipmentNote,
    this.notableDefault = false,
  });

  factory SubjectRecord.fromJson(Map<String, dynamic> json) => SubjectRecord(
    id: json['id'] as String,
    name: json['name'] as String,
    shortName: json['short_name'] as String,
    tint: json['tint'] as String,
    iconKey: json['icon_key'] as String?,
    equipmentNote: json['equipment_note'] as String?,
    notableDefault: json['notable_default'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String shortName;

  /// A `PaperTints` key.
  final String tint;

  /// Opaque key from the starter set; mapped to an icon by [schoolIcon].
  final String? iconKey;
  final String? equipmentNote;
  final bool notableDefault;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'short_name': shortName,
    'tint': tint,
    'icon_key': iconKey,
    'equipment_note': equipmentNote,
    'notable_default': notableDefault,
  };
}

/// The paper subject tints offered by the subject editor.
const subjectTints = [
  'blue',
  'rose',
  'lilac',
  'leaf',
  'peach',
  'lemon',
  'mint',
  'stone',
];

class TimetableRecord {
  const TimetableRecord({
    required this.id,
    required this.profileId,
    required this.schoolId,
    required this.termId,
    required this.weekCycle,
    required this.validFrom,
    this.classLabel,
    this.validTo,
  });

  factory TimetableRecord.fromJson(Map<String, dynamic> json) =>
      TimetableRecord(
        id: json['id'] as String,
        profileId: json['profile_id'] as String,
        schoolId: json['school_id'] as String,
        termId: json['term_id'] as String,
        classLabel: json['class_label'] as String?,
        weekCycle: json['week_cycle'] as String? ?? 'weekly',
        validFrom: parseDate(json['valid_from'] as String),
        validTo: json['valid_to'] == null
            ? null
            : parseDate(json['valid_to'] as String),
      );

  final String id;
  final String profileId;
  final String schoolId;
  final String termId;
  final String? classLabel;

  /// 'weekly' or 'ab'.
  final String weekCycle;
  final DateTime validFrom;
  final DateTime? validTo;

  bool get isAb => weekCycle == 'ab';

  /// The wire form for `timetable_save`; no id creates the timetable.
  Map<String, dynamic> toMetaJson() => {
    if (id.isNotEmpty) 'id': id,
    'profile_id': profileId,
    'school_id': schoolId,
    'term_id': termId,
    'class_label': classLabel,
    'week_cycle': weekCycle,
    'valid_from': ymd(validFrom),
    'valid_to': validTo == null ? null : ymd(validTo!),
  };
}

/// One cell of the grid, or a care/club row. `isNotable` null means "the subject's
/// default" (the server fills it in).
class LessonRecord {
  const LessonRecord({
    required this.id,
    required this.timetableId,
    required this.weekday,
    this.periodIndex,
    this.startsAt,
    this.endsAt,
    this.subjectId,
    this.kind = 'lesson',
    this.title,
    this.teacher,
    this.room,
    this.weekParity = 'all',
    this.isNotable,
    this.note,
  });

  factory LessonRecord.fromJson(Map<String, dynamic> json) => LessonRecord(
    id: json['id'] as String,
    timetableId: json['timetable_id'] as String,
    weekday: json['weekday'] as int,
    periodIndex: json['period_index'] as int?,
    startsAt: _tod(json['starts_at']),
    endsAt: _tod(json['ends_at']),
    subjectId: json['subject_id'] as String?,
    kind: json['kind'] as String? ?? 'lesson',
    title: json['title'] as String?,
    teacher: json['teacher'] as String?,
    room: json['room'] as String?,
    weekParity: json['week_parity'] as String? ?? 'all',
    isNotable: json['is_notable'] as bool?,
    note: json['note'] as String?,
  );

  final String id;
  final String timetableId;

  /// ISO weekday, 1 = Monday.
  final int weekday;
  final int? periodIndex;
  final TimeOfDay? startsAt;
  final TimeOfDay? endsAt;
  final String? subjectId;
  final String kind;
  final String? title;
  final String? teacher;
  final String? room;

  /// 'all', 'a' or 'b'.
  final String weekParity;
  final bool? isNotable;
  final String? note;

  /// The wire form for `timetable_lessons_set`. A null id is a new row.
  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'period_index': periodIndex,
    'starts_at': _hm(startsAt),
    'ends_at': _hm(endsAt),
    'subject_id': subjectId,
    'kind': kind,
    'title': title,
    'teacher': teacher,
    'room': room,
    'week_parity': weekParity,
    'note': note,
    'is_notable': ?isNotable,
  };
}

class ExceptionRecord {
  const ExceptionRecord({
    required this.id,
    required this.timetableId,
    required this.onDate,
    required this.kind,
    this.periodIndex,
    this.subjectId,
    this.teacher,
    this.room,
    this.startsAt,
    this.endsAt,
    this.note,
  });

  factory ExceptionRecord.fromJson(Map<String, dynamic> json) =>
      ExceptionRecord(
        id: json['id'] as String,
        timetableId: json['timetable_id'] as String,
        onDate: parseDate(json['on_date'] as String),
        periodIndex: json['period_index'] as int?,
        kind: json['kind'] as String,
        subjectId: json['subject_id'] as String?,
        teacher: json['teacher'] as String?,
        room: json['room'] as String?,
        startsAt: _tod(json['starts_at']),
        endsAt: _tod(json['ends_at']),
        note: json['note'] as String?,
      );

  final String id;
  final String timetableId;
  final DateTime onDate;
  final int? periodIndex;

  /// 'cancelled', 'substituted', 'room_change' or 'extra'.
  final String kind;
  final String? subjectId;
  final String? teacher;
  final String? room;
  final TimeOfDay? startsAt;
  final TimeOfDay? endsAt;
  final String? note;

  /// The wire form for `timetable_exception_save`; an id updates the existing row.
  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'timetable_id': timetableId,
    'on_date': ymd(onDate),
    'period_index': periodIndex,
    'kind': kind,
    'subject_id': subjectId,
    'teacher': teacher,
    'room': room,
    'starts_at': _hm(startsAt),
    'ends_at': _hm(endsAt),
    'note': note,
  };
}

class HolidayRecord {
  const HolidayRecord({
    required this.id,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    this.schoolId,
    this.kind = 'holiday',
    this.source = 'manual',
  });

  factory HolidayRecord.fromJson(Map<String, dynamic> json) => HolidayRecord(
    id: json['id'] as String,
    schoolId: json['school_id'] as String?,
    name: json['name'] as String,
    startsOn: parseDate(json['starts_on'] as String),
    endsOn: parseDate(json['ends_on'] as String),
    kind: json['kind'] as String? ?? 'holiday',
    source: json['source'] as String? ?? 'manual',
  );

  final String id;
  final String? schoolId;
  final String name;
  final DateTime startsOn;

  /// Inclusive.
  final DateTime endsOn;
  final String kind;

  /// 'manual', or 'imported' for a row taken from the region's holiday feed.
  final String source;

  bool get isImported => source == 'imported';

  bool overlaps(DateTime from, DateTime to) =>
      !endsOn.isBefore(from) && !startsOn.isAfter(to);

  Map<String, dynamic> toJson({String? id}) => {
    'id': ?id,
    'school_id': schoolId,
    'name': name,
    'starts_on': ymd(startsOn),
    'ends_on': ymd(endsOn),
    'kind': kind,
  };
}

/// Everything the Stundenplan reads in one go (the eight views).
class SchoolData {
  const SchoolData({
    required this.schools,
    required this.periods,
    required this.terms,
    required this.subjects,
    required this.timetables,
    required this.lessons,
    required this.exceptions,
    required this.holidays,
  });

  final List<SchoolRecord> schools;
  final List<PeriodRecord> periods;
  final List<TermRecord> terms;
  final List<SubjectRecord> subjects;
  final List<TimetableRecord> timetables;
  final List<LessonRecord> lessons;
  final List<ExceptionRecord> exceptions;
  final List<HolidayRecord> holidays;

  bool get hasSchool => schools.isNotEmpty;

  TimetableRecord? timetableOf(String profileId, String termId) => timetables
      .where((t) => t.profileId == profileId && t.termId == termId)
      .firstOrNull;

  /// The subject's icon key, by name (the projected lessons carry names, not ids).
  String? iconKeyFor(String subjectName) =>
      subjects.where((s) => s.name == subjectName).firstOrNull?.iconKey;

  /// The term covering [day]. With [schoolId], only that school's terms count.
  /// Never reuse another term: the projected week would still have no timetable.
  TermRecord? termFor(DateTime day, {String? schoolId}) {
    final own = [
      for (final t in terms)
        if (schoolId == null || t.schoolId == schoolId) t,
    ];
    return own.where((t) => t.covers(day)).firstOrNull;
  }
}

/// One day of the `school-week` reply: a SchoolDay and its date.
class SchoolWeekDay {
  const SchoolWeekDay({required this.date, required this.day});

  factory SchoolWeekDay.fromJson(Map<String, dynamic> json) => SchoolWeekDay(
    date: parseDate(json['date'] as String),
    day: SchoolDay.fromJson(json),
  );

  final DateTime date;
  final SchoolDay day;
}

/// `POST school-week` → `{timetables, days}`.
class SchoolWeek {
  const SchoolWeek({required this.timetables, required this.days});

  factory SchoolWeek.fromJson(Map<String, dynamic> json) => SchoolWeek(
    timetables: [
      for (final t in (json['timetables'] as List? ?? const []))
        BoardTimetable.fromJson(t as Map<String, dynamic>),
    ],
    days: [
      for (final d in (json['days'] as List? ?? const []))
        SchoolWeekDay.fromJson(d as Map<String, dynamic>),
    ],
  );

  final List<BoardTimetable> timetables;
  final List<SchoolWeekDay> days;

  BoardTimetable? timetableOf(String memberId) =>
      timetables.where((t) => t.memberId == memberId).firstOrNull;

  /// The projected day of [memberId] on [date], or null when none came back.
  SchoolDay? dayOf(String memberId, DateTime date) => days
      .where((d) => d.date == date && d.day.memberId == memberId)
      .firstOrNull
      ?.day;
}
