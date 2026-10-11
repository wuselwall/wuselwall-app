/// Build-time configuration, injected with `--dart-define-from-file=env/<name>.json`.
///
/// Nothing secret belongs here: the publishable key is public by design and the
/// database's row-level security is what protects the data (ADR-010).
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  /// Reads the compile-time defines. Call [validate] before using the result.
  factory AppConfig.fromEnvironment() => const AppConfig(
    environment: String.fromEnvironment('ENV', defaultValue: 'dev'),
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final String environment;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get isProd => environment == 'prod';

  /// Names of the settings that are missing; empty when the config is usable.
  List<String> validate() => [
    if (supabaseUrl.isEmpty) 'SUPABASE_URL',
    if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
  ];
}
