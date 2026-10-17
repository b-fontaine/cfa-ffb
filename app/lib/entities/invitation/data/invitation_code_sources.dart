import 'dart:math';

import 'package:billard_cfa/entities/invitation/domain/invitation_code_source.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:injectable/injectable.dart';

/// Codes tirés au hasard cryptographique (production).
@LazySingleton(as: InvitationCodeSource, env: [Environment.prod])
class SecureInvitationCodeSource implements InvitationCodeSource {
  SecureInvitationCodeSource() : _random = Random.secure();

  final Random _random;

  @override
  InvitationCode next() => InvitationCode.generate(_random);
}

/// Codes prévisibles des tests et des scénarios BDD : `TESTCODEAAAA`,
/// `TESTCODEAAAB`, … (douze caractères de l'alphabet Base32).
@LazySingleton(as: InvitationCodeSource, env: [Environment.test])
class SequentialInvitationCodeSource implements InvitationCodeSource {
  int _count = 0;

  @override
  InvitationCode next() {
    var n = _count++;
    final suffix = List.filled(4, 'A');
    for (var i = 3; i >= 0; i--) {
      suffix[i] = invitationAlphabet[n % invitationAlphabet.length];
      n ~/= invitationAlphabet.length;
    }
    return InvitationCode.tryParse('TESTCODE${suffix.join()}')!;
  }
}
