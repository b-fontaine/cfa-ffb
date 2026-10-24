import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

/// [codes] : les codes restants, séparés par des virgules (vide : aucun).
Future<void> ilResteLesInvitations(WidgetTester tester, String codes) async {
  final expected = [
    for (final code in codes.split(','))
      if (code.trim().isNotEmpty) code.trim(),
  ]..sort();
  expect(OperationsWorld.current.invitationCodes(), expected);
}
