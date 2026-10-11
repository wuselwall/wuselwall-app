import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/supabase/api_client.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(supabaseClientProvider)),
);

/// The current auth state, as a stream Riverpod can watch.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
);

/// The signed-in Auth user's id, or null. Unlike the session itself it does not change
/// when the access token is refreshed, so watching it does not cause hourly rebuilds.
final sessionUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});
