import 'dart:math';

import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvitationCode.tryParse', () {
    test('normalises case, spaces and dashes', () {
      expect(InvitationCode.tryParse('abcd-efgh jkmn')?.value, 'ABCDEFGHJKMN');
    });

    test('accepts from 10 to 32 characters, nothing outside', () {
      expect(InvitationCode.tryParse('ABCDEFGHJ'), isNull);
      expect(InvitationCode.tryParse('ABCDEFGHJK')?.value, 'ABCDEFGHJK');
      expect(InvitationCode.tryParse('A' * 32)?.value, 'A' * 32);
      expect(InvitationCode.tryParse('A' * 33), isNull);
    });

    test(
      'refuses characters outside the Base32 alphabet (0, 1, 8, 9, symbols)',
      () {
        for (final bad in [
          'ABCDEFGHJK0',
          'ABCDEFGHJK1',
          'ABCDEFGHJK8',
          'ABCDEFGHJK9',
          'ABCDEFGHJK!',
          'ÉBCDEFGHJKM',
        ]) {
          expect(InvitationCode.tryParse(bad), isNull, reason: bad);
        }
      },
    );

    test('accepts every character of the alphabet', () {
      expect(
        InvitationCode.tryParse(invitationAlphabet)?.value,
        invitationAlphabet,
      );
    });
  });

  group('InvitationCode.generate', () {
    test('is twelve characters of the alphabet, and parses back', () {
      final code = InvitationCode.generate(Random(1));
      expect(code.value, hasLength(generatedInvitationCodeLength));
      expect(InvitationCode.tryParse(code.value), code);
    });

    test('uses the whole alphabet and never an ambiguous character', () {
      final random = Random(7);
      final seen = <String>{};
      for (var i = 0; i < 400; i++) {
        seen.addAll(InvitationCode.generate(random).value.split(''));
      }
      expect(seen, invitationAlphabet.split('').toSet());
      expect(seen.intersection({'0', '1', '8', '9'}), isEmpty);
    });

    test('two draws differ', () {
      final random = Random(3);
      expect(
        InvitationCode.generate(random),
        isNot(InvitationCode.generate(random)),
      );
    });
  });

  test('readable groups the code by four, with dashes', () {
    expect(InvitationCode.tryParse('ABCDEFGHJKMN')!.readable, 'ABCD-EFGH-JKMN');
    expect(InvitationCode.tryParse('ABCDEFGHJKM')!.readable, 'ABCD-EFGH-JKM');
    expect(
      InvitationCode.tryParse('abcd-efgh-jkmn')!.readable,
      'ABCD-EFGH-JKMN',
    );
  });

  test('the bounds are the ones of the rules', () {
    expect(minInvitationCodeLength, 10);
    expect(maxInvitationCodeLength, 32);
    expect(invitationAlphabet, hasLength(32));
  });
}
