import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: {'root@example.org'} is an administrator
///
/// Le compte (créé, adresse vérifiée) a son document `admins/{uid}`, vide comme
/// celui que l'on crée à la main dans la console : aucun club, aucun member.
Future<void> isAnAdministrator(WidgetTester tester, String email) async {
  await UiWorld.prepare(tester);
  final account =
      UiWorld.auth.accountOf(email) ??
      UiWorld.auth.seed(email: email, password: 'correct-horse-battery');
  UiWorld.documents.seed('admins/${account.id.value}', {});
}
