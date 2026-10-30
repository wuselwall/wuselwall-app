import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/details/board_details.dart';
import 'package:wuselwall/features/board/ui/details/meal_week_detail.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/meals/ui/meals_page.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';

import '../support/fake_meals.dart';
import '../support/fakes.dart';

/// The Monday of this week plus [offset] days, at midnight.
DateTime dayOf(int offset) {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day + offset);
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Opens the app as an adult on a personal device, on the meals tab.
Future<ProviderContainer> pumpMeals(
  WidgetTester t,
  FakeMealsRepository meals, {
  Size size = const Size(1000, 1600),
}) async {
  final container = await pumpApp(
    t,
    overrides: [
      ...baseOverrides(identity: FakeIdentityRepository(current: device())),
      householdSettingsRepositoryProvider.overrideWithValue(
        DemoHouseholdSettingsRepository(),
      ),
    ],
    meals: meals,
    size: size,
  );
  container.read(homeTabProvider.notifier).select(HomeTab.meals);
  await t.pumpAndSettle();
  return container;
}

/// A week board whose first day has a dinner for Emma and Papa, cooked by Papa. The
/// kiosk correction is tested against it.
WeekBoard kioskBoard() {
  final monday = dayOf(0);
  Map<String, dynamic> day(int i) => {
    'date': ymd(dayOf(i)),
    'events': <Map<String, dynamic>>[],
    'busy_until': <Map<String, dynamic>>[],
    'school': <Map<String, dynamic>>[],
    'meal': i == 0
        ? {
            'slot': 'dinner',
            'time': '18:30',
            'title': 'Kürbissuppe',
            'cook_id': 'm-papa',
            'eating': ['m-emma', 'm-papa'],
            'guests': 0,
          }
        : null,
  };
  return WeekBoard.fromJson({
    'week_start': ymd(monday),
    'today': ymd(monday),
    'generated_at': monday.toUtc().toIso8601String(),
    'members': [
      {
        'id': 'm-emma',
        'display_name': 'Emma',
        'color': '#7B3FE4',
        'kind': 'child',
      },
      {
        'id': 'm-papa',
        'display_name': 'Papa',
        'color': '#C2255C',
        'kind': 'adult',
      },
    ],
    'presence': <Map<String, dynamic>>[],
    'timetables': <Map<String, dynamic>>[],
    'days': [for (var i = 0; i < 7; i++) day(i)],
    'open_tasks': <Map<String, dynamic>>[],
    'shopping_count': 0,
  });
}

void main() {
  testWidgets('a free-text meal saves without a recipe', (t) async {
    final meals = FakeMealsRepository();
    final container = await pumpMeals(t, meals);

    // Monday's warm meal (dinner on a school day) is the first empty card.
    await t.tap(find.text('Noch nichts geplant').first);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Pizza');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await t.pumpAndSettle();

    final saved = meals.setMeals.single;
    expect(saved.freeText, 'Pizza');
    expect(saved.recipeId, isNull);
    expect(saved.slot, PlanSlot.dinner);
    expect(saved.date, dayOf(0));
    expect(find.text('Pizza'), findsOneWidget);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  testWidgets('a typed name suggests a recipe, and picking it stores the id', (
    t,
  ) async {
    final meals = FakeMealsRepository(
      recipes: const [
        Recipe(
          id: 'r-braten',
          title: 'Rinderbraten',
          servingsDefault: 4,
          ingredients: [
            RecipeIngredient(rawName: 'Rindfleisch', quantity: 800, unit: 'g'),
          ],
        ),
      ],
    );
    final container = await pumpMeals(t, meals);

    await t.tap(find.text('Noch nichts geplant').first);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Rind');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ListTile, 'Rinderbraten'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await t.pumpAndSettle();

    final saved = meals.setMeals.single;
    expect(saved.recipeId, 'r-braten');
    expect(saved.freeText, isNull);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  testWidgets('dragging a meal onto another day moves it, keeping its slot', (
    t,
  ) async {
    final meals = FakeMealsRepository(
      entries: [
        MealEntry(
          id: 'm1',
          onDate: dayOf(0),
          slot: PlanSlot.dinner,
          freeText: 'Kürbissuppe',
          title: 'Kürbissuppe',
        ),
      ],
    );
    final container = await pumpMeals(t, meals);

    final from = t.getCenter(find.text('Kürbissuppe'));
    final to = t.getCenter(find.text('Noch nichts geplant').first);
    final gesture = await t.startGesture(from);
    await t.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(to);
    await t.pump();
    await gesture.up();
    await t.pumpAndSettle();

    final move = meals.moves.single;
    expect(move.fromDate, dayOf(0));
    expect(move.toDate, dayOf(1));
    expect(move.toSlot, PlanSlot.dinner);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  testWidgets('the shopping preview adds only the ticked keys', (t) async {
    final meals = FakeMealsRepository(
      entries: [
        MealEntry(
          id: 'm1',
          onDate: dayOf(0),
          slot: PlanSlot.dinner,
          recipeId: 'r-pesto',
          title: 'Nudeln mit Pesto',
        ),
      ],
      preview: const [
        MealShoppingItem(
          key: 'k1',
          name: 'Nudeln',
          quantity: 500,
          unit: 'g',
          mealEntryIds: ['m1'],
          alreadyOnList: false,
        ),
        MealShoppingItem(
          key: 'k2',
          name: 'Salz',
          mealEntryIds: ['m1'],
          alreadyOnList: true,
        ),
      ],
    );
    final container = await pumpMeals(t, meals);

    await t.tap(find.widgetWithText(FilledButton, 'Einkaufsliste füllen'));
    await t.pumpAndSettle();

    expect(
      t
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Nudeln'),
          )
          .value,
      isTrue,
    );
    expect(
      t
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Salz'),
          )
          .value,
      isFalse,
    );

    await t.tap(find.widgetWithText(FilledButton, '1 Artikel hinzufügen'));
    await t.pumpAndSettle();

    expect(meals.generated.single.keys, ['k1']);
    expect(
      find.text('1 Artikel auf die Einkaufsliste gesetzt'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  testWidgets('the recipe editor saves its ingredients in order', (t) async {
    final meals = FakeMealsRepository();
    final container = await pumpMeals(t, meals);
    unawaited(container.read(routerProvider).push(Routes.recipeEdit));
    await t.pumpAndSettle();

    final semantics = t.ensureSemantics();
    try {
      await t.pump();
      // Servings actions must announce both their direction and their subject.
      for (final icon in [Icons.remove, Icons.add]) {
        final action = find.widgetWithIcon(IconButton, icon).first;
        final node = t.getSemantics(action);
        final label = '${node.label} ${node.tooltip}';
        expect(label, contains('Portionen'));
        expect(
          label,
          contains(icon == Icons.remove ? 'Verringern' : 'Erhöhen'),
        );
      }
    } finally {
      semantics.dispose();
    }

    await t.enterText(find.byType(TextField).first, 'Pfannkuchen');
    await t.tap(find.text('Zutat hinzufügen'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'Mehl');
    await t.enterText(find.byType(TextFormField).at(1), '500');
    await t.enterText(find.byType(TextFormField).at(2), 'g');
    await t.tap(find.text('Zutat hinzufügen'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(4), 'Milch');
    await t.enterText(find.byType(TextFormField).at(5), '0,5');
    await t.enterText(find.byType(TextFormField).at(6), 'l');
    await t.tap(find.widgetWithText(FilledButton, 'Rezept speichern'));
    await t.pumpAndSettle();

    final saved = meals.savedRecipes.single;
    expect(saved.title, 'Pfannkuchen');
    expect(saved.ingredients.map((i) => i.rawName), ['Mehl', 'Milch']);
    expect(saved.ingredients.first.quantity, 500);
    expect(saved.ingredients.last.quantity, 0.5);
    expect(saved.ingredients.last.unit, 'l');
    expect(saved.ingredients.first.toJson(), containsPair('raw_name', 'Mehl'));
    expect(saved.ingredients.first.toJson(), containsPair('quantity', 500.0));
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  testWidgets('the kiosk meal week toggles a dot and calls meal_eating_set', (
    t,
  ) async {
    final meals = FakeMealsRepository();
    final board = kioskBoard();
    final container = await pumpApp(
      t,
      overrides: [
        ...baseOverrides(
          identity: FakeIdentityRepository(
            current: device(
              deviceClass: DeviceClass.kiosk,
              register: UiRegister.kiosk,
              profileId: null,
            ),
          ),
        ),
      ],
      board: FakeBoardRepository(board),
      meals: meals,
    );
    container.read(actingProfileProvider.notifier).select('m-papa');
    await t.pumpAndSettle();

    final context = t.element(find.byType(Scaffold).first);
    unawaited(openMealWeek(context, board));
    await t.pumpAndSettle();

    await t.tap(
      find.descendant(
        of: find.byType(MealWeekDetailBody),
        matching: find.text('Emma'),
      ),
    );
    await t.pumpAndSettle();

    final call = meals.eatingCalls.single;
    expect(call.actor, 'm-papa');
    expect(call.date, dayOf(0));
    expect(call.slot, PlanSlot.dinner);
    expect(call.profileId, 'm-emma');
    // Emma was eating, so the tap turns her off.
    expect(call.eating, isFalse);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  /// The day [n] days before today, at midnight.
  DateTime daysAgo(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - n);
  }

  testWidgets('the suggestion chips fill the title and link the recipe', (
    t,
  ) async {
    final meals = FakeMealsRepository(
      recipes: const [
        Recipe(id: 'r-braten', title: 'Rinderbraten', servingsDefault: 4),
      ],
      history: [
        MealHistoryEntry(
          recipeId: 'r-braten',
          title: 'Rinderbraten',
          times: 4,
          firstOn: daysAgo(150),
          lastOn: daysAgo(9),
        ),
        MealHistoryEntry(
          title: 'Pizza',
          times: 2,
          firstOn: daysAgo(30),
          lastOn: daysAgo(3),
        ),
        MealHistoryEntry(
          title: 'Linseneintopf',
          times: 3,
          firstOn: daysAgo(330),
          lastOn: daysAgo(200),
        ),
      ],
    );
    final container = await pumpMeals(t, meals);

    await t.tap(find.text('Noch nichts geplant').first);
    await t.pumpAndSettle();
    expect(find.text('Oft bei uns'), findsOneWidget);
    expect(find.text('Lange nicht gegessen'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Linseneintopf'), findsOneWidget);

    await t.tap(find.widgetWithText(ActionChip, 'Rinderbraten'));
    await t.pumpAndSettle();
    expect(find.text('Oft bei uns'), findsNothing);
    await t.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await t.pumpAndSettle();

    final saved = meals.setMeals.single;
    expect(saved.recipeId, 'r-braten');
    expect(saved.freeText, isNull);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  testWidgets('a free-text suggestion saves as free text', (t) async {
    final meals = FakeMealsRepository(
      history: [
        MealHistoryEntry(
          title: 'Pizza',
          times: 2,
          firstOn: daysAgo(30),
          lastOn: daysAgo(3),
        ),
      ],
    );
    final container = await pumpMeals(t, meals);

    await t.tap(find.text('Noch nichts geplant').first);
    await t.pumpAndSettle();
    expect(find.text('Lange nicht gegessen'), findsNothing);
    await t.tap(find.widgetWithText(ActionChip, 'Pizza'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await t.pumpAndSettle();

    final saved = meals.setMeals.single;
    expect(saved.freeText, 'Pizza');
    expect(saved.recipeId, isNull);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  testWidgets('with no history the editor shows no suggestion rows', (t) async {
    final meals = FakeMealsRepository();
    final container = await pumpMeals(t, meals);

    await t.tap(find.text('Noch nichts geplant').first);
    await t.pumpAndSettle();
    expect(find.text('Oft bei uns'), findsNothing);
    expect(find.text('Lange nicht gegessen'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  testWidgets('a row with no meals is hidden, the other still shows', (
    t,
  ) async {
    final meals = FakeMealsRepository(
      history: [
        MealHistoryEntry(
          title: 'Linseneintopf',
          times: 3,
          firstOn: daysAgo(330),
          lastOn: daysAgo(200),
        ),
      ],
    );
    final container = await pumpMeals(t, meals);

    await t.tap(find.text('Noch nichts geplant').first);
    await t.pumpAndSettle();
    expect(find.text('Oft bei uns'), findsNothing);
    expect(find.text('Lange nicht gegessen'), findsOneWidget);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  testWidgets('the planned time stays whole on a narrow week column', (
    t,
  ) async {
    final meals = FakeMealsRepository(
      entries: [
        MealEntry(
          id: 'm1',
          onDate: dayOf(0),
          slot: PlanSlot.dinner,
          freeText: 'Kürbissuppe',
          title: 'Kürbissuppe',
          cookProfileId: guardianId,
          atTime: const TimeOfDay(hour: 18, minute: 30),
          guests: 2,
        ),
      ],
    );
    final container = await pumpMeals(t, meals, size: const Size(1024, 768));

    expect(find.text('18:30'), findsOneWidget);
    expect(find.text('Papa kocht · +2 Gäste'), findsOneWidget);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  for (final (width, rows) in [(1024.0, 2), (1440.0, 1)]) {
    testWidgets('at $width the week takes $rows row(s) of columns that keep a '
        'dish of one long word whole', (t) async {
      final container = await pumpMeals(
        t,
        FakeMealsRepository(),
        size: Size(width, 900),
      );
      final monday = t.getRect(find.textContaining(RegExp(r'^Mo ')));
      final friday = t.getRect(find.textContaining(RegExp(r'^Fr ')));
      final tuesday = t.getRect(find.textContaining(RegExp(r'^Di ')));
      // Each column keeps its minimum (seven at 141 px broke "Fischstäbch/en").
      expect(tuesday.left - monday.left, greaterThanOrEqualTo(mealsMinColumn));
      // A second row starts well below the first (today's label sits a pixel
      // lower, highlighted, which is not a row).
      expect(friday.top > monday.top + 20, rows == 2);
      expect(t.takeException(), isNull);
      await unmountApp(t, container);
    });
  }

  testWidgets('clearing a planned meal offers undo, which puts it back', (
    t,
  ) async {
    final meals = FakeMealsRepository(
      entries: [
        MealEntry(
          id: 'm1',
          onDate: dayOf(0),
          slot: PlanSlot.dinner,
          freeText: 'Pizza',
          title: 'Pizza',
        ),
      ],
    );
    final container = await pumpMeals(t, meals);

    await t.tap(find.text('Pizza'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.delete_outline));
    await t.pumpAndSettle();

    expect(find.text('„Pizza“ entfernt'), findsOneWidget);
    expect(find.text('Pizza'), findsNothing);

    await t.tap(find.text('Rückgängig'));
    await t.pumpAndSettle();

    final restored = meals.setMeals.single;
    expect(restored.freeText, 'Pizza');
    expect(restored.date, dayOf(0));
    expect(restored.slot, PlanSlot.dinner);
    expect(find.text('Pizza'), findsOneWidget);
    expect(t.takeException(), isNull);
    await unmountApp(t, container);
  });

  for (final width in [390.0, 1348.0]) {
    testWidgets('the meals header uses one bar at $width', (t) async {
      final container = await pumpMeals(
        t,
        FakeMealsRepository(),
        size: Size(width, 844),
      );
      final l10n = lookupAppLocalizations(const Locale('de'));
      final appBar = find.byType(AppBar);
      expect(t.widget<AppBar>(appBar).bottom, isNull);
      expect(
        t.getSize(appBar).height,
        Theme.of(t.element(appBar)).appBarTheme.toolbarHeight,
      );
      final settings = find.byTooltip(l10n.settingsTitle);
      final next = find.byTooltip(l10n.mealsNextWeek);
      expect(t.getCenter(next).dy, closeTo(t.getCenter(settings).dy, 1));
      final week = container.read(mealsWeekProvider);
      await t.tap(next);
      await t.pumpAndSettle();
      expect(
        container.read(mealsWeekProvider),
        DateTime(week.year, week.month, week.day + 7),
      );
      expect(t.takeException(), isNull);
    });
  }
}
