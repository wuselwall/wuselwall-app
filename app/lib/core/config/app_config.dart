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
    this.passkeys = true,
    this.server,
  });

  /// The build combined with a chosen server. Passkeys stay with the project's own
  /// servers (ADR-018, decision 6).
  factory AppConfig.forServer(AppConfig build, ServerInfo server) => AppConfig(
    environment: build.environment,
    supabaseUrl: server.supabaseUrl.toString().replaceAll(RegExp(r'/$'), ''),
    supabasePublishableKey: server.publishableKey,
    passkeys: isFirstParty(server.supabaseUrl),
    server: server,
  );

  /// Reads the compile-time defines. Call [validate] before using the result.
  factory AppConfig.fromEnvironment() => const AppConfig(
    environment: String.fromEnvironment('ENV', defaultValue: 'dev'),
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final String environment;
  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Whether passkeys may be used: only with the project's own servers
  /// (WW_FIRST_PARTY_HOSTS, whose domain is in the apps' associated domains) and with
  /// builds that name their server.
  final bool passkeys;

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
