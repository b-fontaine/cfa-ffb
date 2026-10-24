import 'package:flutter_test/flutter_test.dart';

import '../support/account_deletion_world.dart';
import '../support/ui_world.dart';

/// Usage: no member exists for {'new@example.org'} in the club {'Test club'}
///
/// Vaut aussi pour un compte supprimé depuis (son identifiant est retrouvé).
Future<void> noMemberExistsForInTheClub(
  WidgetTester tester,
  String email,
  String club,
) async {
  final uid = AccountDeletionWorld.uidOf(email);
  expect(
    UiWorld.documents.read(
      'clubs/${UiWorld.clubIdOf(club).value}/members/${uid.value}',
    ),
    isNull,
  );
}
