import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/features/account/domain/member_security.dart';
import 'package:wuselwall/features/account/domain/sign_in_freshness.dart';

/// Deleting the account, resetting another guardian's second factor, and what a guardian sees
/// of the household's security (specs/20 J4 and J6). Holds no rules: the Edge Functions and
/// the `api` functions do.
class AccountAdminRepository {
  const AccountAdminRepository(this._api, this._auth);

  final ApiClient _api;
  final GoTrueClient _auth;

  /// The sign-in provider of the current session: `email`, `apple`, `google`, or null.
  String? currentProvider() =>
      _auth.currentUser?.appMetadata['provider'] as String?;

  /// Whether the current session signed in within the last five minutes.
  bool hasRecentSignIn() {
    final token = _auth.currentSession?.accessToken;
    if (token == null) return false;
    return signedInRecently(token, now: DateTime.now());
  }

  /// Deletes the account (account-delete). A `reauth_required` failure means the sign-in is
  /// older than five minutes. On success the account is gone: this phone signs out locally.
  Future<Result<void>> deleteAccount() async {
    final deleted = await _api.function<void>(
      'account-delete',
      body: const {},
      parse: (_) {},
    );
    if (deleted is Err<void>) return deleted;
    try {
      await _auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // The account is gone already; the session is dropped on the next start regardless.
    }
    return const Ok(null);
  }

  /// Removes another guardian's authenticator (mfa-reset). The server decides who may.
  Future<Result<void>> resetMfa({
    required String actorProfileId,
    required String profileId,
  }) => _api.function<void>(
    'mfa-reset',
    body: {'actor_profile_id': actorProfileId, 'profile_id': profileId},
    parse: (_) {},
  );

  /// The household's adults with their account and second-factor state, for a guardian.
  Future<Result<List<MemberSecurity>>> memberSecurity(String actorProfileId) =>
      _api.rpc(
        'member_security',
        params: {'p_actor': actorProfileId},
        parse: (json) => [
          for (final row in (json as List? ?? const []))
            MemberSecurity.fromJson(row as Map<String, dynamic>),
        ],
      );
}
