import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/setup_link.dart';

void main() {
  const token = '0123456789abcdef01234567';
  test('server-origin setup fragment carries its separate API origin', () {
    final link = parseSetupLink(
      'https://web.example.org/#setup=$token&server=https%3A%2F%2Fapi.example.org',
    );
    expect(link?.server, Uri.parse('https://api.example.org'));
    expect(link?.token, token);
    expect(link.toString(), isNot(contains(token)));
  });
  test('handoff QR retains capability but plain QR stays compatible', () {
    final server = Uri.parse('https://api.example.org');
    final payload = serverQrPayload(
      server,
      setupToken: token,
      webOrigin: Uri.parse('https://web.example.org'),
    );
    expect(parseSetupLink(payload)?.token, token);
    expect(parseSetupLink(payload)?.server, server);
    expect(Uri.parse(payload).host, 'web.example.org');
    expect(Uri.parse(payload).query, isEmpty);
    expect(serverQrPayload(server), server.toString());
  });
  test('rejects query secrets, malformed tokens and non-origin destinations', () {
    for (final raw in [
      'https://web.example.org/?setup=$token&server=https://api.example.org',
      'https://web.example.org/#setup=bad&server=https://api.example.org',
      'https://web.example.org/#setup=$token&server=https://api.example.org/path',
      'https://web.example.org/#setup=$token&server=http://api.example.org',
      'https://web.example.org/#setup=$token&setup=$token&server=https://api.example.org',
      'https://wuselwall.app/i/#$token@api.example.org',
      'https://api.example.org',
    ]) {
      expect(parseSetupLink(raw), isNull);
    }
  });
}
