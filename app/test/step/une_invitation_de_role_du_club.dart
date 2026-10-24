import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

/// [state] : `valable`, `utilisée` ou `échue` (à l'heure de l'appareil).
Future<void> uneInvitationDeRoleDuClub(
  WidgetTester tester,
  String code,
  String role,
  String clubId,
  String state,
) async {
  expect(['valable', 'utilisée', 'échue'], contains(state));
  OperationsWorld.current.seedInvitation(
    code,
    role: role,
    clubId: clubId,
    used: state == 'utilisée',
    expired: state == 'échue',
  );
}
