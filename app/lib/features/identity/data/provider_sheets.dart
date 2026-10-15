import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/error/failure.dart';

/// An ID token from a provider's own sheet, ready for Supabase's id-token grant.
class ProviderCredential {
  const ProviderCredential({
    required this.idToken,
    required this.nonce,
    this.givenName,
    this.familyName,
    this.authorizationCode,
  });

  final String idToken;

  /// The raw nonce. The sheet was given its SHA-256, which the token carries and
  /// Supabase checks against this value, so a token cannot be replayed elsewhere.
  final String nonce;

  /// Apple sends the name only on the first authorisation, and never in the token.
  final String? givenName;
  final String? familyName;

  /// Apple's one-time authorisation code. The server exchanges it for a refresh token, which
  /// revokes Apple's access when the account is deleted (apple-token, specs/20).
  final String? authorizationCode;
}

/// The platforms' native sign-in sheets (specs/20, "With Apple", "With Google").
/// Each returns null when the person cancelled: a choice, not an error.
abstract interface class ProviderSheets {
  Future<ProviderCredential?> apple();
  Future<ProviderCredential?> google();
}

class NativeProviderSheets implements ProviderSheets {
  NativeProviderSheets(this._config);

  final AppConfig _config;

  /// google_sign_in takes its nonce once, in `initialize`, so there is one per launch.
  Future<String>? _googleNonce;

  @override
  Future<ProviderCredential?> apple() async {
    final nonce = _randomNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256(nonce),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw AuthFailure(code: 'provider_failed', cause: e);
    }
    final token = credential.identityToken;
    if (token == null) throw const AuthFailure(code: 'provider_failed');
    return ProviderCredential(
      idToken: token,
      nonce: nonce,
      givenName: credential.givenName,
      familyName: credential.familyName,
      authorizationCode: credential.authorizationCode,
    );
  }

  @override
  Future<ProviderCredential?> google() async {
    final nonce = await (_googleNonce ??= _initGoogle());
    try {
      // The default request is openid, email and profile; nothing more is ever asked.
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const AuthFailure(code: 'provider_failed');
      return ProviderCredential(idToken: token, nonce: nonce);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthFailure(code: 'provider_failed', cause: e);
    }
  }

  Future<String> _initGoogle() async {
    final nonce = _randomNonce();
    try {
      await GoogleSignIn.instance.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? _config.googleIosClientId
            : null,
        serverClientId: _config.googleWebClientId,
        nonce: _sha256(nonce),
      );
    } catch (e) {
      _googleNonce = null;
      throw AuthFailure(code: 'provider_failed', cause: e);
    }
    return nonce;
  }

  static String _randomNonce() {
    final random = Random.secure();
    return base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
  }

  static String _sha256(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
