import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/domain/timetable_import.dart';

import '../support/fake_school.dart';

const _fenced = '''
Here is the timetable as JSON:

```json
{
  "format": "wuselwall-timetable/1",
  "member": "Anna",
  "school": "Grundschule Lindenhof",
  "class": "3b",
  "lessons": [
    {"day": "Mo", "period": 1, "subject": "Ma", "room": "R1"},
    {"day": "Montag", "period": "2.", "subject": "D"},
    {"day": 3, "period": 1, "subject": "Sp", "teacher": "Fr. Kurz"},
    {"day": "Thu", "starts": "8:50", "ends": "9:35", "subject": "Englisch"},
    {"day": "vie", "period": 3, "subject": "Phy", "name": "Physik", "week": "A"},
    {"day": "Fr", "period": 4, "subject": "Ku"},
    {"day": "Fr", "period": 5, "subject": ""}
  ],
  "care": [
    {"title": "Hort", "days": ["Mo", "Di", "Mi"], "starts": "13:30", "ends": "15:30"}
  ]
}
```
''';

void main() {
  group('parseTimetableImport', () {
    test('reads a fenced payload with days in several languages', () {
      final import = parseTimetableImport(_fenced);
      expect(import.member, 'Anna');
      expect(import.classLabel, '3b');
      expect(import.lessons, hasLength(6), reason: 'the empty cell is skipped');
      expect(import.lessons.map((l) => l.weekday), [1, 1, 3, 4, 5, 5]);
      expect(import.lessons[1].period, 2);
      expect(import.lessons[3].period, isNull);
      expect(import.lessons[3].starts, const TimeOfDay(hour: 8, minute: 50));
      expect(import.lessons[4].subjectName, 'Physik');
      expect(import.lessons[4].parity, 'a');
      expect(import.effectiveCycle, 'ab');
      expect(import.care.single.days, {1, 2, 3});
    });

    test('reads a grid: one list per day, index is the period', () {
      final import = parseTimetableImport(
        '{"grid": {"Mo": ["Ma", "D", null, "Sp"], "Di": ["", "Ku"]}}',
      );
      expect(
        import.lessons.map((l) => '${l.weekday}:${l.period}:${l.subject}'),
        ['1:1:Ma', '1:2:D', '1:4:Sp', '2:2:Ku'],
      );
      expect(import.effectiveCycle, 'weekly');
    });

    test('round-trips through toJson', () {
      final import = parseTimetableImport(_fenced);
      final again = parseTimetableImport(
        // ignore: avoid_dynamic_calls
        '${import.toJson()}'.isEmpty ? '' : _encode(import),
      );
      expect(again.lessons.length, import.lessons.length);
      expect(again.lessons[3].starts, import.lessons[3].starts);
      expect(again.care.single.title, 'Hort');
    });

    test('names the error', () {
      expect(
        () => parseTimetableImport('Sorry, I cannot read this.'),
        throwsA(
          isA<ImportParseException>().having(
            (e) => e.error,
            'error',
            ImportError.notJson,
          ),
        ),
      );
      expect(
        () => parseTimetableImport('{"member": "Anna"}'),
        throwsA(
          isA<ImportParseException>().having(
            (e) => e.error,
            'error',
            ImportError.noLessons,
          ),
        ),
      );
      expect(
        () => parseTimetableImport(
          '{"lessons": [{"day": "Funday", "period": 1, "subject": "Ma"}]}',
        ),
        throwsA(
          isA<ImportParseException>()
              .having((e) => e.error, 'error', ImportError.badDay)
              .having((e) => e.detail, 'detail', 'Funday'),
        ),
      );
      expect(
        () =>
            parseTimetableImport('{"lessons": [{"day": 1, "subject": "Ma"}]}'),
        throwsA(
          isA<ImportParseException>().having(
            (e) => e.error,
            'error',
            ImportError.badLesson,
          ),
        ),
      );
      expect(
        () => parseTimetableImport(
          '{"lessons": [{"day": 1, "starts": "25:00", "subject": "Ma"}]}',
        ),
        throwsA(
          isA<ImportParseException>().having(
            (e) => e.error,
            'error',
            ImportError.badTime,
          ),
        ),
      );
    });

    test('weekdays and clocks', () {
      expect(parseWeekday('Mi.'), 3);
      expect(parseWeekday('mié'), 3);
      expect(parseWeekday('MAR'), 2);
      expect(parseWeekday('dom'), 7);
      expect(parseWeekday('8'), isNull);
      expect(parseClock('08.00 Uhr'), const TimeOfDay(hour: 8, minute: 0));
      expect(parseClock('8h05'), const TimeOfDay(hour: 8, minute: 5));
      expect(parseClock('noon'), isNull);
    });
  });

  group('resolveImport', () {
    final data = referenceSchoolData();

    test('matches subjects by short name or name and lists the new ones', () {
      final import = parseTimetableImport(_fenced);
      final resolved = resolveImport(
        import,
        subjects: data.subjects,
        periods: data.periods,
        schoolId: 'school-1',
        schoolName: 'Grundschule Lindenhof',
      );
      expect(resolved.lessons, hasLength(6));
      expect(resolved.lessons[0].subjectId, 'sub-ma');
      expect(resolved.lessons[1].subjectId, 'sub-d');
      expect(resolved.lessons[2].subjectId, 'sub-sp');
      // "8:50" is the start of the second period.
      expect(resolved.lessons[3].period, 2);
      expect(resolved.lessons[3].newSubjectKey, 'englisch');
      expect(resolved.newSubjects.map((s) => s.name), [
        'Englisch',
        'Physik',
        'Ku',
      ]);
      expect(resolved.newSubjects[1].shortName, 'Phy');
      expect(resolved.weekCycle, 'ab');
      // Period 4 is beyond the three bell times: extended, with a warning.
      expect(resolved.periods, isNotNull);
      expect(resolved.periods!.where((p) => !p.isBreak).map((p) => p.index), [
        1,
        2,
        3,
        4,
      ]);
      expect(
        resolved.warnings.map((w) => w.kind),
        contains(ImportWarningKind.periodsExtended),
      );
      expect(
        resolved.warnings.map((w) => w.kind),
        isNot(contains(ImportWarningKind.schoolDiffers)),
      );
    });

    test(
      'a remembered alias matches, and a like-word preselects a subject',
      () {
        final subjects = [
          ...data.subjects,
          const SubjectRecord(
            id: 'sub-su',
            name: 'Sachunterricht',
            shortName: 'SU',
            tint: 'leaf',
            aliases: ['Sachkunde'],
          ),
        ];
        final import = parseTimetableImport('''
{"format": "wuselwall-timetable/1", "lessons": [
  {"day": "Mo", "period": 1, "subject": "Sachkunde"},
  {"day": "Mo", "period": 2, "subject": "HSU", "like": "SU"},
  {"day": "Mo", "period": 3, "subject": "Werken"}
]}''');
        final resolved = resolveImport(
          import,
          subjects: subjects,
          periods: data.periods,
          schoolId: 'school-1',
        );
        expect(resolved.lessons[0].subjectId, 'sub-su');
        expect(resolved.lessons[1].subjectId, isNull);
        expect(resolved.newSubjects.map((s) => s.word), ['HSU', 'Werken']);
        expect(resolved.newSubjects[0].suggestedId, 'sub-su');
        expect(resolved.newSubjects[1].suggestedId, isNull);
      },
    );

    test('drops a time that matches no bell time, and says so', () {
      final import = parseTimetableImport(
        '{"lessons": [{"day": 1, "starts": "14:00", "subject": "Ma"}, {"day": 1, "period": 1, "subject": "Ma"}]}',
      );
      final resolved = resolveImport(
        import,
        subjects: data.subjects,
        periods: data.periods,
        schoolId: 'school-1',
      );
      expect(resolved.lessons, hasLength(1));
      expect(resolved.warnings.single.kind, ImportWarningKind.unmatchedTimes);
      expect(resolved.warnings.single.count, 1);
    });

    test('extends bell times from the sheet when it names them', () {
      final extended = extendPeriods(
        data.periods,
        schoolId: 'school-1',
        upTo: 5,
        sheet: const [
          ImportPeriod(
            index: 5,
            starts: TimeOfDay(hour: 11, minute: 50),
            ends: TimeOfDay(hour: 12, minute: 35),
          ),
        ],
      );
      final lessons = extended.where((p) => !p.isBreak).toList();
      expect(lessons.map((p) => p.index), [1, 2, 3, 4, 5]);
      // Period 4 continues after a 5-minute break; period 5 takes the sheet's time.
      expect(lessons[3].starts, const TimeOfDay(hour: 10, minute: 45));
      expect(lessons[4].starts, const TimeOfDay(hour: 11, minute: 50));
      expect(extended.where((p) => p.isBreak).map((p) => p.index), [
        1,
        2,
        3,
        4,
      ]);
    });

    test('a different school name is a warning, not an error', () {
      final import = parseTimetableImport(_fenced);
      final resolved = resolveImport(
        import,
        subjects: data.subjects,
        periods: data.periods,
        schoolId: 'school-1',
        schoolName: 'Gymnasium Lindenhof',
      );
      expect(
        resolved.warnings.map((w) => w.kind),
        contains(ImportWarningKind.schoolDiffers),
      );
    });

    test('the next tint is the least used', () {
      final subjects = [
        for (final tint in ['blue', 'rose', 'blue'])
          SubjectRecord(id: tint, name: tint, shortName: tint, tint: tint),
      ];
      expect(nextSubjectTint(subjects, 0), 'lilac');
      expect(nextSubjectTint(subjects, 1), 'leaf');
      expect(nextSubjectTint(const [], 0), 'blue');
    });
  });
}

String _encode(TimetableImport import) {
  // jsonEncode cannot take TimeOfDay, but toJson() has already turned it into text.
  final json = import.toJson();
  return _toJsonText(json);
}

String _toJsonText(Object? v) => switch (v) {
  null => 'null',
  String s => '"${s.replaceAll('"', r'\"')}"',
  num n => '$n',
  bool b => '$b',
  List<Object?> l => '[${l.map(_toJsonText).join(',')}]',
  Map<Object?, Object?> m =>
    '{${m.entries.map((e) => '"${e.key}":${_toJsonText(e.value)}').join(',')}}',
  _ => throw ArgumentError(v),
};
