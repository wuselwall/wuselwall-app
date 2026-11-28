import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/search_field.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';

final _de = lookupAppLocalizations(const Locale('de'));

const _choreTitles = [
  'Bett machen',
  'Müll rausbringen',
  'Geschirrspüler ausräumen',
  'Tisch decken',
  'Staub saugen',
  'Käse reiben',
  'Blumen giessen',
];

const _rewardTitles = [
  'Samstagsfilm aussuchen',
  'Eis essen gehen',
  'Länger aufbleiben',
  'Zoo-Besuch',
  'Käsefondue wünschen',
  'Neues Buch',
  'Ausflug planen',
];

FakeTasksApi _api({int chores = 0, int rewards = 0}) => FakeTasksApi(
  tables: {
    'task_definitions': [
      for (var i = 0; i < chores; i++)
        definitionRow(id: 'd$i', title: _choreTitles[i]),
    ],
    'rewards': [
      for (var i = 0; i < rewards; i++)
        {
          'id': 'r$i',
          'title': _rewardTitles[i],
          'cost_points': 5,
          'requires_approval': true,
          'is_active': true,
        },
    ],
  },
);

/// The adult home on the Tasks destination, on the tab named [tab].
Future<ProviderContainer> _open(
  WidgetTester t,
  FakeTasksApi api,
  String tab,
) async {
  final container = await pumpApp(
    t,
    overrides: baseOverrides(
      identity: FakeIdentityRepository(current: device()),
    ),
    tasks: api,
  );
  container.read(homeTabProvider.notifier).select(HomeTab.tasks);
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(Tab, tab));
  await t.pumpAndSettle();
  return container;
}

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester t, String key, String text) async {
  await t.enterText(_field(key), text);
  await t.pumpAndSettle();
}

void main() {
  test('a list gets its filter from seven entries on', () {
    expect(listFilterFrom, 7);
  });

  group('the chores', () {
    const key = 'chores-filter';

    testWidgets('a short list has no filter field', (t) async {
      await _open(t, _api(chores: 6), _de.tasksTabChores);

      expect(find.text('Käse reiben'), findsOneWidget);
      expect(find.byKey(const ValueKey(key)), findsNothing);
    });

    testWidgets('a list of seven has one, with its hint', (t) async {
      await _open(t, _api(chores: 7), _de.tasksTabChores);

      expect(find.byKey(const ValueKey(key)), findsOneWidget);
      expect(find.text(_de.tasksFilterChores), findsOneWidget);
      for (final title in _choreTitles) {
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('typing narrows the list, with umlauts folded', (t) async {
      await _open(t, _api(chores: 7), _de.tasksTabChores);

      await _type(t, key, 'muell');

      expect(find.text('Müll rausbringen'), findsOneWidget);
      expect(find.text('Bett machen'), findsNothing);
      expect(find.text('Käse reiben'), findsNothing);

      await _type(t, key, 'KÄSE');
      expect(find.text('Käse reiben'), findsOneWidget);
      expect(find.text('Müll rausbringen'), findsNothing);
    });

    testWidgets('a word in the middle of a title finds it too', (t) async {
      await _open(t, _api(chores: 7), _de.tasksTabChores);

      // "saugen" is the second word; "spüler" is inside one.
      await _type(t, key, 'saugen');
      expect(find.text('Staub saugen'), findsOneWidget);
      await _type(t, key, 'spueler');
      expect(find.text('Geschirrspüler ausräumen'), findsOneWidget);
      expect(find.text('Staub saugen'), findsNothing);
    });

    testWidgets('a query without a match shows the empty line', (t) async {
      await _open(t, _api(chores: 7), _de.tasksTabChores);

      await _type(t, key, 'zzzqq');

      expect(find.byKey(const ValueKey('chores-filter-empty')), findsOneWidget);
      expect(find.text(_de.searchNothingFound), findsOneWidget);
      for (final title in _choreTitles) {
        expect(find.text(title), findsNothing);
      }
      // The field stays, so the query can be changed.
      expect(find.byKey(const ValueKey(key)), findsOneWidget);
    });

    testWidgets('clearing the field restores the whole list', (t) async {
      await _open(t, _api(chores: 7), _de.tasksTabChores);
      await _type(t, key, 'zzzqq');

      await t.tap(find.byKey(const ValueKey('search-clear')));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('chores-filter-empty')), findsNothing);
      for (final title in _choreTitles) {
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('blanks do not narrow the list', (t) async {
      await _open(t, _api(chores: 7), _de.tasksTabChores);

      await _type(t, key, '   ');

      expect(find.byKey(const ValueKey('chores-filter-empty')), findsNothing);
      expect(find.text('Bett machen'), findsOneWidget);
    });
  });

  group('the rewards', () {
    const key = 'rewards-filter';

    testWidgets('a short list has no filter field', (t) async {
      await _open(t, _api(rewards: 6), _de.tasksTabRewards);

      expect(find.text('Neues Buch'), findsOneWidget);
      expect(find.text('Ausflug planen'), findsNothing, reason: 'six rewards');
      expect(find.byKey(const ValueKey(key)), findsNothing);
    });

    testWidgets('a list of seven has one, with its hint', (t) async {
      await _open(t, _api(rewards: 7), _de.tasksTabRewards);

      expect(find.byKey(const ValueKey(key)), findsOneWidget);
      expect(find.text(_de.tasksFilterRewards), findsOneWidget);
      expect(find.text('Samstagsfilm aussuchen'), findsOneWidget);
    });

    testWidgets('typing narrows the list, with umlauts folded', (t) async {
      await _open(t, _api(rewards: 7), _de.tasksTabRewards);

      await _type(t, key, 'kaese');

      expect(find.text('Käsefondue wünschen'), findsOneWidget);
      expect(find.text('Eis essen gehen'), findsNothing);
      expect(find.text('Zoo-Besuch'), findsNothing);

      await _type(t, key, 'LAENGER');
      expect(find.text('Länger aufbleiben'), findsOneWidget);
      expect(find.text('Käsefondue wünschen'), findsNothing);
    });

    testWidgets('a query without a match shows the empty line', (t) async {
      await _open(t, _api(rewards: 7), _de.tasksTabRewards);

      await _type(t, key, 'zzzqq');

      expect(
        find.byKey(const ValueKey('rewards-filter-empty')),
        findsOneWidget,
      );
      expect(find.text(_de.searchNothingFound), findsOneWidget);
      expect(find.text('Zoo-Besuch'), findsNothing);
      expect(find.byKey(const ValueKey(key)), findsOneWidget);
    });

    testWidgets('clearing the field restores the whole list', (t) async {
      await _open(t, _api(rewards: 7), _de.tasksTabRewards);
      await _type(t, key, 'zzzqq');

      await t.tap(find.byKey(const ValueKey('search-clear')));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('rewards-filter-empty')), findsNothing);
      for (final title in _rewardTitles) {
        expect(find.text(title), findsOneWidget);
      }
    });
  });
}
