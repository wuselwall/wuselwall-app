import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/ui/swipe_stepper.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/kiosk_canvas.dart';
import 'package:wuselwall/features/board/ui/week_board_view.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/application/kid_providers.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fakes.dart';

/// Swipes (specs/09 "Gestures"). The app runs with animations off here
/// ([pumpApp]), so a swipe steps at once; the sliding itself is
/// test/core/swipe_stepper_test.dart's.
final _de = AppLocalizationsDe();

/// A quick flick on [target]: towards the start (-1) goes on, towards the end goes back.
Future<void> _swipe(WidgetTester t, Finder target, int direction) async {
  await t.fling(target, Offset(-300.0 * direction, 0), 1000);
  await t.pumpAndSettle();
}

DateTime _plusDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

void main() {
  testWidgets('the calendar steps a day per swipe on a phone', (t) async {
    final container = await pumpApp(
      t,
      size: const Size(390, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );
    await openTab(t, _de.calendarTitle);
    final start = container.read(calendarViewProvider);
    expect(start.mode, CalendarMode.day);

    await _swipe(t, find.byType(SwipeStepper), 1);
    expect(
      container.read(calendarViewProvider).anchor,
      _plusDays(start.anchor, 1),
    );

    await _swipe(t, find.byType(SwipeStepper), -1);
    await _swipe(t, find.byType(SwipeStepper), -1);
    expect(
      container.read(calendarViewProvider).anchor,
      _plusDays(start.anchor, -1),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('the meals week steps a week per swipe', (t) async {
    final container = await pumpApp(
      t,
      size: const Size(390, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );
    container.read(homeTabProvider.notifier).select(HomeTab.meals);
    await t.pumpAndSettle();
    final week = container.read(mealsWeekProvider);

    await _swipe(t, find.byType(SwipeStepper), 1);
    expect(container.read(mealsWeekProvider), _plusDays(week, 7));
    expect(t.takeException(), isNull);
  });

  testWidgets('the adult timetable steps a week per swipe', (t) async {
    final container = await pumpApp(
      t,
      size: const Size(390, 844),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
    );
    container.read(homeTabProvider.notifier).select(HomeTab.schedule);
    await t.pumpAndSettle();
    final week = container.read(selectedWeekProvider);

    await _swipe(t, find.byType(SwipeStepper), 1);
    expect(container.read(selectedWeekProvider), _plusDays(week, 7));
    await _swipe(t, find.byType(SwipeStepper), -1);
    expect(container.read(selectedWeekProvider), week);
    expect(t.takeException(), isNull);
  });

  testWidgets('a child swipes through the timetable, Monday to Friday', (
    t,
  ) async {
    final container = await pumpApp(
      t,
      size: const Size(820, 1180),
      overrides: baseOverrides(
        identity: FakeIdentityRepository(
          current: device(profileId: kidId, register: UiRegister.kid),
        ),
      ),
    );
    container.read(kidTabProvider.notifier).select(KidTab.school);
    await t.pumpAndSettle();

    Finder day(int i) => find.byKey(ValueKey('kid-day-$i'));
    void expectSelected(int i) {
      for (var d = 0; d < 5; d++) {
        expect(
          t.getSemantics(day(d)),
          isSemantics(isSelected: d == i),
          reason: 'day $d',
        );
      }
    }

    await t.tap(day(0));
    await t.pumpAndSettle();
    expectSelected(0);

    await _swipe(t, find.byType(SwipeStepper), 1);
    expectSelected(1);
    await _swipe(t, find.byType(SwipeStepper), -1);
    expectSelected(0);
    // Monday is the start: nothing before it.
    await _swipe(t, find.byType(SwipeStepper), -1);
    expectSelected(0);

    await t.tap(day(4));
    await t.pumpAndSettle();
    await _swipe(t, find.byType(SwipeStepper), 1);
    expectSelected(4);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  group('shopping: a swipe takes an item off', () {
    Future<(FakeShoppingRepository, ProviderContainer)> openShopping(
      WidgetTester t, {
      UiRegister register = UiRegister.adult,
    }) async {
      final shopping = FakeShoppingRepository([
        item('1', 'Milch'),
        item('2', 'Brot'),
      ]);
      final container = await pumpApp(
        t,
        size: const Size(390, 844),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(
            current: device(
              register: register,
              profileId: register == UiRegister.kid ? kidId : guardianId,
            ),
          ),
          shopping: shopping,
        ),
      );
      if (register == UiRegister.kid) {
        container.read(kidTabProvider.notifier).select(KidTab.shopping);
      } else {
        container.read(homeTabProvider.notifier).select(HomeTab.shopping);
      }
      await t.pumpAndSettle();
      return (shopping, container);
    }

    Future<void> swipeAway(WidgetTester t, String name) async {
      await t.drag(find.text(name), const Offset(-350, 0));
      await t.pumpAndSettle();
    }

    testWidgets('it goes at once and is removed when the undo has passed', (
      t,
    ) async {
      final (shopping, _) = await openShopping(t);

      await swipeAway(t, 'Milch');
      expect(find.text('Milch'), findsNothing);
      expect(find.text(_de.shoppingItemRemoved('Milch')), findsOneWidget);
      // Not sent while the undo is offered.
      expect(shopping.list.map((i) => i.id), contains('1'));

      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      expect(shopping.list.map((i) => i.id), ['2']);
      expect(find.text('Milch'), findsNothing);
      expect(find.text('Brot'), findsOneWidget);
    });

    testWidgets('the undo brings it back and sends nothing', (t) async {
      final (shopping, _) = await openShopping(t);

      await swipeAway(t, 'Milch');
      await t.tap(find.text(_de.shoppingUndo));
      await t.pumpAndSettle();
      expect(find.text('Milch'), findsOneWidget);

      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      expect(shopping.list.map((i) => i.id), containsAll(['1', '2']));
      expect(find.text('Milch'), findsOneWidget);
    });

    testWidgets('without a swipe: the item dialog and the screen reader', (
      t,
    ) async {
      final semantics = t.ensureSemantics();
      final (shopping, _) = await openShopping(t);

      // The row offers "Entfernen" as an action.
      expect(
        t.getSemantics(find.text('Brot')),
        isSemantics(
          customActions: [CustomSemanticsAction(label: _de.shoppingRemoveItem)],
        ),
      );

      // The long press's dialog has "Entfernen" too.
      await t.longPress(find.text('Milch'));
      await t.pumpAndSettle();
      await t.tap(find.text(_de.shoppingRemoveItem));
      await t.pumpAndSettle();
      expect(find.text('Milch'), findsNothing);
      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      expect(shopping.list.map((i) => i.id), ['2']);
      semantics.dispose();
    });

    testWidgets('the children cannot swipe an item away', (t) async {
      final (shopping, container) = await openShopping(
        t,
        register: UiRegister.kid,
      );

      expect(find.byType(Dismissible), findsNothing);
      await swipeAway(t, 'Milch');
      expect(find.text('Milch'), findsOneWidget);

      await t.longPress(find.text('Milch'));
      await t.pumpAndSettle();
      expect(find.text(_de.shoppingRemoveItem), findsNothing);
      expect(shopping.list.map((i) => i.id), containsAll(['1', '2']));
      await unmountApp(t, container);
    });
  });

  group('the wall looks ahead to next week', () {
    final now = DateTime.now();
    final thisWeek = emptyWeekBoard(now);
    final nextMonday = _plusDays(thisWeek.weekStart, 7);

    Future<(FakeBoardRepository, ProviderContainer)> pumpKiosk(
      WidgetTester t, {
      Result<WeekBoard>? ahead,
    }) async {
      final board = FakeBoardRepository(
        thisWeek,
        ahead ?? Ok(emptyWeekBoard(_plusDays(now, 7))),
      );
      final container = await pumpApp(
        t,
        size: const Size(1920, 1200),
        board: board,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(
            current: device(
              deviceClass: DeviceClass.kiosk,
              register: UiRegister.kiosk,
            ),
          ),
        ),
      );
      return (board, container);
    }

    DateTime? shownWeek(WidgetTester t) =>
        t.widget<WeekBoardView>(find.byType(WeekBoardView)).week?.weekStart;

    testWidgets('by its switch, and back', (t) async {
      final (board, container) = await pumpKiosk(t);
      expect(shownWeek(t), isNull);

      await t.tap(find.text(_de.boardNextWeek));
      await t.pumpAndSettle();
      expect(board.weekStarts, contains(nextMonday));
      expect(shownWeek(t), nextMonday);

      await t.tap(find.text(_de.boardNextWeek));
      await t.pumpAndSettle();
      expect(shownWeek(t), isNull);
      await unmountApp(t, container);
    });

    testWidgets('by a swipe, only one week ahead', (t) async {
      final (_, container) = await pumpKiosk(t);

      await _swipe(t, find.byType(KioskCanvas), 1);
      expect(shownWeek(t), nextMonday);
      // Never further than next week.
      await _swipe(t, find.byType(KioskCanvas), 1);
      expect(shownWeek(t), nextMonday);

      await _swipe(t, find.byType(KioskCanvas), -1);
      expect(shownWeek(t), isNull);
      // Nor back before this one.
      await _swipe(t, find.byType(KioskCanvas), -1);
      expect(shownWeek(t), isNull);
      await unmountApp(t, container);
    });

    testWidgets('and comes back to this week after a minute untouched', (
      t,
    ) async {
      final (_, container) = await pumpKiosk(t);

      await _swipe(t, find.byType(KioskCanvas), 1);
      expect(shownWeek(t), nextMonday);
      await t.pump(const Duration(seconds: 61));
      await t.pumpAndSettle();
      expect(shownWeek(t), isNull);
      await unmountApp(t, container);
    });

    testWidgets('says so when next week cannot be loaded', (t) async {
      final (_, container) = await pumpKiosk(
        t,
        ahead: const Err(NetworkFailure()),
      );

      await t.tap(find.text(_de.boardNextWeek));
      await t.pumpAndSettle();
      expect(find.text(_de.boardNextWeekUnavailable), findsOneWidget);
      // The way back is where it was.
      await t.tap(find.text(_de.boardNextWeek));
      await t.pumpAndSettle();
      expect(find.text(_de.boardNextWeekUnavailable), findsNothing);
      expect(t.takeException(), isNull);
      await unmountApp(t, container);
    });
  });
}
