import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/features/sign_in/domain/credentials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPlausibleEmail', () {
    test('accepts the usual shapes, with surrounding spaces', () {
      expect(isPlausibleEmail('coach@example.org'), isTrue);
      expect(isPlausibleEmail('  a.b+c@sub.example.fr '), isTrue);
    });

    test('refuses what is not an address', () {
      for (final bad in [
        '',
        'coach',
        'coach@',
        '@example.org',
        'a@b',
        'a b@c.d',
      ]) {
        expect(isPlausibleEmail(bad), isFalse, reason: bad);
      }
    });
  });

  group('InvitationCode.parse', () {
    test('normalises case, spaces and dashes', () {
      expect(InvitationCode.parse('abcd-efgh jkmn').value, 'ABCDEFGHJKMN');
    });

    test('accepts exactly the minimum length', () {
      expect(InvitationCode.parse('ABCDEFGHJK').value, 'ABCDEFGHJK');
    });

    test('refuses a short code', () {
      expect(
        () => InvitationCode.parse('ABCDEFGHJ'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.code,
            'code',
            AuthFailureCode.invalidInvitationCode,
          ),
        ),
      );
    });

    test('refuses characters outside the Base32 alphabet', () {
      for (final bad in [
        'ABCDEFGHJK1',
        'ABCDEFGHJK0',
        'ABCDEFGHJK8',
        'ABCDEFGHJK!',
      ]) {
        expect(
          () => InvitationCode.parse(bad),
          throwsA(isA<AuthFailure>()),
          reason: bad,
        );
      }
    });
  });

  test('the minimum lengths are the ones of the ADR (10 and 10)', () {
    expect(minPasswordLength, 10);
    expect(minInvitationCodeLength, 10);
  });

  test('AuthFailure prints its code, with the detail when there is one', () {
    expect(
      const AuthFailure(AuthFailureCode.network).toString(),
      'AuthFailure(network)',
    );
    expect(
      const AuthFailure(AuthFailureCode.network, 'x').toString(),
      'AuthFailure(network: x)',
    );
  });
}
