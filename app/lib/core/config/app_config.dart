import 'package:wuselwall/core/server/first_party.dart';
import 'package:wuselwall/core/server/server_info.dart';

/// The configuration the app runs with: the build's
/// (`--dart-define-from-file=env/<name>.json`), and the server's.
///
/// A development build names its server (`SUPABASE_URL`) and never asks. A store build
/// names none: the person chooses one, and [AppConfig.forServer] combines the build with
/// that server's discovery document (ADR-018).
///
/// Nothing secret belongs here: the publishable key is public by design and the
/// database's row-level security is what protects the data (ADR-010).
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.appleSignIn = false,
    this._googleSignIn,
    this.googleWebClientId = '',
    this.googleIosClientId = '',
    this.nativeSignIn = true,
    this.server,
  });

  /// The build combined with a chosen server. The native sheets and their client IDs
  /// stay with the project's own servers (ADR-018, decision 6); elsewhere Apple and
  /// Google go through the operator's own redirect, if they configured one.
  factory AppConfig.forServer(AppConfig build, ServerInfo server) {
    final firstParty = isFirstParty(server.supabaseUrl);
    return AppConfig(
      environment: build.environment,
      supabaseUrl: server.supabaseUrl.toString().replaceAll(RegExp(r'/$'), ''),
      supabasePublishableKey: server.publishableKey,
      appleSignIn: server.appleSignIn,
      googleSignIn: server.googleSignIn,
      googleWebClientId: firstParty ? build.googleWebClientId : '',
      googleIosClientId: firstParty ? build.googleIosClientId : '',
      nativeSignIn: firstParty,
      server: server,
    );
  }

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

  final bool? _googleSignIn;

  /// Whether the server offers Google: from its discovery document, or for a build with
  /// a fixed server, whether the build carries Google's client.
  bool get googleSignIn => _googleSignIn ?? googleWebClientId.isNotEmpty;

  /// Whether the native Apple and Google sheets and passkeys may be used: only with the
  /// project's own servers (WW_FIRST_PARTY_HOSTS) and builds that name their server.
  final bool nativeSignIn;

  /// The chosen server, or null for a build that names its own (`SUPABASE_URL`).
  final ServerInfo? server;

  /// Whether this build names its server; otherwise the person chooses one.
  bool get hasFixedServer => server == null && supabaseUrl.isNotEmpty;

  bool get isProd => environment == 'prod';

  /// Names of the settings that are missing; empty when the config is usable. A build
  /// without `SUPABASE_URL` is a store build, which asks for its server instead.
  List<String> validate() => [
    if (supabaseUrl.isNotEmpty && supabasePublishableKey.isEmpty)
      'SUPABASE_PUBLISHABLE_KEY',
  ];
}
