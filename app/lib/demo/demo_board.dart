import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/board/data/board_repository.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';

/// The kiosk week board for the invented family in [DemoData], used by the demo build
/// (`lib/main_demo.dart`). It builds the JSON that `api.board_week` returns and runs it
/// through [WeekBoard.fromJson], so the demo also exercises the parser. It always shows
/// the week of [clock]; the demo has no other weeks.
class DemoBoardRepository implements BoardRepository {
  DemoBoardRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// [weekStart] is ignored: the demo always shows the current week.
  @override
  Future<Result<WeekBoard>> week({DateTime? weekStart}) async =>
      Ok(WeekBoard.fromJson(_json(_clock())));
}

const _family = [DemoData.lotta, DemoData.hanna, DemoData.mama, DemoData.papa];

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

/// One child's timetable. Rows of [grid] are Monday to Friday, columns periods 1–7;
/// null is a free period. [hort] maps a day index to the end of the Hort.
class _Plan {
  const _Plan({
    required this.member,
    required this.klasse,
    required this.school,
    required this.grid,
    this.rooms = const {},
    this.hort = const {},
  });

  final String member;
  final String klasse;
  final String school;
  final List<List<String?>> grid;
  final Map<String, String> rooms;
  final Map<int, String> hort;
}

const _plans = [
  _Plan(
    member: DemoData.lotta,
    klasse: '5a',
    school: 'Gemeinschaftsschule am Park',
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
    member: DemoData.hanna,
    klasse: 'SAPh E',
    school: 'Grundschule Lindenhof',
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
const _exceptions = [
  (DemoData.lotta, 2, 3, 'substituted', 'Frau Klein'),
  (DemoData.lotta, 4, 6, 'cancelled', 'fällt aus'),
];

const _subjects = {
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

/// Subjects worth seeing on the wall the evening before.
const _notable = {'Sp': 'Sport', 'Sw': 'Schwimmen', 'FreiDay': 'FreiDay'};

const _equipment = {'Sp': 'Sportsachen', 'Sw': 'Schwimmzeug'};

/// Lukas' `busy_until` per day; null is no line.
const _lukasBusy = <String?>[
  '16:30',
  '18:00',
  '17:00',
  '16:00',
  '15:30',
  null,
  null,
];

/// (slot, time, dish, cook, eating, guests) per day; a null dish is nothing planned.
const _meals = <(String, String, String?, String, List<String>, int)>[
  ('dinner', '18:30', 'Kürbissuppe', DemoData.mama, _family, 0),
  ('dinner', '18:30', 'Nudelauflauf', DemoData.papa, _family, 0),
  ('dinner', '18:30', 'Chili sin Carne', DemoData.mama, _family, 0),
  // Thursday is Christi Himmelfahrt (a public holiday of the household's region): a free day, so
  // the warm meal is at lunch, as on a weekend.
  (
    'lunch',
    '12:30',
    'Fischstäbchen',
    DemoData.mama,
    [DemoData.lotta, DemoData.hanna, DemoData.mama],
    0,
  ),
  (
    'dinner',
    '18:00',
    null,
    DemoData.mama,
    [DemoData.lotta, DemoData.hanna, DemoData.mama],
    0,
  ),
  (
    'lunch',
    '12:30',
    'Nudeln mit Pesto',
    DemoData.papa,
    [DemoData.lotta, DemoData.papa],
    0,
  ),
  ('lunch', '12:30', 'Rinderbraten', DemoData.mama, _family, 2),
];

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The demo week's public holiday: Thursday, Christi Himmelfahrt.
const _holidayDay = 3;

Map<String, dynamic> _json(DateTime now) {
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final dates = [
    for (var i = 0; i < 7; i++)
      _iso(DateTime(monday.year, monday.month, monday.day + i)),
  ];
  return {
    'week_start': dates.first,
    'today': _iso(now),
    'generated_at': now.toUtc().toIso8601String(),
    'settings': {
      'day_parts': ['12:00', '17:00'],
      'member_label': 'name',
    },
    'members': [
      {
        'id': DemoData.lotta,
        'display_name': 'Lotta',
        'color': '#7B3FE4',
        'kind': 'child',
      },
      {
        'id': DemoData.hanna,
        'display_name': 'Hanna',
        'color': '#08737F',
        'kind': 'child',
      },
      {
        'id': DemoData.mama,
        'display_name': 'Sabine',
        'color': '#9A5300',
        'kind': 'adult',
        'baseline': {'state': 'off', 'label': 'zu Hause'},
      },
      {
        'id': DemoData.papa,
        'display_name': 'Lukas',
        'color': '#C2255C',
        'kind': 'adult',
        'baseline': {'state': 'home_office', 'label': 'Homeoffice'},
      },
    ],
    'presence': _presence(dates),
    'timetables': [
      for (final p in _plans)
        {
          'member_id': p.member,
          'class_label': p.klasse,
          'school_name': p.school,
          'periods': _periods(),
        },
    ],
    'days': [
      for (var i = 0; i < 7; i++)
        {
          'date': dates[i],
          'holiday': i == _holidayDay
              ? {'name': 'Christi Himmelfahrt', 'source': 'region'}
              : null,
          'events': _events(i),
          'busy_until': [
            if (_lukasBusy[i] != null)
              {'member_id': DemoData.papa, 'until': _lukasBusy[i]},
          ],
          'school': [
            for (final p in _plans)
              i == _holidayDay
                  ? {
                      'member_id': p.member,
                      'free': 'holiday',
                      'holiday_name': 'Christi Himmelfahrt',
                      'lessons': <Map<String, dynamic>>[],
                    }
                  : i < 5
                  ? _school(p, i)
                  : {
                      'member_id': p.member,
                      'free': 'weekend',
                      'lessons': <Map<String, dynamic>>[],
                    },
          ],
          'meal': _meal(i),
        },
    ],
    'open_tasks': [
      {'member_id': DemoData.lotta, 'count': 2},
      {'member_id': DemoData.hanna, 'count': 1},
      {'member_id': DemoData.mama, 'count': 1},
    ],
    'shopping_count': 7,
  };
}

Map<String, dynamic> _band(
  String id,
  String member,
  String state,
  String label,
  String first,
  String last, {
  String? starts,
  String? ends,
  bool tentative = false,
}) => {
  'id': id,
  'member_id': member,
  'state': state,
  'label': label,
  'first_day': first,
  'last_day': last,
  'starts': starts,
  'ends': ends,
  'tentative': tentative,
  'starts_before_week': false,
  'ends_after_week': false,
};

List<Map<String, dynamic>> _presence(List<String> d) => [
  _band(
    'pr-sabine-mo',
    DemoData.mama,
    'working',
    'Dienst',
    d[0],
    d[0],
    starts: '08:30',
    ends: '14:00',
  ),
  _band(
    'pr-lukas-di',
    DemoData.papa,
    'working',
    'Büro Hamburg',
    d[1],
    d[1],
    starts: '08:00',
  ),
  _band(
    'pr-sabine-mi',
    DemoData.mama,
    'working',
    'Dienst',
    d[2],
    d[2],
    starts: '08:30',
    ends: '14:00',
  ),
  _band(
    'pr-lukas-do',
    DemoData.papa,
    'travel',
    'Dienstreise Berlin',
    d[3],
    d[4],
  ),
  _band(
    'pr-hanna-sa',
    DemoData.hanna,
    'childcare',
    'Oma',
    d[5],
    d[5],
    tentative: true,
  ),
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

Map<String, dynamic> _school(_Plan plan, int day) {
  final row = plan.grid[day];
  final lessons = <Map<String, dynamic>>[];
  final notable = <String>[];
  for (var period = 1; period <= row.length; period++) {
    final code = row[period - 1];
    if (code == null) continue;
    final (from, to) = _bells[period - 1];
    final notableName = _notable[code];
    if (notableName != null && !notable.contains(notableName)) {
      notable.add(notableName);
    }
    var status = 'normal';
    String? note;
    for (final (m, d, p, s, n) in _exceptions) {
      if (m == plan.member && d == day && p == period) {
        status = s;
        note = n;
      }
    }
    lessons.add({
      'period': period,
      'starts': from,
      'ends': to,
      'subject': _subjects[code] ?? code,
      'short': code,
      'room': plan.rooms[code],
      'tint': _tints[code],
      'kind': 'lesson',
      'status': status,
      'note': note,
      'notable': notableName != null,
      'equipment': _equipment[code],
    });
  }
  final hort = plan.hort[day];
  if (hort != null) {
    lessons.add({
      'period': null,
      'starts': lessons.last['ends'],
      'ends': hort,
      'subject': 'Hort',
      'kind': 'care',
      'status': 'normal',
      'notable': false,
      'tint': null,
    });
  }
  return {
    'member_id': plan.member,
    'starts': lessons.first['starts'],
    // The school day ends with the last lesson that takes place; Hort is shown apart.
    'ends': lessons.lastWhere(
      (l) => l['status'] != 'cancelled' && l['kind'] != 'care',
    )['ends'],
    'notable': notable,
    'care_until': hort,
    'care_label': hort == null ? null : 'Hort',
    'lessons': lessons,
  };
}

Map<String, dynamic> _ev(
  String title,
  String? starts,
  String? ends,
  List<String> who, {
  String? place,
  bool tentative = false,
  bool key = true,
}) => {
  'title': title,
  'location': place,
  'starts': starts,
  'ends': ends,
  'attendee_ids': who,
  'tentative': tentative,
  'key': key,
};

/// The day's appointments, all-day first, then by start.
List<Map<String, dynamic>> _events(int day) {
  final list = switch (day) {
    0 => [
      _ev('Müll rausstellen', '07:30', '08:00', [DemoData.papa], key: false),
      _ev('Heizung wird gewartet', '10:00', '11:00', [DemoData.papa]),
      _ev('Turnen', '15:00', '16:00', [DemoData.hanna], place: 'TSV-Halle'),
    ],
    1 => [
      _ev('Zahnarzt', '14:30', '15:30', [DemoData.lotta], place: 'Dr. Behrens'),
    ],
    2 => [
      _ev('Turnen', '16:00', '17:00', [DemoData.hanna], place: 'TSV-Halle'),
      _ev('Elternabend', '19:30', '20:30', [DemoData.mama], place: 'Klasse 5a'),
    ],
    3 => [
      _ev('Fotografin in der Schule', null, null, [DemoData.lotta], key: false),
      _ev('Klavier', '15:30', '16:30', [DemoData.lotta], place: 'Musikschule'),
    ],
    4 => [
      _ev('Kinoabend', '18:00', '19:00', [
        DemoData.lotta,
        DemoData.hanna,
        DemoData.mama,
      ]),
    ],
    5 => [
      _ev('Fußballturnier', '10:00', '11:00', [
        DemoData.hanna,
        DemoData.mama,
      ], place: 'Sportplatz Ost'),
      _ev('Grillen bei Webers', '16:00', '17:00', _family, tentative: true),
    ],
    _ => [_ev('Oma & Opa kommen', '11:00', '12:00', _family)],
  };
  final sorted = [...list]
    ..sort(
      (a, b) => ((a['starts'] as String?) ?? '').compareTo(
        (b['starts'] as String?) ?? '',
      ),
    );
  return [
    for (final (i, e) in sorted.indexed) {...e, 'id': 'ev-$day-$i'},
  ];
}

Map<String, dynamic> _meal(int day) {
  final (slot, time, dish, cook, eating, guests) = _meals[day];
  return {
    'slot': slot,
    'time': time,
    'title': dish,
    'cook_id': cook,
    'eating': eating,
    'guests': guests,
  };
}
