import 'package:flutter_test/flutter_test.dart';

import '../support/account_deletion_world.dart';
import '../support/ui_world.dart';

/// Usage: the invitation issued by {'coach@example.org'} no longer exists
Future<void> theInvitationIssuedByNoLongerExists(
  WidgetTester tester,
  String email,
) async {
  final code = AccountDeletionWorld.invitationOf(email);
  expect(UiWorld.documents.read('invitations/$code'), isNull);
}
