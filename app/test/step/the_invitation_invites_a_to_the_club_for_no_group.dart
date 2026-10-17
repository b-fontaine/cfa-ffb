import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the invitation {'TEACHERCODE'} invites a {'teacher'} to the club
/// {'Test club'} for no group
///
/// Invitation valable (durée de son rôle), sans groupe ni fiche.
Future<void> theInvitationInvitesAToTheClubForNoGroup(
  WidgetTester tester,
  String code,
  String role,
  String club,
) async {
  await UiWorld.prepare(tester);
  UiWorld.seedInvitation(code: code, club: club, role: role);
}
