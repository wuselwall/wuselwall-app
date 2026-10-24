import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';

final _de = AppLocalizationsDe();

const _memberId = 'p-member';

/// The test household plus an adult without guardian rights (an au pair).
final _withMember = [
  ...testMembers,
  const Member(
    id: _memberId,
    displayName: 'Julia',
    color: Color(0xFF3366CC),
    role: Role.member,
    active: true,
  ),
];

/// Two ticked chores that wait for a check and one reward request, as the views return
/// them. The fake `api` ignores filters, so `task_instances` holds only the checks.
FakeTasksApi _pending() => FakeTasksApi(
  tables: {
    'task_instances': [
      instanceRow(
        id: 'i-1',
        title: 'Zimmer aufräumen',
        assignee: kidId,
        status: 'done',
        verification: true,
        completedBy: kidId,
      ),
      instanceRow(
        id: 'i-2',
        title: 'Tisch decken',
        assignee: kidId,
        status: 'done',
        verification: true,
        completedBy: kidId,
      ),
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
      // Decided requests do not count.
      {
        'id': 'rd-2',
        'reward_id': 'r-movie',
        'profile_id': kidId,
        'cost_points': 5,
        'status': 'fulfilled',
        'requested_at': '2026-10-13T07:00:00Z',
      },
    ],
  },
);

/// The badge on the Tasks destination of the navigation bar, if any shows.
Finder _tasksBadge() => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byWidgetPredicate((w) => w is Badge && w.isLabelVisible),
);

void main() {
  testWidgets('a guardian sees one card with both counts and the badge', (
    t,
  ) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      tasks: _pending(),
    );

    expect(find.text(_de.todayApprovalsTitle), findsOneWidget);
    expect(
      find.text(
        '${_de.todayApprovalsChecks(2)} · ${_de.todayApprovalsRequests(1)}',
      ),
      findsOneWidget,
    );
    // Not a notice to wave away: it has no "Gesehen".
    expect(find.text(_de.todayNoticeDismiss), findsNothing);
    expect(_tasksBadge(), findsOneWidget);
    expect(
      find.descendant(of: _tasksBadge(), matching: find.text('3')),
      findsOneWidget,
    );
  });

  testWidgets('a member sees neither the card nor the badge', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(
          current: device(profileId: _memberId),
          members: _withMember,
        ),
      ),
      tasks: _pending(),
    );

    expect(find.text(_de.todayApprovalsTitle), findsNothing);
    expect(_tasksBadge(), findsNothing);
  });

  testWidgets('the kids and the wall never see it', (t) async {
    for (final register in [UiRegister.kid, UiRegister.kiosk]) {
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(
            current: device(
              deviceClass: register == UiRegister.kid
                  ? DeviceClass.shared
                  : DeviceClass.kiosk,
              register: register,
              profileId: null,
            ),
          ),
        ),
        tasks: _pending(),
      );
      expect(find.text(_de.todayApprovalsTitle), findsNothing);
      await unmountApp(t, container);
    }
  });

  testWidgets('the card follows the counts and goes once all is decided', (
    t,
  ) async {
    final api = _pending();
    final container = await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      tasks: api,
    );

    // The chores are checked: only the reward request is left.
    api.tables['task_instances'] = const [];
    invalidateTasks(container.invalidate);
    await t.pumpAndSettle();
    expect(find.text(_de.todayApprovalsRequests(1)), findsOneWidget);
    expect(
      find.descendant(of: _tasksBadge(), matching: find.text('1')),
      findsOneWidget,
    );

    // And the request is decided: nothing waits any more.
    api.tables['reward_redemptions'] = const [];
    invalidateTasks(container.invalidate);
    await t.pumpAndSettle();
    expect(find.text(_de.todayApprovalsTitle), findsNothing);
    expect(_tasksBadge(), findsNothing);
  });

  testWidgets('a tap opens Aufgaben on Freigaben', (t) async {
    await pumpApp(
      t,
      overrides: baseOverrides(
        identity: FakeIdentityRepository(current: device()),
      ),
      tasks: _pending(),
    );

    await t.tap(find.text(_de.todayApprovalsTitle));
    await t.pumpAndSettle();

    final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 3);
    // The Freigaben segment's own headings, not the Heute segment.
    expect(find.text(_de.tasksCheckChores), findsOneWidget);
    expect(find.text(_de.tasksRewardRequests), findsOneWidget);
    expect(find.text('Zimmer aufräumen'), findsOneWidget);
  });

  for (final locale in const [
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('es'),
  ]) {
    testWidgets('the card fits a 390dp phone at text scale 1.5 '
        '(${locale.languageCode})', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final l10n = lookupAppLocalizations(locale);
      await pumpApp(
        t,
        locale: locale,
        size: const Size(390, 844),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(current: device()),
        ),
        tasks: _pending(),
      );

      final title = find.text(l10n.todayApprovalsTitle);
      final counts = find.text(
        '${l10n.todayApprovalsChecks(2)} · ${l10n.todayApprovalsRequests(1)}',
      );
      expect(title, findsOneWidget);
      expect(counts, findsOneWidget);
      expect(t.getSize(title).width, greaterThan(150));
      expect(
        t.getRect(counts).top,
        greaterThanOrEqualTo(t.getRect(title).bottom - 1),
      );
      expect(t.takeException(), isNull);
    });
  }
}
