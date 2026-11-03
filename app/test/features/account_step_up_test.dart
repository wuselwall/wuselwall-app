import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/features/account/ui/reauth_dialogs.dart';

void main() {
  group('a step-up refusal (security review 2026-11-01, F3/F10/F23)', () {
    test('reauth_required and mfa_required from the server ask for a fresh sign-in', () {
      expect(
        isStepUpFailure(const PermissionFailure(code: 'reauth_required')),
        isTrue,
      );
      expect(
        isStepUpFailure(const PermissionFailure(code: 'mfa_required')),
        isTrue,
      );
    });

    test('other refusals do not', () {
      expect(
        isStepUpFailure(const PermissionFailure(code: 'guardian_required')),
        isFalse,
      );
      expect(
        isStepUpFailure(const PermissionFailure(code: 'mfa_reset_recent')),
        isFalse,
      );
      expect(
        isStepUpFailure(const ValidationFailure(code: 'reauth_required')),
        isFalse,
      );
      expect(isStepUpFailure(const NetworkFailure()), isFalse);
    });
  });
}
