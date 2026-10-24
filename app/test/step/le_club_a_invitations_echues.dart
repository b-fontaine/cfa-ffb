import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

/// Des invitations échues du club, d'enseignant, d'élève et de parent à tour
/// de rôle (le directeur les liste rôle par rôle).
Future<void> leClubAInvitationsEchues(WidgetTester tester, num count) async {
  const roles = ['teacher', 'student', 'guardian'];
  String code(int i) => [
    'EXPIRED',
    for (var n = i, k = 0; k < 3; n ~/= 32, k++) invitationAlphabet[n % 32],
  ].join();
  for (var i = 0; i < count.toInt(); i++) {
    OperationsWorld.current.seedInvitation(
      code(i),
      role: roles[i % roles.length],
      expired: true,
    );
  }
  expect(OperationsWorld.current.invitationCodes(), hasLength(count.toInt()));
}
