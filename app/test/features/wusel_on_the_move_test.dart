import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/core/wusel/wusel_stage.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';

const _emma = 'p-emma';

const _members = [
  Member(
    id: _emma,
    displayName: 'Emma',
    color: Color(0xFFB5306B),
    role: Role.member,
    active: true,
    isChild: true,
  ),
  Member(
    id: 'p-papa',
    displayName: 'Papa',
    color: Color(0xFF1D4E89),
    role: Role.guardian,
    active: true,
  ),
];

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
      Ok(_members);
}

/// Emma's chores; a tick credits three points and raises her balance.
class _Chores extends FakeTasksApi {
  _Chores({bool two = true})
    : super(
        tables: {
          'task_instances': [
            instanceRow(
              id: 'i-tisch',
              title: 'Tisch decken',
              assignee: _emma,
              points: 3,
            ),
            if (two)
              instanceRow(
                id: 'i-blumen',
                title: 'Blumen gießen',
                assignee: _emma,
                points: 2,
              ),
          ],
          'point_balances': [
            {'profile_id': _emma, 'balance': 12},
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
      ];
    }
    return super.rpc(fn, params: params, parse: parse);
  }
}

/// Opens Emma's day on the kid tablet, then lets things move: pumpApp holds every
/// animation still, which is the one thing this test is about.
Future<void> _openEmma(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('kid-pick-$_emma')));
  await tester.pumpAndSettle();
  tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  await tester.pump();
  // The greeting's wave has played.
  await _frames(tester, const Duration(seconds: 3));
}

Future<void> _frames(WidgetTester tester, Duration span) async {
  for (var t = Duration.zero; t < span; t += const Duration(milliseconds: 16)) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

WuselStageState _stage(WidgetTester tester) =>
    tester.state<WuselStageState>(find.byType(WuselStage));

Finder _greetingWusel() => find.descendant(
  of: find.byKey(const ValueKey('kid-greeting')),
  matching: find.byType(Wusel),
);

double _homeOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(
        of: find.byType(WuselHome),
        matching: find.byType(Opacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('a tick sends Wusel to the card, and it carries the coin home', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _Chores(),
    );
    await _openEmma(tester);
    expect(find.byType(WuselHome), findsOneWidget);

    await tester.tap(find.text('Tisch decken'));
    final trip = _stage(tester).trip;
    expect(trip, isNotNull);
    await tester.pump();
    expect(_homeOpacity(tester), 0);
    // The server has credited the points, but the pill waits for Wusel's coin.
    await _frames(tester, const Duration(milliseconds: 200));
    expect(find.text('12'), findsOneWidget);

    var sawCoin = false;
    var done = false;
    unawaited(trip!.done.then((_) => done = true));
    for (var i = 0; i < 250 && !(done && sawCoin); i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('+3').evaluate().isNotEmpty) sawCoin = true;
    }
    expect(done, isTrue);
    // The coin drops from Wusel's hand into the balance once Wusel is home.
    expect(sawCoin, isTrue);
    expect(_homeOpacity(tester), 1);
    await _frames(tester, const Duration(seconds: 1));
    expect(find.text('15'), findsOneWidget);
    // Home: the afterglow has begun.
    expect(_stage(tester).afterglow.value, isTrue);

    await tester.pump(const Duration(seconds: 6));
    await unmountApp(tester, container);
  });

  testWidgets('the last chore: a jump, the cheer at home, and no second Wusel', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _Chores(two: false),
    );
    await _openEmma(tester);

    await tester.tap(find.text('Tisch decken'));
    // The all-done card takes the list's top, so Wusel sets off for it once it
    // is built, a frame later.
    await tester.pump();
    final trip = _stage(tester).trip;
    expect(trip, isNotNull);
    var arrived = false;
    unawaited(trip!.arrived.then((_) => arrived = true));
    for (var i = 0; i < 120 && !arrived; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(arrived, isTrue);
    final allDone = tester.getRect(
      find.ancestor(
        of: find.text('Alles geschafft!'),
        matching: find.byType(KidCard),
      ),
    );
    expect(trip.position.dy, lessThan(allDone.top));
    expect(trip.position.dy, greaterThan(allDone.top - 88));
    await _frames(tester, const Duration(seconds: 4));

    expect(find.text('Alles geschafft!'), findsOneWidget);
    // One Wusel on the screen: the greeting's, cheering.
    expect(find.byType(Wusel), findsOneWidget);
    expect(tester.widget<Wusel>(_greetingWusel()).pose, WuselPose.cheer);
    expect(_stage(tester).trip, isNull);

    await tester.pump(const Duration(seconds: 6));
    await unmountApp(tester, container);
  });

  testWidgets('under reduced motion Wusel stays at home', (tester) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _Chores(two: false),
    );
    await tester.tap(find.byKey(const ValueKey('kid-pick-$_emma')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tisch decken'));
    expect(_stage(tester).trip, isNull);
    await tester.pumpAndSettle();
    // The cheer still comes, held still, at home.
    expect(find.byType(Wusel), findsOneWidget);
    expect(tester.widget<Wusel>(_greetingWusel()).pose, WuselPose.cheer);

    await tester.pump(const Duration(seconds: 6));
    await unmountApp(tester, container);
  });

  testWidgets('back on Mein Tag from another tab, Wusel hops in', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      overrides: baseOverrides(identity: _KidIdentity()),
      tasks: _Chores(),
    );
    await _openEmma(tester);
    // The first open waves; nothing hopped in.
    expect(_stage(tester).trip, isNull);

    await tester.tap(find.text('Punkte'));
    await _frames(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Mein Tag'));
    await tester.pump();
    await tester.pump();
    expect(_stage(tester).trip, isNotNull);
    await _frames(tester, const Duration(seconds: 2));
    expect(_stage(tester).trip, isNull);
    expect(_homeOpacity(tester), 1);

    await unmountApp(tester, container);
  });
}
