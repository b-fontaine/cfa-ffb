import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

/// Un autre appareil (l'enseignant qui l'a créée, l'administrateur) révoque
/// l'invitation [code] après que la clôture l'a listée, juste avant le lot
/// qui la supprime.
Future<void> linvitationEstRevoqueeJusteAvantLeLotQuiLaSupprime(
  WidgetTester tester,
  String code,
) async {
  final world = OperationsWorld.current;
  final path = 'invitations/$code';
  world.store.beforeValidate = (operations) {
    if (operations.any((op) => op is DeleteOp && op.path == path)) {
      world.server.remove(path);
      world.store.beforeValidate = null;
    }
  };
}
