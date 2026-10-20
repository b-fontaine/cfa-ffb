import 'package:flutter_test/flutter_test.dart';

import '../support/import_world.dart';

Future<void>
leClubAClosUneSaisonApresLexportDuFichierEtNeGardeQueDesElevesDuFichier(
  WidgetTester tester,
  num kept,
) async {
  final world = ImportWorld.current
    ..seed('clubs/c1/seasons/season-closed', {
      'label': '2025-2026',
      'startDate': '2025-09-01T00:00:00.000',
      'endDate': '2026-06-30T00:00:00.000',
      'closedOn': '2026-10-20T00:00:00.000',
    });
  for (final student in world.backup!.snapshot.students.take(kept.toInt())) {
    world.seed('clubs/c1/students/${student.id.value}', {
      'firstName': 'Gardé',
      'groupIds': <String>[],
    });
  }
}
