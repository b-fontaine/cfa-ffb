import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'animateur@example.org'} is a {'teacher'} of the club {'Club Lyon'}
///
/// Ajoute une appartenance au compte, qui est créé (adresse vérifiée) s'il
/// n'existe pas encore.
Future<void> isAOfTheClub(
  WidgetTester tester,
  String email,
  String role,
  String club,
) async {
  await UiWorld.prepare(tester);
  final account =
      UiWorld.auth.accountOf(email) ??
      UiWorld.auth.seed(email: email, password: 'correct-horse-battery');
  UiWorld.memberships.grant(account.id, UiWorld.membership(club, role));
}
