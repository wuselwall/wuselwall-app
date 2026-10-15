import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';

  test('a code is read in any case, with or without the hyphen', () {
    expect(parseInvitation('K7QM-3XRP'), 'K7QM3XRP');
    expect(parseInvitation(' k7qm 3xrp '), 'K7QM3XRP');
    expect(parseInvitation('k7qm3xrp'), 'K7QM3XRP');
  });

  test('a token is read as lower-case hex', () {
    expect(parseInvitation(token.toUpperCase()), token);
  });

  test('the invitation link gives its token; the server part is dropped', () {
    expect(parseInvitation('https://wuselwall.app/i/#$token'), token);
    expect(
      parseInvitation('https://wuselwall.app/i/#$token@api.example.org'),
      token,
    );
  });

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

  test('the link a guardian shares', () {
    expect(inviteLink(token), 'https://wuselwall.app/i/#$token');
  });
}
