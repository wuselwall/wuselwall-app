import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/account/domain/member_security.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

import '../support/fakes.dart';

const mamaId = 'p-mama';

/// The account of the test family, as `api.my_account()` reports it for a guardian with a phone.
Account account({String? leaveBlocked}) => Account(
  userId: 'user-1',
  email: 'daniel@example.org',
  hasHousehold: true,
  householdId: 'h1',
  profileId: guardianId,
  creation: HouseholdCreation.code,
  householdName: 'Huser',
  leaveBlocked: leaveBlocked,
);

/// Papa (acting), Mama (a guardian with an account), Anna (a child).
final people = [
  testMembers.first,
  const Member(
    id: mamaId,
    displayName: 'Mama',
    color: Color(0xFF9A5300),
    role: Role.guardian,
    active: true,
  ),
  testMembers.last,
];

final deleteTile = find.byKey(const ValueKey('delete-account'));
final deleteConfirm = find.byKey(const ValueKey('delete-account-confirm'));
final reauthCode = find.byKey(const ValueKey('reauth-code'));

typedef Pumped = ({
  ProviderContainer container,
  FakeIdentityRepository identity,
  FakeAccountAdminRepository admin,
});

Future<Pumped> pumpSettings(
  WidgetTester t, {
  DeviceInfo? device,
  Account? acc,
  List<Member>? members,
  FakeAccountAdminRepository? admin,
  Size size = const Size(1000, 1600),
}) async {
  final identity = FakeIdentityRepository(
    current: device ?? testDevice(),
    members: members,
  );
  final accountAdmin = admin ?? FakeAccountAdminRepository();
  final container = await pumpApp(
    t,
    size: size,
    overrides: baseOverrides(
      identity: identity,
      accountAdmin: accountAdmin,
      household: FakeHouseholdOnboardingRepository(
        identity: identity,
        accountValue: acc ?? account(),
      ),
    ),
  );
  container.read(routerProvider).go(Routes.settings);
  await t.pumpAndSettle();
  return (container: container, identity: identity, admin: accountAdmin);
}

DeviceInfo testDevice({DeviceClass deviceClass = DeviceClass.personal}) =>
    device(deviceClass: deviceClass, register: UiRegister.adult);

void main() {
  group('deleting the account (Konto)', () {
    testWidgets(
      'the last guardian with an account cannot delete it, and is told why',
      (t) async {
        final s = await pumpSettings(
          t,
          acc: account(leaveBlocked: 'last_guardian'),
        );
        await t.ensureVisible(deleteTile);
        await t.pumpAndSettle();
        expect(
          find.text(
            'Du bist die letzte Elternperson mit Konto in dieser Familie. Lade zuerst eine zweite erwachsene Person ein oder lösche die Familie.',
          ),
          findsOneWidget,
        );
        expect(t.widget<ListTile>(deleteTile).enabled, isFalse);
        await t.tap(deleteTile, warnIfMissed: false);
        await t.pumpAndSettle();
        expect(find.text('Konto löschen?'), findsNothing);
        expect(s.admin.deleteCalls, 0);
        await unmountApp(t, s.container);
      },
    );

    testWidgets(
      'a confirmed deletion goes straight through with a recent sign-in',
      (t) async {
        final s = await pumpSettings(t);
        await t.ensureVisible(deleteTile);
        await t.pumpAndSettle();
        await t.tap(deleteTile);
        await t.pumpAndSettle();
        expect(find.text('Konto löschen?'), findsOneWidget);
        expect(
          s.admin.deleteCalls,
          0,
          reason: 'nothing happens before confirming',
        );

        await t.tap(deleteConfirm);
        await t.pumpAndSettle();
        expect(s.admin.deleteCalls, 1);
        expect(
          s.identity.codeRequests,
          isEmpty,
          reason: 'no re-sign-in was needed',
        );
        await unmountApp(t, s.container);
      },
    );

    testWidgets('cancelling the dialog deletes nothing', (t) async {
      final s = await pumpSettings(t);
      await t.ensureVisible(deleteTile);
      await t.pumpAndSettle();
      await t.tap(deleteTile);
      await t.pumpAndSettle();
      await t.tap(find.text('Abbrechen'));
      await t.pumpAndSettle();
      expect(s.admin.deleteCalls, 0);
      await unmountApp(t, s.container);
    });

    testWidgets(
      'an old sign-in asks for the e-mail code, then the deletion is retried once',
      (t) async {
        final admin = FakeAccountAdminRepository()
          ..deleteResults = [
            const Err(PermissionFailure(code: 'reauth_required')),
            const Ok(null),
          ];
        final s = await pumpSettings(t, admin: admin);
        s.identity.verifyFor = (code) {
          admin.recent = true;
          return const Ok(false);
        };
        await t.ensureVisible(deleteTile);
        await t.pumpAndSettle();
        await t.tap(deleteTile);
        await t.pumpAndSettle();
        await t.tap(deleteConfirm);
        await t.pumpAndSettle();

        expect(find.text('Bitte bestätige, dass du es bist'), findsOneWidget);
        await t.tap(find.text('Code senden'));
        await t.pumpAndSettle();
        expect(s.identity.codeRequests, ['daniel@example.org']);

        await t.enterText(reauthCode, '123456');
        await t.pumpAndSettle();
        await t.tap(find.text('Bestätigen'));
        await t.pumpAndSettle();

        expect(s.identity.codeChecks, ['123456']);
        expect(admin.deleteCalls, 2, reason: 'the deletion is retried once');
        expect(find.text('Bitte bestätige, dass du es bist'), findsNothing);
        await unmountApp(t, s.container);
      },
    );

    testWidgets('a wrong code keeps the account, and says so', (t) async {
      final admin = FakeAccountAdminRepository()
        ..deleteResults = [
          const Err(PermissionFailure(code: 'reauth_required')),
        ];
      final s = await pumpSettings(t, admin: admin);
      s.identity.verifyResult = const Err(AuthFailure(code: 'otp_invalid'));
      await t.ensureVisible(deleteTile);
      await t.pumpAndSettle();
      await t.tap(deleteTile);
      await t.pumpAndSettle();
      await t.tap(deleteConfirm);
      await t.pumpAndSettle();
      await t.tap(find.text('Code senden'));
      await t.pumpAndSettle();
      await t.enterText(reauthCode, '654321');
      await t.pumpAndSettle();
      await t.tap(find.text('Bestätigen'));
      await t.pumpAndSettle();

      expect(
        find.text(
          'Der Code stimmt nicht oder ist abgelaufen. Probier es noch einmal oder fordere einen neuen an.',
        ),
        findsOneWidget,
      );
      expect(
        admin.deleteCalls,
        1,
        reason: 'nothing is deleted without a fresh sign-in',
      );
      await unmountApp(t, s.container);
    });

    testWidgets('a child or a shared tablet does not see the tile', (t) async {
      final kid = await pumpSettings(
        t,
        device: device(profileId: kidId, register: UiRegister.kid),
      );
      expect(deleteTile, findsNothing);
      await unmountApp(t, kid.container);

      final shared = await pumpSettings(
        t,
        device: device(
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
        ),
      );
      expect(deleteTile, findsNothing);
      await unmountApp(t, shared.container);
    });
  });

  group('resetting a second factor (Mitglieder)', () {
    final resetButton = find.byKey(const ValueKey('mfa-reset-$mamaId'));

    testWidgets(
      'a guardian on a personal phone resets a co-guardian who has a factor',
      (t) async {
        final admin = FakeAccountAdminRepository()
          ..security = const [
            MemberSecurity(profileId: mamaId, hasAccount: true, hasMfa: true),
          ];
        final s = await pumpSettings(t, members: people, admin: admin);
        await t.ensureVisible(resetButton);
        expect(find.text('Zwei-Faktor zurücksetzen'), findsOneWidget);
        await t.tap(resetButton);
        await t.pumpAndSettle();
        expect(
          find.text(
            'Mama kann sich danach ohne zweiten Faktor anmelden und ihn neu einrichten.',
          ),
          findsOneWidget,
        );
        await t.tap(find.text('Zurücksetzen'));
        await t.pumpAndSettle();

        expect(admin.resets, [(actorProfileId: guardianId, profileId: mamaId)]);
        expect(
          find.text('Der zweite Faktor von Mama ist zurückgesetzt.'),
          findsOneWidget,
        );
        await unmountApp(t, s.container);
      },
    );

    testWidgets('at phone width the reset action leaves the role readable', (
      t,
    ) async {
      final admin = FakeAccountAdminRepository()
        ..security = const [
          MemberSecurity(profileId: mamaId, hasAccount: true, hasMfa: true),
        ];
      final s = await pumpSettings(
        t,
        members: people,
        admin: admin,
        size: const Size(390, 844),
      );
      // The settings list builds rows lazily: scroll the member row into the tree first.
      await t.dragUntilVisible(
        resetButton,
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      final row = find.ancestor(
        of: resetButton,
        matching: find.byType(ListTile),
      );
      final role = find.descendant(
        of: row,
        matching: find.text('Erziehungsberechtigter'),
      );
      expect(role, findsOneWidget);
      // The role takes the column's width and wraps at most to two lines, not
      // one or two letters per line as it did beside the buttons.
      expect(t.getSize(role).height, lessThan(50));
      expect(t.getSize(role).width, greaterThan(200));
      expect(resetButton, findsOneWidget);
      expect(t.takeException(), isNull);
      await unmountApp(t, s.container);
    });

    testWidgets('a co-guardian without a factor has no reset to offer', (
      t,
    ) async {
      final admin = FakeAccountAdminRepository()
        ..security = const [
          MemberSecurity(profileId: mamaId, hasAccount: true, hasMfa: false),
        ];
      final s = await pumpSettings(t, members: people, admin: admin);
      expect(resetButton, findsNothing);
      await unmountApp(t, s.container);
    });

    testWidgets('a member, a shared tablet and oneself never see it', (
      t,
    ) async {
      final admin = FakeAccountAdminRepository()
        ..security = const [
          MemberSecurity(profileId: mamaId, hasAccount: true, hasMfa: true),
        ];
      // The shared tablet of the same guardian: not a personal device.
      final shared = await pumpSettings(
        t,
        members: people,
        device: device(deviceClass: DeviceClass.shared),
        admin: admin,
      );
      expect(resetButton, findsNothing);
      await unmountApp(t, shared.container);

      // A member on a personal phone.
      final member = await pumpSettings(
        t,
        members: [
          for (final m in people)
            if (m.id == guardianId)
              const Member(
                id: guardianId,
                displayName: 'Papa',
                color: Color(0xFF2E7D6B),
                role: Role.member,
                active: true,
              )
            else
              m,
        ],
        admin: admin,
      );
      expect(resetButton, findsNothing);
      await unmountApp(t, member.container);
    });
  });

  group('the second-factor state', () {
    test('MemberSecurity reads the server row', () {
      final row = MemberSecurity.fromJson({
        'profile_id': mamaId,
        'has_account': true,
        'has_mfa': true,
      });
      expect(row.profileId, mamaId);
      expect(row.hasAccount, isTrue);
      expect(row.hasMfa, isTrue);
    });
  });
}
