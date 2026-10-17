import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the invitation {'EXPIREDCODE'} invites a {'teacher'} to the club
/// {'Test club'} for no group and expired on {'2026-10-10'}
///
/// Invitation dont la date d'expiration est passée.
Future<void> theInvitationInvitesAToTheClubForNoGroupAndExpiredOn(
  WidgetTester tester,
  String code,
  String role,
  String club,
  String date,
) async {
  await UiWorld.prepare(tester);
  UiWorld.seedInvitation(
    code: code,
    club: club,
    role: role,
    expiresAt: DateTime.parse(date),
  );
}
