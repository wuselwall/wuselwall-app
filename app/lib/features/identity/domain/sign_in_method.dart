import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;

/// The providers an adult can sign in with besides email (ADR-014).
enum SignInProvider {
  apple(OAuthProvider.apple),
  google(OAuthProvider.google);

  const SignInProvider(this.oauth);

  final OAuthProvider oauth;

  SignInMethodKind get kind => SignInMethodKind.fromProvider(name);
}

/// How a provider is reached on this platform.
enum ProviderRoute {
  /// The platform's own sheet, then Supabase's id-token grant.
  native,

  /// Supabase's OAuth redirect through the browser.
  redirect,
}

/// A kind of linked sign-in method, as Settings lists them.
enum SignInMethodKind {
  email,
  apple,
  google,
  other;

  static SignInMethodKind fromProvider(String provider) => switch (provider) {
    'email' => email,
    'apple' => apple,
    'google' => google,
    _ => other,
  };

  SignInProvider? get provider => switch (this) {
    apple => SignInProvider.apple,
    google => SignInProvider.google,
    _ => null,
  };
}

/// One way into the account (an Auth identity).
class SignInMethod {
  const SignInMethod({
    required this.identityId,
    required this.provider,
    this.email,
  });

  final String identityId;
  final SignInMethodKind provider;

  /// The address the provider vouched for; an Apple relay address looks like
  /// `…@privaterelay.appleid.com`.
  final String? email;
}
