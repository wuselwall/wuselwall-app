import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wuselwall/core/config/app_config.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/server_compat.dart';
import 'package:wuselwall/core/server/server_discovery.dart';
import 'package:wuselwall/core/server/server_info.dart';

Map<String, Object?> doc({
  String? url = 'https://api.example.org',
  int api = 1,
  String min = '1.0.0',
}) => {
  'wuselwall': 1,
  'supabase_url': ?url,
  'publishable_key': 'sb_publishable_abc',
  'api_version': api,
  'min_app_version': min,
  'household_creation': 'token',
  // A server from before social sign-in was removed still advertises Apple; the app
  // ignores it.
  'sign_in': {'password': true, 'apple': true, 'google': false},
  'features': ['calendar', 'shopping'],
};

ServerInfo info({int api = 1, String min = '1.0.0'}) =>
    ServerInfo.fromDiscovery(
      doc(api: api, min: min),
      origin: Uri.parse('https://api.example.org'),
    );

void main() {
  group('parseServerAddress', () {
    test('a host becomes an https origin', () {
      expect(
        parseServerAddress(' API.Example.org '),
        Uri.parse('https://api.example.org'),
      );
    });

    test('a URL keeps only its origin', () {
      expect(
        parseServerAddress('https://api.example.org:8443/rest/v1/?x=1'),
        Uri.parse('https://api.example.org:8443'),
      );
    });

    test('a hosted Supabase project ID is enough', () {
      expect(
        parseServerAddress('abcdefghijklmnopqrst'),
        Uri.parse('https://abcdefghijklmnopqrst.supabase.co'),
      );
    });

    test("the app's own QR payloads carry the server", () {
      expect(
        parseServerAddress(
          'wuselwall://server?url=https%3A%2F%2Fapi.example.org',
        ),
        Uri.parse('https://api.example.org'),
      );
      expect(
        parseServerAddress(
          'wuselwall://enrol?code=ABCD2345&server=https%3A%2F%2Fapi.example.org',
        ),
        Uri.parse('https://api.example.org'),
      );
      expect(parseServerAddress('wuselwall://enrol?code=ABCD2345'), isNull);
    });

    test('a pairing link carries its server in the fragment', () {
      expect(
        parseServerAddress('https://wuselwall.app/p/#ABCD2345@api.example.org'),
        Uri.parse('https://api.example.org'),
      );
    });

    test('plain http only when allowed', () {
      expect(parseServerAddress('http://192.168.1.5:54321'), isNull);
      expect(
        parseServerAddress('http://localhost:54321', allowHttp: true),
        Uri.parse('http://localhost:54321'),
      );
    });

    test('nonsense is refused', () {
      for (final raw in [
        '',
        'hello',
        'ftp://example.org',
        'https://user@x.org',
        'a b.org',
      ]) {
        expect(parseServerAddress(raw), isNull, reason: raw);
      }
    });

    test('the QR payload reads back', () {
      final server = Uri.parse('https://api.example.org');
      expect(parseServerAddress(serverQrPayload(server)), server);
      expect(displayServerAddress(server), 'api.example.org');
    });
  });

  group('ServerInfo', () {
    test('reads a discovery document', () {
      final s = info();
      expect(s.supabaseUrl, Uri.parse('https://api.example.org'));
      expect(s.publishableKey, 'sb_publishable_abc');
      expect(s.features, ['calendar', 'shopping']);
    });

    test('keeps no social sign-in, even when an older server offers it', () {
      expect(info().toJson()['sign_in'], {'password': true});
    });

    test('without supabase_url the document speaks for its own origin', () {
      final s = ServerInfo.fromDiscovery(
        doc(url: null),
        origin: Uri.parse('https://abcdefghijklmnopqrst.supabase.co'),
      );
      expect(s.supabaseUrl.host, 'abcdefghijklmnopqrst.supabase.co');
    });

    test('anything else is not a WuselWall server', () {
      final origin = Uri.parse('https://x.org');
      expect(
        () => ServerInfo.fromDiscovery({'hello': 1}, origin: origin),
        throwsFormatException,
      );
      expect(
        () => ServerInfo.fromDiscovery({
          ...doc(),
          'publishable_key': '',
        }, origin: origin),
        throwsFormatException,
      );
      expect(
        () => ServerInfo.fromDiscovery({
          ...doc(),
          'min_app_version': 'soon',
        }, origin: origin),
        throwsFormatException,
      );
    });

    test('survives being kept on the device', () {
      final s = info();
      final back = ServerInfo.fromDiscovery(
        jsonDecode(jsonEncode(s.toJson())),
        origin: Uri.parse('https://elsewhere.org'),
      );
      expect(back.toJson(), s.toJson());
    });
  });

  group('compatibility', () {
    test('the current and the previous contract are fine', () {
      expect(
        compatibility(info(api: appApiVersion), '1.0.0'),
        Compatibility.ok,
      );
      expect(
        compatibility(info(api: appApiVersion - 1), '1.0.0'),
        Compatibility.ok,
      );
      // A newer server keeps working with this app until min_app_version says otherwise.
      expect(
        compatibility(info(api: appApiVersion + 1), '1.0.0'),
        Compatibility.ok,
      );
    });

    test('an older server needs its update', () {
      expect(
        compatibility(info(api: appApiVersion - 2), '1.0.0'),
        Compatibility.serverTooOld,
      );
    });

    test('min_app_version turns an old app away', () {
      expect(
        compatibility(info(min: '1.2.0'), '1.1.9'),
        Compatibility.appTooOld,
      );
      expect(compatibility(info(min: '1.2.0'), '1.2.0+42'), Compatibility.ok);
      expect(compatibility(info(min: '1.2.0'), '1.10.0'), Compatibility.ok);
    });

    test('versions compare by number, not text', () {
      expect(compareVersions('1.10.0', '1.9.9'), 1);
      expect(compareVersions('2.0.0', '2.0.0'), 0);
      expect(compareVersions('1.0', '1.0.1'), -1);
    });
  });

  group('ServerDiscovery', () {
    final origin = Uri.parse('https://api.example.org');

    test('reads the .well-known document first', () async {
      final asked = <String>[];
      final d = ServerDiscovery(
        client: MockClient((req) async {
          asked.add(req.url.path);
          return http.Response(jsonEncode(doc()), 200);
        }),
      );
      final result = await d.discover(origin);
      expect(result, isA<Ok<ServerInfo>>());
      expect(asked, ['/.well-known/wuselwall.json']);
    });

    test('falls back to the server-info function (hosted Supabase)', () async {
      final d = ServerDiscovery(
        client: MockClient(
          (req) async => req.url.path == '/functions/v1/server-info'
              ? http.Response(jsonEncode(doc(url: null)), 200)
              : http.Response('<html>not here</html>', 404),
        ),
      );
      final result = await d.discover(origin);
      expect((result as Ok<ServerInfo>).value.supabaseUrl, origin);
    });

    test('something that answers but is not WuselWall', () async {
      final d = ServerDiscovery(
        client: MockClient((_) async => http.Response('<html>hi</html>', 200)),
      );
      final result = await d.discover(origin);
      final failure = (result as Err<ServerInfo>).failure;
      expect(failure, isA<NotFoundFailure>());
      expect(failure.code, 'not_wuselwall');
    });

    test('nothing answers', () async {
      final d = ServerDiscovery(
        client: MockClient(
          (_) async => throw const SocketException('no route'),
        ),
      );
      final result = await d.discover(origin);
      expect((result as Err).failure, isA<NetworkFailure>());
    });
  });

  group('AppConfig.forServer', () {
    const build = AppConfig(
      environment: 'store',
      supabaseUrl: '',
      supabasePublishableKey: '',
    );

    test("another operator's server gets no passkeys", () {
      // No WW_FIRST_PARTY_HOSTS in tests: every server is someone else's.
      final c = AppConfig.forServer(build, info());
      expect(c.supabaseUrl, 'https://api.example.org');
      expect(c.supabasePublishableKey, 'sb_publishable_abc');
      expect(c.passkeys, isFalse);
      expect(c.hasFixedServer, isFalse);
    });

    test('a store build without a server is not a configuration error', () {
      expect(build.validate(), isEmpty);
      expect(build.hasFixedServer, isFalse);
    });
  });
}
