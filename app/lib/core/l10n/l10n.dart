import 'package:flutter/widgets.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

export 'package:wuselwall/l10n/generated/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension FailureL10n on Failure {
  /// A message fit for a household member, in the current language. A stable domain
  /// code from the backend (the `hint` of an `api` function's exception) wins over the
  /// generic message for the failure's kind.
  String message(AppLocalizations l10n) {
    final byCode = switch (code) {
      'setup_token_invalid' => l10n.errSetupTokenInvalid,
      'setup_closed' => l10n.errSetupClosed,
      'password_too_short' => l10n.errPasswordTooShort,
      'pin_format' => l10n.errPinFormat,
      'code_invalid' => l10n.errCodeInvalid,
      'guardian_required' => l10n.errGuardianRequired,
      'device_revoked' => l10n.errDeviceRevoked,
      'actor_required' => l10n.errActorRequired,
      'name_required' => l10n.errNameRequired,
      'list_exists' => l10n.errListExists,
      'spec_too_long' => l10n.errSpecTooLong,
      'kiosk_forbidden' => l10n.errKioskForbidden,
      'category_not_found' => l10n.errCategoryNotFound,
      'name_too_long' => l10n.errNameTooLong,
      'actor_invalid' => l10n.errActorInvalid,
      'invalid_credentials' => l10n.errInvalidLogin,
      'rate_limited' => l10n.errRateLimited,
      'mfa_required' => l10n.errMfaRequired,
      'session_invalid' => l10n.errorAuth,
      'provider_failed' => l10n.errProviderFailed,
      'signup_disabled' => l10n.errSignupDisabled,
      'identity_already_exists' => l10n.errIdentityAlreadyExists,
      'single_identity_not_deletable' => l10n.errLastSignInMethod,
      'email_exists' => l10n.errEmailExists,
      'setting_invalid' => l10n.errSettingInvalid,
      'setting_unknown' => l10n.errSettingUnknown,
      'setting_target' => l10n.errSettingTarget,
      'event_invalid' => l10n.errEventInvalid,
      'rrule_invalid' => l10n.errRruleInvalid,
      'attendee_invalid' => l10n.errAttendeeInvalid,
      'event_not_found' => l10n.errEventNotFound,
      'subject_in_use' => l10n.schoolSubjectInUse,
      'school_invalid' => l10n.schoolInvalid,
      'task_invalid' => l10n.errTaskInvalid,
      'task_not_yours' => l10n.errTaskNotYours,
      'balance_insufficient' => l10n.errBalanceInsufficient,
      'reward_out_of_stock' => l10n.errRewardOutOfStock,
      'task_not_open' => l10n.errTaskNotOpen,
      'meal_invalid' => l10n.errMealInvalid,
      'personal_device_required' => l10n.exportPersonalDeviceRequired,
      _ => null,
    };
    if (byCode != null) return byCode;
    return switch (this) {
      NetworkFailure() => l10n.errorNetwork,
      AuthFailure() => l10n.errorAuth,
      PermissionFailure() => l10n.errorPermission,
      NotFoundFailure() => l10n.errorNotFound,
      ConflictFailure() => l10n.errorConflict,
      ValidationFailure() => l10n.errorValidation,
      UnknownFailure() => l10n.errorUnknown,
    };
  }
}
