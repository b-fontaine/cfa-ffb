import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/club_seed.dart';
import '../support/operations_world.dart';

Future<void>
lesElevesAEffacerSontMarquesEnCoursDeffacementEtAucunNestEncorePurge(
  WidgetTester tester,
) async {
  final world = OperationsWorld.current;
  for (final id in world.toErase) {
    expect(
      world.doc('clubs/c1/students/${id.value}')!['erasing'],
      isTrue,
      reason: id.value,
    );
    final attempts = [
      for (final entry in world.server.documents.entries)
        if (entry.key.contains('/attempts/') &&
            entry.value['studentId'] == id.value)
          entry.key,
    ];
    expect(attempts, hasLength(world.spec!.attemptsPerStudent));
  }
  // Les autres élèves ne sont pas marqués.
  for (final name in world.seeded!.all) {
    final id = StudentId(SeededClub.idOf(name));
    if (world.toErase.contains(id)) continue;
    expect(world.doc('clubs/c1/students/${id.value}')!['erasing'], isNull);
  }
}
