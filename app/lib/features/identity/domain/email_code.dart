// The rules of the e-mail sign-in (specs/20, "With email"). Pure Dart: the screens and
// the router read these, and the tests pin them down.

/// Shortest password the app sets, in Settings and on E3.
const passwordMinLength = 10;

/// Digits in the code the server mails (`otp_length` in supabase/config.toml).
const emailCodeLength = 6;

/// Seconds before "Erneut senden" is offered (`max_frequency` in supabase/config.toml).
const emailCodeResendSeconds = 60;

/// User-metadata marker written once E3 has been answered (`sign_in_choice`: `code` or
/// `password`). Its absence on a young account is how E3 is recognised.
const signInChoiceKey = 'sign_in_choice';

/// User-metadata flag set when a password is set in the app, so Settings can say
/// "ändern" instead of "festlegen". Accounts made before this flag read as "festlegen".
const hasPasswordKey = 'has_password';

/// How long after its creation an account still counts as new for E3.
const newAccountWindow = Duration(minutes: 10);

/// Tolerance for a device clock that runs behind the server's.
const newAccountClockSkew = Duration(minutes: 5);

/// Whether a code sign-in just created (or first used) this account, so E3 is owed:
/// the account has no [signInChoiceKey] marker yet and was created within
/// [newAccountWindow]. An account that predates the marker is never new in this sense,
/// because it is older than the window. An account signed in by Apple or Google just
/// now and never answered E3 would also pass this check; E3 then appears once, which is
/// harmless. An app closed before E3 is answered leaves the account to H1 after the
/// window has passed.
bool isFirstCodeSignIn({
  required String createdAt,
  required Map<String, dynamic>? userMetadata,
  required DateTime now,
}) {
  if (userMetadata?.containsKey(signInChoiceKey) ?? false) return false;
  final created = DateTime.tryParse(createdAt);
  if (created == null) return false;
  final age = now.difference(created);
  return age >= -newAccountClockSkew && age <= newAccountWindow;
}

enum PasswordStrength { tooShort, weak, fair, strong }

/// Length plus character classes, no dictionary: a simple indicator, not a verdict.
PasswordStrength ratePassword(String password) {
  if (password.length < passwordMinLength) return PasswordStrength.tooShort;
  final classes = [
    RegExp('[a-z]'),
    RegExp('[A-Z]'),
    RegExp('[0-9]'),
    RegExp('[^a-zA-Z0-9]'),
  ].where((r) => r.hasMatch(password)).length;
  final score =
      classes +
      (password.length >= 14 ? 1 : 0) +
      (password.length >= 18 ? 1 : 0);
  return switch (score) {
    <= 2 => PasswordStrength.weak,
    <= 4 => PasswordStrength.fair,
    _ => PasswordStrength.strong,
  };
}
