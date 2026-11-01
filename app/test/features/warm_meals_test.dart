import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

/// The two warm-meal settings as the server sends them.
List<SettingEntry> _settings({Object? school, Object? free}) => [
  for (final (key, value, fallback) in [
    ('meals.warm_meal.school_day', school, 'dinner'),
    ('meals.warm_meal.free_day', free, 'lunch'),
  ])
    SettingEntry(
      key: key,
      scope: SettingScope.household,
      type: SettingType.enumeration,
      constraints: const {
        'values': ['lunch', 'dinner', 'both', 'none'],
      },
      selfService: false,
      defaultValue: fallback,
      value: value ?? fallback,
      isDefault: value == null,
    ),
];

void main() {
  final wednesday = DateTime(2026, 10, 14);
  final saturday = DateTime(2026, 10, 17);

  group('warm meals (specs/21 meals.warm_meal.*)', () {
    test('the defaults: dinner on school days, lunch on free days', () {
      expect(warmSlotsOf(wednesday, _settings()), [PlanSlot.dinner]);
      expect(warmSlotsOf(saturday, _settings()), [PlanSlot.lunch]);
      expect(warmSlotsOf(saturday, const []), [PlanSlot.lunch]);
    });

    test('both are warm in the day\'s order, or none is', () {
      final settings = _settings(school: 'both', free: 'none');
      expect(warmSlotsOf(wednesday, settings), [
        PlanSlot.lunch,
        PlanSlot.dinner,
      ]);
      expect(warmSlotsOf(saturday, settings), isEmpty);
    });

    test('what needs one meal takes dinner when both or none are warm', () {
      final settings = _settings(school: 'both', free: 'none');
      expect(warmSlotOf(wednesday, settings), PlanSlot.dinner);
      expect(warmSlotOf(saturday, settings), PlanSlot.dinner);
      expect(warmSlotOf(wednesday, _settings(school: 'lunch')), PlanSlot.lunch);
    });
  });

  group('the board day\'s meals', () {
    Map<String, dynamic> meal(String slot, String title) => {
      'slot': slot,
      'time': null,
      'title': title,
      'cook_id': null,
      'eating': <String>[],
      'guests': 0,
    };
    Map<String, dynamic> day(Map<String, dynamic> extra) => {
      'date': '2026-10-14',
      'events': <Object>[],
      'busy_until': <Object>[],
      ...extra,
    };

    test('a server with meals sends lunch and dinner', () {
      final d = BoardDay.fromJson(
        day({
          'meal': meal('dinner', 'Pasta'),
          'meals': [meal('lunch', 'Suppe'), meal('dinner', 'Pasta')],
        }),
      );
      expect(d.meals.map((m) => m.title), ['Suppe', 'Pasta']);
      expect(d.meal?.title, 'Pasta');
    });

    test('a server before meals sends only meal', () {
      final d = BoardDay.fromJson(day({'meal': meal('lunch', 'Suppe')}));
      expect(d.meals.single.slot, MealSlot.lunch);
    });

    test('no warm meal is an empty list', () {
      final d = BoardDay.fromJson(day({'meal': null, 'meals': <Object>[]}));
      expect(d.meals, isEmpty);
      expect(d.meal, isNull);
    });
  });
}
