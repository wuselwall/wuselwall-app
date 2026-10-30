import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/ui/edge_fade.dart';
import 'package:wuselwall/core/wusel/wusel_stage.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/details/task_board_detail.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/tasks/application/task_defaults.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_editor.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';
import 'package:wuselwall/features/wusel/ui/wusel_lines.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

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
  Size size = const Size(1000, 1600),
}) async {
  final container = await pumpApp(
    t,
    size: size,
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

/// The chore editor alone, in German, for [members].
Future<void> _pumpEditor(
  WidgetTester t,
  List<Member> members, {
  TaskDefinition? existing,
}) async {
  await t.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.adult, Shade.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: TaskEditorDialog(
          members: members,
          defaults: const TaskDefaults.curated(),
          existing: existing,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

bool _chosen(WidgetTester t, String label) =>
    t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

void main() {
  test('a tick on a chore that needs a check waits, before and after the '
      'server has it', () {
    TaskInstance chore(String status, {bool verification = true}) =>
        TaskInstance.fromJson(
          instanceRow(
            id: 'i',
            title: 'Zimmer aufräumen',
            status: status,
            verification: verification,
          ),
        );
    // Ticked here and on its way (Today's rows show only open chores).
    expect(awaitsCheckShown(true, chore('open')), isTrue);
    expect(awaitsCheckShown(true, chore('done')), isTrue);
    expect(awaitsCheckShown(true, chore('verified')), isFalse);
    expect(awaitsCheckShown(true, chore('done', verification: false)), isFalse);
    expect(awaitsCheckShown(false, chore('open')), isFalse);
  });

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

    testWidgets('a tick shows before the server answers', (t) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(id: 'i-1', title: 'Tisch decken', assignee: kidId),
          ],
        },
      );
      final hold = api.holds['task_complete'] = Completer<void>();
      await pumpTasks(t, api);

      await t.tap(find.byTooltip('Abhaken'));
      await t.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byTooltip('Erledigt'), findsOneWidget);
      // A second tap while the first is on its way sends nothing more.
      await t.tap(find.byIcon(Icons.check_circle), warnIfMissed: false);
      await t.pump();
      expect(api.named('task_complete'), hasLength(1));

      hold.complete();
      await t.pumpAndSettle();
      expect(find.text('Tisch decken erledigt'), findsOneWidget);
      // The snackbar has an action, and still closes by itself.
      await t.pump(const Duration(seconds: 6));
      await t.pumpAndSettle();
      expect(find.text('Tisch decken erledigt'), findsNothing);
    });

    testWidgets('a tick the server refuses rolls back', (t) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(id: 'i-1', title: 'Tisch decken', assignee: kidId),
          ],
        },
      );
      api.failures['task_complete'] = const NotFoundFailure(
        code: 'task_complete',
      );
      final hold = api.holds['task_complete'] = Completer<void>();
      await pumpTasks(t, api);

      await t.tap(find.byTooltip('Abhaken'));
      await t.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      hold.complete();
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byTooltip('Abhaken'), findsOneWidget);
    });

    testWidgets('a chore waiting for a check is not shown as done', (t) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(
              id: 'i-1',
              title: 'Zimmer aufräumen',
              assignee: kidId,
              status: 'done',
              verification: true,
            ),
            instanceRow(
              id: 'i-2',
              title: 'Tisch decken',
              assignee: kidId,
              status: 'done',
            ),
          ],
        },
      );
      await pumpTasks(t, api);

      TextDecoration? decorationOf(String title) => t
          .widget<AnimatedDefaultTextStyle>(
            find
                .ancestor(
                  of: find.text(title),
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          )
          .style
          .decoration;
      // Waiting: an hourglass, the words, no strike-through.
      expect(decorationOf('Zimmer aufräumen'), TextDecoration.none);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(find.textContaining('wartet auf Freigabe'), findsOneWidget);
      // Done: the green tick and the strike-through.
      expect(decorationOf('Tisch decken'), TextDecoration.lineThrough);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('a chore\'s coin says what it counts', (t) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(
              id: 'i-1',
              title: 'Tisch decken',
              assignee: kidId,
              points: 2,
            ),
          ],
        },
      );
      await pumpTasks(t, api);
      // The unit on the coin, as the kid card says it.
      expect(find.text('2 Punkte'), findsOneWidget);
      expect(find.byTooltip('2 Punkte'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('2 Punkte')), findsOneWidget);
    });

    testWidgets('the tab bar fades where more tabs lie beyond it', (t) async {
      await pumpTasks(t, FakeTasksApi(), size: const Size(390, 844));
      final fade = find.ancestor(
        of: find.byType(TabBar),
        matching: find.byType(EdgeFade),
      );
      expect(fade, findsOneWidget);
      final state = t.state(fade) as dynamic;
      expect((state.fades as ({bool start, bool end})).end, isTrue);
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
    testWidgets('a title alone saves a daily chore that rotates among the '
        'children', (t) async {
      final api = FakeTasksApi(tables: {'task_instances': const []});
      await pumpTasks(t, api);

      await t.tap(find.widgetWithText(Tab, 'Aufgaben'));
      await t.pumpAndSettle();
      await t.tap(find.text('Neue Aufgabe'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).first, 'Blumen gießen');
      await tapIn(t, find.widgetWithText(FilledButton, 'Speichern'));

      final def =
          api.named('task_definition_save').single.params!['p_def']
              as Map<String, dynamic>;
      expect(def['title'], 'Blumen gießen');
      expect(def['rrule'], 'FREQ=DAILY');
      expect(def['assignment'], 'rotating');
      expect(def['assignee_profile_ids'], [kidId]);
    });

    testWidgets('the start date is one row that opens the date picker', (
      t,
    ) async {
      await _pumpEditor(t, testMembers);
      expect(find.text('Ab dem'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Ab dem'), findsNothing);
      await tapIn(t, find.byKey(const ValueKey('task-starts')));
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('without children a new chore is open for anyone', (t) async {
      final de = AppLocalizationsDe();
      await _pumpEditor(t, [testMembers.first]);
      expect(_chosen(t, de.tasksWhoOpen), isTrue);
      expect(_chosen(t, de.tasksRepeatDaily), isTrue);
    });

    testWidgets('an existing one-off chore keeps its repeat and its person', (
      t,
    ) async {
      final de = AppLocalizationsDe();
      await _pumpEditor(
        t,
        testMembers,
        existing: TaskDefinition(
          id: 'd-1',
          title: 'Keller',
          kind: TaskKind.duty,
          points: 1,
          startsOn: DateTime(2026, 10, 14),
          windowDays: 1,
          assignment: TaskAssignment.fixed,
          assigneeIds: const [guardianId],
          requiresVerification: false,
          isActive: true,
        ),
      );
      expect(_chosen(t, de.tasksRepeatOnce), isTrue);
      expect(_chosen(t, de.tasksWhoFixed), isTrue);
      expect(
        t.widget<FilterChip>(find.widgetWithText(FilterChip, 'Anna')).selected,
        isFalse,
      );
    });

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
      // Anna, the only child, is in the pool already.
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

    testWidgets('a grown-up sees the catalogue: no request, no shortfall', (
      t,
    ) async {
      final api = FakeTasksApi(
        tables: {
          ...requests,
          'point_balances': [
            {'profile_id': guardianId, 'balance': 0},
            {'profile_id': kidId, 'balance': 2},
          ],
        },
      );
      await pumpTasks(t, api);
      await t.tap(find.widgetWithText(Tab, 'Belohnungen'));
      await t.pumpAndSettle();

      expect(find.text('Samstagsfilm aussuchen'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, 'Wünschen'), findsNothing);
      expect(find.textContaining('fehlen'), findsNothing);
    });

    testWidgets('a child on a shared device asks and sees what is missing', (
      t,
    ) async {
      final api = FakeTasksApi(
        tables: {
          ...requests,
          'point_balances': [
            {'profile_id': kidId, 'balance': 2},
          ],
        },
      );
      final container = await pumpTasks(
        t,
        api,
        identity: FakeIdentityRepository(
          current: device(deviceClass: DeviceClass.shared),
        ),
      );
      container.read(actingProfileProvider.notifier).select(kidId);
      await t.pump();
      await t.tap(find.widgetWithText(Tab, 'Belohnungen'));
      await t.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Wünschen'), findsOneWidget);
      expect(find.text('3 Punkte fehlen'), findsOneWidget);
    });

    testWidgets('a reward title keeps the width of its card at 390', (t) async {
      final api = FakeTasksApi(tables: requests);
      await pumpTasks(t, api, size: const Size(390, 844));
      await tapIn(t, find.widgetWithText(Tab, 'Belohnungen'));
      final title = find
          .descendant(
            of: find.byType(Card),
            matching: find.text('Samstagsfilm aussuchen'),
          )
          .first;
      // Not squeezed beside the coin and a button into a ~110 px column, where
      // "Samstagsfilm" broke into "Samstagsfil / m".
      expect(t.getSize(title).width, greaterThan(220));
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
      // The streak is a flame picture and the count, not one text.
      expect(
        find.descendant(
          of: find.byType(StreakBadge),
          matching: find.text('12'),
        ),
        findsOneWidget,
      );
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

  testWidgets(
    'Wusel cheers for 4 s when a member ticks their last chore on the wall',
    (t) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(id: 'i-1', title: 'Tisch decken', assignee: kidId),
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

      final de = lookupAppLocalizations(const Locale('de'));
      final lines = WuselLines.variants(
        de,
        WuselMoment.wallMemberDone,
        name: 'Anna',
      );
      final line = find.descendant(
        of: find.byType(TaskBoardDetailBody),
        matching: find.byWidgetPredicate(
          (w) => w is Text && lines.contains(w.data),
        ),
      );
      final cheer = find.descendant(
        of: find.byType(TaskBoardDetailBody),
        matching: find.byType(WuselSays),
      );
      expect(line, findsNothing);

      // The server now has the chore ticked; the board refetches after the tick.
      api.tables['task_instances'] = [
        instanceRow(
          id: 'i-1',
          title: 'Tisch decken',
          assignee: kidId,
          status: 'done',
          completedBy: kidId,
        ),
      ];
      container.read(actingProfileProvider.notifier).select(kidId);
      await t.pump();
      await t.tap(find.text('Tisch decken'));
      await t.pumpAndSettle();
      expect(cheer, findsOneWidget);
      expect(line, findsOneWidget);

      // The moment passes; the line stays, plain.
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
      expect(cheer, findsNothing);
      expect(line, findsOneWidget);
      await unmountApp(t, container);
    },
  );

  testWidgets(
    'a lively wall sends its corner Wusel over to the column, and back',
    (t) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(id: 'i-1', title: 'Tisch decken', assignee: kidId),
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
      api.tables['task_instances'] = [
        instanceRow(
          id: 'i-1',
          title: 'Tisch decken',
          assignee: kidId,
          status: 'done',
          completedBy: kidId,
        ),
      ];
      container.read(actingProfileProvider.notifier).select(kidId);
      await t.pump();
      // Motion on: pumpApp holds everything still otherwise.
      t.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await t.pump();

      await t.tap(find.text('Tisch decken'));
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      final stage = t.state<WuselStageState>(find.byType(WuselStage));
      final trip = stage.trip;
      expect(trip, isNotNull);
      // The one Wusel is the corner's, travelling: no second one in the column.
      expect(
        find.descendant(
          of: find.byType(TaskBoardDetailBody),
          matching: find.byType(WuselSays),
        ),
        findsNothing,
      );
      var done = false;
      unawaited(trip!.done.then((_) => done = true));
      for (var i = 0; i < 600 && !done; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(done, isTrue);
      expect(stage.trip, isNull);
      await t.pump(const Duration(seconds: 1));
      await unmountApp(t, container);
    },
  );

  testWidgets(
    'a chore ticked before the board opens shows its tick at rest; a new tick pops',
    (t) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(
              id: 'i-1',
              title: 'Tisch decken',
              assignee: kidId,
              status: 'done',
              completedBy: kidId,
            ),
            instanceRow(id: 'i-2', title: 'Brot holen', assignee: kidId),
            instanceRow(id: 'i-3', title: 'Blumen giessen', assignee: kidId),
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
      // Motion on: pumpApp holds everything still otherwise.
      t.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await t.pump();
      // The tick's own ScaleTransition, not the page route's around it.
      List<double> ticks() => t
          .widgetList<ScaleTransition>(
            find.byWidgetPredicate(
              (w) =>
                  w is ScaleTransition &&
                  w.child is Icon &&
                  (w.child! as Icon).icon == Icons.check_circle,
            ),
          )
          .map((s) => s.scale.value)
          .toList();

      await t.tap(find.text('Heute offen'));
      await t.pump();
      for (var i = 0; i < 60; i++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(ticks(), everyElement(1.0));
      }
      expect(ticks(), hasLength(1));

      api.tables['task_instances'] = [
        ...api.tables['task_instances']!.take(1),
        instanceRow(
          id: 'i-2',
          title: 'Brot holen',
          assignee: kidId,
          status: 'done',
          completedBy: kidId,
        ),
        instanceRow(id: 'i-3', title: 'Blumen giessen', assignee: kidId),
      ];
      container.read(actingProfileProvider.notifier).select(kidId);
      await t.pump();
      await t.tap(find.text('Brot holen'));
      var popped = false;
      for (var i = 0; i < 30 && !popped; i++) {
        await t.pump(const Duration(milliseconds: 16));
        final now = ticks();
        popped = now.length == 2 && now.any((s) => s < 1);
      }
      expect(popped, isTrue);
      await t.pump(const Duration(seconds: 1));
      expect(ticks(), everyElement(closeTo(1.0, 0.01)));
      await unmountApp(t, container);
    },
  );

  testWidgets('a column that opens already done does not cheer', (t) async {
    final api = FakeTasksApi(
      tables: {
        'task_instances': [
          instanceRow(
            id: 'i-1',
            title: 'Tisch decken',
            assignee: kidId,
            status: 'done',
            completedBy: kidId,
          ),
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
    expect(
      find.descendant(
        of: find.byType(TaskBoardDetailBody),
        matching: find.byType(WuselSays),
      ),
      findsNothing,
    );
    // The line is there, as text.
    final de = lookupAppLocalizations(const Locale('de'));
    final lines = WuselLines.variants(
      de,
      WuselMoment.wallMemberDone,
      name: 'Anna',
    );
    expect(
      find.byWidgetPredicate((w) => w is Text && lines.contains(w.data)),
      findsOneWidget,
    );
    await unmountApp(t, container);
  });
}
