import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/features/board/data/board_repository.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/details/board_details.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/pack_item_sheet.dart';

import '../support/fake_school.dart';
import '../support/fakes.dart';

// One-off things to bring (specs/15, issue #289): the merge with the subjects' equipment,
// who may note one, the sheet, the Neuer Termin tile and the chips in the Stundenplan
// section. Test data only.

final _de = lookupAppLocalizations(const Locale('de'));

PackItem _item(String id, String member, DateTime date, String title) =>
    PackItem(id: id, memberId: member, date: date, title: title);

DateTime _tomorrow() {
  final now = testNow();
  return DateTime(now.year, now.month, now.day + 1);
}

Future<void> _openSchedule(WidgetTester t) async {
  await t.tap(
    find.descendant(
      of: homeNavigation(),
      matching: find.byIcon(Icons.school_outlined),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  group('the packing list of a day', () {
    final day = DateTime(2026, 10, 15);

    test('the equipment first, then the noted things, each once', () {
      expect(
        toBring(
          ['Sportsachen'],
          [
            _item('1', 'k', day, 'Turnbeutel'),
            _item('2', 'k', day, 'sportsachen'),
            _item('3', 'k', day, 'Turnbeutel '),
          ],
        ),
        ['Sportsachen', 'Turnbeutel'],
      );
    });

    test(
      'a board day carries the things of every child, with school or not',
      () {
        final board = BoardDay.fromJson({
          'date': '2026-10-15',
          'events': <Map<String, dynamic>>[],
          'busy_until': <Map<String, dynamic>>[],
          'school': [
            {
              'member_id': 'emma',
              'starts': '08:00',
              'ends': '09:00',
              'lessons': [
                {
                  'period': 1,
                  'starts': '08:00',
                  'ends': '08:45',
                  'subject': 'Sport',
                  'equipment': 'Sportsachen',
                },
              ],
            },
          ],
          'meal': null,
          'pack': [
            {
              'id': 'p1',
              'member_id': 'emma',
              'date': '2026-10-15',
              'title': 'Turnbeutel',
            },
            {
              'id': 'p2',
              'member_id': 'paul',
              'date': '2026-10-15',
              'title': 'Hausschuhe',
            },
          ],
        });
        expect(board.toBringOf('emma'), ['Sportsachen', 'Turnbeutel']);
        // Paul has no timetable: his things still are on his list.
        expect(board.toBringOf('paul'), ['Hausschuhe']);
        expect(board.packOf('paul').single.id, 'p2');
        expect(board.toBringOf('nobody'), isEmpty);
      },
    );

    test('a server before them sends no pack: the equipment alone', () {
      final week = SchoolWeek.fromJson({
        'timetables': <Map<String, dynamic>>[],
        'days': <Map<String, dynamic>>[],
      });
      expect(week.pack, isEmpty);
      expect(week.toBringOf('emma', day), isEmpty);
      final board = BoardDay.fromJson({
        'date': '2026-10-15',
        'events': <Map<String, dynamic>>[],
        'busy_until': <Map<String, dynamic>>[],
        'school': <Map<String, dynamic>>[],
        'meal': null,
      });
      expect(board.pack, isEmpty);
    });

    test('a school week matches the things to the child and the day', () {
      final week = SchoolWeek.fromJson({
        'timetables': <Map<String, dynamic>>[],
        'days': <Map<String, dynamic>>[],
        'pack': [
          {'id': 'p1', 'member_id': 'k', 'date': '2026-10-15', 'title': 'A'},
          {'id': 'p2', 'member_id': 'k', 'date': '2026-10-16', 'title': 'B'},
          {'id': 'p3', 'member_id': 'j', 'date': '2026-10-15', 'title': 'C'},
        ],
      });
      expect(week.toBringOf('k', day), ['A']);
      expect(week.packOf('j', day).map((p) => p.title), ['C']);
    });
  });

  group('who may note one', () {
    const papa = Member(
      id: 'papa',
      displayName: 'Papa',
      color: Color(0xFF2E7D6B),
      role: Role.guardian,
      active: true,
    );
    const anna = Member(
      id: 'anna',
      displayName: 'Anna',
      color: Color(0xFFFF8800),
      role: Role.member,
      active: true,
      isChild: true,
    );
    const ben = Member(
      id: 'ben',
      displayName: 'Ben',
      color: Color(0xFF0088FF),
      role: Role.member,
      active: true,
      isChild: true,
    );
    const gone = Member(
      id: 'gone',
      displayName: 'Ex',
      color: Color(0xFF888888),
      role: Role.member,
      active: false,
      isChild: true,
    );
    const all = [papa, anna, ben, gone];

    test('an adult for every active child', () {
      expect(packChildrenFor(all, 'papa').map((m) => m.id), ['anna', 'ben']);
    });
    test('a child only for itself', () {
      expect(packChildrenFor(all, 'ben').map((m) => m.id), ['ben']);
    });
    test('nobody acting, nobody', () {
      expect(packChildrenFor(all, null), isEmpty);
    });
  });

  testWidgets(
    'Neuer Termin offers Mitbringen, which notes a thing for tomorrow',
    (t) async {
      final school = FakeSchoolRepository();
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        school: school,
      );
      await openTab(t, _de.calendarTitle);
      await t.tap(
        find.widgetWithText(FloatingActionButton, _de.calendarNewEvent),
      );
      await t.pumpAndSettle();

      final tile = find.byKey(const ValueKey('event-template-pack-item'));
      await t.ensureVisible(tile);
      expect(find.text(_de.packItemTile), findsOneWidget);
      await t.tap(tile);
      await t.pumpAndSettle();

      // One child in the family: chosen, no question who.
      expect(find.text(_de.packItemWho), findsNothing);
      await t.enterText(
        find.byKey(const ValueKey('pack-item-title')),
        ' Turnbeutel ',
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('pack-item-save')));
      await t.pumpAndSettle();

      expect(school.packSaves, hasLength(1));
      final saved = school.packSaves.single;
      expect(saved.profileId, kidId);
      expect(saved.title, 'Turnbeutel');
      expect(saved.date, _tomorrow());
      expect(saved.id, isNull);
      expect(school.actors.last, guardianId);
      expect(
        find.text(_de.packItemSaved('Anna', 'Turnbeutel')),
        findsOneWidget,
      );
      // The template page closed with the sheet.
      expect(
        find.byKey(const ValueKey('event-template-pack-item')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the day can be another one, and nothing is saved without a title',
    (t) async {
      final school = FakeSchoolRepository();
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        school: school,
      );
      await openTab(t, _de.calendarTitle);
      await t.tap(
        find.widgetWithText(FloatingActionButton, _de.calendarNewEvent),
      );
      await t.pumpAndSettle();
      final tile = find.byKey(const ValueKey('event-template-pack-item'));
      await t.ensureVisible(tile);
      await t.tap(tile);
      await t.pumpAndSettle();

      final save = find.byKey(const ValueKey('pack-item-save'));
      expect(t.widget<FilledButton>(save).onPressed, isNull);
      await t.tap(find.text(_de.packItemDayAfter));
      await t.enterText(
        find.byKey(const ValueKey('pack-item-title')),
        'Zettel',
      );
      await t.pump();
      await t.tap(save);
      await t.pumpAndSettle();
      final now = testNow();
      expect(
        school.packSaves.single.date,
        DateTime(now.year, now.month, now.day + 2),
      );
    },
  );

  testWidgets('a server without the feature shows no Mitbringen tile', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: [
        ...baseOverrides(identity: FakeIdentityRepository(current: device())),
        packItemsSupportedProvider.overrideWithValue(false),
      ],
    );
    await openTab(t, _de.calendarTitle);
    await t.tap(
      find.widgetWithText(FloatingActionButton, _de.calendarNewEvent),
    );
    await t.pumpAndSettle();
    expect(find.text(_de.eventTemplatesSchool), findsWidgets);
    expect(
      find.byKey(const ValueKey('event-template-pack-item')),
      findsNothing,
    );
  });

  testWidgets(
    'the Stundenplan section lists a noted thing with the equipment and removes it',
    (t) async {
      final school = FakeSchoolRepository();
      school.packItems.add({
        'id': 'pack-a',
        'member_id': kidId,
        'date': ymd(_tomorrow()),
        'title': 'Turnbeutel',
      });
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        school: school,
      );
      await _openSchedule(t);

      expect(
        find.text('Morgen einpacken: Sportsachen, Turnbeutel'),
        findsOneWidget,
      );
      final chip = find.byKey(const ValueKey('pack-item-pack-a'));
      await t.ensureVisible(chip);
      expect(find.byKey(ValueKey('pack-item-add-$kidId')), findsOneWidget);
      await t.tap(find.byTooltip(_de.packItemRemove('Turnbeutel')));
      await t.pumpAndSettle();

      expect(school.packDeletes, ['pack-a']);
      expect(find.text('Morgen einpacken: Sportsachen'), findsOneWidget);
      expect(find.text(_de.packItemRemoved('Turnbeutel')), findsOneWidget);
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
    },
  );

  testWidgets(
    'on the wall, a child without a timetable gets the strip, and the acting adult the chips',
    (t) async {
      // Wednesday 14 October 2026; tomorrow is Thursday the 15th.
      final now = DateTime(2026, 10, 14, 17);
      final board = WeekBoard.fromJson({
        'week_start': '2026-10-12',
        'today': '2026-10-14',
        'generated_at': '2026-10-14T15:00:00Z',
        'members': [
          {
            'id': kidId,
            'display_name': 'Anna',
            'color': '#FF8800',
            'kind': 'child',
          },
        ],
        'presence': <Map<String, dynamic>>[],
        'timetables': <Map<String, dynamic>>[],
        'days': [
          for (var i = 0; i < 7; i++)
            {
              'date': '2026-10-${12 + i}',
              'events': <Map<String, dynamic>>[],
              'busy_until': <Map<String, dynamic>>[],
              'school': <Map<String, dynamic>>[],
              'pack': [
                if (i == 3)
                  {
                    'id': 'pack-w',
                    'member_id': kidId,
                    'date': '2026-10-15',
                    'title': 'Hausschuhe',
                  },
              ],
            },
        ],
        'open_tasks': <Map<String, dynamic>>[],
        'shopping_count': 0,
      });
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(
              identity: FakeIdentityRepository(current: device()),
              now: now,
            ),
            schoolRepositoryProvider.overrideWithValue(FakeSchoolRepository()),
            boardRepositoryProvider.overrideWithValue(
              FakeBoardRepository(board),
            ),
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
                    onPressed: () => openChildWeek(context, board, kidId),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();

      expect(find.text(_de.boardNoSchoolToday), findsOneWidget);
      expect(find.text('Morgen einpacken: Hausschuhe'), findsOneWidget);
      expect(find.byKey(const ValueKey('pack-item-pack-w')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pack-item-add-$kidId')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
}
