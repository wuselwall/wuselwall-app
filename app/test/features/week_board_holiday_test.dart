import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart' show BoardFrame;
import 'package:wuselwall/features/board/ui/board_zones.dart';
import 'package:wuselwall/features/board/ui/details/board_details.dart';

// The public holidays on the week board (specs/04 "Holidays"): the day's holiday from the
// household's region or its own row, in the header and in the day detail. Test data only.
// Week of Mon 12 Oct 2026; today is Wed 14 Oct.

Map<String, Object?> _day(
  int i, {
  Map<String, Object?>? holiday,
  bool omit = false,
}) {
  final day = DateTime(2026, 10, 12 + i);
  final iso =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  return {
    'date': iso,
    'events': <Object>[],
    'busy_until': <Object>[],
    'school': <Object>[],
    'meal': null,
    if (!omit) 'holiday': holiday,
  };
}

const _auffahrt = {'name': 'Auffahrt', 'source': 'region'};

/// A week with Auffahrt on Thursday (index 3); [holidays] overrides the holiday per day.
WeekBoard _board({
  Map<int, Map<String, Object?>?> holidays = const {3: _auffahrt},
  bool omitKey = false,
}) => WeekBoard.fromJson({
  'week_start': '2026-10-12',
  'today': '2026-10-14',
  'generated_at': '2026-10-14T14:05:00',
  'settings': {
    'day_parts': ['12:00', '17:00'],
    'member_label': 'name',
  },
  'members': [
    {
      'id': 'sabine',
      'display_name': 'Sabine',
      'color': '#D9622B',
      'kind': 'adult',
    },
  ],
  'presence': <Object>[],
  'timetables': <Object>[],
  'days': [
    for (var i = 0; i < 7; i++) _day(i, holiday: holidays[i], omit: omitKey),
  ],
  'open_tasks': <Object>[],
  'shopping_count': 0,
});

void main() {
  group('the day holiday in the read model', () {
    test('a day with a holiday carries its name and source', () {
      final day = _board().days[3];
      expect(day.holiday, isNotNull);
      expect(day.holiday!.name, 'Auffahrt');
      expect(day.holiday!.isHousehold, isFalse);
    });

    test('a household row is marked as the household\'s own', () {
      final board = _board(
        holidays: {
          1: {'name': 'Brückentag', 'source': 'household'},
        },
      );
      expect(board.days[1].holiday!.name, 'Brückentag');
      expect(board.days[1].holiday!.isHousehold, isTrue);
    });

    test(
      'a null holiday and a server without the key both mean no holiday',
      () {
        expect(
          _board(holidays: const {}).days.every((d) => d.holiday == null),
          isTrue,
        );
        expect(
          _board(omitKey: true).days.every((d) => d.holiday == null),
          isTrue,
        );
      },
    );

    test('the holiday leaves the other days alone', () {
      final board = _board();
      expect(board.days[2].holiday, isNull);
      expect(board.days[4].holiday, isNull);
    });

    test('the header row is taller only in a week with a holiday', () {
      expect(DayHeaderRow.heightOf(_board()), DayHeaderRow.holidayHeight);
      expect(
        DayHeaderRow.heightOf(_board(holidays: const {})),
        DayHeaderRow.height,
      );
    });
  });

  group('the holiday on the board', () {
    testWidgets('the header shows the name under the date', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final board = _board();
      await tester.pumpWidget(
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
              body: SizedBox(
                height: DayHeaderRow.heightOf(board),
                width: 1280,
                child: DayHeaderRow(
                  frame: BoardFrame(
                    board: board,
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
      );
      await tester.pump();
      expect(find.text('Auffahrt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the day detail starts with the holiday', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final board = _board();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nowProvider.overrideWithValue(DateTime(2026, 10, 14, 14, 5)),
          ],
          child: MaterialApp(
            theme: AppTheme.build(UiRegister.kiosk, Shade.light),
            localizationsDelegates: localizationsDelegates,
            supportedLocales: supportedLocales,
            locale: const Locale('de'),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => openDayDetail(context, board, 3),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Feiertag · Auffahrt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
