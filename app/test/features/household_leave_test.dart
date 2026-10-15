import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/household/ui/deleted_family_page.dart';
import 'package:wuselwall/features/household/ui/new_family_page.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

import '../support/fakes.dart';

/// The account of the test family "Huser", as `api.my_account()` reports it for a guardian
/// with a phone. Override the fields a test is about.
Account account({
  bool hasHousehold = true,
  String? leaveBlocked,
  DeletedHousehold? deleted,
}) => Account(
  userId: 'user-1',
  email: 'daniel@example.org',
  hasHousehold: hasHousehold,
  householdId: hasHousehold ? 'h1' : null,
  profileId: hasHousehold ? guardianId : null,
  creation: HouseholdCreation.code,
  householdName: hasHousehold ? 'Huser' : null,
  leaveBlocked: leaveBlocked,
  deletedHousehold: deleted,
);

final leaveTile = find.byKey(const ValueKey('leave-family'));
final deleteTile = find.byKey(const ValueKey('delete-family'));

void main() {
  group('leaving a family (Konto)', () {
    Future<
      ({
        ProviderContainer container,
        FakeIdentityRepository identity,
        FakeHouseholdLeaveRepository leave,
      })
    >
    pumpSettings(
      WidgetTester t, {
      required DeviceInfo device,
      Account? acc,
    }) async {
      final identity = FakeIdentityRepository(current: device);
      final leave = FakeHouseholdLeaveRepository();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          leave: leave,
          household: FakeHouseholdOnboardingRepository(
            identity: identity,
            accountValue: acc ?? account(),
          ),
        ),
      );
      container.read(routerProvider).go(Routes.settings);
      await t.pumpAndSettle();
      return (container: container, identity: identity, leave: leave);
    }

    testWidgets('an adult on a personal phone leaves after a confirmation', (
      t,
    ) async {
      final s = await pumpSettings(t, device: device());
      expect(find.text('Familie verlassen'), findsOneWidget);
      expect(
        find.text(
          'Dein Konto verlässt die Familie. Deine Geräte melden sich ab. Die Einträge bleiben bei der Familie; du kannst danach eine andere Familie gründen oder ihr beitreten.',
        ),
        findsOneWidget,
      );

      await t.ensureVisible(leaveTile);
      await t.tap(leaveTile);
      await t.pumpAndSettle();
      expect(find.text('Familie verlassen?'), findsOneWidget);
      expect(
        s.leave.leaves,
        isEmpty,
        reason: 'nothing happens before confirming',
      );

      await t.tap(find.text('Verlassen'));
      await t.pumpAndSettle();
      expect(s.leave.leaves, [guardianId]);
      await unmountApp(t, s.container);
    });

    testWidgets('cancelling the dialog leaves nothing', (t) async {
      final s = await pumpSettings(t, device: device());
      await t.ensureVisible(leaveTile);
      await t.tap(leaveTile);
      await t.pumpAndSettle();
      await t.tap(find.text('Abbrechen'));
      await t.pumpAndSettle();
      expect(s.leave.leaves, isEmpty);
      await unmountApp(t, s.container);
    });

    testWidgets(
      'the last guardian with an account cannot leave, and is told why',
      (t) async {
        final s = await pumpSettings(
          t,
          device: device(),
          acc: account(leaveBlocked: 'last_guardian'),
        );
        expect(
          find.text(
            'Lade zuerst eine zweite erwachsene Person ein oder lösche die Familie.',
          ),
          findsOneWidget,
        );
        final tile = t.widget<ListTile>(leaveTile);
        expect(tile.enabled, isFalse);
        await t.ensureVisible(leaveTile);
        await t.tap(leaveTile, warnIfMissed: false);
        await t.pumpAndSettle();
        expect(find.text('Familie verlassen?'), findsNothing);
        expect(s.leave.leaves, isEmpty);
        await unmountApp(t, s.container);
      },
    );

    testWidgets('a child, a kiosk and a shared tablet do not see it', (
      t,
    ) async {
      final child = await pumpSettings(
        t,
        device: device(profileId: kidId, register: UiRegister.kid),
      );
      expect(leaveTile, findsNothing);
      await unmountApp(t, child.container);

      final kiosk = await pumpSettings(
        t,
        device: device(
          deviceClass: DeviceClass.kiosk,
          register: UiRegister.kiosk,
        ),
      );
      expect(leaveTile, findsNothing);
      await unmountApp(t, kiosk.container);
    });

    testWidgets('a refused leave shows the reason and stays in the family', (
      t,
    ) async {
      final s = await pumpSettings(t, device: device());
      s.leave.leaveResult = const Err(PermissionFailure(code: 'last_guardian'));
      await t.ensureVisible(leaveTile);
      await t.tap(leaveTile);
      await t.pumpAndSettle();
      await t.tap(find.text('Verlassen'));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Lade zuerst eine zweite erwachsene Person ein oder lösche die Familie.',
        ),
        findsWidgets,
      );
      await unmountApp(t, s.container);
    });
  });

  group('deleting a family (Familie)', () {
    Future<
      ({
        ProviderContainer container,
        FakeIdentityRepository identity,
        FakeHouseholdLeaveRepository leave,
      })
    >
    pumpSettings(WidgetTester t, {required DeviceInfo device}) async {
      final identity = FakeIdentityRepository(current: device);
      final leave = FakeHouseholdLeaveRepository();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          leave: leave,
          household: FakeHouseholdOnboardingRepository(
            identity: identity,
            accountValue: account(),
          ),
        ),
      );
      container.read(routerProvider).go(Routes.settings);
      await t.pumpAndSettle();
      return (container: container, identity: identity, leave: leave);
    }

    FilledButton confirmButton(WidgetTester t) => t.widget<FilledButton>(
      find.byKey(const ValueKey('delete-family-confirm')),
    );

    testWidgets(
      'a guardian on a personal phone sees the delete action in Familie',
      (t) async {
        final s = await pumpSettings(t, device: device());
        expect(find.text('Familie löschen'), findsOneWidget);
        expect(
          find.text(
            'Alle Geräte melden sich sofort ab. 14 Tage lang kann eine Elternperson die Familie wiederherstellen, danach werden alle Daten endgültig gelöscht.',
          ),
          findsOneWidget,
        );
        await unmountApp(t, s.container);
      },
    );

    testWidgets('a child on a personal phone does not see it', (t) async {
      final s = await pumpSettings(
        t,
        device: device(profileId: kidId, register: UiRegister.kid),
      );
      expect(deleteTile, findsNothing);
      await unmountApp(t, s.container);
    });

    testWidgets(
      'the confirm button stays off until the name is typed, trimmed and in any case',
      (t) async {
        final s = await pumpSettings(t, device: device());
        await t.ensureVisible(deleteTile);
        await t.tap(deleteTile);
        await t.pumpAndSettle();
        expect(find.text('Familie löschen?'), findsOneWidget);
        expect(confirmButton(t).onPressed, isNull);

        await t.enterText(
          find.byKey(const ValueKey('delete-family-name')),
          'Huse',
        );
        await t.pump();
        expect(
          confirmButton(t).onPressed,
          isNull,
          reason: 'a partial name is no match',
        );

        await t.enterText(
          find.byKey(const ValueKey('delete-family-name')),
          '  hUSER ',
        );
        await t.pump();
        expect(confirmButton(t).onPressed, isNotNull);
        await unmountApp(t, s.container);
      },
    );

    testWidgets(
      'a confirmed delete sends the typed name, then signs this phone out',
      (t) async {
        final s = await pumpSettings(t, device: device());
        await t.ensureVisible(deleteTile);
        await t.tap(deleteTile);
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('delete-family-name')),
          '  hUSER ',
        );
        await t.pump();
        await t.tap(find.byKey(const ValueKey('delete-family-confirm')));
        await t.pumpAndSettle();

        expect(s.leave.deletes, [
          (profileId: guardianId, confirmName: 'hUSER'),
        ]);
        expect(s.identity.signedOut, isTrue);
        await unmountApp(t, s.container);
      },
    );

    testWidgets('a refused delete shows the failure and does not sign out', (
      t,
    ) async {
      final s = await pumpSettings(t, device: device());
      s.leave.deleteResult = const Err(
        ValidationFailure(code: 'confirm_name_mismatch'),
      );
      await t.ensureVisible(deleteTile);
      await t.tap(deleteTile);
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('delete-family-name')),
        'Huser',
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('delete-family-confirm')));
      await t.pumpAndSettle();
      expect(find.text('Der Name stimmt nicht.'), findsOneWidget);
      expect(s.identity.signedOut, isFalse);
      await unmountApp(t, s.container);
    });
  });

  group('a deleted family (the account signs in)', () {
    final deletedAt = DateTime.utc(2026, 10, 15, 9);
    DeletedHousehold deleted({required bool canRestore}) => DeletedHousehold(
      id: 'h1',
      name: 'Huser',
      deletedAt: deletedAt,
      purgeAfter: deletedAt.add(const Duration(days: 14)),
      canRestore: canRestore,
    );

    Future<({ProviderContainer container, FakeHouseholdLeaveRepository leave})>
    pumpSignIn(WidgetTester t, {required Account acc}) async {
      final identity = FakeIdentityRepository();
      final leave = FakeHouseholdLeaveRepository();
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          leave: leave,
          household: FakeHouseholdOnboardingRepository(
            identity: identity,
            accountValue: acc,
          ),
        ),
      );
      return (container: container, leave: leave);
    }

    testWidgets('a guardian sees the date and may restore the family', (
      t,
    ) async {
      final s = await pumpSignIn(
        t,
        acc: account(hasHousehold: false, deleted: deleted(canRestore: true)),
      );
      expect(find.byType(DeletedFamilyPage), findsOneWidget);
      expect(find.textContaining('Huser wird am'), findsOneWidget);
      expect(find.textContaining('endgültig gelöscht'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('deleted-restore')));
      await t.pumpAndSettle();
      expect(s.leave.restores, 1);
      await unmountApp(t, s.container);
    });

    testWidgets('a member cannot restore, but may start afresh', (t) async {
      final s = await pumpSignIn(
        t,
        acc: account(hasHousehold: false, deleted: deleted(canRestore: false)),
      );
      expect(find.byType(DeletedFamilyPage), findsOneWidget);
      expect(find.byKey(const ValueKey('deleted-restore')), findsNothing);
      expect(
        find.text(
          'Nur eine Elternperson kann die Familie wiederherstellen. Du kannst auch neu anfangen; dann verlässt dein Konto diese Familie.',
        ),
        findsOneWidget,
      );

      await t.tap(find.byKey(const ValueKey('deleted-start-afresh')));
      await t.pumpAndSettle();
      expect(s.leave.startAfreshes, 1);
      await unmountApp(t, s.container);
    });

    testWidgets(
      'an account in no deleted family starts a family (H1), not this page',
      (t) async {
        final s = await pumpSignIn(t, acc: account(hasHousehold: false));
        expect(find.byType(NewFamilyPage), findsOneWidget);
        expect(find.byType(DeletedFamilyPage), findsNothing);
        await unmountApp(t, s.container);
      },
    );

    testWidgets(
      'a phone revoked by leaving starts a family afresh, not a sign-out',
      (t) async {
        final identity = FakeIdentityRepository(
          current: DeviceInfo(
            deviceId: 'd1',
            householdId: 'h1',
            label: 'x',
            deviceClass: DeviceClass.personal,
            register: UiRegister.adult,
            profileId: guardianId,
            revoked: true,
            guardianVerifiedUntil: null,
          ),
        );
        final container = await pumpApp(
          t,
          overrides: baseOverrides(
            identity: identity,
            household: FakeHouseholdOnboardingRepository(
              identity: identity,
              accountValue: account(hasHousehold: false),
            ),
          ),
        );
        expect(identity.signedOut, isFalse);
        expect(find.byType(NewFamilyPage), findsOneWidget);
        await unmountApp(t, container);
      },
    );

    test('the account reads the deleted family and the leave block', () {
      final parsed = Account.fromJson({
        'user_id': 'u',
        'has_household': false,
        'household_name': null,
        'leave_blocked': null,
        'deleted_household': {
          'id': 'h1',
          'name': 'Huser',
          'deleted_at': '2026-10-15T09:00:00Z',
          'purge_after': '2026-10-29T09:00:00Z',
          'can_restore': true,
        },
      });
      expect(parsed.hasHousehold, isFalse);
      expect(parsed.deletedHousehold?.name, 'Huser');
      expect(parsed.deletedHousehold?.canRestore, isTrue);
      expect(
        parsed.deletedHousehold?.purgeAfter,
        DateTime.utc(2026, 10, 29, 9),
      );

      final live = Account.fromJson({
        'user_id': 'u',
        'has_household': true,
        'household_name': 'Huser',
        'leave_blocked': 'last_guardian',
        'deleted_household': null,
      });
      expect(live.householdName, 'Huser');
      expect(live.leaveBlocked, 'last_guardian');
      expect(live.deletedHousehold, isNull);
    });
  });
}
