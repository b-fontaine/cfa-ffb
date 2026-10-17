import 'package:flutter_test/flutter_test.dart';

import '../support/invitation_world.dart';
import '../support/ui_world.dart';

/// Usage: the invitation code is stored for the role {'teacher'} in the club
/// {'Test club'}
///
/// Le code affiché existe dans le stock de documents, pour ce rôle et ce club,
/// pas encore utilisé.
Future<void> theInvitationCodeIsStoredForTheRoleInTheClub(
  WidgetTester tester,
  String role,
  String club,
) async {
  final stored = UiWorld.documents.read(
    'invitations/${shownInvitationCode(tester)}',
  );
  expect(stored, isNotNull);
  expect(stored!['role'], role);
  expect(stored['clubId'], UiWorld.clubIdNamed(club));
  expect(stored['used'], isFalse);
}
