import 'dart:convert';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

/// The timetable import payload (specs/24 "The payload"): what a parent pastes after an
/// assistant read the school's sheet, what an assistant proposes over MCP, and what a
/// scan will produce. Names, never ids: subjects by their short name or name, days by
/// number or name in any of the app's languages, lessons by period or by clock time.
///
/// Parsing is tolerant about the wrapping (a code fence, prose around the JSON) and
/// strict about the shape. Resolution against the household's subjects and bell times is
/// a separate step ([resolveImport]), so the preview can show what will be created.
const timetableImportFormat = 'wuselwall-timetable/1';

/// The upper bounds, shared with the server's shape check (`app.proposal_check`).
const importMaxLessons = 200;
const importMaxCare = 10;
const importMaxPeriods = 15;

/// One lesson as the payload names it. Either [period] or both times are set.
class ImportLesson {
  const ImportLesson({
    required this.weekday,
    required this.subject,
    this.period,
    this.starts,
    this.ends,
    this.subjectName,
    this.teacher,
    this.room,
    this.parity = 'all',
  });

  /// ISO weekday, 1 = Monday.
  final int weekday;
  final int? period;
  final TimeOfDay? starts;
  final TimeOfDay? ends;

  /// The short name on the sheet ("Ma"), or a full name when that is all there is.
  final String subject;

  /// The long name, when the payload gives both ("Mathematik").
  final String? subjectName;
  final String? teacher;
  final String? room;

  /// 'all', 'a' or 'b'.
  final String parity;
}

/// A care row (Hort, an AG): a name, times and weekdays.
class ImportCare {
  const ImportCare({
    required this.title,
    required this.days,
    required this.starts,
    required this.ends,
  });

  final String title;
  final Set<int> days;
  final TimeOfDay starts;
  final TimeOfDay ends;
}

/// A bell time the sheet shows: the lesson's index and its clock times.
class ImportPeriod {
  const ImportPeriod({
    required this.index,
    required this.starts,
    required this.ends,
  });

  final int index;
  final TimeOfDay starts;
  final TimeOfDay ends;
}

/// The parsed payload.
class TimetableImport {
  const TimetableImport({
    required this.lessons,
    this.member,
    this.school,
    this.classLabel,
    this.weekCycle,
    this.periods = const [],
    this.care = const [],
  });

  final String? member;
  final String? school;
  final String? classLabel;

  /// 'weekly', 'ab' or null (unknown: 'ab' when any lesson names a parity).
  final String? weekCycle;
  final List<ImportPeriod> periods;
  final List<ImportLesson> lessons;
  final List<ImportCare> care;

  bool get usesParity => lessons.any((l) => l.parity != 'all');

  /// The cycle to use: the payload's, else A/B when a lesson names a week.
  String get effectiveCycle => weekCycle ?? (usesParity ? 'ab' : 'weekly');

  /// The payload as the server stores it (a proposal) and as the app sends it on.
  Map<String, dynamic> toJson() => {
    'format': timetableImportFormat,
    'member': ?member,
    'school': ?school,
    'class': ?classLabel,
    'week_cycle': ?weekCycle,
    if (periods.isNotEmpty)
      'periods': [
        for (final p in periods)
          {'index': p.index, 'starts': _hm(p.starts), 'ends': _hm(p.ends)},
      ],
    'lessons': [
      for (final l in lessons)
        {
          'day': l.weekday,
          'period': ?l.period,
          'starts': ?_hmOrNull(l.starts),
          'ends': ?_hmOrNull(l.ends),
          'subject': l.subject,
          'name': ?l.subjectName,
          'teacher': ?l.teacher,
          'room': ?l.room,
          if (l.parity != 'all') 'week': l.parity,
        },
    ],
    if (care.isNotEmpty)
      'care': [
        for (final c in care)
          {
            'title': c.title,
            'days': c.days.toList()..sort(),
            'starts': _hm(c.starts),
            'ends': _hm(c.ends),
          },
      ],
  };
}

/// Why a text could not be read as a payload. Each maps to one sentence in the app.
enum ImportError {
  /// No JSON object in the text.
  notJson,

  /// A JSON object, but not this format (no lessons, no grid).
  noLessons,

  /// More lessons, care rows or periods than the limits allow.
  tooMany,

  /// A lesson without a day, a period or times, or a subject.
  badLesson,

  /// A day that is no weekday number or name.
  badDay,

  /// A time that is not HH:MM.
  badTime,
}

class ImportParseException implements Exception {
  const ImportParseException(this.error, [this.detail]);

  final ImportError error;

  /// The offending value, for the message.
  final String? detail;

  @override
  String toString() => 'ImportParseException($error, $detail)';
}

/// Reads [text] as a payload. Throws [ImportParseException].
TimetableImport parseTimetableImport(String text) =>
    parseTimetableImportJson(_extractObject(text));

/// Reads an already decoded payload (a stored proposal). Throws [ImportParseException].
TimetableImport parseTimetableImportJson(Map<String, dynamic> json) {
  final cycle = _str(json['week_cycle'], 12)?.toLowerCase();
  final lessons = <ImportLesson>[];
  final rawLessons = json['lessons'];
  if (rawLessons is List) {
    for (final item in rawLessons) {
      if (item is! Map) throw const ImportParseException(ImportError.badLesson);
      final lesson = _lesson(item.cast<String, dynamic>());
      if (lesson != null) lessons.add(lesson);
    }
  }
  final grid = json['grid'];
  if (grid is Map) {
    for (final entry in grid.entries) {
      final weekday = parseWeekday(entry.key.toString());
      if (weekday == null) {
        throw ImportParseException(ImportError.badDay, entry.key.toString());
      }
      final cells = entry.value;
      if (cells is! List) {
        throw const ImportParseException(ImportError.badLesson);
      }
      for (var i = 0; i < cells.length; i++) {
        final cell = cells[i];
        if (cell == null) continue;
        if (cell is String) {
          final subject = cell.trim();
          if (subject.isEmpty || subject == '-' || subject == '—') continue;
          lessons.add(
            ImportLesson(
              weekday: weekday,
              period: i + 1,
              subject: _clip(subject, 60),
            ),
          );
        } else if (cell is Map) {
          final lesson = _lesson({
            ...cell.cast<String, dynamic>(),
            'day': weekday,
            'period': cell['period'] ?? i + 1,
          });
          if (lesson != null) lessons.add(lesson);
        } else {
          throw const ImportParseException(ImportError.badLesson);
        }
      }
    }
  }
  if (rawLessons is! List && grid is! Map) {
    throw const ImportParseException(ImportError.noLessons);
  }
  if (lessons.isEmpty) throw const ImportParseException(ImportError.noLessons);
  if (lessons.length > importMaxLessons) {
    throw const ImportParseException(ImportError.tooMany);
  }

  final periods = <ImportPeriod>[];
  final rawPeriods = json['periods'];
  if (rawPeriods is List) {
    if (rawPeriods.length > importMaxPeriods) {
      throw const ImportParseException(ImportError.tooMany);
    }
    for (final item in rawPeriods) {
      if (item is! Map) throw const ImportParseException(ImportError.badLesson);
      final index = _periodIndex(item['index']);
      final starts = parseClock(item['starts']?.toString() ?? '');
      final ends = parseClock(item['ends']?.toString() ?? '');
      if (index == null || starts == null || ends == null) {
        throw ImportParseException(
          ImportError.badTime,
          '${item['starts']}–${item['ends']}',
        );
      }
      if (minutesOf(ends) <= minutesOf(starts)) {
        throw ImportParseException(
          ImportError.badTime,
          '${item['starts']}–${item['ends']}',
        );
      }
      periods.add(ImportPeriod(index: index, starts: starts, ends: ends));
    }
  }

  final care = <ImportCare>[];
  final rawCare = json['care'];
  if (rawCare is List) {
    if (rawCare.length > importMaxCare) {
      throw const ImportParseException(ImportError.tooMany);
    }
    for (final item in rawCare) {
      if (item is! Map) throw const ImportParseException(ImportError.badLesson);
      final title = _str(item['title'], 60);
      final starts = parseClock(item['starts']?.toString() ?? '');
      final ends = parseClock(item['ends']?.toString() ?? '');
      if (title == null) {
        throw const ImportParseException(ImportError.badLesson);
      }
      if (starts == null ||
          ends == null ||
          minutesOf(ends) <= minutesOf(starts)) {
        throw ImportParseException(
          ImportError.badTime,
          '${item['starts']}–${item['ends']}',
        );
      }
      final days = <int>{};
      final rawDays = item['days'];
      if (rawDays is List) {
        for (final d in rawDays) {
          final weekday = parseWeekday(d.toString());
          if (weekday == null) {
            throw ImportParseException(ImportError.badDay, d.toString());
          }
          days.add(weekday);
        }
      }
      if (days.isEmpty) continue;
      care.add(
        ImportCare(title: title, days: days, starts: starts, ends: ends),
      );
    }
  }

  return TimetableImport(
    member: _str(json['member'], 60),
    school: _str(json['school'], 120),
    classLabel: _str(json['class'], 20),
    weekCycle: cycle == 'ab' || cycle == 'weekly' ? cycle : null,
    periods: periods,
    lessons: lessons,
    care: care,
  );
}

/// The first JSON object in [text]: the whole text, or the part between the first `{`
/// and the last `}` when the assistant wrapped it in a code fence or a sentence.
Map<String, dynamic> _extractObject(String text) {
  final trimmed = text.trim();
  Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const ImportParseException(ImportError.notJson);
    }
    try {
      decoded = jsonDecode(trimmed.substring(start, end + 1));
    } on FormatException {
      throw const ImportParseException(ImportError.notJson);
    }
  }
  if (decoded is! Map) throw const ImportParseException(ImportError.notJson);
  return decoded.cast<String, dynamic>();
}

ImportLesson? _lesson(Map<String, dynamic> item) {
  final subject = _str(item['subject'], 60) ?? _str(item['title'], 60);
  if (subject == null) {
    // An empty cell in a list is skipped, not an error: "Fr, 6. Stunde: —".
    if (item['subject'] == null || item['subject'].toString().trim().isEmpty) {
      return null;
    }
    throw const ImportParseException(ImportError.badLesson);
  }
  if (subject == '-' || subject == '—') return null;
  final rawDay = item['day'] ?? item['weekday'];
  if (rawDay == null) throw const ImportParseException(ImportError.badLesson);
  final weekday = parseWeekday(rawDay.toString());
  if (weekday == null) {
    throw ImportParseException(ImportError.badDay, rawDay.toString());
  }
  final period = _periodIndex(item['period']);
  TimeOfDay? starts;
  TimeOfDay? ends;
  if (item['starts'] != null || item['ends'] != null) {
    starts = parseClock(item['starts']?.toString() ?? '');
    ends = parseClock(item['ends']?.toString() ?? '');
    if (starts == null ||
        (ends != null && minutesOf(ends) <= minutesOf(starts))) {
      throw ImportParseException(
        ImportError.badTime,
        '${item['starts']}–${item['ends']}',
      );
    }
  }
  if (period == null && starts == null) {
    throw const ImportParseException(ImportError.badLesson);
  }
  final week = (item['week'] ?? item['parity'])
      ?.toString()
      .trim()
      .toLowerCase();
  return ImportLesson(
    weekday: weekday,
    period: period,
    starts: starts,
    ends: ends,
    subject: subject,
    subjectName: _str(item['name'], 60),
    teacher: _str(item['teacher'], 60),
    room: _str(item['room'], 40),
    parity: week == 'a' || week == 'b' ? week! : 'all',
  );
}

String? _str(Object? v, int max) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : _clip(s, max);
}

String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);

/// "1", 1, "1.", "1. Stunde", "P1", "Std 3" → the leading integer, 1–15.
int? _periodIndex(Object? v) {
  if (v == null) return null;
  if (v is num) {
    final n = v.toInt();
    return n == v && n >= 1 && n <= importMaxPeriods ? n : null;
  }
  final match = RegExp(r'(\d{1,2})').firstMatch(v.toString());
  if (match == null) return null;
  final n = int.parse(match.group(1)!);
  return n >= 1 && n <= importMaxPeriods ? n : null;
}

/// "08:00", "8:00", "8.00", "08.00 Uhr", "8h00" → a time; null when it is none.
TimeOfDay? parseClock(String text) {
  final match = RegExp(r'^\s*(\d{1,2})\s*[:.h]\s*(\d{2})')
      .firstMatch(text.trim().toLowerCase());
  if (match == null) return null;
  final h = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  if (h > 23 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

const _weekdays = <String, int>{
  // Numbers, German, English, French, Spanish; keys lowercased, accents stripped.
  'mo': 1, 'mon': 1, 'montag': 1, 'monday': 1,
  'lu': 1, 'lun': 1, 'lundi': 1, 'lunes': 1,
  'di': 2, 'die': 2, 'dienstag': 2, 'tu': 2, 'tue': 2, 'tues': 2,
  'tuesday': 2, 'ma': 2, 'mar': 2, 'mardi': 2, 'martes': 2,
  'mi': 3, 'mit': 3, 'mittwoch': 3, 'we': 3, 'wed': 3, 'wednesday': 3,
  'me': 3, 'mer': 3, 'mercredi': 3, 'mie': 3, 'miercoles': 3,
  'do': 4, 'don': 4, 'donnerstag': 4, 'th': 4, 'thu': 4, 'thur': 4,
  'thurs': 4, 'thursday': 4, 'je': 4, 'jeu': 4, 'jeudi': 4, 'ju': 4,
  'jue': 4, 'jueves': 4,
  'fr': 5, 'fre': 5, 'freitag': 5, 'fri': 5, 'friday': 5, 've': 5,
  'ven': 5, 'vendredi': 5, 'vi': 5, 'vie': 5, 'viernes': 5,
  'sa': 6, 'sam': 6, 'samstag': 6, 'sat': 6, 'saturday': 6, 'samedi': 6,
  'sab': 6, 'sabado': 6,
  'so': 7, 'son': 7, 'sonntag': 7, 'su': 7, 'sun': 7, 'sunday': 7,
  'dim': 7, 'dimanche': 7, 'dom': 7, 'domingo': 7,
};

/// A weekday from a number (1–7, Monday first) or a name or abbreviation in German,
/// English, French or Spanish ("Mo", "Mittwoch", "Thu", "mar", "mié."). Null otherwise.
int? parseWeekday(String text) {
  final t = foldText(text).replaceAll(RegExp(r'[.\s]+$'), '');
  if (t.isEmpty) return null;
  final n = int.tryParse(t);
  if (n != null) return n >= 1 && n <= 7 ? n : null;
  return _weekdays[t];
}

/// Lowercase without accents, trimmed: the key subjects and days are matched by.
String foldText(String s) {
  const from = 'äöüàáâãåçèéêëìíîïñòóôõùúûýÿœæß';
  const to = [
    'a',
    'o',
    'u',
    'a',
    'a',
    'a',
    'a',
    'a',
    'c',
    'e',
    'e',
    'e',
    'e',
    'i',
    'i',
    'i',
    'i',
    'n',
    'o',
    'o',
    'o',
    'o',
    'u',
    'u',
    'u',
    'y',
    'y',
    'oe',
    'ae',
    'ss',
  ];
  final buffer = StringBuffer();
  for (final rune in s.trim().toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buffer.write(i < 0 ? ch : to[i]);
  }
  return buffer.toString();
}

String _hm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String? _hmOrNull(TimeOfDay? t) => t == null ? null : _hm(t);

// ── resolution against the household ─────────────────────────────────────────────

/// A subject the import would create, because nothing in the household matched.
class NewSubject {
  const NewSubject({
    required this.key,
    required this.name,
    required this.shortName,
  });

  /// The folded short name, what the lessons refer to.
  final String key;
  final String name;
  final String shortName;
}

/// One lesson ready for the grid: a period, and a subject that exists ([subjectId]) or
/// is about to ([newSubjectKey]).
class ResolvedLesson {
  const ResolvedLesson({
    required this.weekday,
    required this.period,
    required this.parity,
    this.subjectId,
    this.newSubjectKey,
    this.teacher,
    this.room,
  });

  final int weekday;
  final int period;
  final String parity;
  final String? subjectId;
  final String? newSubjectKey;
  final String? teacher;
  final String? room;
}

/// What the preview tells before the import is applied.
enum ImportWarningKind {
  /// Lessons with a clock time that matched no bell time: dropped.
  unmatchedTimes,

  /// Lessons in periods the bell times do not have: the bell times will be extended.
  periodsExtended,

  /// The payload's bell times differ from the school's: the school's are kept.
  periodsDiffer,

  /// The payload names a different school than the one chosen.
  schoolDiffers,
}

class ImportWarning {
  const ImportWarning(this.kind, {this.count = 0, this.detail});

  final ImportWarningKind kind;
  final int count;
  final String? detail;
}

class ResolvedImport {
  const ResolvedImport({
    required this.lessons,
    required this.newSubjects,
    required this.care,
    required this.periods,
    required this.warnings,
    required this.weekCycle,
  });

  final List<ResolvedLesson> lessons;
  final List<NewSubject> newSubjects;
  final List<ImportCare> care;

  /// The school's bell times after the import: the existing ones, extended when the
  /// sheet has more periods than the school. Null when nothing changes.
  final List<PeriodRecord>? periods;
  final List<ImportWarning> warnings;
  final String weekCycle;

  int get lessonCount => lessons.length;
}

/// Matches [import]'s subjects to [subjects] (short name first, then name, folded) and
/// its lessons to [periods] (by index, or by start time within five minutes).
ResolvedImport resolveImport(
  TimetableImport import, {
  required List<SubjectRecord> subjects,
  required List<PeriodRecord> periods,
  required String schoolId,
  String? schoolName,
}) {
  final byShort = {for (final s in subjects) foldText(s.shortName): s};
  final byName = {for (final s in subjects) foldText(s.name): s};
  final lessonPeriods = periods.where((p) => !p.isBreak).toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  final newSubjects = <String, NewSubject>{};
  final out = <ResolvedLesson>[];
  var unmatchedTimes = 0;
  var maxPeriod = 0;

  for (final l in import.lessons) {
    var period = l.period;
    if (period == null) {
      final start = minutesOf(l.starts!);
      final hit = lessonPeriods
          .where((p) => (minutesOf(p.starts) - start).abs() <= 5)
          .firstOrNull;
      if (hit == null) {
        unmatchedTimes++;
        continue;
      }
      period = hit.index;
    }
    if (period > maxPeriod) maxPeriod = period;
    final key = foldText(l.subject);
    final existing =
        byShort[key] ??
        byName[key] ??
        (l.subjectName == null ? null : byName[foldText(l.subjectName!)]);
    String? newKey;
    if (existing == null) {
      newKey = key;
      newSubjects.putIfAbsent(
        key,
        () => NewSubject(
          key: key,
          name: l.subjectName ?? l.subject,
          shortName: _clip(l.subject, 12),
        ),
      );
    }
    out.add(
      ResolvedLesson(
        weekday: l.weekday,
        period: period,
        parity: l.parity,
        subjectId: existing?.id,
        newSubjectKey: newKey,
        teacher: l.teacher,
        room: l.room,
      ),
    );
  }

  final warnings = <ImportWarning>[];
  if (unmatchedTimes > 0) {
    warnings.add(
      ImportWarning(ImportWarningKind.unmatchedTimes, count: unmatchedTimes),
    );
  }
  if (schoolName != null &&
      import.school != null &&
      foldText(import.school!) != foldText(schoolName)) {
    warnings.add(
      ImportWarning(ImportWarningKind.schoolDiffers, detail: import.school),
    );
  }

  List<PeriodRecord>? extended;
  final have = lessonPeriods.isEmpty ? 0 : lessonPeriods.last.index;
  if (maxPeriod > have) {
    extended = extendPeriods(
      periods,
      schoolId: schoolId,
      upTo: maxPeriod,
      sheet: import.periods,
    );
    warnings.add(
      ImportWarning(ImportWarningKind.periodsExtended, count: maxPeriod - have),
    );
  } else if (import.periods.isNotEmpty &&
      _periodsDiffer(import.periods, periods)) {
    warnings.add(const ImportWarning(ImportWarningKind.periodsDiffer));
  }

  return ResolvedImport(
    lessons: out,
    newSubjects: newSubjects.values.toList(),
    care: import.care,
    periods: extended,
    warnings: warnings,
    weekCycle: import.effectiveCycle,
  );
}

bool _periodsDiffer(List<ImportPeriod> sheet, List<PeriodRecord> periods) {
  for (final p in sheet) {
    final own = periods
        .where((x) => !x.isBreak && x.index == p.index)
        .firstOrNull;
    if (own == null) return true;
    if (minutesOf(own.starts) != minutesOf(p.starts) ||
        minutesOf(own.ends) != minutesOf(p.ends)) {
      return true;
    }
  }
  return false;
}

/// [periods] with lessons added up to index [upTo]: from the sheet's bell times where
/// it names them, else 45 minutes after a 5-minute break, continuing the last lesson.
List<PeriodRecord> extendPeriods(
  List<PeriodRecord> periods, {
  required String schoolId,
  required int upTo,
  List<ImportPeriod> sheet = const [],
}) {
  final out = [...periods]
    ..sort((a, b) => minutesOf(a.starts).compareTo(minutesOf(b.starts)));
  var last = out.isEmpty ? 0 : out.where((p) => !p.isBreak).last.index;
  var end = out.isEmpty ? 8 * 60 : minutesOf(out.last.ends);
  TimeOfDay at(int m) => TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60);
  while (last < upTo) {
    last++;
    final named = sheet.where((p) => p.index == last).firstOrNull;
    final starts = named?.starts ?? at(end + (out.isEmpty ? 0 : 5));
    final ends = named?.ends ?? at(minutesOf(starts) + 45);
    if (out.isNotEmpty && minutesOf(starts) > end) {
      out.add(
        PeriodRecord(
          schoolId: schoolId,
          index: last - 1,
          starts: at(end),
          ends: starts,
          kind: 'break',
        ),
      );
    }
    out.add(
      PeriodRecord(
        schoolId: schoolId,
        index: last,
        starts: starts,
        ends: ends,
        kind: 'lesson',
      ),
    );
    end = minutesOf(ends);
  }
  return out;
}

/// The next tint for a subject the import creates: the least used one, ties in order.
String nextSubjectTint(Iterable<SubjectRecord> existing, int offset) {
  final counts = {for (final t in subjectTints) t: 0};
  for (final s in existing) {
    counts.update(s.tint, (n) => n + 1, ifAbsent: () => 0);
  }
  final least = counts.values.reduce((a, b) => a < b ? a : b);
  final candidates = [
    for (final t in subjectTints)
      if (counts[t] == least) t,
  ];
  return candidates[offset % candidates.length];
}
