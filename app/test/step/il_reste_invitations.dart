import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> ilResteInvitations(WidgetTester tester, num count) async {
  expect(OperationsWorld.current.invitationCodes(), hasLength(count.toInt()));
}
