import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/server_link.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/home/ui/register_home_page.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/application/pairing_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

import '../support/fake_invitations.dart';
import '../support/fake_pairing.dart';
import '../support/fakes.dart';
import 'screen_log.dart';

// The budgets of NFR-17 (specs/02) for the three onboarding journeys of specs/20, driven
// through the real screens with fake repositories. A change that adds a screen to a
// journey fails here. What these cannot see (seconds on a real phone, the mail's journey)
// stays on the release checklist (specs/18).
//
// "After sign-in" starts when E3 is answered: E1 to E3 are the sign-in itself, whatever the
// account does next is the journey.

/// Whether the account is signed in: a stand-in for the Auth session, which the fakes do
/// not have. The fake identity repository flips it when the code is accepted.
class _SignedIn extends Notifier<bool> {
  @override
  bool build() => false;

  void signIn() => state = true;
}

final _signedIn = NotifierProvider<_SignedIn, bool>(_SignedIn.new);

/// An identity repository whose accepted code signs the account in.
class _JourneyIdentity extends FakeIdentityRepository {
  _JourneyIdentity() {
    verifyResult = const Ok(true); // a new account: E3 is owed
  }

  void Function()? onVerified;

  @override
  Future<Result<bool>> verifyEmailCode(String email, String code) async {
    final result = await super.verifyEmailCode(email, code);
    if (result.isOk) onVerified?.call();
    return result;
  }
}

/// Accepting an invitation makes this session a personal device, as the server does.
class _JourneyInvitations extends FakeInvitationRepository {
  _JourneyInvitations(this._identity);

  final FakeIdentityRepository _identity;

  @override
  Future<Result<AcceptOutcome>> accept({
    String? secret,
    String? invitationId,
    required String displayName,
    String? colorHex,
    required String deviceLabel,
  }) async {
    final result = await super.accept(
      secret: secret,
      invitationId: invitationId,
      displayName: displayName,
      colorHex: colorHex,
      deviceLabel: deviceLabel,
    );
    if (result.valueOrNull is Accepted) _identity.current = device();
    return result;
  }
}

const _codeTitle = 'Code aus der E-Mail';
const _choiceTitle = 'Wie möchtest du dich künftig anmelden?';

/// The overrides of a signed-out start whose sign-in works.
List<Override> _journeyOverrides(
  ProviderContainer Function() container,
  _JourneyIdentity identity, {
  FakeHouseholdOnboardingRepository? household,
  FakeInvitationRepository? invitations,
  MemoryInvitationStore? store,
  ServerSession? session,
}) {
  identity.onVerified = () => container().read(_signedIn.notifier).signIn();
  return [
    ...baseOverrides(
      identity: identity,
      household: household,
      invitations: invitations,
      invitationStore: store,
      sessionUser: sessionUserIdProvider.overrideWith(
        (ref) => ref.watch(_signedIn) ? 'user-1' : null,
      ),
    ),
    if (session != null) serverSessionProvider.overrideWithValue(session),
  ];
}

/// The address, then the six digits (E1, E2), from wherever E1 is.
Future<void> _enterAddressAndCode(WidgetTester t, String address) async {
  await t.enterText(find.byType(TextField), address);
  await t.tap(find.text('Weiter'));
  await t.pumpAndSettle();
  expect(find.text(_codeTitle), findsOneWidget);
  await t.enterText(find.byKey(const ValueKey('email-code-field')), '123456');
  await t.pumpAndSettle();
}

/// E3, which a new account answers once; the code is the default, so one tap. The sign-in
/// is over with it: everything the router shows next counts.
Future<void> _answerE3(WidgetTester t, ScreenLog log) async {
  expect(find.text(_choiceTitle), findsOneWidget);
  log.mark('signed in');
  await t.tap(find.text('Weiter'));
  await t.pumpAndSettle();
}

void main() {
  group(
    'J1 — start a family: at most 3 screens after sign-in, only names typed',
    () {
      testWidgets('front door → E1 → E2 → E3 → H1 → H2 → Today', (t) async {
        final identity = _JourneyIdentity();
        final household = FakeHouseholdOnboardingRepository(
          identity: identity,
          // `open` mode asks for no founder code; in `code` mode that one field is typed.
          accountValue: const Account(
            userId: 'user-1',
            email: 'daniel@example.org',
            hasHousehold: false,
            creation: HouseholdCreation.open,
            fullName: 'Daniel Huser',
            givenName: 'Daniel',
          ),
        );
        late ProviderContainer container;
        container = await pumpApp(
          t,
          overrides: _journeyOverrides(
            () => container,
            identity,
            household: household,
          ),
        );
        final log = ScreenLog(container.read(routerProvider));
        addTearDown(log.dispose);

        await t.tap(find.text('Mit E-Mail fortfahren'));
        await t.pumpAndSettle();
        await _enterAddressAndCode(t, 'daniel@example.org');
        await _answerE3(t, log);

        // H1 arrives with everything filled in: no field is empty, no code is asked.
        expect(find.text('Neue Familie'), findsOneWidget);
        expect(
          find.widgetWithText(TextFormField, 'Gründungscode'),
          findsNothing,
        );
        final fields = t.widgetList<EditableText>(find.byType(EditableText));
        expect(fields, isNotEmpty);
        for (final field in fields) {
          expect(field.controller.text, isNotEmpty);
        }
        await t.tap(find.text('Familie anlegen'));
        await t.pumpAndSettle();
        expect(household.created, hasLength(1));
        // The app refreshes the session after the creation: this phone is a device now.
        container.invalidate(sessionStateProvider);
        await t.pumpAndSettle();

        // H2: a name is all it takes.
        expect(find.text('Wer gehört noch zu euch?'), findsOneWidget);
        await t.enterText(find.widgetWithText(TextField, 'Name'), 'Lotta');
        await t.tap(find.text('Fertig'));
        await t.pumpAndSettle();

        expect(find.byType(RegisterHomePage), findsOneWidget);
        final screens = log.after('signed in');
        expect(screens, [Routes.newFamily, Routes.welcomeMembers, Routes.home]);
        expect(screens.length, lessThanOrEqualTo(3));
      });
    },
  );

  group('J2 — join by link: at most 2 screens after sign-in', () {
    testWidgets('link → banner → E1 → E2 → E3 → join confirmation → Today', (
      t,
    ) async {
      final identity = _JourneyIdentity();
      final invitations = _JourneyInvitations(identity);
      final store = MemoryInvitationStore();
      // The app was opened with an invitation link of the server it is on.
      final session = ServerSession(
        initialLink: const LinkEvent(
          OpenedLink(LinkKind.invitation, 'K7QM3XRP'),
          LinkVerdict.proceed,
        ),
      );
      late ProviderContainer container;
      container = await pumpApp(
        t,
        overrides: _journeyOverrides(
          () => container,
          identity,
          invitations: invitations,
          store: store,
          session: session,
          household: FakeHouseholdOnboardingRepository(
            identity: identity,
            accountValue: const Account(
              userId: 'user-1',
              email: 'sabine@example.org',
              hasHousehold: false,
              creation: HouseholdCreation.code,
              givenName: 'Sabine',
            ),
          ),
        ),
      );
      final log = ScreenLog(container.read(routerProvider));
      addTearDown(log.dispose);

      // The link opened the code entry with the banner, checked without typing.
      expect(invitations.previews, ['K7QM3XRP']);
      expect(
        find.text('Papa hat dich zu Familie Huser eingeladen'),
        findsOneWidget,
      );
      await t.tap(find.text('Weiter zur Anmeldung'));
      await t.pumpAndSettle();
      expect(store.value?.secret, 'K7QM3XRP');

      await _enterAddressAndCode(t, 'sabine@example.org');
      await _answerE3(t, log);

      // The join confirmation carries the name the inviter chose.
      expect(find.text('Du bist Sabine in Familie Huser'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('join-confirm')));
      await t.pumpAndSettle();

      expect(invitations.accepted, hasLength(1));
      expect(find.byType(RegisterHomePage), findsOneWidget);
      final screens = log.after('signed in');
      expect(screens, [Routes.joinInvite, Routes.home]);
      expect(screens.length, lessThanOrEqualTo(2));
    });
  });

  group('J3 — connect a shared device: nothing typed on it', () {
    testWidgets('P1 has no text input and connects when the poll approves', (
      t,
    ) async {
      final pairing = FakePairingRepository();
      final identity = FakeIdentityRepository()..signInResult = const Ok(null);
      final container = await pumpApp(
        t,
        overrides: baseOverrides(
          identity: identity,
          pairing: pairing,
          signedIn: false,
        ),
      );
      final log = ScreenLog(container.read(routerProvider));
      addTearDown(log.dispose);
      container.read(routerProvider).go(Routes.pair);
      await t.pump();
      await t.pump();

      // The code and its QR code are shown; there is nothing to type into.
      expect(find.text('K7QM-3XRP'), findsOneWidget);
      expect(find.byKey(const ValueKey('pair-qr')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(EditableText), findsNothing);

      pairing.pollQueue.add(
        PairingApproved(
          email: 'device-1@devices.wuselwall.invalid',
          password: 'pw',
          householdName: 'Familie Huser',
          deviceClass: DeviceClass.shared,
          register: UiRegister.kid,
        ),
      );
      await t.pump(const Duration(seconds: 2));
      expect(identity.signIns, [('device-1@devices.wuselwall.invalid', 'pw')]);
      expect(find.text('Verbunden mit Familie Huser'), findsOneWidget);
      expect(container.read(pairingHandoffProvider), 'Familie Huser');
      expect(find.byType(EditableText), findsNothing);
      expect(log.all.where((p) => p != Routes.splash && p != Routes.setup), [
        Routes.pair,
      ], reason: 'the new device shows one screen until it is connected');

      await t.pump(const Duration(seconds: 3));
      await unmountApp(t, container);
    });
  });
}
