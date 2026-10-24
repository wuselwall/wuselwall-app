import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';

const _emma = 'p-emma';
const _paul = 'p-paul';
const _papa = 'p-papa';

/// The shared kid iPad's household: two children and a guardian, in that order.
final _kidMembers = [
  const Member(
    id: _emma,
    displayName: 'Emma',
    color: Color(0xFFB5306B),
    role: Role.member,
    active: true,
    isChild: true,
  ),
  const Member(
    id: _paul,
    displayName: 'Paul',
    color: Color(0xFF2E7D6B),
    role: Role.member,
    active: true,
    isChild: true,
  ),
  const Member(
    id: _papa,
    displayName: 'Papa',
    color: Color(0xFF1D4E89),
    role: Role.guardian,
    active: true,
  ),
];

/// Identity backend with the kid household's members, on a kid device.
class _KidIdentity extends FakeIdentityRepository {
  _KidIdentity()
    : super(
        current: device(
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
          profileId: null,
        ),
      );

  @override
  Future<Result<List<Member>>> members({bool includeInactive = false}) async =>
      Ok(_kidMembers);
}

/// The `api` layer after a tick: Emma's balance rises by the points credited, as the
/// server would do before the tasks topic refetches.
class _TickingApi extends FakeTasksApi {
  _TickingApi()
    : super(
        tables: {
          'task_instances': [
            instanceRow(
              id: 'i-tisch',
              title: 'Tisch decken',
              assignee: _emma,
              points: 3,
              iconKey: 'table',
            ),
            instanceRow(
              id: 'i-zimmer',
              title: 'Zimmer aufräumen',
              assignee: _paul,
              points: 2,
            ),
          ],
          'point_balances': [
            {'profile_id': _emma, 'balance': 12},
            {'profile_id': _paul, 'balance': 37},
          ],
          'rewards': [
            {
              'id': 'r-film',
              'title': 'Film aussuchen',
              'cost_points': 5,
              'requires_approval': false,
              'is_active': true,
            },
            {
              'id': 'r-late',
              'title': 'Länger aufbleiben',
              'cost_points': 50,
              'requires_approval': true,
              'is_active': true,
            },
          ],
        },
        replies: {
          'task_complete': {'status': 'done', 'points_credited': 3},
        },
      );

  @override
  Future<Result<T>> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    required T Function(Object? json) parse,
  }) {
    if (fn == 'task_complete') {
      tables['point_balances'] = [
        {'profile_id': _emma, 'balance': 15},
        {'profile_id': _paul, 'balance': 37},
      ];
    }
    return super.rpc(fn, params: params, parse: parse);
  }
}

/// A board of this week with the kid household as members and one open chore each.
WeekBoard _familyBoard() {
  final today = DateTime.now();
  final monday = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));
  String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return WeekBoard.fromJson({
    'week_start': ymd(monday),
    'today': ymd(today),
    'generated_at': today.toUtc().toIso8601String(),
    'members': [
      {
        'id': _emma,
        'display_name': 'Emma',
        'color': '#B5306B',
        'role': 'member',
        'kind': 'child',
        'active': true,
        'baseline': null,
      },
      {
        'id': _paul,
        'display_name': 'Paul',
        'color': '#2E7D6B',
        'role': 'member',
        'kind': 'child',
        'active': true,
        'baseline': null,
      },
    ],
    'presence': <Map<String, dynamic>>[],
    'timetables': <Map<String, dynamic>>[],
    'days': [
      for (var i = 0; i < 7; i++)
        {
          'date': ymd(monday.add(Duration(days: i))),
          'events': <Map<String, dynamic>>[],
          'busy_until': <Map<String, dynamic>>[],
          'school': <Map<String, dynamic>>[],
        },
    ],
    'open_tasks': [
      {'member_id': _emma, 'count': 1},
      {'member_id': _paul, 'count': 1},
    ],
    'shopping_count': 0,
  });
}

Future<void> _pickEmma(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('kid-pick-$_emma')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without an acting child the picker replaces the content', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _TickingApi(),
    );

    expect(find.byKey(const ValueKey('kid-picker')), findsOneWidget);
    expect(find.text('Tisch decken'), findsNothing);
    await unmountApp(tester, container);
  });

  testWidgets('picking Emma shows her chores, not Paul’s', (tester) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _TickingApi(),
    );

    await _pickEmma(tester);

    expect(find.byKey(const ValueKey('kid-picker')), findsNothing);
    // Wusel greets her by name; the words vary with the time of day (specs/25).
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kid-greeting')),
        matching: find.textContaining('Emma'),
      ),
      findsOneWidget,
    );
    expect(find.text('Tisch decken'), findsOneWidget);
    expect(find.text('Zimmer aufräumen'), findsNothing);
    await unmountApp(tester, container);
  });

  testWidgets('the settings gear sits above the greeting, not on it', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _TickingApi(),
    );
    await _pickEmma(tester);

    final gear = tester.getRect(find.byTooltip('Einstellungen'));
    final greeting = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('kid-greeting')),
        matching: find.textContaining('Emma'),
      ),
    );
    expect(gear.bottom, lessThanOrEqualTo(greeting.top));
    expect(gear.overlaps(greeting), isFalse);
    expect(
      tester.getSize(find.byTooltip('Einstellungen')).width,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byTooltip('Einstellungen')).height,
      greaterThanOrEqualTo(48),
    );
    await unmountApp(tester, container);
  });

  testWidgets(
    'ticking calls the task action as Emma, flies the coin and updates the balance',
    (tester) async {
      final api = _TickingApi();
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity()),
        tasks: api,
      );
      await _pickEmma(tester);

      await tester.tap(find.text('Tisch decken'));
      await tester.pumpAndSettle();

      final call = api.named('task_complete').single;
      expect(call.params, {'p_actor': _emma, 'p_instance_id': 'i-tisch'});
      final pill = find.byType(KidBalancePill);
      expect(
        find.descendant(of: pill, matching: find.text('15')),
        findsOneWidget,
      );
      // Reduced motion (the test default): no coin in the overlay.
      expect(find.text('+3'), findsNothing);
      expect(find.text('Rückgängig'), findsOneWidget);
      // Done, the card keeps full contrast: no strike-through, no fading (specs/26).
      final title = tester.widget<Text>(find.text('Tisch decken'));
      expect(title.style?.decoration, isNot(TextDecoration.lineThrough));
      expect(
        find.ancestor(
          of: find.text('Tisch decken'),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Rückgängig'));
      await tester.pumpAndSettle();
      expect(api.named('task_undo').single.params, {
        'p_actor': _emma,
        'p_instance_id': 'i-tisch',
      });
      await tester.pump(const Duration(seconds: 6));
      await unmountApp(tester, container);
    },
  );

  testWidgets('a reward Emma cannot afford says how far to go, kindly', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _TickingApi(),
    );
    await _pickEmma(tester);

    await tester.tap(find.text('Punkte'));
    await tester.pumpAndSettle();

    expect(find.text('Noch 38 Punkte'), findsOneWidget);
    expect(find.text('Film aussuchen'), findsOneWidget);
    // The cheap one is affordable and offers to be redeemed.
    expect(find.text('Einlösen'), findsOneWidget);
    // A6: the kid "Einlösen" button's actual rendered hit area is >=56x56
    // logical px, not just a nominal minimumSize that density then shrinks.
    final redeemButton = find.ancestor(
      of: find.text('Einlösen'),
      matching: find.byType(FilledButton),
    );
    final redeemSize = tester.getSize(redeemButton);
    expect(redeemSize.width, greaterThanOrEqualTo(56));
    expect(redeemSize.height, greaterThanOrEqualTo(56));
    await unmountApp(tester, container);
  });

  testWidgets('Punkte shows only the acting child’s balance', (tester) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _TickingApi(),
    );
    await _pickEmma(tester);

    await tester.tap(find.text('Punkte'));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('37'), findsNothing);
    await unmountApp(tester, container);
  });

  testWidgets('Familie shows presence and open counts, never points', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _TickingApi(),
      board: FakeBoardRepository(_familyBoard()),
    );

    // Family opens without an acting child.
    await tester.tap(find.text('Familie'));
    await tester.pumpAndSettle();

    expect(find.text('1 Aufgabe offen'), findsNWidgets(2));
    expect(find.text('12'), findsNothing);
    expect(find.text('37'), findsNothing);
    expect(find.byType(PointsCoin), findsNothing);
    await unmountApp(tester, container);
  });

  testWidgets('completing works with reduced motion, without a flying coin', (
    tester,
  ) async {
    // pumpApp runs with reduced motion, as a child with the setting on would.
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _TickingApi(),
    );
    await _pickEmma(tester);

    await tester.tap(find.text('Tisch decken'));
    await tester.pump();

    expect(find.text('+3'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('15'), findsOneWidget);
    // Let the five-second undo bar expire before the test ends.
    await tester.pump(const Duration(seconds: 6));
    await unmountApp(tester, container);
  });

  // A11y polish (audit t_d7ce38d4, A10): what a screen reader hears on the kid's day.
  testWidgets('the task title is read once, on the card', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _TickingApi(),
    );
    await _pickEmma(tester);
    expect(find.bySemanticsLabel(RegExp(r'^Tisch decken')), findsOneWidget);
    await unmountApp(tester, container);
    handle.dispose();
  });

  testWidgets(
    'the greeting has no stray initial and the balance has its unit',
    (tester) async {
      final handle = tester.ensureSemantics();
      final container = await pumpApp(
        tester,
        overrides: baseOverrides(identity: _KidIdentity()),
        tasks: _TickingApi(),
      );
      await _pickEmma(tester);
      expect(find.bySemanticsLabel('E'), findsNothing);
      expect(find.bySemanticsLabel('12 Punkte'), findsOneWidget);
      await unmountApp(tester, container);
      handle.dispose();
    },
  );

  testWidgets('kid section titles are headers', (tester) async {
    final handle = tester.ensureSemantics();
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _TickingApi(),
    );
    await _pickEmma(tester);
    final node = tester.getSemantics(find.text('Meine Aufgaben'));
    expect(node.flagsCollection.isHeader, isTrue);
    await unmountApp(tester, container);
    handle.dispose();
  });
}
