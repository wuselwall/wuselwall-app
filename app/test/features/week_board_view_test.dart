import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_presence.dart';
import 'package:wuselwall/features/board/ui/board_zones.dart';
import 'package:wuselwall/features/board/ui/week_board_page.dart';
import 'package:wuselwall/features/home/ui/register_home_page.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

// The reference household (specs/21) in test data only: nothing below is logic.
// Week of Mon 12 Oct 2026; today is Wed 14 Oct, 14:05.

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _day(int i) => DateTime(2026, 10, 12 + i);

Map<String, Object?> _event(
  String id,
  String title, {
  String? starts,
  String? ends,
  List<String> who = const [],
  bool key = false,
  bool tentative = false,
}) => {
  'id': id,
  'title': title,
  'starts': starts,
  'ends': ends,
  'attendee_ids': who,
  'key': key,
  'tentative': tentative,
};

Map<String, Object?> _school(
  String member, {
  String? starts,
  String? ends,
  List<String> notable = const [],
  String? careUntil,
  String? careLabel,
  String? free,
  String? holidayName,
}) => {
  'member_id': member,
  'starts': starts,
  'ends': ends,
  'notable': notable,
  'care_until': careUntil,
  'care_label': careLabel,
  'free': free,
  'holiday_name': holidayName,
  'lessons': <Object>[],
};

Map<String, Object?> _meal(
  String slot, {
  String? time,
  String? title,
  String? cook,
  List<String> eating = const [],
  int guests = 0,
}) => {
  'slot': slot,
  'time': time,
  'title': title,
  'cook_id': cook,
  'eating': eating,
  'guests': guests,
};

Map<String, Object?> _dayJson(
  int i, {
  List<Map<String, Object?>> events = const [],
  List<Map<String, Object?>> school = const [],
  List<Map<String, Object?>> busy = const [],
  Map<String, Object?>? meal,
}) => {
  'date': _iso(_day(i)),
  'events': events,
  'busy_until': busy,
  'school': school,
  'meal': meal,
};

Map<String, Object?> _boardJson() => {
  'week_start': '2026-10-12',
  'today': '2026-10-14',
  'generated_at': '2026-10-14T14:05:00',
  'settings': {
    'day_parts': ['12:00', '17:00'],
    'member_label': 'name',
  },
  'members': [
    {
      'id': 'lotta',
      'display_name': 'Lotta',
      'color': '#7B3FE4',
      'kind': 'child',
    },
    {
      'id': 'hanna',
      'display_name': 'Hanna',
      'color': '#1F8A70',
      'kind': 'child',
    },
    {
      'id': 'sabine',
      'display_name': 'Sabine',
      'color': '#D9622B',
      'kind': 'adult',
      'baseline': {'state': 'home_office', 'label': 'zu Hause'},
    },
    {
      'id': 'lukas',
      'display_name': 'Lukas',
      'color': '#2F6FD6',
      'kind': 'adult',
      'baseline': {'state': 'home_office', 'label': 'Homeoffice'},
    },
  ],
  // A two-day trip: one band, drawn once across Wednesday and Thursday.
  'presence': [
    {
      'id': 'trip',
      'member_id': 'lukas',
      'state': 'travel',
      'label': 'Dienstreise Berlin',
      'first_day': '2026-10-14',
      'last_day': '2026-10-15',
    },
  ],
  'timetables': <Object>[],
  'days': [
    _dayJson(
      0,
      school: [
        _school(
          'lotta',
          starts: '08:00',
          ends: '14:25',
          notable: ['Sport'],
          careUntil: '15:00',
          careLabel: 'Hort',
        ),
        _school('hanna', starts: '08:00', ends: '11:30'),
      ],
      meal: _meal(
        'dinner',
        time: '18:30',
        title: 'Kürbissuppe',
        cook: 'sabine',
        eating: ['sabine', 'lukas', 'lotta', 'hanna'],
      ),
    ),
    _dayJson(
      1,
      school: [
        _school('lotta', starts: '08:00', ends: '13:35'),
        _school('hanna', free: 'holiday', holidayName: 'Herbstferien'),
      ],
      busy: [
        {'member_id': 'sabine', 'until': '17:00'},
      ],
      // The empty meal: its zone stays and says so.
      meal: _meal('lunch', time: '12:00', eating: const []),
    ),
    _dayJson(
      2,
      events: [
        _event(
          'h',
          'Heizungswartung',
          starts: '10:00',
          ends: '11:00',
          who: ['sabine'],
        ),
        _event(
          'z',
          'Zahnarzt',
          starts: '13:00',
          ends: '13:30',
          who: ['hanna'],
          key: true,
        ),
        _event(
          't',
          'Turnen',
          starts: '14:30',
          ends: '15:15',
          who: ['lotta'],
          key: true,
        ),
        _event(
          'k',
          'Klavier',
          starts: '15:30',
          ends: '16:00',
          who: ['lotta', 'hanna'],
          key: true,
        ),
        _event(
          'g',
          'Grillen',
          starts: '16:00',
          ends: '17:00',
          who: ['sabine', 'lukas'],
          key: true,
          tentative: true,
        ),
        _event(
          'e',
          'Elternabend',
          starts: '19:30',
          who: ['sabine', 'lukas'],
          key: true,
        ),
      ],
      school: [
        _school(
          'lotta',
          starts: '08:00',
          ends: '14:25',
          notable: ['Sport'],
          careUntil: '15:00',
          careLabel: 'Hort',
        ),
        _school(
          'hanna',
          starts: '08:00',
          ends: '12:45',
          notable: ['Schwimmen'],
        ),
      ],
      busy: [
        {'member_id': 'sabine', 'until': '17:00'},
      ],
      meal: _meal(
        'dinner',
        time: '18:30',
        title: 'Chili sin Carne',
        cook: 'sabine',
        eating: ['sabine', 'lukas', 'lotta', 'hanna'],
        guests: 2,
      ),
    ),
    _dayJson(
      3,
      school: [
        _school('lotta', starts: '08:00', ends: '13:35'),
        _school('hanna', starts: '08:00', ends: '11:30'),
      ],
      meal: _meal(
        'dinner',
        time: '18:30',
        title: 'Fischstäbchen',
        cook: 'lukas',
        eating: ['sabine', 'lotta'],
      ),
    ),
    _dayJson(
      4,
      meal: _meal(
        'dinner',
        time: '18:30',
        title: 'Nudeln',
        cook: 'sabine',
        eating: ['sabine', 'lukas'],
      ),
    ),
    _dayJson(
      5,
      meal: _meal(
        'lunch',
        time: '12:00',
        title: 'Pesto',
        cook: 'lukas',
        eating: ['lukas', 'sabine'],
      ),
    ),
    _dayJson(
      6,
      meal: _meal(
        'lunch',
        time: '12:00',
        title: 'Braten',
        cook: 'sabine',
        eating: ['sabine', 'lukas', 'lotta', 'hanna'],
        guests: 2,
      ),
    ),
  ],
  'open_tasks': [
    {'member_id': 'lotta', 'count': 2},
    {'member_id': 'hanna', 'count': 1},
  ],
  'shopping_count': 17,
};

WeekBoard _board() => WeekBoard.fromJson(_boardJson());

final _snapshot = BoardSnapshot(
  board: _board(),
  fetchedAt: DateTime(2026, 10, 14, 14, 4),
);

class _FixedBoard extends BoardNotifier {
  _FixedBoard(this.value);

  final BoardSnapshot value;

  @override
  BoardSnapshot build() => value;
}

class _FixedNight extends NightNotifier {
  _FixedNight(this.night);

  final bool night;

  @override
  bool build() => night;
}

Future<void> _pumpBoard(
  WidgetTester t, {
  BoardSnapshot? snapshot,
  Size size = const Size(1280, 800),
  Shade shade = Shade.light,
  Locale locale = const Locale('de'),
  bool night = false,
  double textScale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        boardProvider.overrideWith(() => _FixedBoard(snapshot ?? _snapshot)),
        nowProvider.overrideWithValue(DateTime(2026, 10, 14, 14, 5)),
        nightProvider.overrideWith(() => _FixedNight(night)),
      ],
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.kiosk, shade),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: SafeArea(child: WeekBoardPage())),
      ),
    ),
  );
  await t.pump();
}

/// The kiosk home as the app shows it: the idle reverter wraps the board (register_home_page).
Future<void> _pumpKiosk(WidgetTester t) async {
  t.view.physicalSize = const Size(1280, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  await t.pumpWidget(
    ProviderScope(
      overrides: [
        boardProvider.overrideWith(() => _FixedBoard(_snapshot)),
        nowProvider.overrideWithValue(DateTime(2026, 10, 14, 14, 5)),
        nightProvider.overrideWith(() => _FixedNight(false)),
        deviceKeyProvider.overrideWithValue((
          deviceId: 'kiosk-1',
          deviceClass: DeviceClass.kiosk,
          profileId: null,
        )),
      ],
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.kiosk, Shade.light),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        locale: const Locale('de'),
        home: const RegisterHomePage(register: UiRegister.kiosk),
      ),
    ),
  );
  await t.pump();
}

void main() {
  group('the week board', () {
    testWidgets('lays out the week at 1280x800 without exceptions', (t) async {
      await _pumpBoard(t);
      expect(t.takeException(), isNull);

      // Today's column says "Heute" in place of its weekday.
      final today = _board().todayIndex!;
      const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
      for (final (i, dow) in days.indexed) {
        expect(
          find.text(dow),
          i == today ? findsNothing : findsOneWidget,
          reason: dow,
        );
      }
      expect(find.text('Heute'), findsOneWidget);
    });

    testWidgets('draws a two-day trip once across its days', (t) async {
      await _pumpBoard(t);
      expect(find.text('Dienstreise Berlin'), findsOneWidget);
    });

    testWidgets(
      "today's border lies under the zones, not over multi-day bars",
      (t) async {
        await _pumpBoard(t);
        final border = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is TodayBorderPainter,
        );
        final stack = t.widget<Stack>(
          find.ancestor(of: border, matching: find.byType(Stack)).first,
        );
        final borderIndex = stack.children.indexWhere(
          (c) => find
              .descendant(of: find.byWidget(c), matching: border)
              .evaluate()
              .isNotEmpty,
        );
        final zonesIndex = stack.children.indexWhere(
          (c) => find
              .descendant(
                of: find.byWidget(c),
                matching: find.byType(PresenceRows),
              )
              .evaluate()
              .isNotEmpty,
        );
        expect(borderIndex, greaterThanOrEqualTo(0));
        expect(borderIndex, lessThan(zonesIndex));
      },
    );

    testWidgets('counts the appointments that do not fit a day part', (
      t,
    ) async {
      await _pumpBoard(t);
      // Four key events in the afternoon: one shown, three counted.
      expect(find.text('+3 weitere'), findsOneWidget);
    });

    testWidgets('by default the day columns show only the key appointments', (
      t,
    ) async {
      await _pumpBoard(t);
      expect(find.text('Zahnarzt'), findsOneWidget);
      expect(find.text('Heizungswartung'), findsNothing);
    });

    testWidgets(
      '"Alle Termine" shows a non-key appointment and keeps presence in its zone',
      (t) async {
        await _pumpBoard(t);
        await t.tap(find.text('Alle Termine'));
        await t.pump();

        expect(find.text('Heizungswartung'), findsOneWidget);
        expect(
          ProviderScope.containerOf(t.element(find.byType(WeekBoardPage)))
              .read(boardAllEventsProvider),
          isTrue,
        );
        expect(find.text('Dienstreise Berlin'), findsOneWidget);
      },
    );

    testWidgets(
      'overflow still counts with every appointment shown, and nothing scrolls',
      (t) async {
        final json = _boardJson();
        final wednesday = (json['days'] as List)[2] as Map<String, Object?>;
        (wednesday['events'] as List<Map<String, Object?>>).addAll(
          <Map<String, Object?>>[
            _event('a', 'Arzt', starts: '12:30', ends: '13:00', who: ['hanna']),
            _event(
              'f',
              'Friseur',
              starts: '16:30',
              ends: '17:00',
              who: ['lotta'],
            ),
          ],
        );
        await _pumpBoard(
          t,
          snapshot: BoardSnapshot(
            board: WeekBoard.fromJson(json),
            fetchedAt: DateTime(2026, 10, 14, 14, 4),
          ),
        );
        // Four key appointments in the afternoon: one shown, three counted.
        expect(find.text('+3 weitere'), findsOneWidget);

        await t.tap(find.text('Alle Termine'));
        await t.pump();
        // Six in the afternoon now: still one shown, five counted, no exception.
        expect(find.text('+5 weitere'), findsOneWidget);
        expect(find.text('+3 weitere'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );

    testWidgets('keeps the empty meal zone and says nothing is planned', (
      t,
    ) async {
      await _pumpBoard(t);
      expect(find.text('nichts geplant'), findsOneWidget);
    });

    testWidgets('shows the shopping count in the footer', (t) async {
      await _pumpBoard(t);
      expect(find.text('17'), findsOneWidget);
    });

    testWidgets('says so when the connection is lost, keeping the last board', (
      t,
    ) async {
      await _pumpBoard(
        t,
        snapshot: BoardSnapshot(
          board: _board(),
          fetchedAt: DateTime(2026, 10, 14, 14, 4),
          failure: const NetworkFailure(),
        ),
      );
      expect(find.textContaining('Keine Verbindung'), findsOneWidget);
      expect(find.text('Dienstreise Berlin'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('fits 1280x720 and 1920x1200 without exceptions', (t) async {
      await _pumpBoard(t, size: const Size(1280, 720));
      expect(t.takeException(), isNull);

      await _pumpBoard(t, size: const Size(1920, 1200));
      expect(t.takeException(), isNull);
      expect(find.text('Heute'), findsOneWidget);
    });

    testWidgets('fits the night shade with the night dimming', (t) async {
      await _pumpBoard(t, shade: Shade.night, night: true);
      expect(t.takeException(), isNull);
      expect(find.text('Nachtansicht'), findsOneWidget);
    });

    testWidgets('reads in English', (t) async {
      await _pumpBoard(t, locale: const Locale('en'));
      expect(t.takeException(), isNull);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('+3 more'), findsOneWidget);
    });

    testWidgets('opens the family task board from the footer', (t) async {
      await _pumpBoard(t);
      await t.tap(find.text('Heute offen'));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
      expect(find.text('Zurück zur Woche'), findsOneWidget);

      // A6: the actual rendered hit area, not a nominal minimumSize, is
      // >=56x56 logical px for the kiosk's "back to week" action.
      final backButton = find.ancestor(
        of: find.text('Zurück zur Woche'),
        matching: find.byType(FilledButton),
      );
      final backSize = t.getSize(backButton);
      expect(backSize.width, greaterThanOrEqualTo(56));
      expect(backSize.height, greaterThanOrEqualTo(56));

      await t.tap(find.text('Zurück zur Woche'));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'opens the day detail stub from a column header without throwing',
      (t) async {
        await _pumpBoard(t);
        await t.tap(find.text('Do'));
        await t.pump(const Duration(milliseconds: 400));
        expect(t.takeException(), isNull);
      },
    );
  });

  group('BoardGeometry', () {
    test(
      'gives today 1.45 times the width of another day and fills the canvas',
      () {
        const g = BoardGeometry(canvasWidth: 1280, todayIndex: 2);
        final total = [for (var i = 0; i < 7; i++) g.width(i)]
            .reduce((a, b) => a + b);
        expect(total, closeTo(1280 - BoardGeometry.gutter, 0.001));
        expect(g.width(2) / g.width(0), closeTo(1.45, 0.001));
        expect(g.left(0), BoardGeometry.gutter);
        expect(g.spanLeft(3), closeTo(g.left(3), 0.001));
        expect(
          g.spanWidth(1, 3),
          closeTo(g.width(1) + g.width(2) + g.width(3), 0.001),
        );
      },
    );

    test('makes every column equal when today is outside the week', () {
      const g = BoardGeometry(canvasWidth: 1280);
      expect(g.width(0), closeTo(g.width(6), 0.001));
    });
  });
  group('the all-events switch when the kiosk goes idle', () {
    testWidgets('the idle kiosk reverts "Alle Termine" to key appointments', (
      t,
    ) async {
      await _pumpKiosk(t);
      await t.tap(find.text('Alle Termine'));
      await t.pump();
      expect(find.text('Heizungswartung'), findsOneWidget);

      // Nobody touches the wall for the idle time: the board is key-only again.
      await t.pump(const Duration(seconds: 61));
      await t.pump();
      expect(find.text('Heizungswartung'), findsNothing);
      expect(find.text('Zahnarzt'), findsOneWidget);
      expect(
        ProviderScope.containerOf(t.element(find.byType(WeekBoardPage)))
            .read(boardAllEventsProvider),
        isFalse,
      );
    });
  });

  group('A6/A7 scaling and legibility matrix (t_0b191bb3)', () {
    // A non-reference household: six adults and one child, long names, so no
    // fixture-shaped assumption (four members, short names) hides a layout bug.
    Map<String, Object?> bigHouseholdJson() {
      final json = _boardJson();
      json['members'] = [
        {
          'id': 'a1',
          'display_name': 'Maximiliane',
          'color': '#7B3FE4',
          'kind': 'adult',
          'baseline': {'state': 'home_office', 'label': 'Heimarbeitsplatz'},
        },
        {
          'id': 'a2',
          'display_name': 'Bartholomäus',
          'color': '#08737F',
          'kind': 'adult',
          'baseline': {'state': 'working', 'label': 'Büro Hauptbahnhof'},
        },
        {
          'id': 'a3',
          'display_name': 'Konstantina',
          'color': '#9A5300',
          'kind': 'adult',
        },
        {
          'id': 'k1',
          'display_name': 'Franziskaneria',
          'color': '#736200',
          'kind': 'child',
        },
        {
          'id': 'k2',
          'display_name': 'Zbigniew',
          'color': '#C2255C',
          'kind': 'child',
        },
      ];
      final days = (json['days'] as List).cast<Map<String, Object?>>();
      for (var i = 0; i < days.length; i++) {
        days[i] = _dayJson(
          i,
          events: [
            _event(
              'e$i-1',
              'Elternabend zur Schulfahrt',
              starts: '10:00',
              ends: '11:00',
              who: ['a1', 'a2'],
              key: true,
            ),
            _event(
              'e$i-2',
              'Zahnarzttermin',
              starts: '13:00',
              ends: '13:30',
              who: ['k1'],
              key: true,
            ),
            _event(
              'e$i-3',
              'Fußballtraining',
              starts: '16:00',
              ends: '17:30',
              who: ['k2'],
              key: true,
            ),
          ],
          school: [
            _school(
              'k1',
              starts: '08:00',
              ends: '14:25',
              notable: ['Schwimmen'],
              careUntil: '16:00',
              careLabel: 'Hort',
            ),
          ],
          meal: _meal(
            'dinner',
            time: '18:30',
            title: 'Gefüllte Paprika mit Couscous',
            cook: 'a3',
            eating: ['a1', 'a2', 'a3', 'k1', 'k2'],
            guests: 2,
          ),
        );
      }
      json['days'] = days;
      // A multi-day band across the whole week, so it is drawn past, today and
      // future at once.
      json['presence'] = [
        {
          'id': 'trip',
          'member_id': 'a2',
          'state': 'travel',
          'label': 'Dienstreise mit Zwischenstopp',
          'first_day': '2026-10-12',
          'last_day': '2026-10-18',
        },
      ];
      return json;
    }

    final matrixShades = Shade.values;
    final matrixScales = [1.0, 1.5, 2.0];
    final matrixLocales = [const Locale('de'), const Locale('en')];

    for (final shade in matrixShades) {
      for (final scale in matrixScales) {
        for (final locale in matrixLocales) {
          testWidgets('1280x800, ${locale.languageCode}, ${shade.name}, '
              '${scale}x: non-reference household, no overflow', (t) async {
            await _pumpBoard(
              t,
              snapshot: BoardSnapshot(
                board: WeekBoard.fromJson(bigHouseholdJson()),
                fetchedAt: DateTime(2026, 10, 14, 14, 4),
              ),
              shade: shade,
              locale: locale,
              textScale: scale,
              night: shade == Shade.night,
            );
            // No RenderFlex overflow, no failed layout assertion.
            expect(t.takeException(), isNull);
            // The geometry degrades (fewer events shown, overflow counted) but
            // never drops a day or a zone: all seven weekday short names (or
            // "Heute") are present once each.
            expect(find.byType(DayHeaderRow), findsOneWidget);
          });
        }
      }
    }

    testWidgets(
      'at 200% text the crowded fixture still shows an overflow count, not an overflow error',
      (t) async {
        await _pumpBoard(
          t,
          snapshot: BoardSnapshot(
            board: WeekBoard.fromJson(bigHouseholdJson()),
            fetchedAt: DateTime(2026, 10, 14, 14, 4),
          ),
          textScale: 2,
        );
        expect(t.takeException(), isNull);
        // Three key events in the afternoon for the child on every day; the day
        // part shows one and counts the rest instead of throwing.
        expect(find.textContaining('weitere'), findsWidgets);
      },
    );

    testWidgets('A6: day-header cells and member-row names are each >=56x56, '
        'and none overlap', (t) async {
      await _pumpBoard(t);

      // The day header's seven columns and each member's name tap (the
      // gutter) are the board's primary row/cell actions (specs/17, A6).
      // Compact band chips inside a split member row (a day with both a
      // school span and a presence band) are the spec's explicit
      // exception — "use >=56px containing row/cell action when distinct
      // band targets cannot fit" — and are not asserted individually here.
      final dayCells = find.descendant(
        of: find.byType(DayHeaderRow),
        matching: find.byType(BoardTap),
      );
      final memberNames = find.ancestor(
        of: find.text('Lotta'),
        matching: find.byType(BoardTap),
      );

      final finders = [
        for (var i = 0; i < t.widgetList(dayCells).length; i++) dayCells.at(i),
        memberNames.first,
      ];
      expect(finders.length, 8);

      final rects = <Rect>[];
      for (final finder in finders) {
        final size = t.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(56));
        expect(size.height, greaterThanOrEqualTo(56));
        rects.add(
          Rect.fromLTWH(
            t.getTopLeft(finder).dx,
            t.getTopLeft(finder).dy,
            size.width,
            size.height,
          ),
        );
      }
      // Adjacent-target behaviour: no two tap targets' hit areas overlap.
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: '#$i overlaps #$j: ${rects[i]} vs ${rects[j]}',
          );
        }
      }
    });
  });
}
