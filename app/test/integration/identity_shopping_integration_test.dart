@Tags(['integration'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otp/otp.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';

/// The whole M0.1 + M0.2 story against a real backend:
/// `flutter test test/integration --dart-define-from-file=env/ci.json` against a throwaway
/// stack (CI starts one; locally `npx supabase start`).
///
/// Idempotent on a database that already has the household (setup is then skipped and
/// the guardian just signs in), so it can run repeatedly without a reset.
void main() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  // It creates a household, devices and items and revokes devices: throwaway stacks
  // only (CI, or a local `supabase start`), never the family's environment (ADR-013).
  final host = Uri.tryParse(url)?.host;
  final skip = url.isEmpty
      ? 'no backend configured (SUPABASE_URL)'
      : !{'127.0.0.1', 'localhost'}.contains(host)
      ? 'refusing to run against $host: throwaway stacks only (ADR-013)'
      : null;

  const email = 'papa@example.org';
  const password = 'correct-horse-battery';
  const pin = '123456';

  setUpAll(() => HttpOverrides.global = null);

  Future<DeviceInfo> ensureDevice(IdentityRepository repo, String label) async {
    final existing = (await repo.currentDevice()).unwrap();
    if (existing != null) return existing;
    expect((await repo.myProfile()).unwrap(), isNotNull);
    return (await repo.registerPersonalDevice(label)).unwrap();
  }

  SupabaseClient newClient() => SupabaseClient(
    url,
    key,
    postgrestOptions: const PostgrestClientOptions(schema: 'api'),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  (SupabaseClient, IdentityRepository, ShoppingRepository) stack() {
    final client = newClient();
    addTearDown(client.dispose);
    final api = ApiClient(client);
    return (
      client,
      IdentityRepository(api, client.auth),
      ShoppingRepository(api),
    );
  }

  test(
    'household → guardian → enrol shared device → shopping → revoke',
    () async {
      // --- the guardian's phone -------------------------------------------------
      final (_, guardianRepo, guardianShop) = stack();
      final setup = await guardianRepo.setupHousehold(
        token: 'dev-setup',
        householdName: 'Haus Wusel',
        displayName: 'Papa',
        email: email,
        password: password,
        pin: pin,
        colorHex: '#2E7D6B',
      );
      if (setup case Err(:final failure)) {
        expect(
          failure.code,
          'setup_closed',
          reason: 'only "already set up" is acceptable',
        );
        expect((await guardianRepo.signIn(email, password)).isOk, isTrue);
      }

      // A fresh sign-in has no device on its session: the phone registers itself.
      expect(
        (await guardianRepo.currentDevice()).unwrap() == null ||
            (await guardianRepo.currentDevice()).unwrap()!.label.isNotEmpty,
        isTrue,
      );
      final guardianDevice = await ensureDevice(guardianRepo, 'Papas Handy');
      expect(guardianDevice.deviceClass, DeviceClass.personal);
      final guardian = (await guardianRepo.members()).unwrap().firstWhere(
        (m) => m.isGuardian,
      );
      expect(guardianDevice.profileId, guardian.id);

      // --- add a member, create an enrolment code ----------------------------------
      final stamp = DateTime.now().millisecondsSinceEpoch;
      (await guardianRepo.addMember(
        actor: null,
        name: 'Kind $stamp',
        colorHex: '#FF8800',
      )).unwrap();
      final kid = (await guardianRepo.members()).unwrap().firstWhere(
        (m) => m.displayName == 'Kind $stamp',
      );

      final code = (await guardianRepo.createEnrolmentCode(
        actor: null,
        label: 'iPad $stamp',
        deviceClass: DeviceClass.shared,
        register: UiRegister.kid,
      )).unwrap();
      expect(code.code, hasLength(8));

      // --- the child's iPad enrols with the code -------------------------------------
      final (_, ipadRepo, ipadShop) = stack();
      expect((await ipadRepo.enrolDevice(code.code)).isOk, isTrue);
      final ipad = (await ipadRepo.currentDevice()).unwrap()!;
      expect(ipad.deviceClass, DeviceClass.shared);
      expect(ipad.register, UiRegister.kid);
      expect(ipad.profileId, isNull);

      // The code is single use.
      final (_, otherRepo, _) = stack();
      expect(
        (await otherRepo.enrolDevice(code.code)).failureOrNull?.code,
        'code_invalid',
      );

      // A shared device must name an acting profile ...
      final noActor = await ipadShop.add(actor: null, name: 'Brot');
      expect(noActor.failureOrNull?.code, 'actor_required');

      // ... and a member cannot do guardian things, even by naming the guardian
      // (no PIN yet).
      final denied = await ipadRepo.createEnrolmentCode(
        actor: guardian.id,
        label: 'x',
        deviceClass: DeviceClass.shared,
        register: UiRegister.kid,
      );
      expect(denied.failureOrNull, isA<PermissionFailure>());
      expect(denied.failureOrNull?.code, 'guardian_required');

      // --- realtime: the guardian's phone hears the iPad's change -----------------------
      final topics = StreamController<String>.broadcast();
      addTearDown(topics.close);
      // A second phone of the same guardian: its own session, its own device row.
      final (guardianClient, phone2Repo, _) = stack();
      expect((await phone2Repo.signIn(email, password)).isOk, isTrue);
      final phone2 = await ensureDevice(phone2Repo, 'Mamas Handy');
      expect(phone2.deviceId, isNot(guardianDevice.deviceId));
      // The socket must authorise with the *refreshed* token (it carries the device claims).
      await guardianClient.realtime.setAuth(
        guardianClient.auth.currentSession!.accessToken,
      );
      final channel = guardianClient
          .channel(
            'household:${guardianDevice.householdId}',
            opts: const RealtimeChannelConfig(private: true),
          )
          .onBroadcast(
            event: 'invalidate',
            callback: (message) {
              final body = message['payload'] as Map<String, dynamic>?;
              final topic = body?['topic'];
              if (topic is String) topics.add(topic);
            },
          );
      final subscribed = Completer<void>();
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed &&
            !subscribed.isCompleted) {
          subscribed.complete();
        }
      });
      await subscribed.future.timeout(const Duration(seconds: 10));

      // Realtime sets up its database replication lazily on the first join, so on a
      // freshly started stack (every CI run) the first broadcasts can be lost. Poke with
      // a throwaway item until one arrives, then remove it.
      String? warmUp;
      for (var attempt = 1; ; attempt++) {
        final next = topics.stream.firstWhere((t) => t == 'shopping');
        warmUp = (await ipadShop.add(
          actor: kid.id,
          name: 'Warm-up $stamp',
        )).unwrap();
        try {
          await next.timeout(const Duration(seconds: 5));
          break;
        } on TimeoutException {
          if (attempt == 6) rethrow;
        }
      }
      final removed = topics.stream.firstWhere((t) => t == 'shopping');
      (await ipadShop.adjustCount(
        actor: kid.id,
        itemId: warmUp,
        delta: -99,
      )).unwrap();
      await removed.timeout(const Duration(seconds: 5));

      // --- shopping from the iPad as the child: seen live by the guardian (NFR-5) --------
      final heard = topics.stream.firstWhere((t) => t == 'shopping');
      (await ipadShop.add(
        actor: kid.id,
        name: 'Milch $stamp',
        quantity: '2 l',
      )).unwrap();
      await heard.timeout(const Duration(seconds: 5));

      final items = (await guardianShop.items()).unwrap();
      final milk = items.firstWhere((i) => i.name == 'Milch $stamp');
      expect(milk.quantity, '2 l');
      expect(milk.checked, isFalse);

      (await guardianShop.toggle(actor: null, itemId: milk.id)).unwrap();
      expect(
        (await ipadShop.items())
            .unwrap()
            .firstWhere((i) => i.id == milk.id)
            .checked,
        isTrue,
      );

      // --- M1.1: finishing teaches the catalogue; adding again merges into a count ------
      final trip = (await guardianShop.finish(actor: null)).unwrap();
      expect(trip.bought, greaterThanOrEqualTo(1));
      final lists = (await guardianShop.lists()).unwrap();
      final defaultList = lists.firstWhere((l) => l.isDefault);
      final catalog = (await guardianShop.catalog()).unwrap();
      expect(catalog.map((c) => c.name), contains('Milch $stamp'));
      expect((await guardianShop.trips(defaultList.id)).unwrap(), isNotEmpty);
      final again = (await ipadShop.add(
        actor: kid.id,
        name: 'milch $stamp',
      )).unwrap();
      expect(
        (await ipadShop.add(actor: kid.id, name: 'MILCH $stamp')).unwrap(),
        again,
      );
      final merged = (await guardianShop.items()).unwrap().firstWhere(
        (i) => i.id == again,
      );
      expect((merged.name, merged.count), ('Milch $stamp', 2));

      // --- PIN step-up on the shared device, then a guardian action ----------------------
      final wrong = (await ipadRepo.verifyPin(
        profileId: guardian.id,
        pin: '000000',
      )).unwrap();
      expect(wrong, isA<PinWrong>());
      final ok = (await ipadRepo.verifyPin(
        profileId: guardian.id,
        pin: pin,
      )).unwrap();
      expect(ok, isA<PinVerified>());
      (await ipadRepo.createEnrolmentCode(
        actor: guardian.id,
        label: 'y',
        deviceClass: DeviceClass.shared,
        register: UiRegister.kid,
      )).unwrap();

      // --- revoke the iPad: it is locked out on its very next request ---------------------
      (await guardianRepo.revokeDevice(
        actor: null,
        deviceId: ipad.deviceId,
      )).unwrap();
      final after = await ipadShop.items();
      expect(!after.isOk || after.valueOrNull!.isEmpty, isTrue);

      await guardianClient.removeChannel(channel);
      await guardianShop.finish(actor: null);

      // --- per-phone revocation: blocking phone 2 leaves phone 1 working -----------------
      (await guardianRepo.revokeDevice(
        actor: null,
        deviceId: phone2.deviceId,
      )).unwrap();
      final phone2After = await phone2Repo.currentDevice();
      expect(
        !phone2After.isOk || phone2After.valueOrNull?.revoked == true,
        isTrue,
      );
      expect((await guardianShop.items()).isOk, isTrue);

      // --- second factor: enrol TOTP, then a new sign-in is gated until the code ---------
      final totp = (await guardianRepo.totpEnrol()).unwrap();
      String codeFor(DateTime at) => OTP.generateTOTPCodeString(
        totp.secret,
        at.millisecondsSinceEpoch,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );
      (await guardianRepo.totpVerify(
        totp.factorId,
        codeFor(DateTime.now()),
      )).unwrap();
      expect(guardianRepo.mfaState(), MfaState.satisfied);

      final (_, phone3Repo, phone3Shop) = stack();
      expect((await phone3Repo.signIn(email, password)).isOk, isTrue);
      expect(phone3Repo.mfaState(), MfaState.challengeRequired);
      // Registering a device is allowed pre-MFA, but household data stays invisible.
      final phone3 = await ensureDevice(phone3Repo, 'Opas Handy');
      expect(phone3.label, 'Opas Handy');
      expect((await phone3Shop.items()).valueOrNull ?? const [], isEmpty);
      expect((await phone3Shop.add(actor: null, name: 'nope')).isOk, isFalse);

      // A code from the next 30 s step: a code is single use per step.
      (await phone3Repo.totpChallenge(
        codeFor(DateTime.now().add(const Duration(seconds: 30))),
      )).unwrap();
      expect(phone3Repo.mfaState(), MfaState.satisfied);
      expect((await phone3Shop.items()).isOk, isTrue);

      // Leave the database as found, so the test can run again.
      (await phone3Repo.totpDisable(totp.factorId)).unwrap();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
