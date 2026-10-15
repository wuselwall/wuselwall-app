import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_english.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

/// The Stundenplan for the invented family in [DemoData], used by the demo build
/// (`lib/main_demo.dart`). The grids are the ones `demo_board.dart` draws; the views
/// and the `school-week` reply are built as JSON and run through the same parsers the
/// app uses. Writes change in-memory lists, so the editor and the sheets work in the demo.
class DemoSchoolRepository implements SchoolRepository {
  DemoSchoolRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _exceptions = _seedExceptions();
  }

  final DateTime Function() _clock;

  late final List<Map<String, dynamic>> _exceptions;

  List<Map<String, dynamic>> _seedExceptions() => [
    for (final e in _exceptionSeeds)
      {
        'id': 'ex-${e.$1}-${e.$2}-${e.$3}',
        'timetable_id': _plans.firstWhere((p) => p.member == e.$1).timetableId,
        'on_date': _dateOfWeekday(e.$2),
        'period_index': e.$3,
        'kind': e.$4,
        'note': demoText(e.$5),
      },
  ];

  final List<Map<String, dynamic>> _subjects = [
    for (final e in _subjectCodes.entries)
      {
        'id': _subjectId(e.key),
        'name': demoText(e.value),
        'short_name': demoShort(e.key),
        'tint': _tints[e.key] ?? 'stone',
        'icon_key': _icons[e.key],
        'equipment_note': demoTextOrNull(_equipment[e.key]),
        'notable_default': _notable.containsKey(e.key),
      },
  ];

  /// Ids for the exceptions the demo's writes create.
  int _nextId = 100;

  String _dateOfWeekday(int dayIndex) =>
      _ymd(_monday().add(Duration(days: dayIndex)));

  DateTime _monday() {
    final now = _clock();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> get _schoolRows => [
    for (final p in _plans)
      {
        'id': p.schoolId,
        'name': demoText(p.school),
        'state_code': 'DE-BE',
        'region_code': 'DE-BE',
        'timezone': 'Europe/Berlin',
      },
  ];

  List<Map<String, dynamic>> get _periodRows => [
    for (final p in _plans)
      for (final row in _periods())
        {
          'id': '${p.schoolId}-${row['index']}-${row['kind']}',
          'school_id': p.schoolId,
          ...row,
          'starts_at': row['starts'],
          'ends_at': row['ends'],
        },
  ];

  List<Map<String, dynamic>> get _termRows => [
    for (final p in _plans)
      {
        'id': 'term-${p.member}',
        'school_id': p.schoolId,
        'name': demoText('Schuljahr 2026/27'),
        'starts_on': '2026-08-01',
        'ends_on': '2027-07-31',
        'ab_anchor_week': null,
        'is_current': true,
      },
  ];

  List<Map<String, dynamic>> get _timetableRows => [
    for (final p in _plans)
      {
        'id': p.timetableId,
        'profile_id': p.member,
        'school_id': p.schoolId,
        'term_id': 'term-${p.member}',
        'class_label': demoText(p.klasse),
        'week_cycle': 'weekly',
        'valid_from': '2026-08-01',
        'valid_to': null,
      },
  ];

  List<Map<String, dynamic>> get _lessonRows => [
    for (final p in _plans)
      for (var d = 0; d < p.grid.length; d++)
        for (var i = 0; i < p.grid[d].length; i++)
          if (p.grid[d][i] != null)
            {
              'id': '${p.timetableId}-$d-${i + 1}',
              'timetable_id': p.timetableId,
              'weekday': d + 1,
              'period_index': i + 1,
              'starts_at': null,
              'ends_at': null,
              'subject_id': _subjectId(p.grid[d][i]!),
              'kind': 'lesson',
              'title': null,
              'teacher': null,
              'room': demoTextOrNull(p.rooms[p.grid[d][i]]),
              'week_parity': 'all',
              'is_notable': _notable.containsKey(p.grid[d][i]),
              'note': null,
            },
    for (final p in _plans)
      for (final e in p.hort.entries)
        {
          'id': '${p.timetableId}-hort-${e.key}',
          'timetable_id': p.timetableId,
          'weekday': e.key + 1,
          'period_index': null,
          'starts_at': '13:30',
          'ends_at': e.value,
          'subject_id': null,
          'kind': 'care',
          'title': demoText('Hort'),
          'week_parity': 'all',
          'is_notable': false,
        },
  ];

  @override
  Future<Result<List<SchoolRecord>>> schools() async =>
      Ok([for (final r in _schoolRows) SchoolRecord.fromJson(r)]);

  @override
  Future<Result<List<PeriodRecord>>> periods() async =>
      Ok([for (final r in _periodRows) PeriodRecord.fromJson(r)]);

  @override
  Future<Result<List<TermRecord>>> terms() async =>
      Ok([for (final r in _termRows) TermRecord.fromJson(r)]);

  @override
  Future<Result<List<SubjectRecord>>> subjects() async =>
      Ok([for (final r in _subjects) SubjectRecord.fromJson(r)]);

  @override
  Future<Result<List<TimetableRecord>>> timetables() async =>
      Ok([for (final r in _timetableRows) TimetableRecord.fromJson(r)]);

  @override
  Future<Result<List<LessonRecord>>> lessons() async =>
      Ok([for (final r in _lessonRows) LessonRecord.fromJson(r)]);

  @override
  Future<Result<List<ExceptionRecord>>> exceptions() async =>
      Ok([for (final r in _exceptions) ExceptionRecord.fromJson(r)]);

  @override
  Future<Result<List<HolidayRecord>>> holidays() async => const Ok([]);

  @override
  Future<Result<SchoolData>> all() async => Ok(
    SchoolData(
      schools: [for (final r in _schoolRows) SchoolRecord.fromJson(r)],
      periods: [for (final r in _periodRows) PeriodRecord.fromJson(r)],
      terms: [for (final r in _termRows) TermRecord.fromJson(r)],
      subjects: [for (final r in _subjects) SubjectRecord.fromJson(r)],
      timetables: [for (final r in _timetableRows) TimetableRecord.fromJson(r)],
      lessons: [for (final r in _lessonRows) LessonRecord.fromJson(r)],
      exceptions: [for (final r in _exceptions) ExceptionRecord.fromJson(r)],
      holidays: const [],
    ),
  );

  /// Projects every day of [from]..[to] for the demo's two children (weekends free).
  @override
  Future<Result<SchoolWeek>> week({
    required DateTime from,
    required DateTime to,
  }) async {
    final dates = <DateTime>[
      for (
        var d = DateTime(from.year, from.month, from.day);
        !d.isAfter(to);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ];
    final days = [
      for (final date in dates)
        for (final p in _plans) {'date': _ymd(date), ..._day(p, date)},
    ];
    return Ok(
      SchoolWeek.fromJson({
        'timetables': [
          for (final p in _plans)
            {
              'member_id': p.member,
              'class_label': demoText(p.klasse),
              'school_name': demoText(p.school),
              'periods': _periods(),
            },
        ],
        'days': days,
      }),
    );
  }

  Map<String, dynamic> _day(_Plan plan, DateTime date) {
    final weekday = date.weekday;
    if (weekday > 5) {
      return {
        'member_id': plan.member,
        'free': 'weekend',
        'lessons': <Map<String, dynamic>>[],
      };
    }
    final row = plan.grid[weekday - 1];
    final lessons = <Map<String, dynamic>>[];
    final notable = <String>[];
    for (var period = 1; period <= row.length; period++) {
      final code = row[period - 1];
      if (code == null) continue;
      final (from, to) = _bells[period - 1];
      final notableName = _notable[code];
      if (notableName != null && !notable.contains(demoText(notableName))) {
        notable.add(demoText(notableName));
      }
      var status = 'normal';
      String? note;
      for (final e in _exceptionSeeds) {
        if (e.$1 == plan.member && e.$2 == weekday - 1 && e.$3 == period) {
          status = e.$4;
          note = e.$5;
        }
      }
      lessons.add({
        'period': period,
        'starts': from,
        'ends': to,
        'subject': demoText(_subjectCodes[code] ?? code),
        'short': demoShort(code),
        'room': demoTextOrNull(plan.rooms[code]),
        'tint': _tints[code],
        'kind': 'lesson',
        'status': status,
        'note': demoTextOrNull(note),
        'notable': notableName != null,
        'equipment': demoTextOrNull(_equipment[code]),
      });
    }
    final hort = plan.hort[weekday - 1];
    if (hort != null) {
      lessons.add({
        'period': null,
        'starts': lessons.last['ends'],
        'ends': hort,
        'subject': demoText('Hort'),
        'kind': 'care',
        'status': 'normal',
        'notable': false,
        'tint': null,
      });
    }
    return {
      'member_id': plan.member,
      'starts': lessons.first['starts'],
      'ends': lessons.lastWhere(
        (l) => l['status'] != 'cancelled' && l['kind'] != 'care',
      )['ends'],
      'notable': notable,
      'care_until': hort,
      'care_label': hort == null ? null : demoText('Hort'),
      'lessons': lessons,
    };
  }

  @override
  Future<Result<String>> saveSchool({
    required String? actor,
    String? id,
    required String name,
    String? regionCode,
    String? timezone,
  }) async => Ok(id ?? 'school-new');

  @override
  Future<Result<void>> setPeriods({
    required String? actor,
    required String schoolId,
    required List<PeriodRecord> periods,
  }) async => const Ok(null);

  @override
  Future<Result<String>> saveTerm({
    required String? actor,
    required TermRecord term,
  }) async => Ok(term.id.isEmpty ? 'term-new' : term.id);

  @override
  Future<Result<String>> saveSubject({
    required String? actor,
    required SubjectRecord subject,
  }) async => Ok(subject.id.isEmpty ? 'sub-new' : subject.id);

  @override
  Future<Result<void>> deleteSubject({
    required String? actor,
    required String id,
  }) async => const Ok(null);

  @override
  Future<Result<String>> saveTimetable({
    required String? actor,
    required TimetableRecord timetable,
  }) async => Ok(timetable.id.isEmpty ? 'tt-new' : timetable.id);

  @override
  Future<Result<void>> setLessons({
    required String? actor,
    required String timetableId,
    required List<LessonRecord> lessons,
  }) async => const Ok(null);

  @override
  Future<Result<String>> copyTimetable({
    required String? actor,
    required String fromTimetableId,
    required String profileId,
    required String termId,
  }) async => const Ok('tt-copy');

  @override
  Future<Result<String>> saveException({
    required String? actor,
    required ExceptionRecord exception,
  }) async {
    final id = exception.id.isEmpty ? 'ex-${_nextId++}' : exception.id;
    _exceptions.removeWhere((e) => e['id'] == id);
    _exceptions.add({...exception.toJson(), 'id': id});
    return Ok(id);
  }

  @override
  Future<Result<void>> deleteException({
    required String? actor,
    required String id,
  }) async {
    _exceptions.removeWhere((e) => e['id'] == id);
    return const Ok(null);
  }

  @override
  Future<Result<String>> saveHoliday({
    required String? actor,
    required HolidayRecord holiday,
  }) async => Ok(holiday.id.isEmpty ? 'holiday-new' : holiday.id);

  @override
  Future<Result<void>> deleteHoliday({
    required String? actor,
    required String id,
  }) async => const Ok(null);
}

String _subjectId(String code) => 'sub-${code.replaceAll('/', '-')}';

/// The lesson bells (lessons 1–7); the breaks between them are derived.
const _bells = [
  ('08:00', '08:45'),
  ('08:50', '09:35'),
  ('09:55', '10:40'),
  ('10:45', '11:30'),
  ('12:00', '12:45'),
  ('12:50', '13:35'),
  ('13:40', '14:25'),
];

/// Bell times in time order: each lesson, then the break after it.
List<Map<String, dynamic>> _periods() => [
  for (var i = 0; i < _bells.length; i++) ...[
    {
      'index': i + 1,
      'starts': _bells[i].$1,
      'ends': _bells[i].$2,
      'kind': 'lesson',
    },
    if (i < _bells.length - 1)
      {
        'index': i + 1,
        'starts': _bells[i].$2,
        'ends': _bells[i + 1].$1,
        'kind': 'break',
      },
  ],
];

/// One child's timetable. Rows of [grid] are Monday to Friday, columns periods 1–7;
/// null is a free period. [hort] maps a day index to the end of the Hort.
class _Plan {
  const _Plan({
    required this.member,
    required this.klasse,
    required this.school,
    required this.schoolId,
    required this.grid,
    this.rooms = const {},
    this.hort = const {},
  });

  final String member;
  final String klasse;
  final String school;
  final String schoolId;
  final List<List<String?>> grid;
  final Map<String, String> rooms;
  final Map<int, String> hort;

  String get timetableId => 'tt-$member';
}

const _plans = [
  _Plan(
    member: DemoData.daughter,
    klasse: '5a',
    school: 'Gemeinschaftsschule am Park',
    schoolId: 'school-park',
    grid: [
      ['Ma', 'D', 'D', 'E/F', 'E/F', 'BK', 'BK'],
      ['Fö', 'Ma', 'FreiDay', 'FreiDay', 'FreiDay', 'FreiDay', 'Rel/LK'],
      ['Sp', 'Mu', 'Ma', 'Ma', 'GeWi', 'GeWi', 'NaWi'],
      ['Fö', 'Mu', 'D', 'D', 'Sp', 'Rel/LK', 'Ma'],
      ['NaWi', 'NaWi', 'F/E', 'F/E', 'Sp', 'D', null],
    ],
    rooms: {'Sp': 'Turnhalle', 'BK': 'Kunstraum', 'NaWi': 'NaWi-Raum'},
  ),
  _Plan(
    member: DemoData.son,
    klasse: 'SAPh E',
    school: 'Grundschule Lindenhof',
    schoolId: 'school-lindenhof',
    grid: [
      ['D', 'Ma', 'SU', 'Sp', null, null, null],
      ['Ma', 'D', 'Mu', 'Lernzeit', 'SU', null, null],
      ['Sw', 'Sw', 'D', 'Ma', null, null, null],
      ['D', 'Ma', 'SU', 'Mu', 'Sp', null, null],
      ['Ma', 'D', 'Ku', 'Ku', null, null, null],
    ],
    rooms: {'Sp': 'Turnhalle', 'Sw': 'Schwimmbad'},
    hort: {0: '15:00', 1: '15:00', 3: '15:00'},
  ),
];

/// Lesson changes: (member, day index, period, status, note).
const _exceptionSeeds = [
  (DemoData.daughter, 2, 3, 'substituted', 'Frau Klein'),
  (DemoData.daughter, 4, 6, 'cancelled', 'fällt aus'),
];

const _subjectCodes = {
  'Ma': 'Mathematik',
  'D': 'Deutsch',
  'Fö': 'Förderunterricht',
  'Sp': 'Sport',
  'Sw': 'Schwimmen',
  'NaWi': 'Naturwissenschaften',
  'Mu': 'Musik',
  'GeWi': 'Gesellschaftswissenschaften',
  'BK': 'Bildende Kunst',
  'Ku': 'Kunst',
  'Rel/LK': 'Religion / Lebenskunde',
  'E/F': 'Englisch / Französisch',
  'F/E': 'Französisch / Englisch',
  'SU': 'Sachunterricht',
  'Lernzeit': 'Lernzeit',
  'FreiDay': 'FreiDay — Projektlernen',
};

/// Paper tint keys (`PaperTints`) per subject.
const _tints = {
  'Ma': 'blue',
  'Fö': 'blue',
  'D': 'rose',
  'E/F': 'lilac',
  'F/E': 'lilac',
  'NaWi': 'leaf',
  'SU': 'leaf',
  'FreiDay': 'leaf',
  'Sp': 'peach',
  'Sw': 'peach',
  'Mu': 'lemon',
  'BK': 'mint',
  'Ku': 'mint',
  'Rel/LK': 'stone',
  'GeWi': 'stone',
  'Lernzeit': 'stone',
};

/// Starter icon keys of the migration's set (`school_icons.dart`).
const _icons = {
  'D': 'book',
  'Ma': 'numbers',
  'SU': 'globe',
  'GeWi': 'globe',
  'NaWi': 'globe',
  'E/F': 'chat',
  'F/E': 'chat',
  'Mu': 'music',
  'Ku': 'palette',
  'BK': 'palette',
  'Rel/LK': 'hands',
  'Sp': 'run',
  'Sw': 'swim',
};

/// Subjects worth seeing on the wall the evening before.
const _notable = {'Sp': 'Sport', 'Sw': 'Schwimmen', 'FreiDay': 'FreiDay'};

const _equipment = {'Sp': 'Sportsachen', 'Sw': 'Schwimmzeug'};
