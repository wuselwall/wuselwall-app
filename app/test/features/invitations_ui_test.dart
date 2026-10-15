import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/invitations/application/invitation_providers.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

import '../support/fake_invitations.dart';
import '../support/fakes.dart';

/// A pending invitation from Papa for Sabine, to the account of the test.
const _pending = PendingInvitation(
  id: 'inv-pending',
  householdName: 'Familie Huser',
  inviterFirstName: 'Papa',
  profileName: 'Sabine',
  profileColor: '#08737F',
  role: InvitationRole.guardian,
);

Account _account({List<PendingInvitation> pending = const []}) => Account(
  userId: 'user-1',
  email: 'sabine@example.org',
  hasHousehold: false,
  creation: HouseholdCreation.code,
  givenName: 'Sabine',
  pendingInvitations: pending,
);

/// An adult of the household without an account: the one a guardian invites.
const _sabine = Member(
  id: 'p-sabine',
  displayName: 'Sabine',
  color: Color(0xFF08737F),
  role: Role.guardian,
  active: true,
  hasAccount: false,
);

void main() {
  group('H0', () {
    testWidgets('a pending invitation is offered before H1', (t) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          household: FakeHouseholdOnboardingRepository(
            accountValue: _account(pending: [_pending]),
          ),
        ),
      );
      expect(
        find.text('Papa hat dich zu Familie Huser eingeladen'),
        findsOneWidget,
      );
      expect(find.text('Beitreten'), findsOneWidget);
      expect(find.text('Eigene Familie anlegen'), findsOneWidget);
      expect(find.text('Neue Familie'), findsNothing);
    });

    testWidgets('without a pending invitation the account starts H1', (
      t,
    ) async {
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          household: FakeHouseholdOnboardingRepository(
            accountValue: _account(),
          ),
        ),
      );
      expect(find.text('Neue Familie'), findsOneWidget);
    });

    testWidgets('the join confirmation accepts with an edited name', (t) async {
      final invitations = FakeInvitationRepository();
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          invitations: invitations,
          household: FakeHouseholdOnboardingRepository(
            accountValue: _account(pending: [_pending]),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('join-inv-pending')));
      await t.pumpAndSettle();

      expect(find.text('Du bist Sabine in Familie Huser'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Sabine S.');
      await t.pump();
      expect(find.text('Du bist Sabine S. in Familie Huser'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('join-confirm')));
      await t.pumpAndSettle();

      expect(invitations.accepted, hasLength(1));
      final sent = invitations.accepted.single;
      expect(sent.invitationId, 'inv-pending');
      expect(sent.secret, isNull);
      expect(sent.displayName, 'Sabine S.');
      expect(sent.colorHex, '#08737F', reason: 'the colour the inviter chose');
    });

    testWidgets('an account already in a household says so', (t) async {
      final invitations = FakeInvitationRepository(
        acceptResult: refused<AcceptOutcome>('already_in_household'),
      );
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          invitations: invitations,
          household: FakeHouseholdOnboardingRepository(
            accountValue: _account(pending: [_pending]),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('join-inv-pending')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('join-confirm')));
      await t.pumpAndSettle();
      expect(find.text('Du bist schon in Familie Huser.'), findsOneWidget);
    });
  });

  group('front door', () {
    testWidgets(
      'a code is checked, the banner names the inviter, and the code is kept',
      (t) async {
        final invitations = FakeInvitationRepository();
        final store = MemoryInvitationStore();
        await pumpApp(
          t,
          overrides: baseOverrides(
            identity: FakeIdentityRepository(),
            signedIn: false,
            invitations: invitations,
            invitationStore: store,
          ),
        );
        await t.tap(find.text('Ich habe einen Einladungscode'));
        await t.pumpAndSettle();

        await t.enterText(find.byType(TextField), 'K7QM-3XRP');
        await t.tap(find.text('Einladung prüfen'));
        await t.pumpAndSettle();

        expect(invitations.previews, ['K7QM3XRP']);
        expect(
          find.text('Papa hat dich zu Familie Huser eingeladen'),
          findsOneWidget,
        );

        await t.tap(find.text('Weiter zur Anmeldung'));
        await t.pumpAndSettle();

        expect(store.value?.secret, 'K7QM3XRP');
        expect(store.value?.householdName, 'Familie Huser');
      },
    );

    testWidgets('a refused code shows why and keeps nothing', (t) async {
      final invitations = FakeInvitationRepository(
        previewResult: const Ok(PreviewRefused('expired')),
      );
      final store = MemoryInvitationStore();
      await pumpApp(
        t,
        overrides: baseOverrides(
          identity: FakeIdentityRepository(),
          signedIn: false,
          invitations: invitations,
          invitationStore: store,
        ),
      );
      await t.tap(find.text('Ich habe einen Einladungscode'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'K7QM3XRP');
      await t.tap(find.text('Einladung prüfen'));
      await t.pumpAndSettle();

      expect(find.textContaining('gilt nicht mehr'), findsOneWidget);
      expect(store.value, isNull);
    });
  });

  group('guardians', () {
    /// Settings → Mitglieder, on the given personal phone and with the given people.
    Future<ProviderContainer> pumpMembers(
      WidgetTester t, {
      required FakeInvitationRepository invitations,
      required List<Member> members,
      DeviceInfo? phone,
      ValueChanged<String>? shared,
      Size size = const Size(1000, 1600),
    }) async {
      final container = await pumpApp(
        t,
        size: size,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(
              current: phone ?? device(),
              members: members,
            ),
            invitations: invitations,
          ),
          inviteSharerProvider.overrideWithValue((text) async {
            shared?.call(text);
          }),
        ],
      );
      container.read(routerProvider).go(Routes.settings);
      await t.pumpAndSettle();
      return container;
    }

    testWidgets(
      'inviting an adult without an account shows the code and shares it',
      (t) async {
        final invitations = FakeInvitationRepository();
        final shared = <String>[];
        await pumpMembers(
          t,
          invitations: invitations,
          members: [...testMembers, _sabine],
          shared: shared.add,
        );

        await t.tap(find.byKey(const ValueKey('invite-member-p-sabine')));
        await t.pumpAndSettle();

        expect(invitations.created.single.profileId, 'p-sabine');
        expect(invitations.created.single.role, InvitationRole.guardian);
        expect(find.text('Einladung für Sabine'), findsOneWidget);
        expect(find.byKey(const ValueKey('invite-code')), findsOneWidget);
        expect(find.text('K7QM-3XRP'), findsOneWidget);
        expect(find.byKey(const ValueKey('invite-qr')), findsOneWidget);

        await t.tap(find.byKey(const ValueKey('invite-share')));
        await t.pumpAndSettle();
        expect(shared, hasLength(1));
        expect(shared.single, contains('K7QM-3XRP'));
        expect(
          shared.single,
          contains('https://wuselwall.app/i/#0123456789abcdef0123456789abcdef'),
        );
        expect(shared.single, contains('Familie Huser'));
      },
    );

    testWidgets(
      'an open invitation is listed as Eingeladen, and can be shared again or withdrawn',
      (t) async {
        final invitations = FakeInvitationRepository(open: [openInvitation()]);
        await pumpMembers(
          t,
          invitations: invitations,
          members: [...testMembers, _sabine],
        );

        expect(find.textContaining('Eingeladen · bis'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('invite-member-p-sabine')),
          findsNothing,
          reason: 'no second invitation while one is open',
        );

        await t.tap(find.text('Erneut teilen'));
        await t.pumpAndSettle();
        expect(invitations.created.single.profileId, 'p-sabine');
        expect(find.text('Einladung für Sabine'), findsOneWidget);
        await t.tap(find.text('Fertig'));
        await t.pumpAndSettle();

        await t.tap(find.text('Zurückziehen'));
        await t.pumpAndSettle();
        expect(invitations.revoked, ['inv-1']);
        expect(find.textContaining('Eingeladen · bis'), findsNothing);
      },
    );

    testWidgets('a child on a phone sees the invitation but no actions', (
      t,
    ) async {
      final invitations = FakeInvitationRepository(open: [openInvitation()]);
      final container = await pumpMembers(
        t,
        invitations: invitations,
        members: [...testMembers, _sabine],
        phone: device(profileId: kidId, register: UiRegister.kid),
      );
      expect(find.textContaining('Eingeladen · bis'), findsOneWidget);
      expect(find.text('Zurückziehen'), findsNothing);
      expect(find.text('Erwachsene Person einladen'), findsNothing);
      await unmountApp(t, container);
    });

    testWidgets('"Erwachsene Person einladen" opens the adult form', (t) async {
      final container = await pumpMembers(
        t,
        invitations: FakeInvitationRepository(),
        members: testMembers,
      );
      await t.tap(find.text('Erwachsene Person einladen'));
      await t.pumpAndSettle();
      expect(find.text('Rolle'), findsOneWidget);
      expect(find.text('Erziehungsberechtigt'), findsWidgets);
      await unmountApp(t, container);
    });

    testWidgets('at phone width an open invitation keeps its name readable', (
      t,
    ) async {
      final invitations = FakeInvitationRepository(open: [openInvitation()]);
      await pumpMembers(
        t,
        invitations: invitations,
        members: [...testMembers, _sabine],
        size: const Size(390, 844),
      );
      final row = find.byKey(const ValueKey('open-invitation-inv-1'));
      await t.scrollUntilVisible(row, 200);
      final title = find.descendant(of: row, matching: find.text('Sabine'));
      expect(t.getSize(title).width, greaterThan(40));
      expect(t.getSize(title).height, lessThan(30), reason: 'one line');
      expect(
        find.descendant(of: row, matching: find.text('Erneut teilen')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Zurückziehen')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  });
}
