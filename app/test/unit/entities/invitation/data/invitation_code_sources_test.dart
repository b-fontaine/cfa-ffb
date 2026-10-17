import 'package:billard_cfa/entities/invitation/data/invitation_code_sources.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecureInvitationCodeSource', () {
    test('draws a 12-character Base32 code that parses back unchanged', () {
      final code = SecureInvitationCodeSource().next();

      expect(code.value, hasLength(generatedInvitationCodeLength));
      expect(code.value, matches(RegExp(r'^[A-Z2-7]{12}$')));
      expect(InvitationCode.tryParse(code.value)?.value, code.value);
    });

    test('never repeats a code (60 bits drawn from a secure source)', () {
      final source = SecureInvitationCodeSource();

      final codes = {for (var i = 0; i < 200; i++) source.next().value};

      expect(codes, hasLength(200));
    });

    test('uses the whole alphabet, not a partial one', () {
      final source = SecureInvitationCodeSource();
      final letters = {
        for (var i = 0; i < 200; i++) ...source.next().value.split(''),
      };

      // 2 400 tirages sur 32 symboles : un alphabet partiel se verrait ici.
      expect(letters.length, greaterThanOrEqualTo(30));
    });

    test('two sources do not draw the same sequence (no fixed seed)', () {
      final first = SecureInvitationCodeSource();
      final second = SecureInvitationCodeSource();

      // `Random(1)` donnerait toujours la même suite à chaque instance.
      expect(first.next().value, isNot(second.next().value));
    });
  });

  group('SequentialInvitationCodeSource', () {
    test('draws predictable codes, one after the other', () {
      final source = SequentialInvitationCodeSource();

      expect(source.next().value, 'TESTCODEAAAA');
      expect(source.next().value, 'TESTCODEAAAB');
    });
  });
}
