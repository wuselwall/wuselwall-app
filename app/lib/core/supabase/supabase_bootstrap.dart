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
    authOptions: authClientOptions(SecureSessionStorage()),
    postgrestOptions: const PostgrestClientOptions(schema: 'api'),
  );
}

/// The client's Auth options. Sign-in is by e-mail (a code or a password) or a passkey,
/// never through a browser redirect, so the client never takes a session from a link:
/// a link carrying an OAuth `code` or tokens (an old Apple or Google callback, say)
/// cannot sign anyone in.
FlutterAuthClientOptions authClientOptions(LocalStorage localStorage) =>
    FlutterAuthClientOptions(
      localStorage: localStorage,
      detectSessionInUri: false,
    );
