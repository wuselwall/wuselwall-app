import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/details/board_details.dart';

/// Week of Monday 12 October 2026; today is Wednesday 14 October, 10:30.
final _now = DateTime(2026, 10, 14, 10, 30);

Map<String, dynamic> _lesson({
  required int period,
  required String starts,
  required String ends,
  required String subject,
  String? short,
  String? room,
  String? tint,
  String status = 'normal',
  String? note,
  String? equipment,
}) => {
  'period': period,
  'starts': starts,
  'ends': ends,
  'subject': subject,
  'short': short,
  'room': room,
  'tint': tint,
  'status': status,
  'note': note,
  'equipment': equipment,
};

Map<String, dynamic> _care(String starts, String ends) => {
  'starts': starts,
  'ends': ends,
  'subject': 'Hort',
  'kind': 'care',
};

Map<String, dynamic> _schoolDay({
  required String memberId,
  String? starts,
  String? ends,
  List<String> notable = const [],
  String? careUntil,
  required List<Map<String, dynamic>> lessons,
  String? free,
}) => {
  'member_id': memberId,
  'starts': starts,
  'ends': ends,
  'notable': notable,
  'care_until': careUntil,
  'care_label': careUntil == null ? null : 'Hort',
  'free': free,
  'lessons': lessons,
};

final Map<String, dynamic> _json = {
  'week_start': '2026-10-12',
  'today': '2026-10-14',
  'generated_at': '2026-10-14T10:30:00+02:00',
  'settings': {
    'day_parts': ['12:00', '17:00'],
    'member_label': 'name',
  },
  'members': [
    {
      'id': 'sabine',
      'display_name': 'Sabine',
      'color': '#C0566B',
      'kind': 'adult',
      'baseline': {'state': 'home_office', 'label': 'Homeoffice'},
    },
    {
      'id': 'lukas',
      'display_name': 'Lukas',
      'color': '#3B6FB6',
      'kind': 'adult',
      'baseline': {'state': 'working', 'label': null},
    },
    {
      'id': 'lotta',
      'display_name': 'Lotta',
      'color': '#3E8E4F',
      'kind': 'child',
    },
    {
      'id': 'hanna',
      'display_name': 'Hanna',
      'color': '#7A5CC2',
      'kind': 'child',
    },
  ],
  'presence': [
    {
      'id': 'travel',
      'member_id': 'sabine',
      'state': 'travel',
      'label': 'Dienstreise Berlin',
      'first_day': '2026-10-14',
      'last_day': '2026-10-15',
      'starts': null,
      'ends': null,
      'tentative': false,
    },
    {
      'id': 'off',
      'member_id': 'lukas',
      'state': 'off',
      'label': null,
      'first_day': '2026-10-16',
      'last_day': '2026-10-16',
    },
  ],
  'timetables': [
    {
      'member_id': 'lotta',
      'class_label': '5b',
      'school_name': 'Gesamtschule Nord',
      'periods': [
        {'index': 1, 'starts': '08:00', 'ends': '08:45', 'kind': 'lesson'},
        {'index': 2, 'starts': '08:45', 'ends': '09:30', 'kind': 'lesson'},
        {'index': 2, 'starts': '09:30', 'ends': '09:45', 'kind': 'break'},
        {'index': 3, 'starts': '09:45', 'ends': '10:30', 'kind': 'lesson'},
        {'index': 4, 'starts': '10:30', 'ends': '11:15', 'kind': 'lesson'},
        {'index': 4, 'starts': '11:15', 'ends': '11:30', 'kind': 'break'},
        {'index': 5, 'starts': '11:30', 'ends': '12:15', 'kind': 'lesson'},
      ],
    },
    {
      'member_id': 'hanna',
      'class_label': '3a',
      'school_name': 'Grundschule Süd',
      'periods': [
        {'index': 1, 'starts': '08:00', 'ends': '08:45', 'kind': 'lesson'},
        {'index': 2, 'starts': '08:45', 'ends': '09:30', 'kind': 'lesson'},
      ],
    },
  ],
  'days': [
    for (var i = 0; i < 7; i++)
      {
        'date': '2026-10-${12 + i}',
        'events': switch (i) {
          0 => [
            {
              'id': 'd0',
              'title': 'Chor',
              'location': null,
              'starts': '17:30',
              'ends': '18:30',
              'attendee_ids': ['hanna'],
              'tentative': false,
              'key': false,
            },
          ],
          2 => [
            {
              'id': 'allday',
              'title': 'Geburtstag planen',
              'location': null,
              'starts': null,
              'ends': null,
              'attendee_ids': ['sabine'],
              'tentative': false,
              'key': false,
            },
            {
              'id': 'zahn',
              'title': 'Zahnarzt Lotta',
              'location': 'Praxis Weber',
              'starts': '08:00',
              'ends': '09:00',
              'attendee_ids': ['lotta'],
              'tentative': false,
              'key': true,
            },
            {
              'id': 'hanna',
              'title': 'Kinderturnen',
              'location': 'Halle Ost',
              'starts': '14:00',
              'ends': '14:45',
              'attendee_ids': ['hanna', 'sabine'],
              'tentative': true,
              'key': false,
            },
            {
              'id': 'abend',
              'title': 'Elternabend',
              'location': 'Aula',
              'starts': '19:00',
              'ends': '20:30',
              'attendee_ids': ['sabine', 'lukas'],
              'tentative': false,
              'key': true,
            },
          ],
          _ => <Map<String, dynamic>>[],
        },
        'busy_until': [
          if (i == 2) {'member_id': 'sabine', 'until': '17:00'},
        ],
        'school': [
          if (i == 2) ...[
            _schoolDay(
              memberId: 'lotta',
              starts: '08:00',
              ends: '13:00',
              notable: ['Sport'],
              careUntil: '15:00',
              lessons: [
                _lesson(
                  period: 1,
                  starts: '08:00',
                  ends: '08:45',
                  subject: 'Mathematik',
                  short: 'Ma',
                  room: 'R12',
                  tint: 'blue',
                ),
                _lesson(
                  period: 2,
                  starts: '08:45',
                  ends: '09:30',
                  subject: 'Deutsch',
                  short: 'De',
                  room: 'R4',
                  tint: 'rose',
                ),
                _lesson(
                  period: 3,
                  starts: '09:45',
                  ends: '10:30',
                  subject: 'Englisch',
                  short: 'En',
                  room: 'R7',
                  tint: 'lilac',
                  status: 'substituted',
                  note: 'Frau Berg',
                ),
                _lesson(
                  period: 4,
                  starts: '10:30',
                  ends: '11:15',
                  subject: 'Biologie',
                  short: 'Bio',
                  room: 'B2',
                  tint: 'leaf',
                  status: 'cancelled',
                  note: 'fällt aus',
                ),
                _lesson(
                  period: 5,
                  starts: '11:30',
                  ends: '12:15',
                  subject: 'Musik',
                  short: 'Mu',
                  room: 'M1',
                  tint: 'peach',
                  status: 'room_change',
                ),
                _care('13:00', '15:00'),
              ],
            ),
            _schoolDay(memberId: 'hanna', free: 'holiday', lessons: const []),
          ],
          if (i == 3) ...[
            _schoolDay(
              memberId: 'lotta',
              starts: '08:00',
              ends: '10:30',
              careUntil: '15:00',
              lessons: [
                _lesson(
                  period: 1,
                  starts: '08:00',
                  ends: '08:45',
                  subject: 'Sport',
                  short: 'Sp',
                  room: 'Halle',
                  tint: 'mint',
                  equipment: 'Sportsachen',
                ),
                _lesson(
                  period: 2,
                  starts: '08:45',
                  ends: '09:30',
                  subject: 'Mathematik',
                  short: 'Ma',
                  room: 'R12',
                  tint: 'blue',
                ),
              ],
            ),
          ],
        ],
        'meal': switch (i) {
          0 => {
            'slot': 'lunch',
            'time': '12:30',
            'title': null,
            'cook_id': null,
            'eating': <String>[],
            'guests': 0,
          },
          2 => {
            'slot': 'dinner',
            'time': '18:30',
            'title': 'Lasagne',
            'cook_id': 'lukas',
            'eating': ['lukas', 'sabine', 'lotta'],
            'guests': 1,
          },
          3 => {
            'slot': 'dinner',
            'time': '18:30',
            'title': 'Kürbissuppe',
            'cook_id': 'sabine',
            'eating': ['sabine', 'lotta', 'hanna', 'lukas'],
            'guests': 0,
          },
          _ => null,
        },
      },
  ],
  'open_tasks': <Map<String, dynamic>>[],
  'shopping_count': 0,
};

final WeekBoard _board = WeekBoard.fromJson(_json);

typedef _Opener = void Function(BuildContext context);

Widget _host({
  required _Opener open,
  Shade shade = Shade.light,
  Locale locale = const Locale('de'),
}) => ProviderScope(
  overrides: [nowProvider.overrideWithValue(_now)],
  child: MaterialApp(
    theme: AppTheme.build(UiRegister.kiosk, shade),
    localizationsDelegates: localizationsDelegates,
    supportedLocales: supportedLocales,
    locale: locale,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

void _wall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Opens a detail, checks its texts, closes it with the back button, then opens it
/// again and checks that it closes by itself after 61 seconds.
Future<void> _check(
  WidgetTester tester, {
  required _Opener open,
  required List<String> expected,
  Shade shade = Shade.light,
  Locale locale = const Locale('de'),
  String backLabel = 'Zurück zur Woche',
}) async {
  _wall(tester);
  await tester.pumpWidget(_host(open: open, shade: shade, locale: locale));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  for (final text in expected) {
    expect(find.textContaining(text), findsWidgets, reason: text);
  }
  expect(find.text(backLabel), findsOneWidget);

  await tester.tap(find.text(backLabel));
  await tester.pumpAndSettle();
  expect(find.text(backLabel), findsNothing);
  expect(tester.takeException(), isNull);

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 61));
  await tester.pumpAndSettle();
  expect(find.text(backLabel), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('day detail: every appointment, who is where, the meal', (
    tester,
  ) async {
    await _check(
      tester,
      open: (context) => openDayDetail(context, _board, 2),
      expected: [
        'Mittwoch, 14. Oktober',
        'Heute',
        'Zahnarzt Lotta',
        'Kinderturnen ?',
        'Geburtstag planen',
        'Elternabend',
        'Dienstreise Berlin',
        'Termine bis 17:00',
        'Lasagne',
        'Lukas kocht',
        'Schule 8–13',
      ],
    );
  });

  testWidgets('day detail: attendee dots sit right after their title', (
    tester,
  ) async {
    _wall(tester);
    await tester.pumpWidget(
      _host(open: (context) => openDayDetail(context, _board, 2)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final title = find.text('Elternabend');
    final row = find.ancestor(of: title, matching: find.byType(Row)).first;
    final dots = find.descendant(of: row, matching: find.byType(MemberDots));
    expect(dots, findsOneWidget);
    final titleBox = tester.getRect(title);
    final dotsBox = tester.getRect(dots);
    // The dots follow the title block with a 12 px gap, centred on the title line.
    expect(dotsBox.left - titleBox.right, closeTo(12, 1));
    expect((dotsBox.center.dy - titleBox.center.dy).abs(), lessThan(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('child week: paper timetable with Entfall, Vertretung, packing', (
    tester,
  ) async {
    await _check(
      tester,
      open: (context) => openChildWeek(context, _board, 'lotta'),
      expected: [
        'Stundenplan von Lotta',
        'Klasse 5b',
        'Entfall',
        'Vertretung',
        'Raumwechsel',
        'Hort',
        'Morgen einpacken: Sportsachen',
        'Mi',
      ],
    );
  });

  testWidgets('child week in the dark shade', (tester) async {
    await _check(
      tester,
      open: (context) => openChildWeek(context, _board, 'lotta'),
      shade: Shade.dark,
      expected: ['Stundenplan von Lotta', 'Entfall', 'Vertretung'],
    );
  });

  testWidgets('child week in English', (tester) async {
    await _check(
      tester,
      open: (context) => openChildWeek(context, _board, 'lotta'),
      locale: const Locale('en'),
      backLabel: 'Back to the week',
      expected: [
        "Lotta's timetable",
        'Cancelled',
        'Substitute',
        'Pack for tomorrow: Sportsachen',
      ],
    );
  });

  testWidgets('school day: Stunde by Stunde, now and over, the whole week', (
    tester,
  ) async {
    await _check(
      tester,
      open: (context) => openSchoolDay(context, _board, 'lotta', 2),
      expected: [
        'Lotta · Mittwoch',
        'Schule 8–13',
        'Hort bis 15:00',
        'Mathematik',
        'Englisch',
        'Entfall',
        'Vertretung',
        'Pause',
        'jetzt',
        'vorbei',
        'Die ganze Woche',
      ],
    );
  });

  testWidgets('member week: baseline, travel band, cooking', (tester) async {
    await _check(
      tester,
      open: (context) => openMemberWeek(context, _board, 'sabine'),
      expected: [
        'Die Woche von Sabine',
        'Normalerweise: Homeoffice',
        'Dienstreise Berlin',
        'Termine bis 17:00',
        'Kocht: Kürbissuppe',
        'Geburtstag planen',
      ],
    );
  });

  testWidgets('meal week: nothing planned, who is eating', (tester) async {
    await _check(
      tester,
      open: (context) => openMealWeek(context, _board),
      expected: [
        'Essen dieser Woche',
        'nichts geplant',
        'Lasagne',
        'Lukas kocht',
        'Kürbissuppe',
      ],
    );
  });
}
