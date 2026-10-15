import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/features/identity/data/pairing_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';

import '../support/fake_tasks.dart';

Failure _cause(Failure failure) =>
    failure is UnknownFailure && failure.cause is Failure
    ? failure.cause! as Failure
    : failure;

void main() {
  group('parsePairingCode', () {
    test('reads the bare code in any case, with or without the hyphen', () {
      expect(parsePairingCode('K7QM3XRP'), 'K7QM3XRP');
      expect(parsePairingCode('K7QM-3XRP'), 'K7QM3XRP');
      expect(parsePairingCode(' k7qm 3xrp '), 'K7QM3XRP');
    });

    test('reads the code from the link the new device shows', () {
      final payload = pairingQrPayload('K7QM3XRP');
      expect(payload, 'https://wuselwall.app/p/#K7QM3XRP');
      expect(parsePairingCode(payload), 'K7QM3XRP');
      expect(parsePairingCode('https://wuselwall.app/p/K7QM-3XRP'), 'K7QM3XRP');
    });

    test('refuses what is not a pairing code', () {
      expect(parsePairingCode(''), isNull);
      expect(parsePairingCode('K7QM3XR'), isNull, reason: 'seven symbols');
      expect(
        parsePairingCode('K7QM3XR0'),
        isNull,
        reason: 'zero is not in the alphabet',
      );
      expect(
        parsePairingCode('K7QM3XRI'),
        isNull,
        reason: 'I is not in the alphabet',
      );
      expect(parsePairingCode('https://example.org/p/#K7QM3XRP'), isNull);
      expect(parsePairingCode('wuselwall://enrol?code=ABCD2345'), isNull);
    });

    test('formats the code for reading out: four and four', () {
      expect(formatPairingCode('K7QM3XRP'), 'K7QM-3XRP');
    });
  });

  group('PairingKind', () {
    test('maps each choice to its device class and register', () {
      expect(PairingKind.wallDisplay.deviceClass, DeviceClass.kiosk);
      expect(PairingKind.wallDisplay.register, UiRegister.kiosk);
      expect(PairingKind.kidTablet.deviceClass, DeviceClass.shared);
      expect(PairingKind.kidTablet.register, UiRegister.kid);
      expect(PairingKind.familyTablet.deviceClass, DeviceClass.shared);
      expect(PairingKind.familyTablet.register, UiRegister.adult);
      expect(PairingKind.childPhone.deviceClass, DeviceClass.personal);
      expect(PairingKind.childPhone.register, UiRegister.kid);
    });

    test('only a child phone is bound to a child', () {
      expect(PairingKind.values.where((k) => k.bindsChild), [
        PairingKind.childPhone,
      ]);
    });

    test('the wire values are the ones api.pairing_approve takes', () {
      expect(PairingKind.values.map((k) => k.wire), [
        'wall_display',
        'kid_tablet',
        'family_tablet',
        'child_phone',
      ]);
      expect(PairingKind.fromWire('kid_tablet'), PairingKind.kidTablet);
      expect(PairingKind.fromWire('nope'), isNull);
      expect(PairingKind.fromWire(null), isNull);
    });
  });

  group('PairingPoll.fromJson', () {
    test('reads each status the server answers with', () {
      expect(
        PairingPoll.fromJson({'status': 'pending'}),
        isA<PairingPending>(),
      );
      expect(
        PairingPoll.fromJson({'status': 'expired'}),
        isA<PairingExpired>(),
      );
      expect(
        PairingPoll.fromJson({'status': 'rate_limited'}),
        isA<PairingRateLimited>(),
      );
      expect(
        PairingPoll.fromJson({'status': 'invalid'}),
        isA<PairingInvalid>(),
      );
      expect(
        PairingPoll.fromJson({'status': 'something new'}),
        isA<PairingInvalid>(),
      );
    });

    test('an approval carries the credentials and the device it becomes', () {
      final poll = PairingPoll.fromJson({
        'status': 'approved',
        'email': 'device-1@devices.wuselwall.invalid',
        'password': 'secret',
        'household_name': 'Familie Huser',
        'class': 'shared',
        'register': 'kid',
      });
      expect(poll, isA<PairingApproved>());
      final approved = poll as PairingApproved;
      expect(approved.householdName, 'Familie Huser');
      expect(approved.deviceClass, DeviceClass.shared);
      expect(approved.register, UiRegister.kid);
    });
  });

  group('PairingRepository', () {
    test(
      'a start gives the request; a rate-limited start is a permission failure',
      () async {
        final ok = PairingRepository(
          FakeTasksApi(
            replies: {
              'pairing_start': {
                'ok': true,
                'request_id': 'r-1',
                'secret': 's-1',
                'code': 'K7QM3XRP',
                'expires_at': '2030-01-01T00:10:00Z',
              },
            },
          ),
        );
        final request = (await ok.start()).valueOrNull!;
        expect(request.requestId, 'r-1');
        expect(request.code, 'K7QM3XRP');

        final limited = PairingRepository(
          FakeTasksApi(
            replies: {
              'pairing_start': {'ok': false, 'reason': 'rate_limited'},
            },
          ),
        );
        final failure = (await limited.start()).failureOrNull!;
        expect(_cause(failure), isA<PermissionFailure>());
        expect(_cause(failure).code, 'rate_limited');
      },
    );

    test(
      'an approval sends the kind and the child, and reads the device back',
      () async {
        final api = FakeTasksApi(
          replies: {
            'pairing_approve': {
              'ok': true,
              'device_id': 'd-7',
              'label': 'Handy von Anna',
              'needs_pin': true,
            },
          },
        );
        final approval = (await PairingRepository(api).approve(
          code: 'K7QM3XRP',
          kind: PairingKind.childPhone,
          label: ' Handy von Anna ',
          childProfileId: 'p-kid',
        )).valueOrNull!;

        expect(approval.deviceId, 'd-7');
        expect(approval.label, 'Handy von Anna');
        expect(approval.needsPin, isTrue);
        final call = api.named('pairing_approve').single.params!;
        expect(call['p_kind'], 'child_phone');
        expect(call['p_profile'], 'p-kid');
        expect(
          call['p_actor'],
          isNull,
          reason: 'the phone is personal: the server reads the actor',
        );
        expect(call['p_label'], 'Handy von Anna');
      },
    );

    test('a wrong or expired code is a validation failure, a limit a permission one', () async {
      final wrong = PairingRepository(
        FakeTasksApi(
          replies: {
            'pairing_approve': {'ok': false, 'reason': 'code_invalid'},
          },
        ),
      );
      expect(
        _cause(
          (await wrong.approve(
            code: 'XXXXXXXX',
            kind: PairingKind.kidTablet,
            label: 'Tablet',
          )).failureOrNull!,
        ).code,
        'code_invalid',
      );

      final limited = PairingRepository(
        FakeTasksApi(
          replies: {
            'pairing_approve': {'ok': false, 'reason': 'rate_limited'},
          },
        ),
      );
      expect(
        _cause(
          (await limited.approve(
            code: 'XXXXXXXX',
            kind: PairingKind.kidTablet,
            label: 'Tablet',
          )).failureOrNull!,
        ),
        isA<PermissionFailure>(),
      );
    });

    test('a poll hands back the status the device acts on', () async {
      final repo = PairingRepository(
        FakeTasksApi(
          replies: {
            'pairing_poll': {'status': 'pending'},
          },
        ),
      );
      final request = PairingRequest(
        requestId: 'r-1',
        secret: 's-1',
        code: 'K7QM3XRP',
        expiresAt: DateTime(2030),
      );
      expect((await repo.poll(request)).valueOrNull, isA<PairingPending>());
    });
  });
}
