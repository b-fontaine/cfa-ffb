import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void> leMarqueurDimportIndiqueTousLesLotsTermines(
  WidgetTester tester,
) async {
  final marker = ImportWorld.current.marker()!;
  expect(marker['done'], marker['lots']);
  expect(marker['state'], 'done');
  // Aucun identifiant d'élève : des empreintes, des compteurs, un rôle,
  // l'auteur (pseudonyme : lui seul fait avancer le marqueur).
  expect(marker.keys.toSet(), {
    'fileId',
    'planId',
    'lots',
    'done',
    'writes',
    'restored',
    'role',
    'createdBy',
    'state',
    'startedAt',
    'updatedAt',
  });
  expect('$marker', isNot(contains('Élève')));
}
