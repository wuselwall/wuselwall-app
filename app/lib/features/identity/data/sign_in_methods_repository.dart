import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/error/error_mapper.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_bootstrap.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/identity/data/provider_sheets.dart';
import 'package:wuselwall/features/identity/domain/sign_in_method.dart';

/// Sign in with Apple and Google, and the account's linked methods (specs/20,
/// "The front door" and "Several ways into one account").
///
/// Native sheets hand an ID token to Supabase's id-token grant; where there is no
/// native sheet (Apple on Android, both on the web) Supabase's OAuth redirect runs
/// instead and the session arrives through the deep link.
class SignInMethodsRepository {
  SignInMethodsRepository({
    required this._auth,
    required this._sheets,
    required this._config,
    TargetPlatform? platform,
    this._isWeb = kIsWeb,
    http.Client? httpClient,
    this._api,
  }) : _platform = platform ?? defaultTargetPlatform,
       _http = httpClient ?? http.Client();

  final GoTrueClient _auth;
  final ProviderSheets _sheets;
  final AppConfig _config;
  final TargetPlatform _platform;
  final bool _isWeb;
  final http.Client _http;

  /// Hands Apple's authorisation code to the server (apple-token). Null in tests that do not
  /// care; the store is best effort either way.
  final ApiClient? _api;

  /// How [provider] is reached on this platform, or null when it is not offered
  /// here. The front door never shows a button that will fail.
  ProviderRoute? route(SignInProvider provider) => switch (provider) {
    SignInProvider.apple when !_config.appleSignIn => null,
    SignInProvider.apple when _isWeb => ProviderRoute.redirect,
    SignInProvider.apple => switch (_platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => ProviderRoute.native,
      TargetPlatform.android => ProviderRoute.redirect,
      _ => null,
    },
    SignInProvider.google when _config.googleWebClientId.isEmpty => null,
    SignInProvider.google when _isWeb => ProviderRoute.redirect,
    SignInProvider.google => switch (_platform) {
      TargetPlatform.android => ProviderRoute.native,
      TargetPlatform.iOS when _config.googleIosClientId.isNotEmpty =>
        ProviderRoute.native,
      _ => null,
    },
  };

  /// The providers offered here, in the front door's order: Apple first on Apple
  /// devices, Google first everywhere else.
  List<SignInProvider> available() {
    final appleFirst =
        !_isWeb &&
        (_platform == TargetPlatform.iOS || _platform == TargetPlatform.macOS);
    final order = appleFirst
        ? const [SignInProvider.apple, SignInProvider.google]
        : const [SignInProvider.google, SignInProvider.apple];
    return [
      for (final p in order)
        if (route(p) != null) p,
    ];
  }

  /// Signs in with [provider]. A cancelled sheet is `Ok` and changes nothing. With
  /// the redirect, `Ok` only means the browser opened; the outcome arrives on the
  /// auth state stream (see [authErrors]).
  Future<Result<void>> signIn(SignInProvider provider) => _guard(() async {
    switch (route(provider)) {
      case ProviderRoute.native:
        final credential = await _sheet(provider);
        if (credential == null) return;
        await _auth.signInWithIdToken(
          provider: provider.oauth,
          idToken: credential.idToken,
          nonce: credential.nonce,
        );
        _storeAppleToken(provider, credential);
        await _keepAppleName(credential);
      case ProviderRoute.redirect:
        await _auth.signInWithOAuth(provider.oauth, redirectTo: _redirectTo);
      case null:
        throw const AuthFailure(code: 'provider_failed');
    }
  });

  /// Failures of a redirect sign-in, which come back through the deep link rather
  /// than from [signIn].
  Stream<Failure> authErrors() {
    final errors = StreamController<Failure>();
    final sub = _auth.onAuthStateChange.listen(
      (_) {},
      onError: (Object e, StackTrace st) =>
          errors.add(_providerFailure(mapError(e, st))),
    );
    errors.onCancel = sub.cancel;
    return errors.stream;
  }

  // ------------------------------------------------------------ linked methods

  /// The account's sign-in methods, oldest first.
  Future<Result<List<SignInMethod>>> methods() => Result.guard(() async {
    final identities = await _auth.getUserIdentities();
    return [
      for (final i in identities)
        SignInMethod(
          identityId: i.identityId,
          provider: SignInMethodKind.fromProvider(i.provider),
          email: i.identityData?['email'] as String?,
        ),
    ];
  });

  /// Whether [provider] can be linked on this device. Linking needs the native
  /// sheet: the redirect would come back with a new session, and a personal device
  /// is bound to its session, so this phone would forget it is registered.
  bool canLink(SignInProvider provider) =>
      route(provider) == ProviderRoute.native;

  /// Adds [provider] to the signed-in account. Returns false when cancelled.
  ///
  /// Supabase answers a link with a fresh session. This device keeps its own (its
  /// device record is bound to it), so the fresh one is signed out at once and the
  /// current session refreshed to pick up the new identity.
  Future<Result<bool>> link(SignInProvider provider) => _guard(() async {
    if (!canLink(provider)) throw const AuthFailure(code: 'provider_failed');
    final credential = await _sheet(provider);
    if (credential == null) return false;
    final current = _auth.currentSession;
    if (current == null) throw const AuthFailure(code: 'session_invalid');

    final linked = await _authPost(
      'token',
      query: {'grant_type': 'id_token'},
      accessToken: current.accessToken,
      body: {
        'provider': provider.oauth.name,
        'id_token': credential.idToken,
        'nonce': credential.nonce,
        'link_identity': true,
      },
    );
    final extra = linked['access_token'] as String?;
    if (extra != null) {
      await _authPost('logout', query: {'scope': 'local'}, accessToken: extra);
    }
    await _auth.refreshSession();
    _storeAppleToken(provider, credential);
    await _keepAppleName(credential);
    return true;
  });

  /// Removes a method. Supabase refuses to remove the last one.
  Future<Result<void>> unlink(String identityId) => _guard(() async {
    final identities = await _auth.getUserIdentities();
    final identity = identities.firstWhere(
      (i) => i.identityId == identityId,
      orElse: () => throw const NotFoundFailure(),
    );
    await _auth.unlinkIdentity(identity);
    await _auth.refreshSession();
  });

  // ------------------------------------------------------------ internals

  Future<ProviderCredential?> _sheet(SignInProvider provider) =>
      switch (provider) {
        SignInProvider.apple => _sheets.apple(),
        SignInProvider.google => _sheets.google(),
      };

  /// Where the redirect returns: the web app's own page, or the app's deep link.
  String get _redirectTo =>
      _isWeb ? '${Uri.base.origin}${Uri.base.path}' : authRedirectUri;

  /// Sends Apple's authorisation code to apple-token, so the account can be revoked at Apple
  /// later (specs/20, "Server side"). Fire and forget: the sign-in has already succeeded, and
  /// a missing token only means the revocation cannot be done.
  void _storeAppleToken(SignInProvider provider, ProviderCredential c) {
    final api = _api;
    final code = c.authorizationCode;
    if (api == null || provider != SignInProvider.apple || code == null) return;
    unawaited(
      api
          .function<void>(
            'apple-token',
            body: {'authorization_code': code},
            parse: (_) {},
          )
          .then((result) {
            if (result case Err(:final failure)) {
              logError('Could not store the Apple token', error: failure);
            }
          }),
    );
  }

  /// Apple sends the name only on the first authorisation, so it is written into
  /// the user's metadata at once; onboarding prefills from there. Best effort: the
  /// sign-in has already succeeded.
  Future<void> _keepAppleName(ProviderCredential c) async {
    final names = [c.givenName, c.familyName].whereType<String>();
    if (names.isEmpty) return;
    try {
      await _auth.updateUser(
        UserAttributes(
          data: {
            'given_name': ?c.givenName,
            'family_name': ?c.familyName,
            'full_name': names.join(' '),
          },
        ),
      );
    } catch (e, st) {
      logError('Could not keep the name Apple sent', error: e, stackTrace: st);
    }
  }

  Future<Map<String, dynamic>> _authPost(
    String path, {
    required Map<String, String> query,
    required String accessToken,
    Map<String, Object?>? body,
  }) async {
    final uri = Uri.parse('${_config.supabaseUrl}/auth/v1/$path')
        .replace(queryParameters: query);
    final response = await _http.post(
      uri,
      headers: {
        'apikey': _config.supabasePublishableKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: body == null ? null : jsonEncode(body),
    );
    final json = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 300) {
      throw AuthApiException(
        (json['msg'] ?? json['error_description'] ?? 'auth error').toString(),
        statusCode: '${response.statusCode}',
        code: (json['error_code'] ?? json['code'])?.toString(),
      );
    }
    return json;
  }

  /// Runs [action] and reports any provider error with a code the front door knows.
  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    final result = await Result.guard(action);
    return switch (result) {
      Err(:final failure) => Err(_providerFailure(failure)),
      Ok() => result,
    };
  }
}

/// Auth codes a person can act on keep their meaning; any other auth error from a
/// provider becomes "that did not work, try again or use email" (specs/20).
Failure _providerFailure(Failure f) => switch (f) {
  AuthFailure(
    code: 'signup_disabled' ||
        'identity_already_exists' ||
        'single_identity_not_deletable' ||
        'email_exists' ||
        'session_invalid',
  ) =>
    f,
  AuthFailure() => AuthFailure(code: 'provider_failed', cause: f.cause),
  _ => f,
};

final signInMethodsRepositoryProvider = Provider<SignInMethodsRepository>(
  (ref) => SignInMethodsRepository(
    auth: ref.watch(supabaseClientProvider).auth,
    sheets: ref.watch(providerSheetsProvider),
    config: ref.watch(appConfigProvider),
    api: ref.watch(apiClientProvider),
  ),
);

final providerSheetsProvider = Provider<ProviderSheets>(
  (ref) => NativeProviderSheets(ref.watch(appConfigProvider)),
);
