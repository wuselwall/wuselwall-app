import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/server/server_link.dart';
import 'package:wuselwall/features/identity/domain/pairing.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';
  final server = Uri.parse('https://api.example.org');

  group('the server in the fragment', () {
    test('host without port, port only when it is not the default', () {
      expect(linkServerHost(server), 'api.example.org');
      expect(
        linkServerHost(Uri.parse('https://api.example.org:443')),
        'api.example.org',
      );
      expect(
        linkServerHost(Uri.parse('https://api.example.org:8443')),
        'api.example.org:8443',
      );
    });

    test('invitation links round-trip with and without a port', () {
      for (final s in [server, Uri.parse('https://api.example.org:8443')]) {
        final parsed = parseInvitation(inviteLink(token, server: s));
        expect(parsed, LinkSecret(token, server: s));
      }
    });

    test('pairing QR payloads round-trip', () {
      final payload = pairingQrPayload('K7QM3XRP', server: server);
      expect(payload, 'https://wuselwall.app/p/#K7QM3XRP@api.example.org');
      expect(parsePairingCode(payload), LinkSecret('K7QM3XRP', server: server));
      expect(
        parsePairingCode(
          pairingQrPayload('K7QM3XRP', server: Uri.parse('https://a.b:8443')),
        )?.server,
        Uri.parse('https://a.b:8443'),
      );
    });

    test('the old forms without a host still work', () {
      expect(
        parseInvitation('https://wuselwall.app/i/#$token')?.server,
        isNull,
      );
      expect(
        parsePairingCode('https://wuselwall.app/p/#K7QM3XRP')?.secret,
        'K7QM3XRP',
      );
      expect(
        parsePairingCode('https://wuselwall.app/p/K7QM-3XRP')?.server,
        isNull,
      );
    });

    test('a typed code can carry the server', () {
      expect(
        parseInvitation('k7qm-3xrp@Api.Example.org'),
        LinkSecret('K7QM3XRP', server: server),
      );
      expect(parsePairingCode('K7QM3XRP@api.example.org')?.server, server);
    });

    for (final language in ['en', 'fr', 'es']) {
      test('the $language landing path is read too', () {
        expect(
          parseInvitation(
            'https://wuselwall.app/$language/i/#$token@api.example.org',
          ),
          LinkSecret(token, server: server),
        );
        expect(
          parseAppLink(
            'https://wuselwall.app/$language/p/#K7QM3XRP@api.example.org',
          ),
          OpenedLink(LinkKind.pairing, 'K7QM3XRP', server: server),
        );
      });
    }

    test('a host that cannot be a server makes the link unreadable', () {
      expect(
        parseInvitation('https://wuselwall.app/i/#$token@nonsense'),
        isNull,
      );
      expect(parseInvitation('K7QM3XRP@'), isNull);
      expect(parsePairingCode('K7QM3XRP@a b.org'), isNull);
    });
  });

  group('parseAppLink', () {
    test('tells invitations from pairing codes by their path', () {
      expect(
        parseAppLink('https://wuselwall.app/i/#K7QM3XRP'),
        const OpenedLink(LinkKind.invitation, 'K7QM3XRP'),
      );
      expect(
        parseAppLink('https://wuselwall.app/p/#K7QM3XRP'),
        const OpenedLink(LinkKind.pairing, 'K7QM3XRP'),
      );
    });

    test('ignores everything else', () {
      expect(parseAppLink('https://evil.example/i/#$token'), isNull);
      expect(parseAppLink('https://wuselwall.app/'), isNull);
      expect(parseAppLink('https://wuselwall.app/i/'), isNull);
      expect(
        parseAppLink('ch.goomba.wuselwall://login-callback?code=1'),
        isNull,
      );
      expect(parseAppLink('K7QM3XRP'), isNull);
    });
  });

  group('decideLink', () {
    final other = Uri.parse('https://other.example.org');

    test('no server yet: use the link\'s', () {
      expect(
        decideLink(linkServer: server, current: null, signedIn: false),
        LinkVerdict.connect,
      );
    });

    test('no server and none in the link: ask for the address', () {
      expect(
        decideLink(linkServer: null, current: null, signedIn: false),
        LinkVerdict.needsServer,
      );
    });

    test('the same server continues, whatever the case or default port', () {
      expect(
        decideLink(
          linkServer: Uri.parse('https://API.example.org:443'),
          current: server,
          signedIn: true,
        ),
        LinkVerdict.proceed,
      );
    });

    test('a link without a server means the one the app is on', () {
      expect(
        decideLink(linkServer: null, current: server, signedIn: true),
        LinkVerdict.proceed,
      );
    });

    test('another port is another server', () {
      expect(
        decideLink(
          linkServer: Uri.parse('https://api.example.org:8443'),
          current: server,
          signedIn: false,
        ),
        LinkVerdict.offerSwitch,
      );
    });

    test('another server: offer a switch only when nobody is signed in', () {
      expect(
        decideLink(linkServer: other, current: server, signedIn: false),
        LinkVerdict.offerSwitch,
      );
      expect(
        decideLink(linkServer: other, current: server, signedIn: true),
        LinkVerdict.otherServer,
      );
    });
  });

  group('links that are not the app\'s (F2)', () {
    test('only https links of the links site are read', () {
      const pairing = 'wuselwall.app/p/#K7QM3XRP@api.example.org';
      expect(parseAppLink('https://$pairing'), isNotNull);
      for (final scheme in ['http', 'wuselwall', 'ftp']) {
        expect(parseAppLink('$scheme://$pairing'), isNull, reason: scheme);
        expect(parsePairingCode('$scheme://$pairing'), isNull, reason: scheme);
        expect(
          parseInvitation('$scheme://wuselwall.app/i/#$token@api.example.org'),
          isNull,
          reason: scheme,
        );
      }
      expect(parseAppLink('https://someone@wuselwall.app/p/#K7QM3XRP'), isNull);
    });

    test('a link carrying a session or a sign-in callback is refused', () {
      for (final extra in [
        '#access_token=a&refresh_token=b&expires_in=3600&token_type=bearer',
        '#refresh_token=b',
        '?code=0f1e2d',
        '?token_type=bearer',
        '#error=access_denied&error_description=x',
        '?error_code=otp_expired',
      ]) {
        expect(
          parseAppLink('https://wuselwall.app/i/$extra'),
          isNull,
          reason: extra,
        );
        expect(
          parseInvitation('https://wuselwall.app/i/$extra'),
          isNull,
          reason: extra,
        );
        expect(
          parsePairingCode('https://wuselwall.app/p/K7QM3XRP$extra'),
          isNull,
          reason: extra,
        );
        expect(
          carriesSessionParameters(Uri.parse('https://wuselwall.app/i/$extra')),
          isTrue,
          reason: extra,
        );
      }
      // The app's own fragments are not parameters.
      expect(
        carriesSessionParameters(
          Uri.parse('https://wuselwall.app/i/#$token@api.example.org'),
        ),
        isFalse,
      );
      // An unrelated query does not hide a valid invitation.
      expect(
        parseInvitation('https://wuselwall.app/i/?lang=de#$token')?.secret,
        token,
      );
    });
  });
}
