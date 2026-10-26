@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/account/data/account_admin_repository.dart';
import 'package:wuselwall/features/household/data/household_leave_repository.dart';
import 'package:wuselwall/features/household/data/household_onboarding_repository.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

/// A server without mail (specs/20 "Choosing the server", Q48), against a real throwaway
/// stack whose Auth autoconfirms addresses: the CLI stack with `enable_confirmations = false`
/// in supabase/config.toml. CI's `backend` job restarts its stack that way after the other
/// integration tests and runs this file with `--dart-define=WW_NO_MAIL=true`; without that
/// define it is skipped, because a stack with mail behaves differently on purpose.
///
/// * Discovery says `sign_in.email_code: false`.
/// * J1: sign-up with a password, then the family (founder code `dev-founder-j1` of the seed,
///   after `supabase db reset`).
/// * An invitation naming an address is not matched to an autoconfirmed account; its code is.
/// * A guardian's reset code gives the other adult a new password, once.
void main() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const noMail = bool.fromEnvironment('WW_NO_MAIL');
  const founderCode = String.fromEnvironment(
    'WW_FOUNDER_CODES',
    defaultValue: 'dev-founder-j1',
  );

  final host = Uri.tryParse(url)?.host;
  final skip = url.isEmpty
      ? 'no backend configured (SUPABASE_URL)'
      : !{'127.0.0.1', 'localhost'}.contains(host)
      ? 'refusing to run against $host: throwaway stacks only (ADR-013)'
      : !noMail
      ? 'needs a stack without mail (--dart-define=WW_NO_MAIL=true)'
      : null;

  setUpAll(() => HttpOverrides.global = null);

  final stamp = DateTime.now().millisecondsSinceEpoch;
  var counter = 0;
  String freshEmail() => 'nomail-$stamp-${counter++}@example.org';

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

  test(
    'discovery, J1 with a password, no email match, and the guardian reset',
    () async {
      // Discovery: the app will offer passwords only.
      final doc = jsonDecode(
        (await http.get(Uri.parse('$url/functions/v1/server-info'))).body,
      ) as Map<String, dynamic>;
      expect(doc['sign_in'], {'password': true, 'email_code': false});
      expect(doc['features'], contains('password-reset'));

      // J1: a password sign-up is signed in at once, no code anywhere.
      const familyName = 'Familie Ohne Mail';
      final founder = device();
      (await founder.identity.signUpWithPassword(
        freshEmail(),
        'founder password 1',
        locale: 'de',
      )).unwrap();
      expect(founder.client.auth.currentSession, isNotNull);
      final account = (await founder.onboarding.account()).unwrap();
      expect(account.hasHousehold, isFalse);
      (await founder.onboarding.create(
        householdName: familyName,
        displayName: 'Papa',
        colorHex: '#2E7D6B',
        timezone: 'Europe/Berlin',
        locale: 'de',
        founderCode: account.creation == HouseholdCreation.code
            ? founderCode.split(',').first
            : null,
        seedExamples: false,
        deviceLabel: 'Test phone',
      )).unwrap();
      addTearDown(() async {
        final me = (await founder.identity.currentDevice()).valueOrNull;
        if (me?.profileId == null) return;
        await HouseholdLeaveRepository(
          founder.api,
          founder.client.auth,
        ).deleteFamily(profileId: me!.profileId!, confirmName: familyName);
      });
      final founderId = (await founder.identity.currentDevice())
          .unwrap()!
          .profileId!;

      // An invitation naming an address: an account that merely typed that address is
      // not offered it, and cannot take it by id. Its code works as everywhere.
      final mamaEmail = freshEmail();
      final invite = (await founder.invitations.create(
        displayName: 'Mama',
        role: InvitationRole.member,
        email: mamaEmail,
      )).unwrap();
      final mama = device();
      (await mama.identity.signUpWithPassword(
        mamaEmail,
        'mama password 1',
        locale: 'de',
      )).unwrap();
      final mamaAccount = (await mama.onboarding.account()).unwrap();
      expect(mamaAccount.pendingInvitations, isEmpty);
      final byId = await mama.invitations.accept(
        invitationId: invite.id,
        displayName: 'Mama',
        deviceLabel: 'Mamas Handy',
      );
      expect(byId.failureOrNull?.code, 'email_not_confirmed');
      final joined = (await mama.invitations.accept(
        secret: invite.code,
        displayName: 'Mama',
        deviceLabel: 'Mamas Handy',
      )).unwrap();
      expect(joined, isA<Accepted>());
      final mamaId = (joined as Accepted).profileId;

      // Mama forgets her password: Papa's phone makes a code, her signed-out phone uses it.
      final code = (await founder.admin.createPasswordResetCode(
        actorProfileId: founderId,
        profileId: mamaId,
      )).unwrap();
      expect(code.code, hasLength(8));
      final newPhone = device();
      final wrong = await newPhone.identity.redeemPasswordReset(
        email: mamaEmail,
        code: 'ZZZZZZZZ',
        password: 'a new password 1',
      );
      expect(wrong.failureOrNull?.code, 'code_invalid');
      (await newPhone.identity.redeemPasswordReset(
        email: mamaEmail,
        code: code.code,
        password: 'a new password 1',
      )).unwrap();
      expect(newPhone.client.auth.currentSession, isNotNull);

      final again = await device().identity.redeemPasswordReset(
        email: mamaEmail,
        code: code.code,
        password: 'yet another one 1',
      );
      expect(again.failureOrNull?.code, 'code_invalid', reason: 'once');
      final old = await device().identity.signIn(mamaEmail, 'mama password 1');
      expect(old.failureOrNull, isA<AuthFailure>());
      (await device().identity.signIn(mamaEmail, 'a new password 1')).unwrap();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );
}

class _Device {
  _Device(this.client)
    : api = ApiClient(client),
      identity = IdentityRepository(ApiClient(client), client.auth),
      admin = AccountAdminRepository(ApiClient(client), client.auth),
      onboarding = HouseholdOnboardingRepository(
        ApiClient(client),
        client.auth,
      ),
      invitations = ApiInvitationRepository(ApiClient(client), client.auth);

  final SupabaseClient client;
  final ApiClient api;
  final IdentityRepository identity;
  final AccountAdminRepository admin;
  final HouseholdOnboardingRepository onboarding;
  final InvitationRepository invitations;
}

/// In-memory PKCE storage for one simulated device, as in onboarding_integration_test.dart.
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
