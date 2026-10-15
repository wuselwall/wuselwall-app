import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/data/provider_sheets.dart';
import 'package:wuselwall/features/identity/data/sign_in_methods_repository.dart';
import 'package:wuselwall/features/identity/domain/sign_in_method.dart';

const _all = AppConfig(
  environment: 'test',
  supabaseUrl: 'http://localhost',
  supabasePublishableKey: 'key',
  appleSignIn: true,
  googleWebClientId: 'web.apps.googleusercontent.com',
  googleIosClientId: 'ios.apps.googleusercontent.com',
);

class _Sheets implements ProviderSheets {
  ProviderCredential? next = const ProviderCredential(
    idToken: 'id-token',
    nonce: 'raw-nonce',
  );
  var opened = 0;

  @override
  Future<ProviderCredential?> apple() async {
    opened++;
    return next;
  }

  @override
  Future<ProviderCredential?> google() async {
    opened++;
    return next;
  }
}

/// A token GoTrueClient can decode: it reads `exp` from the payload.
String _jwt(String sessionId) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  return '${part({'alg': 'HS256'})}.'
      '${part({'sub': 'user-1', 'session_id': sessionId, 'exp': exp})}.sig';
}

Map<String, Object> _session(String sessionId, {List<String>? providers}) => {
  'access_token': _jwt(sessionId),
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh-$sessionId',
  'user': {
    'id': 'user-1',
    'aud': 'authenticated',
    'created_at': '2026-10-12T00:00:00Z',
    'app_metadata': <String, Object>{},
    'user_metadata': <String, Object>{},
    'identities': [
      for (final p in providers ?? const ['email'])
        {
          'id': 'sub-$p',
          'identity_id': 'identity-$p',
          'user_id': 'user-1',
          'provider': p,
          'identity_data': {'email': 'papa@example.org'},
          'created_at': '2026-10-12T00:00:00Z',
          'last_sign_in_at': '2026-10-12T00:00:00Z',
          'updated_at': '2026-10-12T00:00:00Z',
        },
    ],
  },
};

void main() {
  SignInMethodsRepository repo({
    AppConfig config = _all,
    TargetPlatform platform = TargetPlatform.iOS,
    bool isWeb = false,
    http.Client? client,
    ProviderSheets? sheets,
  }) {
    final httpClient =
        client ?? MockClient((_) async => http.Response('{}', 500));
    return SignInMethodsRepository(
      auth: GoTrueClient(
        url: 'http://localhost/auth/v1',
        autoRefreshToken: false,
        httpClient: httpClient,
      ),
      sheets: sheets ?? _Sheets(),
      config: config,
      platform: platform,
      isWeb: isWeb,
      httpClient: httpClient,
    );
  }

  group('which providers are offered', () {
    test('Apple first and both native on an iPhone', () {
      final r = repo();
      expect(r.available(), [SignInProvider.apple, SignInProvider.google]);
      expect(r.route(SignInProvider.apple), ProviderRoute.native);
      expect(r.route(SignInProvider.google), ProviderRoute.native);
    });

    test('Google first on Android, Apple through the redirect', () {
      final r = repo(platform: TargetPlatform.android);
      expect(r.available(), [SignInProvider.google, SignInProvider.apple]);
      expect(r.route(SignInProvider.google), ProviderRoute.native);
      expect(r.route(SignInProvider.apple), ProviderRoute.redirect);
      expect(r.canLink(SignInProvider.google), isTrue);
      expect(r.canLink(SignInProvider.apple), isFalse);
    });

    test('both through the redirect on the web, and never linked there', () {
      final r = repo(isWeb: true);
      expect(r.available(), [SignInProvider.google, SignInProvider.apple]);
      expect(r.route(SignInProvider.apple), ProviderRoute.redirect);
      expect(r.canLink(SignInProvider.apple), isFalse);
      expect(r.canLink(SignInProvider.google), isFalse);
    });

    // ADR-018, decision 6: an ID token addressed to this app never goes to another
    // operator's server; their own redirect clients do the work there.
    const otherServer = AppConfig(
      environment: 'test',
      supabaseUrl: 'https://api.example.org',
      supabasePublishableKey: 'key',
      appleSignIn: true,
      googleSignIn: true,
      nativeSignIn: false,
    );

    test(
      "another operator's server: the redirect on an iPhone, never a sheet",
      () {
        final r = repo(config: otherServer);
        expect(r.route(SignInProvider.apple), ProviderRoute.redirect);
        expect(r.route(SignInProvider.google), ProviderRoute.redirect);
        expect(r.canLink(SignInProvider.apple), isFalse);
      },
    );

    test("another operator's server: the redirect on Android", () {
      final r = repo(config: otherServer, platform: TargetPlatform.android);
      expect(r.available(), [SignInProvider.google, SignInProvider.apple]);
      expect(r.route(SignInProvider.google), ProviderRoute.redirect);
      expect(r.canLink(SignInProvider.google), isFalse);
    });

    test(
      "another operator's server without Apple or Google offers neither",
      () {
        final r = repo(
          config: const AppConfig(
            environment: 'test',
            supabaseUrl: 'https://api.example.org',
            supabasePublishableKey: 'key',
            googleSignIn: false,
            nativeSignIn: false,
          ),
        );
        expect(r.available(), isEmpty);
      },
    );

    test('nothing without configuration — no button that would fail', () {
      final r = repo(
        config: const AppConfig(
          environment: 'test',
          supabaseUrl: 'http://localhost',
          supabasePublishableKey: 'key',
        ),
      );
      expect(r.available(), isEmpty);
    });

    test('no native Google on iOS without the iOS client', () {
      final r = repo(
        config: const AppConfig(
          environment: 'test',
          supabaseUrl: 'http://localhost',
          supabasePublishableKey: 'key',
          googleWebClientId: 'web',
        ),
      );
      expect(r.available(), isEmpty);
    });
  });

  group('signing in with a native sheet', () {
    test(
      'sends the ID token and the raw nonce to the id-token grant',
      () async {
        final requests = <http.Request>[];
        final r = repo(
          platform: TargetPlatform.android,
          client: MockClient((req) async {
            requests.add(req);
            return http.Response(jsonEncode(_session('s1')), 200);
          }),
        );

        final result = await r.signIn(SignInProvider.google);

        expect(result, isA<Ok<void>>());
        expect(requests.single.url.path, '/auth/v1/token');
        expect(requests.single.url.queryParameters['grant_type'], 'id_token');
        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['provider'], 'google');
        expect(body['id_token'], 'id-token');
        expect(body['nonce'], 'raw-nonce');
      },
    );

    test('a cancelled sheet is not an error and sends nothing', () async {
      var requests = 0;
      final sheets = _Sheets()..next = null;
      final r = repo(
        sheets: sheets,
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );

      expect(await r.signIn(SignInProvider.apple), isA<Ok<void>>());
      expect(sheets.opened, 1);
      expect(requests, 0);
    });

    test('an address without an account says so', () async {
      final r = repo(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 422,
              'error_code': 'signup_disabled',
              'msg': 'Signups not allowed for this instance',
            }),
            422,
          ),
        ),
      );

      final result = await r.signIn(SignInProvider.apple);

      expect(result.failureOrNull, isA<AuthFailure>());
      expect(result.failureOrNull?.code, 'signup_disabled');
    });

    test('any other provider error becomes "try again or use email"', () async {
      final r = repo(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'invalid request',
              'error_description': 'Bad ID token',
            }),
            400,
          ),
        ),
      );

      final result = await r.signIn(SignInProvider.google);

      expect(result.failureOrNull?.code, 'provider_failed');
    });
  });

  group('linking', () {
    test('keeps this device\'s session and signs the extra one out', () async {
      final calls = <String>[];
      final s1 = _session('s1');
      final s1Token = s1['access_token']! as String;
      final client = MockClient((req) async {
        final auth = req.headers['Authorization'] ?? '';
        final grant = req.url.queryParameters['grant_type'];
        calls.add(
          '${req.url.path}?${grant ?? req.url.queryParameters['scope']}'
          ' as ${auth == 'Bearer $s1Token' ? 's1' : 'other'}',
        );
        return switch ((req.url.path, grant)) {
          // The sign-in that started this device's session.
          ('/auth/v1/token', 'id_token')
              when !(jsonDecode(req.body) as Map<String, dynamic>).containsKey(
                'link_identity',
              ) =>
            http.Response(jsonEncode(s1), 200),
          // The link answers with a second session …
          ('/auth/v1/token', 'id_token') => http.Response(
            jsonEncode(_session('s2', providers: ['email', 'google'])),
            200,
          ),
          // … which is signed out; s1 is refreshed instead.
          ('/auth/v1/logout', _) => http.Response('', 204),
          ('/auth/v1/user', _) => http.Response(
            jsonEncode(_session('s1', providers: ['email', 'google'])['user']),
            200,
          ),
          ('/auth/v1/token', 'refresh_token') => http.Response(
            jsonEncode(_session('s1', providers: ['email', 'google'])),
            200,
          ),
          _ => http.Response('{}', 404),
        };
      });
      final r = repo(platform: TargetPlatform.android, client: client);
      await r.signIn(SignInProvider.google);
      calls.clear();

      final result = await r.link(SignInProvider.google);

      expect(result, isA<Ok<bool>>());
      expect((result as Ok<bool>).value, isTrue);
      expect(calls, [
        '/auth/v1/token?id_token as s1',
        '/auth/v1/logout?local as other',
        '/auth/v1/token?refresh_token as other',
      ]);
      final methods = await r.methods();
      expect((methods as Ok<List<SignInMethod>>).value.map((m) => m.provider), [
        SignInMethodKind.email,
        SignInMethodKind.google,
      ]);
    });

    test('is refused where only the redirect exists', () async {
      final r = repo(platform: TargetPlatform.android);
      final result = await r.link(SignInProvider.apple);
      expect(result.failureOrNull?.code, 'provider_failed');
    });
  });
}
