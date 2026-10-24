import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';

import '../support/fake_meals.dart';
import '../support/fakes.dart';

/// The Monday of this week plus [offset] days, at midnight.
DateTime _dayOf(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - (now.weekday - 1) + offset);
}

/// Pizza-Freitag on this week's Friday, a tradition carrying its meal (specs/27).
FakeCalendarRepository _calendar({
  TraditionMeal meal = const TraditionMeal(
    slot: 'dinner',
    freeText: 'Pizza',
    title: 'Pizza',
  ),
  bool tradition = true,
}) {
  final friday = _dayOf(4);
  return FakeCalendarRepository(
    [
      Occurrence(
        id: 'pizza-friday',
        eventId: 'pizza',
        calendarId: 'c',
        title: 'Pizza-Freitag',
        kind: EventKind.appointment,
        status: EventStatus.confirmed,
        importance: Importance.key,
        allDay: true,
        start: friday,
        end: friday,
        localStartDate: friday,
        localEndDate: friday,
        isRecurring: true,
        iconKey: 'pizza',
        tradition: tradition,
      ),
    ],
    {
      'pizza': CalendarEvent(
        id: 'pizza',
        title: 'Pizza-Freitag',
        kind: EventKind.appointment,
        isAllDay: true,
        startDate: friday,
        endDate: friday,
        rrule: 'FREQ=WEEKLY',
        tradition: tradition,
        traditionMeal: meal,
      ),
    },
  );
}

Future<void> _pumpMeals(
  WidgetTester t,
  FakeMealsRepository meals,
  FakeCalendarRepository calendar,
) async {
  final container = await pumpApp(
    t,
    overrides: [
      ...baseOverrides(identity: FakeIdentityRepository(current: device())),
      householdSettingsRepositoryProvider.overrideWithValue(
        DemoHouseholdSettingsRepository(),
      ),
    ],
    meals: meals,
    calendar: calendar,
  );
  container.read(homeTabProvider.notifier).select(HomeTab.meals);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'an empty slot on a tradition\'s day offers its meal; one tap plans it',
    (t) async {
      final meals = FakeMealsRepository();
      await _pumpMeals(t, meals, _calendar());

      final chip = find.widgetWithText(ActionChip, 'Pizza');
      expect(chip, findsOneWidget);
      expect(find.byTooltip('Pizza einplanen (Pizza-Freitag)'), findsOneWidget);

      await t.tap(chip);
      await t.pumpAndSettle();

      final saved = meals.setMeals.single;
      expect(saved.date, _dayOf(4));
      expect(saved.slot, PlanSlot.dinner);
      expect(saved.freeText, 'Pizza');
      expect(saved.recipeId, isNull);
      // Planned: the suggestion is gone and the meal is on the plan.
      expect(find.byType(ActionChip), findsNothing);
      expect(find.text('Pizza'), findsWidgets);
    },
  );

  testWidgets('a recipe meal is planned as the recipe', (t) async {
    final meals = FakeMealsRepository();
    await _pumpMeals(
      t,
      meals,
      _calendar(
        meal: const TraditionMeal(
          slot: 'dinner',
          recipeId: 'r-pizza',
          freeText: 'Pizza Margherita',
          title: 'Pizza Margherita',
        ),
      ),
    );
    await t.tap(find.widgetWithText(ActionChip, 'Pizza Margherita'));
    await t.pumpAndSettle();
    expect(meals.setMeals.single.recipeId, 'r-pizza');
    expect(meals.setMeals.single.freeText, isNull);
  });

  testWidgets('nothing is offered when that meal is already planned', (
    t,
  ) async {
    final meals = FakeMealsRepository(
      entries: [
        MealEntry(
          id: 'e1',
          onDate: _dayOf(4),
          slot: PlanSlot.dinner,
          freeText: 'Suppe',
          title: 'Suppe',
        ),
      ],
    );
    await _pumpMeals(t, meals, _calendar());
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('an ordinary recurring event offers nothing', (t) async {
    final meals = FakeMealsRepository();
    await _pumpMeals(t, meals, _calendar(tradition: false));
    expect(find.byType(ActionChip), findsNothing);
  });
}
