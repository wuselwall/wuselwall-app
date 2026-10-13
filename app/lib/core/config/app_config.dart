/// Build-time configuration, injected with `--dart-define-from-file=env/<name>.json`.
///
/// Nothing secret belongs here: the publishable key is public by design and the
/// database's row-level security is what protects the data (ADR-010).
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.appleSignIn = false,
    this.googleWebClientId = '',
    this.googleIosClientId = '',
  });

  /// Reads the compile-time defines. Call [validate] before using the result.
  factory AppConfig.fromEnvironment() => const AppConfig(
    environment: String.fromEnvironment('ENV', defaultValue: 'dev'),
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    appleSignIn: bool.fromEnvironment('APPLE_SIGN_IN'),
    googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
  );

  final String environment;
  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Whether the server has Sign in with Apple configured (specs/10 §4). The native
  /// sheet on iOS needs nothing else; Android and the web use the server's redirect.
  final bool appleSignIn;

  /// Google's OAuth client of type "Web": the audience of every ID token Supabase
  /// accepts, and `serverClientId` for the native sheets. Empty: no Google sign-in.
  final String googleWebClientId;

  /// Google's OAuth client of type "iOS"; needed by the native sheet on iOS only.
  final String googleIosClientId;

  bool get isProd => environment == 'prod';

  /// Names of the settings that are missing; empty when the config is usable.
  List<String> validate() => [
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
  ];
}
