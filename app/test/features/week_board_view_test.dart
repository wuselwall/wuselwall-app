import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:wuselwall/features/board/ui/board_footer.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_next_up.dart';
import 'package:wuselwall/features/board/ui/board_presence.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/board/ui/board_zones.dart';
import 'package:wuselwall/features/board/ui/week_board_page.dart';
import 'package:wuselwall/features/board/ui/week_board_view.dart';
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
    {'id': 'emma', 'display_name': 'Emma', 'color': '#7B3FE4', 'kind': 'child'},
    {'id': 'paul', 'display_name': 'Paul', 'color': '#1F8A70', 'kind': 'child'},
    {
      'id': 'julia',
      'display_name': 'Julia',
      'color': '#D9622B',
      'kind': 'adult',
      'baseline': {'state': 'home_office', 'label': 'zu Hause'},
    },
    {
      'id': 'thomas',
      'display_name': 'Thomas',
      'color': '#2F6FD6',
      'kind': 'adult',
      'baseline': {'state': 'home_office', 'label': 'Homeoffice'},
    },
  ],
  // A two-day trip: one band, drawn once across Wednesday and Thursday.
  'presence': [
    {
      'id': 'trip',
      'member_id': 'thomas',
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
          'emma',
          starts: '08:00',
          ends: '14:25',
          notable: ['Sport'],
          careUntil: '15:00',
          careLabel: 'Hort',
        ),
        _school('paul', starts: '08:00', ends: '11:30'),
      ],
      meal: _meal(
        'dinner',
        time: '18:30',
        title: 'Kürbissuppe',
        cook: 'julia',
        eating: ['julia', 'thomas', 'emma', 'paul'],
      ),
    ),
    _dayJson(
      1,
      school: [
        _school('emma', starts: '08:00', ends: '13:35'),
        _school('paul', free: 'holiday', holidayName: 'Herbstferien'),
      ],
      busy: [
        {'member_id': 'julia', 'until': '17:00'},
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
          who: ['julia'],
        ),
        _event(
          'z',
          'Zahnarzt',
          starts: '13:00',
          ends: '13:30',
          who: ['paul'],
          key: true,
        ),
        _event(
          't',
          'Turnen',
          starts: '14:30',
          ends: '15:15',
          who: ['emma'],
          key: true,
        ),
        _event(
          'k',
          'Klavier',
          starts: '15:30',
          ends: '16:00',
          who: ['emma', 'paul'],
          key: true,
        ),
        _event(
          'g',
          'Grillen',
          starts: '16:00',
          ends: '17:00',
          who: ['julia', 'thomas'],
          key: true,
          tentative: true,
        ),
        _event(
          'e',
          'Elternabend',
          starts: '19:30',
          who: ['julia', 'thomas'],
          key: true,
        ),
      ],
      school: [
        _school(
          'emma',
          starts: '08:00',
          ends: '14:25',
          notable: ['Sport'],
          careUntil: '15:00',
          careLabel: 'Hort',
        ),
        _school('paul', starts: '08:00', ends: '12:45', notable: ['Schwimmen']),
      ],
      busy: [
        {'member_id': 'julia', 'until': '17:00'},
      ],
      meal: _meal(
        'dinner',
        time: '18:30',
        title: 'Chili sin Carne',
        cook: 'julia',
        eating: ['julia', 'thomas', 'emma', 'paul'],
        guests: 2,
      ),
    ),
    _dayJson(
      3,
      school: [
        _school('emma', starts: '08:00', ends: '13:35'),
        _school('paul', starts: '08:00', ends: '11:30'),
      ],
      meal: _meal(
        'dinner',
        time: '18:30',
        title: 'Fischstäbchen',
        cook: 'thomas',
        eating: ['julia', 'emma'],
      ),
    ),
    _dayJson(
      4,
      meal: _meal(
        'dinner',
        time: '18:30',
        title: 'Nudeln',
        cook: 'julia',
        eating: ['julia', 'thomas'],
      ),
    ),
    _dayJson(
      5,
      meal: _meal(
        'lunch',
        time: '12:00',
        title: 'Pesto',
        cook: 'thomas',
        eating: ['thomas', 'julia'],
      ),
    ),
    _dayJson(
      6,
      meal: _meal(
        'lunch',
        time: '12:00',
        title: 'Braten',
        cook: 'julia',
        eating: ['julia', 'thomas', 'emma', 'paul'],
        guests: 2,
      ),
    ),
  ],
  'open_tasks': [
    {'member_id': 'emma', 'count': 2},
    {'member_id': 'paul', 'count': 1},
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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in {
      'AtkinsonHyperlegibleNext': ['Regular', 'SemiBold', 'Bold', 'ExtraBold'],
      'BarlowSemiCondensed': ['Medium', 'SemiBold', 'Bold'],
    }.entries) {
      final loader = FontLoader(family.key);
      for (final weight in family.value) {
        loader.addFont(
          rootBundle.load('assets/fonts/${family.key}-$weight.ttf'),
        );
      }
      await loader.load();
    }
  });
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

    testWidgets('pulses the next-up dot twice, then holds still', (t) async {
      // specs/26 "Protecting the wall": nothing moves all day but the clock.
      await _pumpBoard(t);
      final dot = find.descendant(
        of: find.byType(BoardNextUp),
        matching: find.byType(FadeTransition),
      );
      await t.pump(const Duration(milliseconds: 600));
      expect(t.widget<FadeTransition>(dot).opacity.value, lessThan(1));
      await t.pump(const Duration(seconds: 3));
      expect(t.widget<FadeTransition>(dot).opacity.value, 1);
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('draws a two-day trip once across its days', (t) async {
      await _pumpBoard(t);
      expect(find.text('Dienstreise Berlin'), findsOneWidget);
    });

    testWidgets(
      'draws the usual week per day: a run once, today the current slot',
      (t) async {
        Map<String, Object?> place(
          String label, [
          String? starts,
          String? ends,
        ]) => {
          'member_id': 'julia',
          'state': 'working',
          'label': label,
          'starts': starts,
          'ends': ends,
        };
        final json = _boardJson();
        final days = (json['days'] as List).cast<Map<String, Object?>>();
        for (var i = 0; i < days.length; i++) {
          days[i] = {
            ...days[i],
            // Julia at home Monday, Tuesday, Thursday and Friday; Wednesday (today,
            // 14:05) in two slots. Nobody else has a usual week: their single
            // baselines are not drawn.
            'usual': [
              if (i < 5 && i != 2) place('zu Hause'),
              if (i == 2) ...[
                place('Büro', '08:00', '12:00'),
                place('Praxis', '13:00', '17:00'),
              ],
            ],
          };
        }
        await _pumpBoard(
          t,
          snapshot: BoardSnapshot(
            board: WeekBoard.fromJson(json),
            fetchedAt: DateTime(2026, 10, 14, 14, 4),
          ),
        );
        expect(t.takeException(), isNull);
        expect(find.text('zu Hause'), findsNWidgets(2));
        expect(find.textContaining('Praxis'), findsOneWidget);
        expect(find.textContaining('Büro'), findsNothing);
        expect(find.text('+1'), findsOneWidget);
        expect(find.text('Homeoffice'), findsNothing);
      },
    );

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
            _event('a', 'Arzt', starts: '12:30', ends: '13:00', who: ['paul']),
            _event(
              'f',
              'Friseur',
              starts: '16:30',
              ends: '17:00',
              who: ['emma'],
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

    testWidgets('a presence cell names its member as well as the day (A10)', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await _pumpBoard(t);
      expect(find.bySemanticsLabel(RegExp(r'^Julia, \S')), findsWidgets);
      handle.dispose();
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

  group('review round 3: what the wall shows whole', () {
    testWidgets('a 1920x1080 kiosk scales the board up to fill the panel (G)', (
      t,
    ) async {
      // A holiday in the week: the day names take their second line, as in a
      // week with a birthday.
      final json = _boardJson();
      ((json['days'] as List)[4] as Map)['holiday'] = {'name': 'Auffahrt'};
      await _pumpBoard(
        t,
        size: const Size(1920, 1080),
        snapshot: BoardSnapshot(
          board: WeekBoard.fromJson(json),
          fetchedAt: DateTime(2026, 10, 14, 14, 4),
        ),
      );
      expect(t.takeException(), isNull);
      // The 1280 x 720 canvas drawn 1.5 times, edge to edge, not in the top-left.
      final rect = t.getRect(find.byType(WeekBoardView));
      expect(rect.left, closeTo(0, 0.5));
      expect(rect.top, closeTo(0, 0.5));
      expect(rect.width, closeTo(1920, 0.5));
      expect(rect.height, closeTo(1080, 0.5));
      // The footer is its 56 canvas px, so the 16:9 canvas still has room for the
      // three day parts of the appointments.
      expect(t.getSize(find.byType(BoardFooter)).height, 56);
      expect(find.text('Vormittag'), findsOneWidget);
    });

    testWidgets('a 1280x800 kiosk draws the board at its own size (G)', (
      t,
    ) async {
      await _pumpBoard(t);
      final rect = t.getRect(find.byType(WeekBoardView));
      expect(rect.size.width, closeTo(1280, 0.5));
      expect(rect.size.height, closeTo(800, 0.5));
    });

    Future<void> pumpTicker(WidgetTester t, double width) async {
      t.view.physicalSize = const Size(2400, 300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            nowProvider.overrideWithValue(DateTime(2026, 10, 14, 14, 5)),
          ],
          child: MaterialApp(
            theme: AppTheme.build(UiRegister.kiosk, Shade.light),
            localizationsDelegates: localizationsDelegates,
            supportedLocales: supportedLocales,
            locale: const Locale('de'),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: BoardNextUp(
                    frame: BoardFrame(
                      board: _board(),
                      geometry: const BoardGeometry(
                        canvasWidth: 1280,
                        todayIndex: 2,
                      ),
                      night: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(seconds: 3));
    }

    List<RenderParagraph> painted(WidgetTester t) => [
      for (final e in find.byType(RichText).hitTestable().evaluate())
        e.renderObject! as RenderParagraph,
    ];

    testWidgets('the next-up line keeps its first thing whole (E-1)', (
      t,
    ) async {
      // Wide: the next thing and the one after it.
      await pumpTicker(t, 700);
      var lines = painted(t).map((p) => p.text.toPlainText()).join(' | ');
      expect(lines, contains('14:30 Turnen · in 25 Min'));
      expect(lines, contains('danach 15:30 Klavier'));

      // Too narrow for both: "danach …" goes, the first stays whole.
      await pumpTicker(t, 450);
      expect(t.takeException(), isNull);
      lines = painted(t).map((p) => p.text.toPlainText()).join(' | ');
      expect(lines, contains('14:30 Turnen · in 25 Min'));
      expect(lines, isNot(contains('danach')));
      for (final p in painted(t)) {
        expect(p.didExceedMaxLines, isFalse, reason: p.text.toPlainText());
      }

      // Too narrow even for the first: it ends in an ellipsis, it never overflows.
      await pumpTicker(t, 250);
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'a lone appointment too long for its line moves up beside its time (E-2)',
      (t) async {
        final json = _boardJson();
        final days = (json['days'] as List).cast<Map<String, Object?>>();
        days[2]['events'] = [
          _event(
            'heizung',
            'Heizung wird gewartet',
            starts: '10:00',
            ends: '12:00',
            who: ['julia'],
            key: true,
          ),
        ];
        await _pumpBoard(
          t,
          snapshot: BoardSnapshot(
            board: WeekBoard.fromJson(json),
            fetchedAt: DateTime(2026, 10, 14, 14, 4),
          ),
        );
        expect(t.takeException(), isNull);
        final title = painted(t)
            .where((p) => p.text.toPlainText().contains('Heizung'));
        expect(title, hasLength(1));
        // Today's column: time and title share the two lines and the title is whole,
        // where the title's own line under the time would cut it.
        expect(title.single.text.toPlainText(), '10:00 Heizung wird gewartet');
        expect(title.single.maxLines, 2);
      },
    );

    testWidgets('each member row starts with the colour of its dots (L-9)', (
      t,
    ) async {
      await _pumpBoard(t);
      for (final name in ['Emma', 'Paul', 'Julia', 'Thomas']) {
        expect(
          find.descendant(
            of: find.byType(PresenceRows),
            matching: find.byWidgetPredicate(
              (w) => w is MemberDot && w.semanticLabel == name && w.size == 14,
            ),
          ),
          findsOneWidget,
          reason: name,
        );
      }
    });

    testWidgets('a school\'s own day off with a long name says "schulfrei" '
        '(E-3)', (t) async {
      final handle = t.ensureSemantics();
      final json = _boardJson();
      final days = (json['days'] as List).cast<Map<String, Object?>>();
      days[1]['school'] = [
        _school('paul', free: 'holiday', holidayName: 'Beweglicher Ferientag'),
      ];
      await _pumpBoard(
        t,
        snapshot: BoardSnapshot(
          board: WeekBoard.fromJson(json),
          fetchedAt: DateTime(2026, 10, 14, 14, 4),
        ),
      );
      // Paul's floating holiday on Tuesday does not fit the column: the row says
      // "schulfrei", a screen reader still hears the name.
      expect(find.text('schulfrei'), findsOneWidget);
      expect(find.text('Beweglicher Ferientag'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Beweglicher Ferientag')),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('the meal zone names itself on two lines (E-4)', (t) async {
      await _pumpBoard(t);
      final label = find.text('Warmes Essen');
      expect(t.widget<Text>(label).maxLines, 2);
      final paragraph = t.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
    });

    testWidgets('the view toggles are switches, not checkboxes (L-9)', (
      t,
    ) async {
      await _pumpBoard(t);
      expect(find.byIcon(Icons.check_box_outline_blank), findsNothing);
      expect(find.byIcon(Icons.check_box), findsNothing);
      expect(find.byType(BoardNextWeekToggle), findsOneWidget);
      expect(find.byType(BoardAllEventsToggle), findsOneWidget);
    });
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
    // A non-reference household: three adults and two children, long names, so no
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
          for (final fixture in ['crowded', 'reference-split', 'six-members']) {
            testWidgets('1280x800, ${locale.languageCode}, ${shade.name}, '
                '${scale}x: $fixture targets, fonts and clips', (t) async {
              final json = fixture == 'reference-split'
                  ? _boardJson()
                  : bigHouseholdJson();
              if (fixture == 'six-members') {
                (json['members'] as List).add({
                  'id': 'a4',
                  'display_name': 'Alexandra',
                  'color': '#08737F',
                  'kind': 'adult',
                });
              }
              if (fixture == 'reference-split') {
                (json['presence'] as List).add({
                  'id': 'care',
                  'member_id': 'emma',
                  'state': 'childcare',
                  'label': 'Hort am Nachmittag',
                  'first_day': '2026-10-14',
                  'last_day': '2026-10-14',
                  'starts': '14:25',
                  'ends': '16:00',
                });
                (((json['days'] as List)[3] as Map)['meal'] as Map)['title'] =
                    'Kartoffelgemüseauflauf';
              }
              await _pumpBoard(
                t,
                snapshot: BoardSnapshot(
                  board: WeekBoard.fromJson(json),
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
              final targets = <Rect>[];
              for (final element in find.byType(BoardTap).evaluate()) {
                final box = element.renderObject! as RenderBox;
                final rect = MatrixUtils.transformRect(
                  box.getTransformTo(null),
                  Offset.zero & box.size,
                );
                expect(
                  rect.width,
                  greaterThanOrEqualTo(56),
                  reason: '${(element.widget as BoardTap).label}: $rect',
                );
                expect(
                  rect.height,
                  greaterThanOrEqualTo(56),
                  reason: '${(element.widget as BoardTap).label}: $rect',
                );
                expect(rect.bottom, lessThanOrEqualTo(800));
                for (final previous in targets) {
                  expect(
                    rect.overlaps(previous.deflate(0.01)),
                    isFalse,
                    reason: '$rect overlaps $previous',
                  );
                }
                targets.add(rect);
              }
              for (final element in find.byType(RichText).evaluate()) {
                final paragraph = element.renderObject! as RenderParagraph;
                final text = paragraph.text.toPlainText();
                if (text.runes.every((r) => r >= 0xe000 && r <= 0xf8ff)) {
                  continue; // Icon glyphs.
                }
                final transform = paragraph.getTransformTo(null);
                final x =
                    MatrixUtils.transformPoint(transform, const Offset(1, 0)) -
                    MatrixUtils.transformPoint(transform, Offset.zero);
                void checkSpan(InlineSpan span) {
                  if (span.style?.fontSize case final size?) {
                    expect(
                      paragraph.textScaler.scale(size) * x.distance,
                      greaterThanOrEqualTo(24 * scale - 0.01),
                      reason: text,
                    );
                  }
                  if (span is TextSpan) {
                    for (final child in span.children ?? <InlineSpan>[]) {
                      checkSpan(child);
                    }
                  }
                }

                checkSpan(paragraph.text);
                final bounds = MatrixUtils.transformRect(
                  transform,
                  Offset.zero & paragraph.size,
                );
                for (
                  RenderObject? parent = paragraph.parent;
                  parent != null;
                  parent = parent.parent
                ) {
                  if (parent is RenderClipRect) {
                    final clip = MatrixUtils.transformRect(
                      parent.getTransformTo(null),
                      Offset.zero & parent.size,
                    );
                    expect(
                      bounds.top,
                      greaterThanOrEqualTo(clip.top - 0.1),
                      reason: '$text clipped at top',
                    );
                    expect(
                      bounds.bottom,
                      lessThanOrEqualTo(clip.bottom + 0.1),
                      reason: '$text clipped at bottom',
                    );
                  }
                }
              }
            });
          }
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
        // The reduced appointment zone summarises all three events in one
        // containing day cell: one title and a readable count for the other two.
        expect(find.text('+2'), findsWidgets);
        expect(t.getSize(find.byType(TermineRows)).height, 56);
      },
    );

    testWidgets('A6: day-header cells and member-row names are each >=56x56, '
        'and none overlap', (t) async {
      await _pumpBoard(t);

      // A compact member has one containing full-width row action, including
      // both school and care. The matrix above checks EVERY actual BoardTap.
      final dayCells = find.descendant(
        of: find.byType(DayHeaderRow),
        matching: find.byType(BoardTap),
      );
      final memberNames = find.ancestor(
        of: find.text('Emma'),
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
