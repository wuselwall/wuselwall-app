import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

import 'fakes.dart';

/// A school with one timetable for [kidId] (Anna): Mathe, Deutsch and Sport on every
/// weekday, bell times for three lessons. Enough for the grid, the sheet and the editor.
///
/// [secondSchool] adds a Gymnasium with its own bell times and term (the siblings at
/// different schools). [varied] makes Friday's third lesson differ from the others, so
/// day operations show in the saved lessons.
SchoolData referenceSchoolData({
  bool withSchool = true,
  bool withTimetable = true,
  bool secondSchool = false,
  bool varied = false,
}) {
  const schoolId = 'school-1';
  const termId = 'term-1';
  const ttId = 'tt-kid';
  return SchoolData(
    schools: withSchool
        ? [
            SchoolRecord.fromJson({
              'id': schoolId,
              'name': 'Grundschule Lindenhof',
              'state_code': 'DE-BE',
              'timezone': 'Europe/Berlin',
            }),
            if (secondSchool)
              SchoolRecord.fromJson({
                'id': secondSchoolId,
                'name': 'Gymnasium Lindenhof',
                'state_code': 'DE-BE',
                'timezone': 'Europe/Berlin',
              }),
          ]
        : const [],
    periods: withSchool
        ? [
            for (final p in _bellRows)
              PeriodRecord.fromJson({...p, 'school_id': schoolId}),
            if (secondSchool)
              for (final p in _gymnasiumBellRows)
                PeriodRecord.fromJson({...p, 'school_id': secondSchoolId}),
          ]
        : const [],
    terms: withSchool
        ? [
            TermRecord.fromJson({
              'id': termId,
              'school_id': schoolId,
              'name': 'Schuljahr 2026/27',
              'starts_on': '2026-08-01',
              'ends_on': '2027-07-31',
              'is_current': true,
            }),
            if (secondSchool)
              TermRecord.fromJson({
                'id': secondTermId,
                'school_id': secondSchoolId,
                'name': 'Schuljahr 2026/27',
                'starts_on': '2026-08-01',
                'ends_on': '2027-07-31',
                'is_current': true,
              }),
          ]
        : const [],
    subjects: [for (final s in _subjectRows) SubjectRecord.fromJson(s)],
    timetables: withTimetable
        ? [
            TimetableRecord.fromJson({
              'id': ttId,
              'profile_id': kidId,
              'school_id': schoolId,
              'term_id': termId,
              'class_label': '3b',
              'week_cycle': 'weekly',
              'valid_from': '2026-08-01',
              'valid_to': null,
            }),
          ]
        : const [],
    lessons: withTimetable
        ? [
            for (var wd = 1; wd <= 5; wd++) ...[
              LessonRecord.fromJson(_lesson(ttId, wd, 1, 'sub-ma', 'R1')),
              LessonRecord.fromJson(_lesson(ttId, wd, 2, 'sub-d', null)),
              if (varied && wd == 5)
                LessonRecord.fromJson(_lesson(ttId, wd, 3, 'sub-d', 'Aula'))
              else
                LessonRecord.fromJson(
                  _lesson(ttId, wd, 3, 'sub-sp', 'Turnhalle'),
                ),
            ],
          ]
        : const [],
    exceptions: const [],
    holidays: const [],
  );
}

Map<String, dynamic> _lesson(
  String tt,
  int weekday,
  int period,
  String subject,
  String? room,
) => {
  'id': 'l-$weekday-$period',
  'timetable_id': tt,
  'weekday': weekday,
  'period_index': period,
  'starts_at': null,
  'ends_at': null,
  'subject_id': subject,
  'kind': 'lesson',
  'title': null,
  'teacher': null,
  'room': room,
  'week_parity': 'all',
  'is_notable': subject == 'sub-sp',
  'note': null,
};

const _bellRows = [
  {
    'id': 'p1',
    'index': 1,
    'label': null,
    'starts_at': '08:00',
    'ends_at': '08:45',
    'kind': 'lesson',
  },
  {
    'id': 'p2',
    'index': 1,
    'label': null,
    'starts_at': '08:45',
    'ends_at': '08:50',
    'kind': 'break',
  },
  {
    'id': 'p3',
    'index': 2,
    'label': null,
    'starts_at': '08:50',
    'ends_at': '09:35',
    'kind': 'lesson',
  },
  {
    'id': 'p4',
    'index': 2,
    'label': null,
    'starts_at': '09:35',
    'ends_at': '09:55',
    'kind': 'break',
  },
  {
    'id': 'p5',
    'index': 3,
    'label': null,
    'starts_at': '09:55',
    'ends_at': '10:40',
    'kind': 'lesson',
  },
];

const secondSchoolId = 'school-2';
const secondTermId = 'term-2';

const _gymnasiumBellRows = [
  {
    'id': 'g1',
    'index': 1,
    'label': null,
    'starts_at': '07:45',
    'ends_at': '08:30',
    'kind': 'lesson',
  },
  {
    'id': 'g2',
    'index': 1,
    'label': null,
    'starts_at': '08:30',
    'ends_at': '08:40',
    'kind': 'break',
  },
  {
    'id': 'g3',
    'index': 2,
    'label': null,
    'starts_at': '08:40',
    'ends_at': '09:25',
    'kind': 'lesson',
  },
];

const _subjectRows = [
  {
    'id': 'sub-ma',
    'name': 'Mathematik',
    'short_name': 'Ma',
    'tint': 'blue',
    'icon_key': 'numbers',
    'equipment_note': null,
    'notable_default': false,
  },
  {
    'id': 'sub-d',
    'name': 'Deutsch',
    'short_name': 'D',
    'tint': 'rose',
    'icon_key': 'book',
    'equipment_note': null,
    'notable_default': false,
  },
  {
    'id': 'sub-sp',
    'name': 'Sport',
    'short_name': 'Sp',
    'tint': 'peach',
    'icon_key': 'run',
    'equipment_note': 'Sportsachen',
    'notable_default': true,
  },
];

/// The `school-week` reply for [from]..[to]: every day has the three lessons, Mathe
/// cancelled on Wednesdays, so the struck-through cell is there whatever the day.
Map<String, dynamic> _weekJson(DateTime from, DateTime to) {
  String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final days = <Map<String, dynamic>>[];
  for (
    var d = DateTime(from.year, from.month, from.day);
    !d.isAfter(to);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    final cancelled = d.weekday == DateTime.wednesday;
    days.add({
      'date': ymd(d),
      'member_id': kidId,
      'starts': '08:00',
      'ends': '10:40',
      'notable': ['Sport'],
      'lessons': [
        {
          'period': 1,
          'starts': '08:00',
          'ends': '08:45',
          'subject': 'Mathematik',
          'short': 'Ma',
          'room': 'R1',
          'tint': 'blue',
          'kind': 'lesson',
          'status': cancelled ? 'cancelled' : 'normal',
          'notable': false,
        },
        {
          'period': 2,
          'starts': '08:50',
          'ends': '09:35',
          'subject': 'Deutsch',
          'short': 'D',
          'tint': 'rose',
          'kind': 'lesson',
          'status': 'normal',
          'notable': false,
        },
        {
          'period': 3,
          'starts': '09:55',
          'ends': '10:40',
          'subject': 'Sport',
          'short': 'Sp',
          'room': 'Turnhalle',
          'tint': 'peach',
          'kind': 'lesson',
          'status': 'normal',
          'notable': true,
          'equipment': 'Sportsachen',
        },
      ],
    });
  }
  return {
    'timetables': [
      {
        'member_id': kidId,
        'class_label': '3b',
        'school_name': 'Grundschule Lindenhof',
        'periods': [
          for (final p in _bellRows)
            {
              'index': p['index'],
              'starts': p['starts_at'],
              'ends': p['ends_at'],
              'kind': p['kind'],
            },
        ],
      },
    ],
    'days': days,
  };
}

/// [d] with some lists replaced.
SchoolData _withData(
  SchoolData d, {
  List<SchoolRecord>? schools,
  List<LessonRecord>? lessons,
}) => SchoolData(
  schools: schools ?? d.schools,
  periods: d.periods,
  terms: d.terms,
  subjects: d.subjects,
  timetables: d.timetables,
  lessons: lessons ?? d.lessons,
  exceptions: d.exceptions,
  holidays: d.holidays,
);

/// In-memory school backend. Serves [data] and a projected week, and records every
/// write the UI makes, so tests can assert the JSON the repository would send.
class FakeSchoolRepository implements SchoolRepository {
  FakeSchoolRepository({SchoolData? data})
    : data = data ?? referenceSchoolData();

  SchoolData data;
  final exceptionSaves = <ExceptionRecord>[];
  final periodSets = <List<PeriodRecord>>[];
  final lessonSets = <({String timetableId, List<LessonRecord> lessons})>[];
  final timetableSaves = <TimetableRecord>[];
  final schoolSaves = <({String? id, String name, String? timezone})>[];
  final actors = <String?>[];

  /// Saved schools join [data], as the server would return them on the refetch.
  @override
  Future<Result<String>> saveSchool({
    required String? actor,
    String? id,
    required String name,
    String? stateCode,
    String? timezone,
  }) async {
    actors.add(actor);
    schoolSaves.add((id: id, name: name, timezone: timezone));
    final newId = id ?? 'school-new-${schoolSaves.length}';
    final school = SchoolRecord.fromJson({
      'id': newId,
      'name': name,
      'state_code': stateCode,
      'timezone': timezone ?? 'Europe/Berlin',
    });
    data = _withData(
      data,
      schools: [...data.schools.where((s) => s.id != newId), school],
    );
    return Ok(newId);
  }

  @override
  Future<Result<SchoolData>> all() async => Ok(data);

  @override
  Future<Result<SchoolWeek>> week({
    required DateTime from,
    required DateTime to,
  }) async {
    final json = _weekJson(from, to);
    // A child without a timetable gets none in the reply, as the projection would.
    if (!data.timetables.any((t) => t.profileId == kidId)) {
      json['timetables'] = <Map<String, dynamic>>[];
    }
    return Ok(SchoolWeek.fromJson(json));
  }

  @override
  Future<Result<String>> saveException({
    required String? actor,
    required ExceptionRecord exception,
  }) async {
    actors.add(actor);
    exceptionSaves.add(exception);
    return const Ok('ex-1');
  }

  @override
  Future<Result<void>> setPeriods({
    required String? actor,
    required String schoolId,
    required List<PeriodRecord> periods,
  }) async {
    actors.add(actor);
    periodSets.add(periods);
    return const Ok(null);
  }

  @override
  Future<Result<void>> setLessons({
    required String? actor,
    required String timetableId,
    required List<LessonRecord> lessons,
  }) async {
    actors.add(actor);
    lessonSets.add((timetableId: timetableId, lessons: lessons));
    data = _withData(
      data,
      lessons: [
        for (final l in data.lessons)
          if (l.timetableId != timetableId) l,
        ...lessons,
      ],
    );
    return const Ok(null);
  }

  @override
  Future<Result<String>> saveTimetable({
    required String? actor,
    required TimetableRecord timetable,
  }) async {
    actors.add(actor);
    timetableSaves.add(timetable);
    return const Ok('tt-kid');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
