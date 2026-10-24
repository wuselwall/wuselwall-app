import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/server_link.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/invitations/application/invitation_providers.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';

import '../support/fake_getting_started.dart';
import '../support/fake_invitations.dart';
import '../support/fakes.dart';

/// A pending invitation from Papa for Julia, to the account of the test.
const _pending = PendingInvitation(
  id: 'inv-pending',
  householdName: 'Familie Huser',
  inviterFirstName: 'Papa',
  profileName: 'Julia',
  profileColor: '#08737F',
  role: InvitationRole.guardian,
);

Account _account({List<PendingInvitation> pending = const []}) => Account(
  userId: 'user-1',
  email: 'julia@example.org',
  hasHousehold: false,
  creation: HouseholdCreation.code,
  givenName: 'Julia',
  pendingInvitations: pending,
);

/// An adult of the household without an account: the one a guardian invites.
const _julia = Member(
  id: 'p-julia',
  displayName: 'Julia',
  color: Color(0xFF08737F),
  role: Role.guardian,
  active: true,
  hasAccount: false,
);

/// The account of a guardian whose phone is already in [household].
Account _inFamily(String household, {String? leaveBlocked}) => Account(
  userId: 'user-1',
  email: 'daniel@example.org',
  hasHousehold: true,
  householdId: 'h1',
  profileId: guardianId,
  creation: HouseholdCreation.code,
  householdName: household,
  leaveBlocked: leaveBlocked,
);

const _secret = '0123456789abcdef0123456789abcdef';

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

      expect(find.text('Du bist Julia in Familie Huser'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Julia S.');
      await t.pump();
      expect(find.text('Du bist Julia S. in Familie Huser'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('join-confirm')));
      await t.pumpAndSettle();

      expect(invitations.accepted, hasLength(1));
      final sent = invitations.accepted.single;
      expect(sent.invitationId, 'inv-pending');
      expect(sent.secret, isNull);
      expect(sent.displayName, 'Julia S.');
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
          members: [...testMembers, _julia],
          shared: shared.add,
        );

        await t.tap(find.byKey(const ValueKey('invite-member-p-julia')));
        await t.pumpAndSettle();

        expect(invitations.created.single.profileId, 'p-julia');
        expect(invitations.created.single.role, InvitationRole.guardian);
        expect(find.text('Einladung für Julia'), findsOneWidget);
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
      'an open invitation appears inside its member row and can be shared or withdrawn',
      (t) async {
        final invitations = FakeInvitationRepository(open: [openInvitation()]);
        await pumpMembers(
          t,
          invitations: invitations,
          members: [...testMembers, _julia],
        );

        expect(find.text('Julia'), findsOneWidget);
        final memberRow = find.byKey(const ValueKey('member-p-julia'));
        expect(
          find.descendant(
            of: memberRow,
            matching: find.textContaining('Eingeladen · bis'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('invite-member-p-julia')),
          findsNothing,
          reason: 'no second invitation while one is open',
        );

        await t.tap(find.text('Erneut teilen'));
        await t.pumpAndSettle();
        expect(invitations.created.single.profileId, 'p-julia');
        expect(find.text('Einladung für Julia'), findsOneWidget);
        await t.tap(find.text('Fertig'));
        await t.pumpAndSettle();

        await t.tap(find.text('Zurückziehen'));
        await t.pumpAndSettle();
        expect(invitations.revoked, ['inv-1']);
        expect(find.textContaining('Eingeladen · bis'), findsNothing);
      },
    );

    testWidgets('invitations match profile IDs even when names are identical', (
      t,
    ) async {
      const otherJulia = Member(
        id: 'p-other-julia',
        displayName: 'Julia',
        color: Color(0xFF08737F),
        role: Role.member,
        active: true,
        hasAccount: false,
      );
      await pumpMembers(
        t,
        invitations: FakeInvitationRepository(
          open: [openInvitation(profileName: 'Previous name')],
        ),
        members: [...testMembers, otherJulia, _julia],
      );
      expect(find.text('Julia'), findsNWidgets(2));
      expect(find.text('Previous name'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('member-p-other-julia')),
          matching: find.textContaining('Eingeladen · bis'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('invite-member-p-other-julia')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('member-p-julia')),
          matching: find.textContaining('Eingeladen · bis'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a child on a phone sees the invitation but no actions', (
      t,
    ) async {
      final invitations = FakeInvitationRepository(open: [openInvitation()]);
      final container = await pumpMembers(
        t,
        invitations: invitations,
        members: [...testMembers, _julia],
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
        members: [...testMembers, _julia],
        size: const Size(390, 844),
      );
      final row = find.byKey(const ValueKey('member-p-julia'));
      await t.scrollUntilVisible(row, 200);
      final title = find.descendant(of: row, matching: find.text('Julia'));
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

  group('an invitation while already in a family', () {
    Future<
      ({
        ProviderContainer container,
        FakeHouseholdLeaveRepository leave,
        MemoryInvitationStore store,
      })
    >
    pumpInFamily(
      WidgetTester t, {
      required String household,
      String? leaveBlocked,
      StoredInvitation? kept,
      FakeInvitationRepository? invitations,
    }) async {
      final identity = FakeIdentityRepository(current: device());
      final leave = FakeHouseholdLeaveRepository();
      final store = MemoryInvitationStore(kept);
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          leave: leave,
          invitations: invitations,
          invitationStore: store,
          household: FakeHouseholdOnboardingRepository(
            identity: identity,
            accountValue: _inFamily(household, leaveBlocked: leaveBlocked),
          ),
        ),
      );
      return (container: container, leave: leave, store: store);
    }

    Future<void> openLink(WidgetTester t, ProviderContainer container) async {
      container.read(serverSessionProvider).inbox.value = const LinkEvent(
        OpenLinkFixture.link,
        LinkVerdict.proceed,
      );
      await t.pumpAndSettle();
    }

    testWidgets(
      'names both families and leads to leaving, never leaving by itself',
      (t) async {
        final s = await pumpInFamily(t, household: 'Familie Becker');
        await openLink(t, s.container);

        expect(find.byKey(const ValueKey('already-in-family')), findsOneWidget);
        expect(find.text('Du bist schon in Familie Becker'), findsOneWidget);
        expect(
          find.text('Papa hat dich zu Familie Huser eingeladen'),
          findsOneWidget,
        );
        expect(s.leave.leaves, isEmpty);

        await t.tap(find.byKey(const ValueKey('already-in-leave')));
        await t.pumpAndSettle();
        expect(find.text('Familie verlassen?'), findsOneWidget);
        expect(s.leave.leaves, isEmpty, reason: 'only after the confirmation');

        await t.tap(find.byKey(const ValueKey('leave-family-confirm')));
        await t.pumpAndSettle();
        expect(s.leave.leaves, [guardianId]);
        expect(
          s.store.value?.secret,
          _secret,
          reason: 'kept, so the join confirmation follows the leave',
        );
        expect(s.store.value?.householdName, 'Familie Huser');
      },
    );

    testWidgets('cancelling keeps the family and the invitation goes', (
      t,
    ) async {
      final s = await pumpInFamily(t, household: 'Familie Becker');
      await openLink(t, s.container);
      await t.tap(find.text('Abbrechen'));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('already-in-family')), findsNothing);
      expect(s.leave.leaves, isEmpty);
      expect(s.store.value, isNull);
    });

    testWidgets('an invitation to the same family just says so', (t) async {
      final s = await pumpInFamily(t, household: 'Familie Huser');
      await openLink(t, s.container);

      expect(find.text('Du bist schon in Familie Huser'), findsOneWidget);
      expect(
        find.text(
          'Diese Einladung ist für Familie Huser, und da bist du schon dabei. Du musst nichts weiter tun.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('already-in-leave')), findsNothing);
      await t.tap(find.byKey(const ValueKey('already-in-close')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('already-in-family')), findsNothing);
      expect(s.leave.leaves, isEmpty);
    });

    testWidgets('the last guardian is told why leaving is not possible', (
      t,
    ) async {
      final s = await pumpInFamily(
        t,
        household: 'Familie Becker',
        leaveBlocked: 'last_guardian',
      );
      await openLink(t, s.container);
      expect(
        find.text(
          'Lade zuerst eine zweite erwachsene Person ein oder lösche die Familie.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('already-in-leave')), findsNothing);
    });

    testWidgets('an invitation that is no longer valid only says that', (
      t,
    ) async {
      final s = await pumpInFamily(
        t,
        household: 'Familie Becker',
        invitations: FakeInvitationRepository(
          previewResult: const Ok(PreviewRefused('expired')),
        ),
      );
      await openLink(t, s.container);
      expect(find.byKey(const ValueKey('already-in-family')), findsNothing);
      expect(find.textContaining('gilt nicht mehr'), findsOneWidget);
    });

    testWidgets(
      'an invitation kept through the sign-in is explained, then forgotten',
      (t) async {
        final s = await pumpInFamily(
          t,
          household: 'Familie Becker',
          kept: const StoredInvitation(
            secret: _secret,
            householdName: 'Familie Huser',
            inviterFirstName: 'Papa',
            profileName: 'Julia',
            role: InvitationRole.guardian,
          ),
        );
        expect(find.text('Du bist schon in Familie Becker'), findsOneWidget);
        await t.tap(find.text('Abbrechen'));
        await t.pumpAndSettle();
        expect(s.store.value, isNull);
      },
    );
  });

  group('inviting the partner from the getting-started card', () {
    Future<void> pumpCard(
      WidgetTester t, {
      required FakeInvitationRepository invitations,
      required List<Member> members,
      ValueChanged<String>? shared,
    }) async {
      await pumpApp(
        t,
        overrides: [
          ...baseOverrides(
            identity: FakeIdentityRepository(
              current: device(),
              members: members,
            ),
            invitations: invitations,
          ),
          inviteSharerProvider.overrideWithValue((text) async {
            shared?.call(text);
          }),
        ],
        gettingStarted: FakeGettingStartedRepository(const [
          GettingStartedItem(item: StartItem.invitePartner, done: false),
        ]),
      );
      await t.tap(find.text('Partner:in einladen'));
      await t.pumpAndSettle();
    }

    testWidgets(
      'the adult added at the start is offered and invited as themselves',
      (t) async {
        final invitations = FakeInvitationRepository();
        final shared = <String>[];
        await pumpCard(
          t,
          invitations: invitations,
          members: [...testMembers, _julia],
          shared: shared.add,
        );

        expect(find.text('Wen möchtest du einladen?'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('invite-pick-p-julia')),
          findsOneWidget,
        );
        expect(find.text('Jemand anderes'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('invite-pick-$guardianId')),
          findsNothing,
          reason: 'who already has an account is not offered',
        );
        expect(
          find.byKey(const ValueKey('invite-pick-$kidId')),
          findsNothing,
          reason: 'a child is not invited',
        );

        await t.tap(find.byKey(const ValueKey('invite-pick-p-julia')));
        await t.pumpAndSettle();

        final sent = invitations.created.single;
        expect(sent.profileId, 'p-julia');
        expect(sent.displayName, isNull, reason: 'no second Julia is created');
        expect(find.text('Einladung für Julia'), findsOneWidget);

        // Sharing is the primary action; "Fertig" only closes.
        final share = find.byKey(const ValueKey('invite-share'));
        expect(
          find.ancestor(
            of: find.text('Teilen'),
            matching: find.byType(FilledButton),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.text('Fertig'),
            matching: find.byType(TextButton),
          ),
          findsOneWidget,
        );
        await t.tap(share);
        await t.pumpAndSettle();
        expect(shared.single, contains('K7QM-3XRP'));
      },
    );

    testWidgets('"Jemand anderes" opens the form for a new adult', (t) async {
      final invitations = FakeInvitationRepository();
      await pumpCard(
        t,
        invitations: invitations,
        members: [...testMembers, _julia],
      );
      await t.tap(find.byKey(const ValueKey('invite-pick-new')));
      await t.pumpAndSettle();
      expect(find.text('Rolle'), findsOneWidget);
      expect(invitations.created, isEmpty);
    });

    testWidgets('without such an adult the form opens at once', (t) async {
      await pumpCard(
        t,
        invitations: FakeInvitationRepository(),
        members: testMembers,
      );
      expect(find.text('Wen möchtest du einladen?'), findsNothing);
      expect(find.text('Rolle'), findsOneWidget);
    });
  });
}

/// The invitation link of the tests, as the bootstrap hands it to the running app.
abstract final class OpenLinkFixture {
  static const link = OpenedLink(LinkKind.invitation, _secret);
}
