import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';

  test('a code is read in any case, with or without the hyphen', () {
    expect(parseInvitation('K7QM-3XRP')?.secret, 'K7QM3XRP');
    expect(parseInvitation(' k7qm 3xrp ')?.secret, 'K7QM3XRP');
    expect(parseInvitation('k7qm3xrp')?.secret, 'K7QM3XRP');
  });

  test('a token is read as lower-case hex', () {
    expect(parseInvitation(token.toUpperCase())?.secret, token);
  });

  test(
    'the invitation link gives its token and, when it has one, its server',
    () {
      final plain = parseInvitation('https://wuselwall.app/i/#$token');
      expect(plain?.secret, token);
      expect(plain?.server, isNull);
      final named = parseInvitation(
        'https://wuselwall.app/i/#$token@api.example.org',
      );
      expect(named?.secret, token);
      expect(named?.server, Uri.parse('https://api.example.org'));
    },
  );

  test('other links and other text give nothing', () {
    expect(parseInvitation('https://evil.example/i/#$token'), isNull);
    expect(parseInvitation('https://wuselwall.app/p/#K7QM3XRP'), isNull);
    expect(
      parseInvitation('K7QM3XR0'),
      isNull,
      reason: 'no zero in the alphabet',
    );
    expect(parseInvitation('Hallo'), isNull);
    expect(parseInvitation(''), isNull);
  });

  test('the link a guardian shares names the server', () {
    expect(inviteLink(token), 'https://wuselwall.app/i/#$token');
    expect(
      inviteLink(token, server: Uri.parse('https://api.example.org')),
      'https://wuselwall.app/i/#$token@api.example.org',
    );
  });
}
