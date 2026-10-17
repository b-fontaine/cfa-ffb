import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the member {'new@example.org'} of the club {'Club Nice'} has the
/// role {'director'}
Future<void> theMemberOfTheClubHasTheRole(
  WidgetTester tester,
  String email,
  String club,
  String role,
) async {
  final account = UiWorld.auth.accountOf(email)!;
  final stored = UiWorld.documents.read(
    'clubs/${UiWorld.clubIdOf(club).value}/members/${account.id.value}',
  );
  expect(stored, isNotNull, reason: 'aucun member pour $email');
  expect(stored!['role'], role);
  expect(stored['uid'], account.id.value);
}
