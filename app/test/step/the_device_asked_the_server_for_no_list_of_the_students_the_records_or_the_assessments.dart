import 'package:flutter_test/flutter_test.dart';

import '../support/family_world.dart';

/// Usage: the device asked the server for no list of the students, the
/// records or the assessments
///
/// Aucune écriture, aucune liste d'une collection entière (élèves, camarades,
/// séances) et rien de ce que les règles cachent à une famille (saisies,
/// bilans, « Vu », appartenances, archives) ; seule exception, la découverte
/// de ses propres clubs à la connexion (`members` filtré sur son `uid`).
Future<void>
theDeviceAskedTheServerForNoListOfTheStudentsTheRecordsOrTheAssessments(
  WidgetTester tester,
) async {
  const hidden = [
    'memberships',
    'records',
    'assessments',
    'acknowledgements',
    'archives',
  ];
  expect(FamilyWorld.requests, isNotEmpty);
  for (final request in FamilyWorld.requests) {
    expect(request, isNot(startsWith('write ')));
    expect(request, isNot(startsWith('list ')));
    expect(request, isNot(startsWith('watch collection ')));
    if (request.startsWith('group ')) {
      expect(request, startsWith('group members uid='));
    }
    for (final name in hidden) {
      expect(request, isNot(contains('/$name')), reason: request);
    }
  }
}
