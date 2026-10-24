import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ui_world.dart';

/// Usage: the connection will drop just before the account itself is deleted
///
/// La purge des données du club passe ; la suppression du compte
/// d'authentification, elle, échoue une fois faute de réseau.
Future<void> theConnectionWillDropJustBeforeTheAccountItselfIsDeleted(
  WidgetTester tester,
) async {
  UiWorld.auth.nextDeletionFailure = AuthFailureCode.network;
}
