import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/supabase/secure_session_storage.dart';

/// Where Supabase's OAuth redirect returns to the native apps. Registered as a URL
/// scheme on iOS and an intent filter on Android, and in the server's redirect
/// allow-list (`ADDITIONAL_REDIRECT_URLS`).
const authRedirectUri = 'ch.goomba.wuselwall://login-callback/';

/// Initialises the one Supabase client.
///
/// PostgREST exposes only the `api` schema (ADR-010), so it is also the client's
/// default schema: a feature repository can never address an `app` table by accident.
Future<void> initSupabase(AppConfig config) async {
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
    authOptions: FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
    postgrestOptions: const PostgrestClientOptions(schema: 'api'),
  );
}
