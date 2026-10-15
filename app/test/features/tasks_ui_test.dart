import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/details/task_board_detail.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';

/// A board of today with the family in household order and open chores per member.
WeekBoard _kioskBoard() {
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
        'id': guardianId,
        'display_name': 'Papa',
        'color': '#2E7D6B',
        'kind': 'adult',
      },
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
          'date': ymd(monday.add(Duration(days: i))),
          'events': <Map<String, dynamic>>[],
          'busy_until': <Map<String, dynamic>>[],
          'school': <Map<String, dynamic>>[],
        },
    ],
    'open_tasks': [
      {'member_id': kidId, 'count': 2},
    ],
    'shopping_count': 0,
  });
}

Future<void> enterPin(WidgetTester t, String digits) async {
  for (final d in digits.split('')) {
    await t.tap(find.widgetWithText(OutlinedButton, d));
    await t.pump();
  }
  await t.pumpAndSettle();
}

/// The adult home on the tasks destination, with [api] behind the repository.
Future<ProviderContainer> pumpTasks(
  WidgetTester t,
  FakeTasksApi api, {
  FakeIdentityRepository? identity,
}) async {
  final container = await pumpApp(
    t,
    overrides: baseOverrides(
      identity: identity ?? FakeIdentityRepository(current: device()),
    ),
    tasks: api,
  );
  await t.tap(find.text('Aufgaben'));
  await t.pumpAndSettle();
  return container;
}

/// Scrolls the enclosing list to [finder] first: the editor's fields lie in a scroll view.
Future<void> tapIn(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  group('today', () {
    testWidgets('ticking a chore completes it as the acting profile', (
      t,
    ) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(id: 'i-1', title: 'Tisch decken', assignee: kidId),
          ],
        },
      );
      await pumpTasks(t, api);

      expect(find.text('Tisch decken'), findsOneWidget);
      await t.tap(find.byTooltip('Abhaken'));
      await t.pumpAndSettle();

      final call = api.named('task_complete').single;
      expect(call.params, {'p_actor': guardianId, 'p_instance_id': 'i-1'});
    });

    testWidgets('the snackbar undoes the tick with task_undo', (t) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(id: 'i-1', title: 'Tisch decken', assignee: kidId),
          ],
        },
      );
      await pumpTasks(t, api);

      await t.tap(find.byTooltip('Abhaken'));
      await t.pumpAndSettle();
      expect(find.text('Tisch decken erledigt'), findsOneWidget);

      await t.tap(find.text('Rückgängig'));
      await t.pumpAndSettle();
      expect(api.named('task_undo').single.params, {
        'p_actor': guardianId,
        'p_instance_id': 'i-1',
      });
    });

    testWidgets('a chore nobody has claimed is grouped under open for anyone', (
      t,
    ) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(
              id: 'i-2',
              title: 'Müll rausbringen',
              points: 5,
              kind: 'bonus',
            ),
          ],
        },
      );
      await pumpTasks(t, api);
      expect(find.text('Offen für alle'), findsOneWidget);
      expect(find.text('Müll rausbringen'), findsOneWidget);
    });
  });

  group('chore editor', () {
    testWidgets('a weekly Saturday chore is saved and then materialised', (
      t,
    ) async {
      final api = FakeTasksApi(tables: {'task_instances': const []});
      await pumpTasks(t, api);

      await t.tap(find.widgetWithText(Tab, 'Aufgaben'));
      await t.pumpAndSettle();
      await t.tap(find.text('Neue Aufgabe'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).first, 'Wäsche falten');
      await tapIn(t, find.widgetWithText(ChoiceChip, 'Wöchentlich'));
      // Weekly keeps one weekday: Saturday replaces the default Monday-of-today.
      await tapIn(t, find.widgetWithText(FilterChip, 'Sa'));
      await tapIn(t, find.widgetWithText(FilterChip, 'Anna'));
      await tapIn(t, find.widgetWithText(FilledButton, 'Speichern'));
      await t.pumpAndSettle();

      final save = api.named('task_definition_save').single;
      final def = save.params!['p_def'] as Map<String, dynamic>;
      expect(def['rrule'], 'FREQ=WEEKLY;BYDAY=SA');
      expect(def['title'], 'Wäsche falten');
      expect(def['assignee_profile_ids'], [kidId]);

      final materialise = api.named('fn:tasks-materialise');
      expect(materialise, hasLength(1));
      expect(
        api.calls.indexOf(materialise.single),
        greaterThan(api.calls.indexOf(save)),
        reason: 'the instances are made after the definition exists',
      );
    });
  });

  group('approvals', () {
    final pending = [
      instanceRow(
        id: 'i-9',
        title: 'Zimmer aufräumen',
        assignee: kidId,
        status: 'done',
        completedBy: kidId,
        verification: true,
        points: 2,
      ),
    ];
    final requests = {
      'rewards': [
        {
          'id': 'r-movie',
          'title': 'Samstagsfilm aussuchen',
          'cost_points': 5,
          'requires_approval': true,
          'is_active': true,
        },
      ],
      'reward_redemptions': [
        {
          'id': 'rd-1',
          'reward_id': 'r-movie',
          'profile_id': kidId,
          'cost_points': 5,
          'status': 'requested',
          'requested_at': '2026-10-14T07:00:00Z',
        },
      ],
    };

    testWidgets('a verification is approved with task_verify after the gate', (
      t,
    ) async {
      final api = FakeTasksApi(
        tables: {'task_instances': pending, ...requests},
      );
      await pumpTasks(t, api);

      await t.tap(find.widgetWithText(Tab, 'Freigaben'));
      await t.pumpAndSettle();
      expect(find.text('Zimmer aufräumen'), findsWidgets);
      await t.tap(find.widgetWithText(FilledButton, 'Freigeben').first);
      await t.pumpAndSettle();

      expect(api.named('task_verify').single.params, {
        'p_actor': guardianId,
        'p_instance_id': 'i-9',
        'p_approve': true,
      });
    });

    testWidgets('the approvals badge sits beside the label, not on it', (
      t,
    ) async {
      final api = FakeTasksApi(
        tables: {'task_instances': pending, ...requests},
      );
      await pumpTasks(t, api);

      final label = t.getRect(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Freigaben'),
        ),
      );
      final badge = t.getRect(
        find.descendant(of: find.byType(TabBar), matching: find.byType(Badge)),
      );
      expect(label.overlaps(badge), isFalse);
    });

    testWidgets('a declined reward request carries the note to reward_decide', (
      t,
    ) async {
      final api = FakeTasksApi(tables: requests);
      await pumpTasks(t, api);

      await t.tap(find.widgetWithText(Tab, 'Freigaben'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(OutlinedButton, 'Ablehnen'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Nicht diese Woche');
      await t.tap(find.widgetWithText(FilledButton, 'Ablehnen'));
      await t.pumpAndSettle();

      expect(api.named('reward_decide').single.params, {
        'p_actor': guardianId,
        'p_redemption_id': 'rd-1',
        'p_approve': false,
        'p_note': 'Nicht diese Woche',
      });
    });

    testWidgets('on a shared device the PIN is asked before reward_decide', (
      t,
    ) async {
      final api = FakeTasksApi(tables: requests);
      final identity =
          FakeIdentityRepository(
              current: device(deviceClass: DeviceClass.shared),
            )
            ..pinResult = PinVerified(
              DateTime.now().add(const Duration(minutes: 15)),
            );
      final container = await pumpTasks(t, api, identity: identity);
      container.read(actingProfileProvider.notifier).select(guardianId);
      await t.pump();

      await t.tap(find.widgetWithText(Tab, 'Freigaben'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Freigeben'));
      await t.pumpAndSettle();

      expect(find.text('PIN für Erziehungsberechtigte'), findsOneWidget);
      expect(api.named('reward_decide'), isEmpty);
      await enterPin(t, '123456');

      expect(identity.pinAttempts, ['123456']);
      expect(api.named('reward_decide').single.params, {
        'p_actor': guardianId,
        'p_redemption_id': 'rd-1',
        'p_approve': true,
        'p_note': null,
      });
    });
  });

  testWidgets('the points screen shows each balance and its ledger', (t) async {
    final api = FakeTasksApi(
      tables: {
        'point_balances': [
          {'profile_id': kidId, 'balance': 14},
        ],
        'point_transactions': [
          {
            'id': 'pt-1',
            'profile_id': kidId,
            'occurred_at': '2026-10-13T18:00:00Z',
            'amount': 2,
            'reason': 'task',
            'note': 'Tisch decken',
          },
        ],
      },
    );
    await pumpTasks(t, api);

    await t.tap(find.widgetWithText(Tab, 'Punkte'));
    await t.pumpAndSettle();
    expect(find.text('14'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.textContaining('Tisch decken'), findsOneWidget);
    // No ranking: the screen never states a position.
    expect(find.textContaining('Rang'), findsNothing);
  });

  testWidgets(
    'the kiosk board shows a column per member and ticks as the actor',
    (t) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(id: 'i-1', title: 'Tisch decken', assignee: kidId),
            instanceRow(id: 'i-2', title: 'Brot holen', assignee: guardianId),
          ],
          'streaks': [
            {
              'profile_id': kidId,
              'definition_id': 'd-1',
              'current_length': 12,
              'longest_length': 12,
            },
          ],
        },
      );
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(
            current: device(
              deviceClass: DeviceClass.kiosk,
              register: UiRegister.kiosk,
            ),
          ),
        ),
        board: FakeBoardRepository(_kioskBoard()),
        tasks: api,
      );

      await t.tap(find.text('Heute offen'));
      await t.pumpAndSettle();
      expect(find.byType(TaskBoardDetailBody), findsOneWidget);
      // Columns in household order, each with its member's name in the header.
      expect(find.text('Papa'), findsWidgets);
      expect(find.text('Anna'), findsWidgets);
      expect(find.text('🔥 12'), findsOneWidget);
      expect(find.text('Wer bist du?'), findsOneWidget);

      // Nobody is acting yet: the tick is not sent.
      await t.tap(find.text('Tisch decken'));
      await t.pumpAndSettle();
      expect(api.named('task_complete'), isEmpty);

      container.read(actingProfileProvider.notifier).select(kidId);
      await t.pump();
      await t.tap(find.text('Tisch decken'));
      await t.pumpAndSettle();

      expect(api.named('task_complete').single.params, {
        'p_actor': kidId,
        'p_instance_id': 'i-1',
      });
      await unmountApp(t, container);
    },
  );
}
