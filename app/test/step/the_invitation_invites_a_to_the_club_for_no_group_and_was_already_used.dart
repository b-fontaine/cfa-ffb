import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the invitation {'USEDCODEUSED'} invites a {'teacher'} to the club
/// {'Test club'} for no group and was already used
///
/// Invitation déjà consommée par un autre compte.
Future<void> theInvitationInvitesAToTheClubForNoGroupAndWasAlreadyUsed(
  WidgetTester tester,
  String code,
  String role,
  String club,
) async {
  await UiWorld.prepare(tester);
  UiWorld.seedInvitation(code: code, club: club, role: role, used: true);
}
