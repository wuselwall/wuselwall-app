import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/supabase/secure_session_storage.dart';

/// Initialises the one Supabase client.
///
/// PostgREST exposes only the `api` schema (ADR-010), so it is also the client's
/// default schema: a feature repository can never address an `app` table by accident.
Future<void> initSupabase(AppConfig config) async {
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
    authOptions: supabaseAuthOptions(),
    postgrestOptions: const PostgrestClientOptions(schema: 'api'),
  );
}

/// How the client keeps and finds its session.
///
/// The session lives in the platform's secure storage. It is never read from a link:
/// the app signs in with codes and passwords only (no magic links, no OAuth callbacks),
/// and supabase_flutter's default would take any opened app link or web address that
/// carries `access_token` or `code` as a sign-in, so a crafted link could replace the
/// signed-in account with someone else's (security review 2026-11-01, F2).
FlutterAuthClientOptions supabaseAuthOptions({LocalStorage? storage}) =>
    FlutterAuthClientOptions(
      localStorage: storage ?? SecureSessionStorage(),
      detectSessionInUri: false,
    );
