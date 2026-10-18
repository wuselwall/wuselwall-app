@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/household/data/household_leave_repository.dart';
import 'package:wuselwall/features/household/data/household_onboarding_repository.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/data/pairing_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';
import 'package:wuselwall/features/today/data/notices_repository.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';
import 'package:wuselwall/features/today/domain/notice.dart';

/// The onboarding journeys of specs/20 (J1 start a family, J2 join, J3 connect a shared
/// device) against a real backend, through the app's repositories:
/// `flutter test test/integration --dart-define-from-file=env/ci.json` on a throwaway stack
/// (CI's `backend` job starts one; locally `npx supabase start`).
///
/// * The six-digit sign-in code is read from the stack's mail catcher (Mailpit, the CLI's
///   `local_smtp`): `http://<SUPABASE_URL host>:54324`, or `--dart-define=WW_MAIL_URL=…`.
/// * A fresh stack creates households in `code` mode. `supabase/seed.sql` plants three
///   founder codes (`dev-founder-j1` … `j3`, one per journey); `--dart-define=WW_FOUNDER_CODES=a,b,c`
///   replaces them. A code is single use, so a second run on the same database needs
///   `supabase db reset` (or fresh codes); in `open` mode no code is sent at all.
/// * Every run uses fresh addresses, and each journey deletes its family when it is done.
void main() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const mailOverride = String.fromEnvironment('WW_MAIL_URL');
  const founderCodesDefine = String.fromEnvironment(
    'WW_FOUNDER_CODES',
    defaultValue: 'dev-founder-j1,dev-founder-j2,dev-founder-j3',
  );

  // Households, accounts and devices are created and removed: throwaway stacks only
  // (CI, or a local `supabase start`), never the family's environment (ADR-013).
  final host = Uri.tryParse(url)?.host;
  final skip = url.isEmpty
      ? 'no backend configured (SUPABASE_URL)'
      : !{'127.0.0.1', 'localhost'}.contains(host)
      ? 'refusing to run against $host: throwaway stacks only (ADR-013)'
      : null;
  final mailUrl = mailOverride.isNotEmpty
      ? mailOverride
      : 'http://${host ?? '127.0.0.1'}:54324';
  final founderCodes = founderCodesDefine.split(',');

  setUpAll(() => HttpOverrides.global = null);

  final stamp = DateTime.now().millisecondsSinceEpoch;
  var counter = 0;
  String freshEmail() => 'e2e-$stamp-${counter++}@example.org';

  /// A client with its repositories, one per simulated device.
  _Device device() {
    final client = SupabaseClient(
      url,
      key,
      postgrestOptions: const PostgrestClientOptions(schema: 'api'),
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _InMemoryPkceStorage(),
      ),
    );
    addTearDown(client.dispose);
    return _Device(client);
  }

  /// E1 + E2: asks for a code, reads it from the mail catcher and verifies it.
  Future<void> signInByEmail(_Device d, String email) async {
    expect((await d.identity.sendEmailCode(email, locale: 'de')).isOk, isTrue);
    final code = await _mailCode(mailUrl, email);
    final first = (await d.identity.verifyEmailCode(email, code)).unwrap();
    expect(first, isTrue, reason: 'a new address is a first code sign-in');
    expect(d.client.auth.currentSession, isNotNull);
  }

  /// H1 for journey [index] (0 based): a wrong and a missing founder code are refused
  /// in `code` mode, the right one creates the family.
  Future<void> createFamily(
    _Device d, {
    required int index,
    required String familyName,
    required String name,
  }) async {
    final account = (await d.onboarding.account()).unwrap();
    expect(account.hasHousehold, isFalse);
    expect(account.pendingInvitations, isEmpty);

    Future<Result<void>> create(String? code) => d.onboarding.create(
      householdName: familyName,
      displayName: name,
      colorHex: '#2E7D6B',
      timezone: 'Europe/Berlin',
      locale: 'de',
      founderCode: code,
      seedExamples: true,
      deviceLabel: 'Test phone',
    );

    if (account.creation == HouseholdCreation.code) {
      expect((await create(null)).failureOrNull?.code, 'founder_code_required');
      expect(
        (await create('not-a-code-$stamp')).failureOrNull?.code,
        'founder_code_invalid',
      );
    }
    final code = account.creation == HouseholdCreation.code
        ? founderCodes[index]
        : null;
    final created = await create(code);
    expect(
      created.failureOrNull?.code,
      isNull,
      reason:
          'founder code ${code ?? '(none)'} refused; a code is single use: '
          'run `supabase db reset` or pass WW_FOUNDER_CODES',
    );
  }

  /// Deletes the family of the guardian on [d] (the journey's own cleanup).
  void deleteFamilyAfter(_Device d, String familyName) {
    addTearDown(() async {
      final me = (await d.identity.currentDevice()).valueOrNull;
      if (me?.profileId == null) return;
      await HouseholdLeaveRepository(
        d.api,
        d.client.auth,
      ).deleteFamily(profileId: me!.profileId!, confirmName: familyName);
    });
  }

  test(
    'J1: email code → family → members → personal device and getting-started card',
    () async {
      final phone = device();
      final email = freshEmail();
      const familyName = 'Familie Test J1';
      await signInByEmail(phone, email);
      await createFamily(phone, index: 0, familyName: familyName, name: 'Papa');
      deleteFamilyAfter(phone, familyName);

      // H2: a child and a second adult without an account.
      (await phone.onboarding.addMembers(const [
        NewMember(displayName: 'Anna', isChild: true),
        NewMember(displayName: 'Mama', isChild: false),
      ])).unwrap();
      (await phone.onboarding.completeExamples()).unwrap();

      // This phone is the founder's personal device, in the new family.
      final me = (await phone.identity.currentDevice()).unwrap()!;
      expect(me.deviceClass, DeviceClass.personal);
      expect(me.register, UiRegister.adult);
      expect(me.profileId, isNotNull);
      final account = (await phone.onboarding.account()).unwrap();
      expect(account.hasHousehold, isTrue);
      expect(account.householdId, me.householdId);
      expect(account.profileId, me.profileId);

      final members = (await phone.identity.members()).unwrap();
      expect(
        members.map((m) => m.displayName),
        containsAll(['Papa', 'Anna', 'Mama']),
      );
      expect(
        members.firstWhere((m) => m.displayName == 'Anna').isChild,
        isTrue,
      );
      final papa = members.firstWhere((m) => m.id == me.profileId);
      expect(papa.isGuardian, isTrue);
      expect(papa.hasAccount, isTrue);
      expect(
        members.firstWhere((m) => m.displayName == 'Mama').hasAccount,
        isFalse,
      );

      // Examples were asked for: the default shopping list and the chores exist.
      expect(
        (await ShoppingRepository(
          phone.api,
        ).lists()).unwrap().any((l) => l.isDefault),
        isTrue,
      );

      // The card: everything still to do, nothing done, no PIN item before a shared device.
      final card = (await GettingStartedRepository(
        phone.api,
      ).items(actor: me.profileId!)).unwrap();
      expect(
        card.map((i) => i.item),
        containsAll([
          StartItem.invitePartner,
          StartItem.connectTablet,
          StartItem.wallDisplay,
          StartItem.subscribeFeed,
          StartItem.school,
        ]),
      );
      expect(card.map((i) => i.item), isNot(contains(StartItem.setPin)));
      expect(card.every((i) => !i.done), isTrue);

      // A signed-in account with a family cannot start a second one.
      final again = await phone.onboarding.create(
        householdName: 'Zweite Familie',
        displayName: 'Papa',
        colorHex: '#2E7D6B',
        timezone: 'Europe/Berlin',
        locale: 'de',
        founderCode: founderCodes[0],
        seedExamples: false,
        deviceLabel: 'Test phone',
      );
      expect(again.failureOrNull?.code, 'already_in_household');
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'J2: invitation by link or code, by matching email, refusals and the join notice',
    () async {
      const familyName = 'Familie Test J2';
      final founder = device();
      await signInByEmail(founder, freshEmail());
      await createFamily(
        founder,
        index: 1,
        familyName: familyName,
        name: 'Sabine',
      );
      deleteFamilyAfter(founder, familyName);
      final founderDevice = (await founder.identity.currentDevice()).unwrap()!;
      final founderId = founderDevice.profileId!;

      // A new adult, by link (token) and by the typed code.
      final omaInvite = (await founder.invitations.create(
        displayName: 'Oma',
        role: InvitationRole.guardian,
      )).unwrap();
      expect(omaInvite.code, hasLength(8));
      expect((await founder.invitations.open()).unwrap(), hasLength(1));

      // Anyone may preview; it reveals the family and the first names, nothing else.
      final stranger = device(); // no session at all
      for (final secret in [omaInvite.token, omaInvite.code]) {
        final preview = (await stranger.invitations.preview(secret)).unwrap();
        expect(preview, isA<PreviewValid>());
        final valid = (preview as PreviewValid).preview;
        expect(valid.householdName, familyName);
        expect(valid.inviterFirstName, 'Sabine');
        expect(valid.profileName, 'Oma');
        expect(valid.role, InvitationRole.guardian);
      }
      final junk = (await stranger.invitations.preview('ZZZZZZZZ')).unwrap();
      expect(junk, isA<PreviewRefused>());

      // The invitee signs in and accepts.
      final oma = device();
      await signInByEmail(oma, freshEmail());
      expect((await oma.onboarding.account()).unwrap().hasHousehold, isFalse);
      final accepted = (await oma.invitations.accept(
        secret: omaInvite.token,
        displayName: 'Oma',
        deviceLabel: 'Omas Handy',
      )).unwrap();
      expect(accepted, isA<Accepted>());
      final omaDevice = (await oma.identity.currentDevice()).unwrap()!;
      expect(omaDevice.deviceClass, DeviceClass.personal);
      expect(omaDevice.householdId, founderDevice.householdId);
      expect(omaDevice.profileId, (accepted as Accepted).profileId);
      expect(
        (await oma.identity.members()).unwrap().map((m) => m.displayName),
        containsAll(['Sabine', 'Oma']),
      );

      // The founder now sees the "join" notice; the joiner does not.
      final notices = (await NoticesRepository(
        founder.api,
      ).notices(actor: founderId)).unwrap();
      final join = notices.where((n) => n.kind == NoticeKind.join).toList();
      expect(join.map((n) => n.name), ['Oma']);
      expect(
        (await NoticesRepository(oma.api).notices(actor: omaDevice.profileId!))
            .unwrap()
            .where((n) => n.kind == NoticeKind.join),
        isEmpty,
      );

      // Accepting again, or into another family, fails: one family per account.
      final spare = (await founder.invitations.create(
        displayName: 'Tante',
        role: InvitationRole.member,
      )).unwrap();
      final second = await oma.invitations.accept(
        secret: spare.token,
        displayName: 'Oma',
        deviceLabel: 'Omas Handy',
      );
      expect(second.failureOrNull, isA<PermissionFailure>());
      expect(second.failureOrNull?.code, 'already_in_household');

      // A spent invitation is gone for everyone else.
      final late = device();
      await signInByEmail(late, freshEmail());
      expect(
        (await late.invitations.accept(
          secret: omaInvite.token,
          displayName: 'Spät',
          deviceLabel: 'Handy',
        )).unwrap(),
        isA<AcceptRefused>(),
      );

      // A revoked one too, on preview and on accept.
      (await founder.invitations.revoke(spare.id)).unwrap();
      expect(
        (await stranger.invitations.preview(spare.token)).unwrap(),
        isA<PreviewRefused>(),
      );
      final refused = (await late.invitations.accept(
        secret: spare.token,
        displayName: 'Spät',
        deviceLabel: 'Handy',
      )).unwrap();
      expect(refused, isA<AcceptRefused>());
      expect((refused as AcceptRefused).reason, 'invalid');
      expect(
        (await founder.invitations.revoke(spare.id)).failureOrNull?.code,
        'invitation_not_open',
      );

      // By email (H0): the invitation names the new account's confirmed address, so
      // sign-in offers it and no secret is typed.
      final opaEmail = freshEmail();
      final opaInvite = (await founder.invitations.create(
        displayName: 'Opa',
        role: InvitationRole.guardian,
        email: opaEmail,
      )).unwrap();
      final opa = device();
      await signInByEmail(opa, opaEmail);
      final waiting = (await opa.onboarding.account()).unwrap();
      expect(waiting.hasHousehold, isFalse);
      expect(waiting.pendingInvitations.map((i) => i.id), [opaInvite.id]);
      expect(waiting.pendingInvitations.single.householdName, familyName);
      expect(
        (await opa.invitations.accept(
          invitationId: opaInvite.id,
          displayName: 'Opa',
          deviceLabel: 'Opas Handy',
        )).unwrap(),
        isA<Accepted>(),
      );
      expect(
        (await opa.identity.currentDevice()).unwrap()!.householdId,
        founderDevice.householdId,
      );
      // The same invitation by id for an account it does not name is refused.
      expect(
        (await late.invitations.accept(
          invitationId: opaInvite.id,
          displayName: 'Spät',
          deviceLabel: 'Handy',
        )).failureOrNull?.code,
        'invitation_not_for_account',
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 180)),
  );

  test(
    'J3: pairing a wall display from the guardian\'s phone',
    () async {
      const familyName = 'Familie Test J3';
      final phone = device();
      await signInByEmail(phone, freshEmail());
      await createFamily(phone, index: 2, familyName: familyName, name: 'Papa');
      deleteFamilyAfter(phone, familyName);
      (await phone.onboarding.addMembers(const [
        NewMember(displayName: 'Anna', isChild: true),
      ])).unwrap();
      final guardian = (await phone.identity.currentDevice()).unwrap()!;

      // The new device is anonymous: it starts a request and polls with its own secret.
      final tv = device();
      final pairing = PairingRepository(tv.api);
      final request = (await pairing.start()).unwrap();
      expect(request.code, hasLength(8));
      expect(
        await pairing.poll(request).then((r) => r.unwrap()),
        isA<PairingPending>(),
      );

      // A poll with the wrong secret, or for an unknown request, learns nothing.
      PairingRequest withSecret(String secret) => PairingRequest(
        requestId: request.requestId,
        secret: secret,
        code: request.code,
        expiresAt: request.expiresAt,
      );
      expect(
        (await pairing.poll(withSecret('wrong-secret'))).unwrap(),
        isA<PairingInvalid>(),
      );
      expect(
        (await pairing.poll(
          PairingRequest(
            requestId: '00000000-0000-4000-8000-000000000000',
            secret: request.secret,
            code: request.code,
            expiresAt: request.expiresAt,
          ),
        )).unwrap(),
        isA<PairingInvalid>(),
      );

      // The guardian types the code. A wrong one is refused; the right one approves.
      final guardianPairing = PairingRepository(phone.api);
      expect(
        (await guardianPairing.approve(
          code: 'AAAAAAAA',
          kind: PairingKind.wallDisplay,
          label: 'Küchenwand',
        )).failureOrNull?.code,
        'code_invalid',
      );
      final approval = (await guardianPairing.approve(
        code: formatPairingCode(request.code),
        kind: PairingKind.wallDisplay,
        label: 'Küchenwand',
      )).unwrap();
      expect(approval.needsPin, isTrue, reason: 'G2 follows: no PIN yet');
      (await phone.identity.setPin(pin: '246810')).unwrap();

      // Approved, but the wrong secret still gets nothing.
      expect(
        (await pairing.poll(withSecret('wrong-secret'))).unwrap(),
        isA<PairingInvalid>(),
      );

      // The right poll collects the credentials, once.
      final approved = (await pairing.poll(request)).unwrap();
      expect(approved, isA<PairingApproved>());
      final creds = approved as PairingApproved;
      expect(creds.householdName, familyName);
      expect(creds.deviceClass, DeviceClass.kiosk);
      expect(creds.register, UiRegister.kiosk);
      expect((await pairing.poll(request)).unwrap(), isA<PairingInvalid>());

      // The device signs in as the wall display and reads the family's data.
      expect(
        (await tv.identity.signIn(creds.email, creds.password)).isOk,
        isTrue,
      );
      final wall = (await tv.identity.currentDevice()).unwrap()!;
      expect(wall.deviceClass, DeviceClass.kiosk);
      expect(wall.householdId, guardian.householdId);
      expect(wall.label, 'Küchenwand');
      expect(
        (await tv.identity.members()).unwrap().map((m) => m.displayName),
        containsAll(['Papa', 'Anna']),
      );
      expect((await ShoppingRepository(tv.api).lists()).unwrap(), isNotEmpty);

      // The card on the guardian's phone ticks "wall display" and now offers the PIN.
      final card = (await GettingStartedRepository(
        phone.api,
      ).items(actor: guardian.profileId!)).unwrap();
      expect(
        card.firstWhere((i) => i.item == StartItem.wallDisplay).done,
        isTrue,
      );
      expect(card.map((i) => i.item), contains(StartItem.setPin));
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );
}

/// One simulated device: a Supabase client with the repositories the journeys use.
class _Device {
  _Device(this.client)
    : api = ApiClient(client),
      identity = IdentityRepository(ApiClient(client), client.auth),
      onboarding = HouseholdOnboardingRepository(
        ApiClient(client),
        client.auth,
      ),
      invitations = ApiInvitationRepository(ApiClient(client), client.auth);

  final SupabaseClient client;
  final ApiClient api;
  final IdentityRepository identity;
  final HouseholdOnboardingRepository onboarding;
  final InvitationRepository invitations;
}

/// In-memory PKCE code-verifier storage for one simulated device. The real app persists
/// this in `SecureSessionStorage` (platform secure storage); a throwaway test device only
/// needs it to survive between `sendEmailCode`/`verifyEmailCode` (or a magic-link exchange)
/// within the same client instance, never shared across devices.
class _InMemoryPkceStorage extends GotrueAsyncStorage {
  final _store = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _store.remove(key);
  }
}

/// The latest six-digit code mailed to [email], read from Mailpit's HTTP API. Polls for up
/// to 20 s: GoTrue sends the mail asynchronously.
Future<String> _mailCode(String mailUrl, String email) async {
  final client = http.Client();
  try {
    for (var attempt = 0; attempt < 40; attempt++) {
      final search = await client.get(
        Uri.parse(
          '$mailUrl/api/v1/search?query=${Uri.encodeQueryComponent('to:$email')}',
        ),
      );
      if (search.statusCode == 200) {
        final messages =
            (jsonDecode(search.body) as Map<String, dynamic>)['messages']
                as List<dynamic>? ??
            const [];
        if (messages.isNotEmpty) {
          // Newest first.
          final id = (messages.first as Map<String, dynamic>)['ID'] as String;
          final message = await client.get(
            Uri.parse('$mailUrl/api/v1/message/$id'),
          );
          final text =
              (jsonDecode(message.body) as Map<String, dynamic>)['Text']
                  as String? ??
              '';
          final match = RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(text);
          if (match != null) return match.group(0)!;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  } finally {
    client.close();
  }
  throw StateError('no sign-in code for $email at $mailUrl (is Mailpit up?)');
}
